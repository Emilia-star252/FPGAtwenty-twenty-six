`timescale 1ns / 1ps

module DCDC_top #(
    // 100 MHz 下默认保持 ADC 复位约 83.9 ms；仿真可覆盖此参数以缩短等待。
    parameter integer ADC_RESET_CYCLES = 8388608,
    // 有符号 Q16 参数：实际值 = 参数 / 65536。
    // 电压外环沿用当前系数；电流内环 Kp=0.01、Ki=0.02，四舍五入为 Q16。
    // KI 沿用 PI.v 原公式：积分增量 = Kp * 误差 * Ki。
    parameter signed [31:0] V_KP_Q16 = 32'sd66,
    parameter signed [31:0] V_KI_Q16 = 32'sd655,
    parameter signed [31:0] I_KP_Q16 = 32'sd655,  // round(0.01 * 65536)
    parameter signed [31:0] I_KI_Q16 = 32'sd1311, // round(0.02 * 65536)
    // 输出母线电压常量：24 V，采用有符号 Q16 格式。
    localparam signed [31:0] V_BUS_Q16 = 32'sd1572864, // 24 * 65536
    parameter signed [31:0] V_REF_Q16 = 32'sd2359296, // 48 V 斜坡速率基准；AXI 目标上限为 64 V
    // AD7606 RANGE=1: +/-10 V. Q16 每码系数 = 2 * 10 * 还原比例。
    // 电压分压还原 20 倍；电流 1 V = 1 A、零点 0 V（用户确认）。
    parameter signed [31:0] V_SCALE_Q16 = 32'sd391,
    parameter signed [31:0] I_SCALE_Q16 = 32'sd19,
    // 实测两点标定的截距，单位分别为 V/A 的 Q16；默认不补偿零偏。
    parameter signed [31:0] V_OFFSET_Q16 = 32'sd6960,
    parameter signed [31:0] I_OFFSET_Q16 = 32'sd299,
    // 25 kHz 下爬升 V_REF_Q16 的时间；默认 0->64 V 约 133.3 ms，0 表示直接到目标。
    parameter integer V_SOFT_START_MS = 100,
    // Existing STM32 link defaults to 8N1; use PARITY=1 for 8E1, or STOP_BITS=2 for 8N2.
    parameter integer RS485_BAUD = 115200,
    parameter integer RS485_PARITY = 0,
    parameter integer RS485_STOP_BITS = 1,
    parameter [7:0] RS485_STATION = 1
) (
    input  wire               I_rs485_rx,
    output wire               O_rs485_tx,
    output wire               O_rs485_de,
    output wire [2:0]          O_hdmi_tx_p,
    output wire               O_hdmi_clk_p,

    input  wire               clk_in,       // 板载时钟：100 MHz
    input  wire               rst_n,        // 外部复位，低电平有效

    // 两组同相的互补 PWM 输出，不插入死区。
    output wire               pwm1_h,
    output wire               pwm1_l,
    output wire               pwm2_h,
    output wire               pwm2_l,

    // 外部 AD7606 的数字接口；ad_busy 为芯片 BUSY 引脚，非驱动状态。
    input  wire               ad_busy,      // 芯片正在转换，高电平有效
    input  wire               ad_dout_a,    // 通道 V1～V4 的串行数据
    input  wire               ad_dout_b,    // 通道 V5～V8 的串行数据
    output wire               card_power_en, // DAQ001 子卡供电使能，高电平有效
    output wire               ad_cs,        // 串行片选，低电平有效
    output wire               ad_sclk,      // 串行读取时钟，当前为 6.25 MHz
    output wire               ad_rst,       // ADC 芯片复位，高电平有效
    output wire               ad_convsta,   // A 组转换启动信号
    output wire               ad_convstb,   // B 组转换启动信号，与 A 组同步
    output wire               ad_range      // 输入量程配置，驱动 RANGE=1，当前为 ±10 V
);

    // AXI 命令默认关闭输出；ADC 采样时基独立运行。
    wire output_enable_cmd;
    wire ps_output_enable_cmd, ps_fault_clear_cmd;
    wire [31:0] ps_vref_cmd_q16;
    wire rs485_remote_mode, rs485_remote_enable, rs485_fault_clear;
    wire rs485_ps_clear;
    wire [31:0] rs485_vref_q16;
    // PL 本地目标：48 V
    wire [31:0] vref_cmd_q16;// = V_REF_Q16;           //需要改回去
    // The AXI register bank rejects ON at zero Vref and clears ON when Vref=0.
    // Keep this asynchronous shutoff driven by a single registered command bit.
    wire control_enable = output_enable_cmd;        //pwm输出使能 1'b1
    wire pi_clear       = 1'b0;
    
    // 内部采样、状态和时钟锁定信号，不占用封装 I/O。
    wire pll_locked;
    wire adc_trigger; // PWM 到 ADC 驱动的内部采样触发
    wire adc_valid;   // 完整采样有效，持续一个 clk_100m 周期
    wire adc_ready;   // ADC 驱动可以接收新的采样触发
    wire adc_busy;    // 驱动处于初始化、转换、读取或故障状态
    wire adc_error;   // ADC 异常锁存，系统复位后清除
    wire clk_100m;
    wire [63:0] adc_data_a; // {V1,V2,V3,V4}，每通道 16 位补码
    wire [63:0] adc_data_b; // {V5,V6,V7,V8}
    reg [11:0] duty_counts;
    // 停机握手清除旧命令；故障原因独立锁存，直到安全清故障或系统复位。
    reg protection_stop;
    reg overcurrent_fault, overvoltage_fault;
    reg protection_sample_safe;
    wire fault_clear_cmd;
    assign output_enable_cmd = rs485_remote_mode ? rs485_remote_enable : ps_output_enable_cmd;
    assign vref_cmd_q16 = rs485_remote_mode ? rs485_vref_q16 : ps_vref_cmd_q16;
    assign fault_clear_cmd = ps_fault_clear_cmd || rs485_fault_clear;
    wire protection_fault = overcurrent_fault || overvoltage_fault;

    // 与厂家 DAQ001 示例一致，子卡供电持续使能，不受控制启停影响。
    assign card_power_en = 1'b1;

    PLL_sys100 u_pll_sys100 (
        .refclk   (clk_in),
        .clk0_out (clk_100m),
        .lock     (pll_locked),
        .reset    (~rst_n)
    );

    // ADC 使用独立的系统复位：外部复位或 PLL 失锁时立即复位，
    // PLL 锁定后经过两个系统时钟同步释放，不受 PI 清零和控制使能影响。
    wire adc_reset_async_n = rst_n && pll_locked;
    reg [1:0] adc_reset_sync;
    always @(posedge clk_100m or negedge adc_reset_async_n) begin
        if (!adc_reset_async_n)
            adc_reset_sync <= 2'b00;
        else
            adc_reset_sync <= {adc_reset_sync[0], 1'b1};
    end
    wire adc_sys_rst_n = adc_reset_sync[1];

    // ADC 完成复位保持和恢复等待、首次就绪后，锁存初始化完成状态。
    // 后续转换/读取时 adc_ready 会变低，不能用它直接门控 PWM 输出。
    reg adc_initialized;
    always @(posedge clk_100m or negedge adc_sys_rst_n) begin
        if (!adc_sys_rst_n)
            adc_initialized <= 1'b0;
        else if (adc_ready)
            adc_initialized <= 1'b1;
    end

    // 复位立即生效，经过两个系统时钟上升沿后同步释放。
    // 外部复位、PLL 失锁、ADC 故障或过流/过压保护立即停止 PI 并关断四路。
    wire run_async_n = rst_n && pll_locked && control_enable && !pi_clear &&
                       !adc_error && !protection_stop && !protection_fault;
    reg [1:0] run_sync;
    always @(posedge clk_100m or negedge run_async_n) begin
        if (!run_async_n)
            run_sync <= 2'b00;
        else
            run_sync <= {run_sync[0], 1'b1};
    end
    wire control_rst_n = run_sync[1];


    // 电压外环输出电流给定，电流内环输出占空比修正量。
    localparam signed [31:0] I_REF_MIN_Q16 = 32'sd0;
    localparam signed [31:0] I_REF_MAX_Q16 = 32'sd393216; // 6 A；过流保护阈值独立设置
    localparam signed [31:0] DUTY_MIN_Q16 = -32'sd13107; // round(-0.2*65536)
    localparam signed [31:0] DUTY_MAX_Q16 = 32'sd13107;  // round(0.2*65536)

    // ADC 原始值是整数；乘 Q16 的单位/计数比例后已经是 Q16，不再右移。
    // 扩展乘积再饱和，避免后续修改比例时产生 32 位回绕。
    wire signed [15:0] voltage_raw = $signed(adc_data_a[47:32]); // V2
    wire signed [15:0] current_raw = $signed(adc_data_a[31:16]); // V3
    wire signed [47:0] voltage_product = voltage_raw * V_SCALE_Q16 + V_OFFSET_Q16;
    wire signed [47:0] current_product = current_raw * I_SCALE_Q16 + I_OFFSET_Q16;
    // 按实际 V/A 的有符号 Q16 判断，严格大于才触发（不取绝对值）。
    // 在饱和前比较与饱和后比较等价；避免把饱和多路器串入保护路径。
    localparam signed [47:0] OVERCURRENT_TRIP_Q16 = 48'sd163840; // 2.5 A
    localparam signed [47:0] OVERVOLTAGE_TRIP_Q16 = 48'sd5242880; // 80 V
    wire overcurrent_sample = current_product > OVERCURRENT_TRIP_Q16;
    wire overvoltage_sample = voltage_product > OVERVOLTAGE_TRIP_Q16;
    wire sample_safe = !overcurrent_sample && !overvoltage_sample;
    always @(posedge clk_100m or negedge adc_sys_rst_n) begin
        if (!adc_sys_rst_n) begin
            overcurrent_fault <= 1'b0;
            overvoltage_fault <= 1'b0;
            protection_sample_safe <= 1'b0;
        end else begin
            // A previous complete safe sample is required. A new unsafe sample
            // takes priority over a concurrent clear; never restart on clear.
            if (fault_clear_cmd && protection_sample_safe && adc_initialized &&
                !adc_error && !(adc_valid && !sample_safe)) begin
                overcurrent_fault <= 1'b0;
                overvoltage_fault <= 1'b0;
            end
            if (adc_valid) begin
                protection_sample_safe <= sample_safe;
                if (overcurrent_sample) overcurrent_fault <= 1'b1;
                if (overvoltage_sample) overvoltage_fault <= 1'b1;
            end
        end
    end
    always @(posedge clk_100m or negedge adc_sys_rst_n) begin
        if (!adc_sys_rst_n) begin
            protection_stop <= 1'b0;
        end else if (adc_valid && ((current_product > OVERCURRENT_TRIP_Q16) ||
                                  (voltage_product > OVERVOLTAGE_TRIP_Q16)))
            protection_stop <= 1'b1;
        else if (!output_enable_cmd)
            protection_stop <= 1'b0;
    end
    function signed [31:0] saturate_q16;
        input signed [47:0] value;
        begin
            if (value > 48'sd2147483647)
                saturate_q16 = 32'sh7fffffff;
            else if (value < -48'sd2147483648)
                saturate_q16 = 32'sh80000000;
            else
                saturate_q16 = value[31:0];
        end
    endfunction

    reg signed [31:0] voltage_fbk_q16;
    reg signed [31:0] current_fbk_q16;
    reg signed [31:0] current_ref_q16;
    wire signed [31:0] voltage_pi_out_q16, pi_out_q16;
    wire voltage_pi_valid, pi_out_valid;
    wire voltage_pi_ready;
    wire current_pi_ready;
    wire voltage_pi_busy;
    wire current_pi_busy;

    // 每组采样：锁存 V2/V3 -> 更新软启动及前馈 -> 电压 PI -> 电流给定
    // -> 电流 PI -> 占空比修正量。两环使用同一帧反馈，均按 25 kHz 更新。
    // valid 保持到对应 PI 接收；V3 同时用于电流闭环、遥测和在线调试。
    localparam [2:0] WAIT_SAMPLE = 3'd0, START_V = 3'd1,
                     WAIT_V = 3'd2, START_I = 3'd3, WAIT_I = 3'd4,
                     WAIT_FF = 3'd5;
    reg [2:0] loop_state;
    wire pi_busy = (loop_state != WAIT_SAMPLE);
    // 内部诊断：计算期间到达新采样时锁存，正常 40 us 周期不会出现。
    reg sample_overrun;

    // 保持原斜率 48 V / 100 ms；64 V 目标也按相同速率爬升，不在 48 V 截止。
    // 上下调节都夹紧到命令目标；余数累加避免小数步长截断。
    localparam integer SOFT_START_STEPS =
        (V_SOFT_START_MS > 0) ? V_SOFT_START_MS * 25 : 1;
    localparam signed [32:0] SOFT_START_STEP_Q16 = V_REF_Q16 / SOFT_START_STEPS;
    localparam [31:0] SOFT_START_REMAINDER = V_REF_Q16 % SOFT_START_STEPS;
    reg signed [31:0] v_ref_soft_q16;
    reg [31:0] soft_start_fraction;
    wire [32:0] soft_start_fraction_sum =
        {1'b0, soft_start_fraction} + SOFT_START_REMAINDER;
    wire soft_start_carry = (soft_start_fraction_sum >= SOFT_START_STEPS);
    wire signed [32:0] v_ref_step = SOFT_START_STEP_Q16 +
        (soft_start_carry ? 33'sd1 : 33'sd0);
    wire signed [32:0] v_ref_ramp_next =
        (v_ref_soft_q16 < $signed(vref_cmd_q16))
            ? $signed({v_ref_soft_q16[31], v_ref_soft_q16}) + v_ref_step
            : $signed({v_ref_soft_q16[31], v_ref_soft_q16}) - v_ref_step;
    wire signed [31:0] v_ref_soft_next =
        (V_SOFT_START_MS == 0) ? vref_cmd_q16 :
        (v_ref_soft_q16 < $signed(vref_cmd_q16))
            ? ((v_ref_ramp_next >= $signed({1'b0, vref_cmd_q16}))
                ? vref_cmd_q16 : v_ref_ramp_next[31:0])
            : ((v_ref_ramp_next <= $signed({1'b0, vref_cmd_q16}))
                ? vref_cmd_q16 : v_ref_ramp_next[31:0]);

    // 前馈 = Vsoft / (Vsoft + Vbus)。逐位生成 16 位小数，耗时 16 拍。
    // 软启动期间每帧更新一次；到达目标后保持，PI 与前馈共用同一给定。
    reg signed [31:0] duty_ff_q16;
    reg [32:0] ff_remainder, ff_denominator;
    reg [15:0] ff_quotient;
    reg [3:0] ff_bit_count;
    wire [33:0] ff_shifted = {ff_remainder, 1'b0};
    wire ff_next_bit = (ff_shifted >= {1'b0, ff_denominator});
    wire [33:0] ff_remainder_next = ff_next_bit
        ? ff_shifted - {1'b0, ff_denominator} : ff_shifted;

    // PS 到 PL 的 AXI-Lite 寄存器使用已有的 100 MHz 时钟。
    // ADC 遥测端口均与 AXI 同时钟；在 adc_valid 时锁存同一帧数据。
    wire axi_reset_n;
    wire [11:0] pwm_active_counts;
    wire pwm_period_start;
    reg pwm_armed;
    wire pwm_output_enable = control_rst_n && adc_initialized && pwm_armed &&
                             !protection_stop && !protection_fault;
    // Report the high time latched by PWM, not the pending PI command.
    // floor(counts * 8589935 / 2^19) exactly equals floor(counts * 65536 / 4000)
    // for all 12-bit counts (exhaustively checked), without a long divide path.
    wire [35:0] duty_fraction_product = pwm_active_counts * 24'd8589935;
    wire [31:0] applied_duty_q16 = pwm_output_enable
        ? {15'd0, duty_fraction_product[35:19]} : 32'd0;
    // bit0=request, bit1=actual PWM enabled, bit2=ADC initialized,
    // bit3=ADC fault, bit4=PLL locked, bit5=period armed, bit6=overrun.
    // bit7=overcurrent latch, bit8=overvoltage latch, bit9=RS485 owns control.
    wire [31:0] output_status = {22'd0, rs485_remote_mode, overvoltage_fault, overcurrent_fault,
        sample_overrun, pwm_armed,
        pll_locked, adc_error, adc_initialized, pwm_output_enable, output_enable_cmd};
    rs485_dcdc_control #(.CLOCK_HZ(100000000), .BAUD(RS485_BAUD),
        .PARITY(RS485_PARITY), .STOP_BITS(RS485_STOP_BITS), .STATION(RS485_STATION)) u_rs485 (
        .clk(clk_100m), .rst_n(adc_sys_rst_n), .rx(I_rs485_rx),
        .tx(O_rs485_tx), .de(O_rs485_de), .sample_valid(adc_valid),
        .protection_stop(protection_stop), .voltage_q16(saturate_q16(voltage_product)),
        .current_q16(saturate_q16(current_product)), .duty_q16(applied_duty_q16),
        .control_status(output_status), .effective_vref_q16(vref_cmd_q16),
        .active_vref_q16(v_ref_soft_q16), .effective_enable(output_enable_cmd),
        .remote_mode(rs485_remote_mode), .remote_enable(rs485_remote_enable),
        .remote_vref_q16(rs485_vref_q16), .fault_clear(rs485_fault_clear),
        .ps_command_clear(rs485_ps_clear));
    axi_system u_axi_system (                       // AXI acquisition and HDMI display
        .O_hdmi_tx_p(O_hdmi_tx_p),
        .O_hdmi_clk_p(O_hdmi_clk_p),
        .axi_clk     (clk_100m),
        .pll_locked  (pll_locked),
        .ext_reset_n (rst_n),
        .axi_reset_n (axi_reset_n),
        .adc_sample_valid (adc_valid),
        .voltage_product_in(voltage_product),
        .current_product_in(current_product),
        .duty_q16_in      (applied_duty_q16),
        .control_status_in(output_status),
        .vref_active_q16_in(v_ref_soft_q16),
        .protection_stop  (protection_stop || rs485_ps_clear),
        .fault_clear_cmd  (ps_fault_clear_cmd),
        .output_enable_cmd(ps_output_enable_cmd),
        .vref_cmd_q16     (ps_vref_cmd_q16),
        // bit6 由寄存器模块提供采样有效标志；bit7/8 为过流/过压锁存。
        .adc_status_in    ({23'd0, overvoltage_fault, overcurrent_fault, 1'b0,
                            sample_overrun, pll_locked, adc_error,
                            adc_busy, adc_ready, adc_initialized})
    );

    always @(posedge clk_100m or negedge control_rst_n) begin
        if (!control_rst_n) begin
            loop_state <= WAIT_SAMPLE;
            voltage_fbk_q16 <= 32'sd0;
            v_ref_soft_q16 <= 32'sd0;
            soft_start_fraction <= 32'd0;
            duty_ff_q16 <= 32'sd0;
            ff_remainder <= 33'd0;
            ff_denominator <= 33'd0;
            ff_quotient <= 16'd0;
            ff_bit_count <= 4'd0;
            current_fbk_q16 <= 32'sd0;
            current_ref_q16 <= 32'sd0;
            sample_overrun <= 1'b0;
        end else begin
            if (adc_valid && pi_busy)
                sample_overrun <= 1'b1;
            case (loop_state)
                WAIT_SAMPLE: if (adc_valid) begin
                    voltage_fbk_q16 <= saturate_q16(voltage_product);
                    current_fbk_q16 <= saturate_q16(current_product);
                    if (v_ref_soft_q16 != $signed(vref_cmd_q16)) begin
                        v_ref_soft_q16 <= v_ref_soft_next;
                        soft_start_fraction <= soft_start_carry
                            ? soft_start_fraction_sum - SOFT_START_STEPS
                            : soft_start_fraction_sum;
                        ff_remainder <= {1'b0, v_ref_soft_next};
                        ff_denominator <= {1'b0, v_ref_soft_next} +
                                          {1'b0, V_BUS_Q16};
                        ff_quotient <= 16'd0;
                        ff_bit_count <= 4'd15;
                        loop_state <= WAIT_FF;
                    end else begin
                        loop_state <= START_V;
                    end
                end
                WAIT_FF: begin
                    ff_remainder <= ff_remainder_next[32:0];
                    ff_quotient <= {ff_quotient[14:0], ff_next_bit};
                    if (ff_bit_count == 4'd0) begin
                        duty_ff_q16 <= {16'd0, ff_quotient[14:0], ff_next_bit};
                        loop_state <= START_V;
                    end else begin
                        ff_bit_count <= ff_bit_count - 4'd1;
                    end
                end
                START_V: if (voltage_pi_ready) loop_state <= WAIT_V;
                WAIT_V: if (voltage_pi_valid) begin
                    current_ref_q16 <= voltage_pi_out_q16;
                    loop_state <= START_I;
                end
                START_I: if (current_pi_ready) loop_state <= WAIT_I;
                WAIT_I: if (pi_out_valid) loop_state <= WAIT_SAMPLE;
                default: loop_state <= WAIT_SAMPLE;
            endcase
        end
    end

    cntl_pi_fixed #(
        .WIDTH(32),
        .FRAC (16)
    ) u_voltage_pi (
        .clk       (clk_100m),
        .rst_n     (control_rst_n),
        .clear     (pi_clear),
        .in_valid  (loop_state == START_V),
        .in_ready  (voltage_pi_ready),
        .ref_in    (v_ref_soft_q16),
        .fbk_in    (voltage_fbk_q16),
        .kp_in     (V_KP_Q16),
        .ki_in     (V_KI_Q16),
        .umax_in   (I_REF_MAX_Q16),
        .umin_in   (I_REF_MIN_Q16),
        .out       (voltage_pi_out_q16),
        .out_valid (voltage_pi_valid),
        .busy      (voltage_pi_busy)
    );

    cntl_pi_fixed #(
        .WIDTH(32),
        .FRAC (16)
    ) u_current_pi (
        .clk       (clk_100m),
        .rst_n     (control_rst_n),
        .clear     (pi_clear),
        .in_valid  (loop_state == START_I),
        .in_ready  (current_pi_ready),
        .ref_in    (current_ref_q16),
        .fbk_in    (current_fbk_q16),
        .kp_in     (I_KP_Q16),
        .ki_in     (I_KI_Q16),
        .umax_in   (DUTY_MAX_Q16),
        .umin_in   (DUTY_MIN_Q16),
        .out       (pi_out_q16),
        .out_valid (pi_out_valid),
        .busy      (current_pi_busy)
    );

    // 原单环直连保留为注释；占空比修正量现由电流内环产生，限幅 +/-0.2。
    // assign pi_out_q16 = voltage_pi_out_q16;
    // assign pi_out_valid = voltage_pi_valid;

    // 前馈与 PI 修正量均采用当前帧的软启动给定。
    wire signed [63:0] duty_q16 = duty_ff_q16 + pi_out_q16;

    // 100 MHz / 4000 = 25 kHz，此换算比例须与 PWM.v 保持一致。
    // 先保留完整位宽的乘积，再移除 16 位小数部分。
    wire signed [63:0] duty_product = duty_q16 * 64'sd4000;
    wire signed [63:0] duty_scaled = duty_product >>> 16;
    always @(posedge clk_100m or negedge control_rst_n) begin
        if (!control_rst_n)
            duty_counts <= 12'd0;
        else if (pi_out_valid) begin
            // 前馈叠加后，沿用最终 PWM 的 5%~95% 限幅：200~3800 个计数。
            if (duty_scaled <= 64'sd200)
                duty_counts <= 12'd200;
            else if (duty_scaled >= 64'sd3800)
                duty_counts <= 12'd3800;
            else
                duty_counts <= duty_scaled[11:0];
        end
    end

    wire pwm_base;
    wire adc_trigger_raw;
    PWM u_pwm (
        .clk_100m    (clk_100m),
        .rst_n       (adc_sys_rst_n),
        .duty_counts (duty_counts),//.duty_counts (12'd2000),  
        .pwm_out     (pwm_base),
        .adc_trigger (adc_trigger_raw),
        .duty_active_out(pwm_active_counts),
        .period_start_out(pwm_period_start)
    );

    // Arm only on a PWM boundary after a new nonzero duty has been computed.
    // Disable/fault/reset clears the arm immediately; sample timing continues.
    always @(posedge clk_100m or negedge control_rst_n) begin
        if (!control_rst_n)
            pwm_armed <= 1'b0;
        else if (pwm_period_start && (duty_counts != 0))
            pwm_armed <= 1'b1;
    end

    // ADC 初始化期间四路输出全低；首次就绪后恢复同相互补 PWM。
    // 初始化完成后，占空比为零仍对应 H=0/L=1；关断或保护则四路全部为 0。
    assign pwm1_h = pwm_output_enable && pwm_base;
    assign pwm1_l = pwm_output_enable && !pwm_base;
    assign pwm2_h = pwm_output_enable && pwm_base;
    assign pwm2_l = pwm_output_enable && !pwm_base;
    // 内部计数和采样节拍独立运行，避免关断输出时无法启动 ADC 采样。
    assign adc_trigger = adc_sys_rst_n && adc_trigger_raw;

    // PWM 的采样脉冲启动一次 ADC 转换，驱动等待 BUSY 结束后读取八通道。
    // 初始化或忙状态下的触发会被丢弃，不排队；adc_valid 才表示新数据到达。
    // 内部持续使能；外部复位或 PLL 失锁会复位 ADC 和控制链路。
    uispi7606 #(
        .RESET_CYCLES (ADC_RESET_CYCLES)
    ) u_adc (
        .I_ad_clk       (clk_100m),
        .I_ad_rst       (~adc_sys_rst_n), // 驱动复位为高电平有效
        .I_sample_start (adc_trigger),
        .I_ad_busy      (ad_busy),
        .I_O_ad_out_a   (ad_dout_a),
        .I_O_ad_out_b   (ad_dout_b),
        .O_ad_os        (), // DAQ001 的过采样脚由子卡电阻配置，不接 FEP
        .O_ad_cs        (ad_cs),
        .O_ad_sclk      (ad_sclk),
        .O_ad_rst       (ad_rst),
        .O_ad_convsta   (ad_convsta),
        .O_ad_convstb   (ad_convstb),
        .O_ad_range     (ad_range),
        .O_ad_out_a     (adc_data_a),
        .O_ad_out_b     (adc_data_b),
        .O_ad_cap_en    (adc_valid),
        .O_sample_ready (adc_ready),
        .O_sample_busy  (adc_busy),
        .O_ad_error     (adc_error)
    );

    // 在线调试：以 100 MHz 系统时钟观察电压、电流原始码及采样状态。
    // 上板后将 Capture Setup 条件设为 probe2 == 1，仅保存完整 ADC 新样本。
    ChipWatcher_0 u_chipwatcher (
        .clk    (clk_100m),
        .probe0 (voltage_raw), // V2：16 位有符号电压原始码
        .probe1 (current_raw), // V3：16 位有符号电流原始码
        .probe2 (adc_valid),   // 整帧采样有效，可作为触发和采集条件
        .probe3 (adc_error),    // ADC 错误锁存，可作为异常触发条件
        .probe4 (adc_busy)
    );

endmodule
