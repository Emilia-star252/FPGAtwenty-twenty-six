"""DC-DC（四开关 buck-boost）工况仿真 + 标注，用于 NPU 训练集生成。

目的
----
板上真实采样还没有成规模数据，先用带物理约束的仿真把「训练 -> ONNX -> 板上 NPU 推理」
整条链路打通。等真实采样（host.py 的 CSV / 板内日志）到位后，用同一个 CSV 表头喂给
train.py 即可重训，代码不用改。

模型假设（都写在这里，便于评审时质疑）
--------------------------------------
* 四开关 buck-boost，单占空比近似：Vout = Vin * d / (1 - d)  =>  d = Vout / (Vin + Vout)
  这一条同时覆盖降压（Vset<Vin）和升压（Vset>Vin）区，d 在 0..0.95 内。
* 输出限流 I_LIM = 2.0 A（对齐赛题「输出电流设定上限 2 A」）：
  负载要的电流超过限流时进入恒流（CC），输出电压被拉低到 Vout = I_LIM * R。
* 保护：OVP 1.15*Vset、OCP 2.5 A、OTP 85 ℃，任一动作即关输出并锁存故障。
* 采样：1 kSPS，电压/电流叠加 0.5% 噪声 + 12 bit 量化，占空比 0.01% 量化；
  窗口 100 ms（100 点）取均值作为模型输入（对应板上 10 Hz 状态帧的统计口径）。

标注规则（4 类，输入不含故障位，故障位只用于标注）
------------------------------------------------
3 保护故障   ：窗口处在故障锁存后（输出已关断：V≈0、I≈0、d=0）
2 重载近限流 ：I_avg > 0.90 * I_LIM（含 CC 恒流段）
1 正常-额定  ：0.35 * I_LIM < I_avg <= 0.90 * I_LIM
0 正常-轻载  ：I_avg <= 0.35 * I_LIM
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field, asdict

# ---------------------------------------------------------------- 硬件/控制常量
I_LIM = 2.0            # 输出限流 A（赛题：输出电流设定上限 2 A）
I_TRIP = 2.5           # OCP 阈值 A
OVP_RATIO = 1.15       # 过压保护比例（相对 Vset）
T_TRIP = 85.0          # 过温保护 ℃
T_AMBIENT = 25.0
R_TH = 1.5             # 热阻 K/W
C_TH = 8.0             # 热容 J/K
DUTY_MAX = 0.95
VREF_MIN, VREF_MAX = 12.0, 48.0   # 电压给定范围（对齐 PL 0x58 = 48V 上限）

# ---------------------------------------------------------------- 采样/窗口
FS = 1000                  # Hz，采样率
DT = 1.0 / FS
WINDOW = 100               # 100 ms 窗口
SETTLE_MS = 300            # 先稳定 300 ms
NOISE = 0.005              # 0.5% 测量噪声
ADC_V_LSB = 0.01           # 10 mV
ADC_I_LSB = 0.001          # 1 mA
ADC_D_LSB = 0.01           # 0.01 %

TAU_V = 0.004              # 输出电容一阶时间常数
TAU_D = 0.006              # 占空比环响应

CLASS_NAMES = [
    "正常-轻载",
    "正常-额定",
    "重载-近限流",
    "保护故障",
]
CLASS_SHORT = ["light", "rated", "heavy", "fault"]


def _clip(x, lo, hi):
    return lo if x < lo else (hi if x > hi else x)


def duty_for(v_out: float, v_in: float) -> float:
    """buck-boost 单占空比近似：d = Vout / (Vin + Vout)。"""
    if v_out <= 0.0:
        return 0.0
    return _clip(v_out / (v_in + v_out), 0.0, DUTY_MAX)


def _quant(x: float, lsb: float) -> float:
    return round(x / lsb) * lsb


@dataclass
class Trial:
    """一次试验的配置 + 输出结果。"""
    trial_id: int
    vin: float
    vset: float
    r_load: float
    r_step: float | None = None      # 窗口前的负载阶跃目标（None = 无阶跃）
    fault: str = "none"              # none / ocp / ovp / otp
    seed: int = 0

    # 结果
    label: int = 0
    fault_code: str = "none"
    v_mean: float = 0.0
    i_mean: float = 0.0
    d_mean: float = 0.0
    v_std: float = 0.0
    i_std: float = 0.0
    d_std: float = 0.0
    v_last: float = 0.0
    i_last: float = 0.0
    d_last: float = 0.0
    r_mean: float = 0.0
    samples: list = field(default_factory=list, repr=False)


def simulate(trial: Trial, rng: random.Random) -> Trial:
    """跑一次试验：稳定 -> (可选阶跃/故障) -> 采 100 点窗口 -> 打标签。"""
    vin = trial.vin
    vset = trial.vset
    r = trial.r_load
    v = 0.0
    d = 0.0
    temp = T_AMBIENT
    fault = "none"

    r_th = R_TH

    def step_sim(dt: float):
        nonlocal v, d, temp, r, fault
        if fault != "none":
            # 故障锁存：输出关断，占空比回零，输出电容放电
            d += (0.0 - d) * (1.0 - math.exp(-dt / TAU_D))
            v += (0.0 - v) * (1.0 - math.exp(-dt / TAU_V))
            temp += ((T_AMBIENT - temp) / r_th) / C_TH * dt
            return
        # --- 电流环 / 限流 ---
        i_want = vset / max(r, 1e-3)
        if i_want > I_LIM:                     # CC：限流后电压被拉低
            v_target = I_LIM * r
        else:
            v_target = vset
        # 负载阶跃后按目标推进
        v += (v_target - v) * (1.0 - math.exp(-dt / TAU_V))
        d_target = duty_for(v, vin)
        d += (d_target - d) * (1.0 - math.exp(-dt / TAU_D))
        d = _clip(d, 0.0, DUTY_MAX)
        i = v / max(r, 1e-3)
        # --- 结温 ---
        heat = i * i * 0.6
        temp += (heat - (temp - T_AMBIENT) / r_th) / C_TH * dt
        # --- 保护（与 PL 逻辑同口径）---
        if vset >= 1.0 and v > vset * OVP_RATIO:
            fault = "OVP"
        elif i > I_TRIP:
            fault = "OCP"
        elif temp > T_TRIP:
            fault = "OTP"

    # 1) 稳定阶段
    n_settle = int(SETTLE_MS / 1000.0 * FS)
    for _ in range(n_settle):
        step_sim(DT)
        if fault != "none":
            break

    # 2) 故障注入（在稳定后）
    if fault == "none" and trial.fault != "none":
        if trial.fault == "ocp":
            r = 0.25                                   # 近似短路，环路来不及限流 -> OCP
        elif trial.fault == "ovp":
            vset = max(VREF_MIN, trial.vset * 0.6)      # 给定骤降 -> 输出过压
        elif trial.fault == "otp":
            r = 1.0                                    # 散热失效：热阻放大，持续大电流到 85 ℃
            r_th = 60.0
        for _ in range(int(0.25 * FS)):
            step_sim(DT)
            if fault != "none":
                break
        # 保护动作后让输出电容放电 50 ms，再采窗口：
        # 否则窗口头部会混进「短路瞬间的大电流」，与“已锁存停机”的物理状态不符
        for _ in range(int(0.05 * FS)):
            step_sim(DT)

    # 3) 窗口前的负载阶跃（只在无故障时用，制造真实的动态过程）
    if fault == "none" and trial.r_step is not None:
        r = trial.r_step
        for _ in range(int(0.08 * FS)):
            step_sim(DT)

    # 4) 采样窗口
    vs, iss, ds, rs = [], [], [], []
    for _ in range(WINDOW):
        step_sim(DT)
        vn = v * (1.0 + rng.uniform(-NOISE, NOISE))
        inn = (v / max(r, 1e-3)) * (1.0 + rng.uniform(-NOISE, NOISE))
        # 开关纹波（三角波近似，1% 峰峰值）
        rip = rng.uniform(-1.0, 1.0) * 0.005 * max(v, 0.0)
        vs.append(max(0.0, _quant(vn + rip, ADC_V_LSB)))
        iss.append(max(0.0, _quant(inn, ADC_I_LSB)))
        ds.append(_quant(d * 100.0, ADC_D_LSB))
        rs.append(r)

    trial.fault_code = fault
    trial.v_mean = sum(vs) / len(vs)
    trial.i_mean = sum(iss) / len(iss)
    trial.d_mean = sum(ds) / len(ds)
    trial.v_std = math.sqrt(sum((x - trial.v_mean) ** 2 for x in vs) / len(vs))
    trial.i_std = math.sqrt(sum((x - trial.i_mean) ** 2 for x in iss) / len(iss))
    trial.d_std = math.sqrt(sum((x - trial.d_mean) ** 2 for x in ds) / len(ds))
    trial.v_last, trial.i_last, trial.d_last = vs[-1], iss[-1], ds[-1]
    trial.r_mean = sum(rs) / len(rs)
    trial.samples = list(zip(vs, iss, ds))
    trial.label = label_of(trial)
    return trial


def label_of(t: Trial) -> int:
    """标注规则（只依赖真值，不看模型输入）。"""
    if t.fault_code != "none":
        return 3
    if t.i_mean > 0.90 * I_LIM:
        return 2
    if t.i_mean > 0.35 * I_LIM:
        return 1
    return 0


def random_trial(trial_id: int, rng: random.Random) -> Trial:
    """按类别均衡地生成一次试验配置。

    先定目标类别，再反推负载电阻：I = Vset / R，因此 R = Vset / I。
    这样每类样本量接近，避免训练集被「恒流点」淹没（真实数据的先验不同，
    正式训练时应改用实测分布的采样权重）。
    """
    want = trial_id % 4
    vin = rng.uniform(12.0, 48.0)
    vset = rng.uniform(VREF_MIN, VREF_MAX)
    r = 10.0
    if want != 3:
        lo, hi = [(0.05, 0.68), (0.72, 1.78), (1.85, 1.99)][want]
        for _ in range(64):
            vset = rng.uniform(VREF_MIN, VREF_MAX)
            i_target = rng.uniform(lo, hi)
            r = vset / i_target
            if 0.5 <= r <= 500.0:
                break
        else:
            r = 10.0
    else:
        r = math.exp(rng.uniform(math.log(0.6), math.log(80.0)))

    step = None
    if rng.random() < 0.20:
        step = min(500.0, max(0.5, r * math.exp(rng.uniform(math.log(0.4), math.log(2.5)))))
    fault = "none"
    if want == 3:
        # 只用 V/I/D 三个量能看到的两类保护：OVP（给定骤降）与 OCP（短路）。
        # OTP 的物理量是温度，不在模型输入里，停机后的 V/I/D 也与 OVP/OCP 相同，
        # 因此不单列（见 README「已知局限」）。
        fault = rng.choice(["ocp", "ovp"])
    return Trial(trial_id=trial_id, vin=vin, vset=vset, r_load=r, r_step=step,
                 fault=fault, seed=rng.randrange(1 << 30))


def make_trial(trial_id: int, rng: random.Random) -> Trial:
    t = random_trial(trial_id, rng)
    return simulate(t, random.Random(t.seed))


CSV_HEADER = (
    "trial_id,vin,vset,r_mean,v_mean,i_mean,d_mean,v_std,i_std,d_std,"
    "v_last,i_last,d_last,fault_code,label,class_name"
)


def row_of(t: Trial) -> str:
    return ",".join([
        str(t.trial_id),
        f"{t.vin:.2f}", f"{t.vset:.2f}", f"{t.r_mean:.4f}",
        f"{t.v_mean:.4f}", f"{t.i_mean:.4f}", f"{t.d_mean:.4f}",
        f"{t.v_std:.4f}", f"{t.i_std:.5f}", f"{t.d_std:.4f}",
        f"{t.v_last:.4f}", f"{t.i_last:.4f}", f"{t.d_last:.4f}",
        t.fault_code, str(t.label), CLASS_NAMES[t.label].replace(",", " "),
    ])


def describe(t: Trial) -> dict:
    d = asdict(t)
    d.pop("samples", None)
    return d
