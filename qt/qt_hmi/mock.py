from PIL import Image, ImageDraw, ImageFont
import os, math

W,H = 1024,600
BG=(14,17,22); PANEL=(22,27,34); PANEL2=(28,35,44)
TEXT=(230,237,243); DIM=(125,135,148); ACC=(0,229,160); AMB=(255,176,32)
RED=(255,77,79); BLUE=(59,169,255); GRID=(32,38,46); BORDER=(35,42,51)

img=Image.new("RGB",(W,H),BG); d=ImageDraw.Draw(img)

def font(sz, bold=False):
    for name in [("C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc"),
                 ("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf")]:
        if os.path.exists(name):
            try: return ImageFont.truetype(name, sz)
            except Exception: pass
    return ImageFont.load_default()

def txt(xy,s,sz,color,bold=False,anchor=None):
    d.text(xy,s,font=font(sz,bold),fill=color,anchor=anchor)

def panel(box):
    d.rounded_rectangle(box, radius=8, fill=PANEL, outline=BORDER)

# header
txt((14,10),"智能电源状态监测与故障诊断系统",26,TEXT,True)
txt((W-250,16),"● 板卡在线",18,ACC,True)
txt((W-120,16),"2026-10-25 20:30:00",16,DIM)

# left panel
panel((10,58,540,352))
txt((28,70),"输出电压",16,DIM)
txt((28,92),"12.00",56,ACC,True); txt((190,120),"V",22,DIM)
txt((28,168),"输出电流",16,DIM)
txt((28,190),"1.09",56,AMB,True); txt((190,218),"A",22,DIM)
txt((28,266),"占空比",16,DIM)
txt((28,288),"50.0 %",34,TEXT,True)
txt((28,330),"给定 12.00 V / 5.00 A",16,DIM)

# right panel
panel((552,58,1014,352))
txt((572,72),"电压给定 (V)",15,DIM)
d.rounded_rectangle((760,64,990,102),radius=6,fill=(11,14,18),outline=(43,51,61)); txt((774,72),"12.00",22,TEXT)
txt((572,116),"电流给定 (A)",15,DIM)
d.rounded_rectangle((760,108,990,146),radius=6,fill=(11,14,18),outline=(43,51,61)); txt((774,116),"5.00",22,TEXT)
d.rounded_rectangle((572,158,990,200),radius=6,fill=(31,111,235)); txt((781,169),"下发给定",19,(255,255,255),anchor="mm")
for i,(lbl,col) in enumerate([("输出开",(35,134,54)),("输出关",(139,46,46)),("清故障",(110,90,30))]):
    x=572+i*140
    d.rounded_rectangle((x,210,x+130,254),radius=6,fill=col); txt((x+65,232),lbl,19,(255,255,255),anchor="mm")
leds=[("● 运行",ACC),("● 输出",ACC),("● 上位机",ACC),("● 过压",DIM),("● 过流",DIM),("● 过温",DIM),("● PWM",ACC),("● PLL",ACC),("● ADC",ACC)]
for i,(s,c) in enumerate(leds):
    txt((572+(i%3)*140, 270+(i//3)*26), s, 15, c, True)
txt((572,352-8),"故障：无",17,ACC,True) if False else None
txt((572,352-30),"故障：无",17,ACC,True)

# curve panel
panel((10,362,1014,552))
d.rectangle((62,374,1002,530),outline=(35,42,51))
for k in range(5):
    y=374+(530-374)*k/4; d.line((62,y,1002,y),fill=GRID)
for k in range(7):
    x=62+(1002-62)*k/6; d.line((x,374,x,530),fill=GRID)
# curves
pv=[]; pi=[]
for k in range(600):
    t=k/600.0
    pv.append(12.0+0.35*math.sin(t*18)+0.12*math.sin(t*53))
    pi.append(1.09+0.22*math.sin(t*11+1.2)+0.06*math.sin(t*41))
def series(a,mx,col):
    pts=[]
    for k,v in enumerate(a):
        x=62+(1002-62)*k/(len(a)-1); y=530-(530-374)*max(0,min(1,v/mx))
        pts.append((x,y))
    d.line(pts,fill=col,width=2,joint="curve")
series(pi,4.5,AMB); series(pv,16.0,ACC)
txt((14,378),"4.5",12,DIM); txt((14,520),"0",12,DIM)
txt((70,536),"电压 V (绿) / 电流 A (黄)",12,DIM)

# log
txt((14,566),"[20:30:00] 已连接板卡 192.168.137.101:5000",14,DIM)

out=r"D:\deepseek\work\qt_hmi\preview_1024x600.png"
img.save(out,"PNG")
print("saved", out, os.path.getsize(out), "bytes")
