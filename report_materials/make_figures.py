"""Create standalone figures from original reports and actual VCD events."""
from pathlib import Path
import csv
import hashlib
import json
import os
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/'report_materials/.runtime'))
os.environ.setdefault('MPLCONFIGDIR',str(ROOT/'report_materials/.runtime/mplconfig'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from PIL import Image,ImageDraw,ImageFont

BASE=Path(os.environ.get('RADAR_REPORT_BUNDLE',ROOT/'report_materials/radar_1270LE_20261022'))
FONT='C:/Windows/Fonts/msyh.ttc'
font_manager.fontManager.addfont(FONT)
plt.rcParams.update({'font.family':'Microsoft YaHei','axes.unicode_minus':False,'font.size':10,'svg.fonttype':'none'})


def txt(image,xy,text,size=25,fill='#172e43'):
    ImageDraw.Draw(image).text(xy,text,font=ImageFont.truetype(FONT,size),fill=fill)


def arrow(draw,a,b):
    draw.line([a,b],fill='#426881',width=4)
    x,y=b;dx=b[0]-a[0];dy=b[1]-a[1]
    if abs(dx)>abs(dy):p=[(x,y),(x-13*(1 if dx>0 else -1),y-7),(x-13*(1 if dx>0 else -1),y+7)]
    else:p=[(x,y),(x-7,y-13*(1 if dy>0 else -1)),(x+7,y-13*(1 if dy>0 else -1))]
    draw.polygon(p,fill='#426881')


def architecture():
    image=Image.new('RGB',(1800,1080),'white');d=ImageDraw.Draw(image)
    txt(image,(55,28),'1270 LE 雷达：模块与数据流',40)
    txt(image,(55,87),'对应冻结编译输入；模块图示，不是RTL自动综合网表',22,'#627381')
    def box(rect,title,lines):
        d.rounded_rectangle(rect,radius=14,fill='#edf5fa',outline='#6188a3',width=3)
        x,y,_,_=rect;txt(image,(x+20,y+17),title,27)
        for i,line in enumerate(lines):txt(image,(x+20,y+62+i*30),line,21)
    box((50,155,445,345),'输入 / 同步 / 复位',['50 MHz、SW6、SW7、ECHO','reset_ctrl / switch_pair_sampled','两级同步；SW6切换扫描模式'])
    box((530,155,1060,345),'共享时基',['radar_global_timebase_alarm','us / ms / 20ms帧 / 250us扫描','2kHz载波、250ms反显相位'])
    box((1150,155,1745,345),'扫描调度与舵机PWM',['radar_unified_scan','OFF → SELF → STANDBY → RUN','基本2s/45°；连续60ms/1°'])
    box((1150,425,1745,625),'超声测距 / BCD / 半径',['ultrasonic_bcd_budget_compact','TRIG / ECHO；20..4000mm有效','distance_bcd、等级、r=距离/25'])
    box((530,425,1060,625),'数码管 / 点阵 / 声光报警',['radar_display_gated/shared','五条角度历史与双色占空显示','alarm_global → LED / 蜂鸣器'])
    box((50,425,445,625),'UFM静态背景',['ALTUFM_NONE / 512×16 bit','8位串行读器','初始化整屏复制；A恢复背景'])
    box((530,720,1060,920),'统一LCD绘图状态机',['radar_lcd_micro + 串行数据通路','撤旧线 → A → B → 画新线','pending快照；字节掩码RMW'])
    box((1150,720,1745,920),'LCD 8080总线 / LCM12864',['lcd_bus_phase','地址后空读；读写方向切换','背景 / 目标 / XOR线 / A7-A6'])
    arrow(d,(445,240),(530,240));arrow(d,(1060,240),(1150,240))
    arrow(d,(1450,345),(1450,425));arrow(d,(1150,525),(1060,525))
    arrow(d,(795,345),(795,425))
    arrow(d,(250,625),(250,815));arrow(d,(250,815),(530,815))
    arrow(d,(1060,815),(1150,815));arrow(d,(1450,625),(1450,670));arrow(d,(1450,670),(950,670));arrow(d,(950,670),(950,720))
    txt(image,(55,985),'控制关键：SW7同步即时关断；切换/关闭时等待撤线和总线释放。',25)
    txt(image,(55,1028),'来源：完整工程/rtl/radar_unified_top.v；总LE=1270（Fitter自身LE相加）。',21,'#627381')
    image.save(BASE/'02_系统设计/总体框图.png')
    (BASE/'02_系统设计/总体框图.mmd').write_text('''flowchart TD
  A[SW6/SW7/ECHO/50MHz] --> B[复位与两级同步/消抖]
  B --> C[统一扫描控制与舵机PWM]
  T[全局共享时基] --> C
  C --> D[超声测距与BCD/半径]
  D --> E[数码管与五角度历史点阵]
  D --> F[LED/蜂鸣器报警]
  C --> G[统一LCD绘图FSM]
  D --> G
  U[UFM静态背景] --> G
  G --> H[共享串行射线数据通路]
  H --> G
  G --> I[8080 LCD总线]
  I --> J[LCM12864]
''',encoding='utf-8')


def tables():
    qsf=(BASE/'08_顶层代码与完整工程/完整工程/lcd_p4/radar_unified_bcd.qsf').read_text()
    pins=re.findall(r'set_location_assignment\s+(PIN_\d+)\s+-to\s+(\S+)',qsf)
    with (BASE/'02_系统设计/引脚表.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.writer(f);w.writerow(['signal','device_pin']);w.writerows((sig,pin) for pin,sig in pins)
    modules=list(csv.DictReader((BASE/'04_功能与资源/candidate_modules.csv').open(encoding='utf-8-sig')))
    assert sum(int(r['byte_a1270']) for r in modules)==1270
    with (BASE/'02_系统设计/模块表.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.writer(f);w.writerow(['module','fitter_self_LE','note'])
        for r in modules:w.writerow([r['module'],r['byte_a1270'],'自身LE，不含子模块重复累计'])


def reports():
    path=BASE/'04_功能与资源/原始编译报告'
    fit=(path/'radar_unified_bcd.fit.summary').read_text()
    sta=(path/'radar_unified_bcd.sta.summary').read_text()
    image=Image.new('RGB',(1700,1170),'white')
    txt(image,(45,28),'Quartus 原始编译报告摘录',36)
    txt(image,(45,85),'原始文本直接排版；非Quartus界面截图。完整报告与SHA来源索引随包提供。',22,'#7c4c24')
    draw=ImageDraw.Draw(image);font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',24)
    lines=fit.strip().splitlines()+['','--- TimeQuest summary (original text) ---']
    matches=re.findall(r"Type\s*: ([^\n]+)\s+Slack\s*: ([^\n]+)\s+TNS\s*: ([^\n]+)",sta)
    lines += [f'{kind:36} Slack: {slack} ns   TNS: {tns}' for kind,slack,tns in matches if kind.startswith(('Setup','Hold'))]
    for i,line in enumerate(lines):draw.text((48,150+i*37),line,font=font,fill='#111820')
    txt(image,(45,1060),'Fitter Successful；1270/1270 LE；setup 2.994 ns；hold 1.078 ns。',25)
    txt(image,(45,1110),'原始报告：04_功能与资源/原始编译报告/；最终POF以烧录回读记录为准。',20,'#627381')
    image.save(BASE/'04_功能与资源/编译报告原文摘录_非GUI.png')


def parse_vcd(path):
    raw=path.read_text()
    units={'s':1e9,'ms':1e6,'us':1e3,'ns':1,'ps':1e-3,'fs':1e-6}
    m=re.search(r'\$timescale\s+(\d+)\s*([a-z]+)\s+\$end',raw,re.S)
    scale=int(m[1])*units[m[2]]
    codes={};scopes=[];series={};widths={};time=0;end=0;body=False
    for line in raw.splitlines():
        if line.startswith('$scope'):scopes.append(line.split()[2])
        elif line.startswith('$upscope'):scopes.pop()
        elif line.startswith('$var'):
            v=line.split();name=v[4];code=v[3];codes[code]=name;widths[name]=int(v[2]);series[name]=[]
        elif line.startswith('$enddefinitions'):body=True
        elif body:
            if line.startswith('#'):time=int(line[1:])*scale;end=time
            elif line and line[0] in '01xz':
                code=line[1:];val=line[0]
                if code in codes:series[codes[code]].append((time,None if val in 'xz' else int(val)))
            elif line.startswith('b'):
                val,code=line[1:].split()
                if code in codes:series[codes[code]].append((time,None if any(x in val for x in 'xz') else int(val,2)))
    return series,widths,end


def bcd(n):
    if n is None:return None
    return sum(((n>>(4*i))&15)*10**i for i in range(4))


def wave(name, title, subtitle, specs, filename, window=None):
    folder=BASE/'03_仿真波形与日志/新增波形'/name
    data,widths,end=parse_vcd(folder/'trace.vcd')
    a,z=window or (0,end/1e6)
    height=1.0*len(specs)+1.9
    fig,axes=plt.subplots(len(specs),1,figsize=(14,height),sharex=True)
    fig.suptitle(title,fontsize=16,x=.07,ha='left',y=1-.12/height)
    fig.text(.07,1-.57/height,subtitle,fontsize=9,color='#596c79',va='top')
    for ax,(key,label,kind) in zip(axes,specs):
        events=data[key]
        current=None
        for time,val in events:
            if time/1e6<=a:current=val
        selected=[(a,current)]+[(t/1e6,v) for t,v in events if a<t/1e6<z]
        selected.append((z,selected[-1][1]))
        times=[t for t,v in selected]
        values=[float('nan') if v is None else bcd(v) if kind=='bcd' else v for t,v in selected]
        ax.step(times,values,where='post',color='#176e9b',linewidth=1.5)
        ax.set_ylabel(label,rotation=0,ha='right',va='center',labelpad=14,fontsize=9)
        ax.spines[['top','right']].set_visible(False)
        ax.grid(axis='x',alpha=.22);ax.set_xlim(a,z)
        if widths[key]==1:
            ax.set_ylim(-.2,1.3);ax.set_yticks([0,1]);ax.tick_params(axis='y',labelsize=8)
        else:
            for (t,v),(next_t,_) in zip(selected,selected[1:]):
                if v is not None and next_t-t>(z-a)/24:
                    labelvalue=f'{v:02X}' if kind=='hex' else str(bcd(v) if kind=='bcd' else v)
                    if kind=='task':labelvalue={0:'空闲',1:'撤旧线',2:'A恢复',3:'B目标',4:'画新线',5:'初始化'}.get(v,str(v))
                    ax.text((t+next_t)/2,.75,labelvalue,transform=ax.get_xaxis_transform(),ha='center',fontsize=8,color='#813d12')
            ax.yaxis.set_major_locator(plt.MaxNLocator(3,integer=True))
    axes[-1].set_xlabel('时间 / ms（原始VCD时间单位为1ps）',fontsize=10)
    fig.text(.07,.12/height,f'来源：新增波形/{name}/trace.vcd；Icarus实际事件导出，非实物/ModelSim截图。',fontsize=9,color='#596c79')
    fig.subplots_adjust(left=.17,right=.97,top=1-.95/height,bottom=.8/height,hspace=.22)
    dest=BASE/'03_仿真波形与日志/波形图';dest.mkdir(exist_ok=True)
    fig.savefig(dest/(filename+'.png'),dpi=160)
    fig.savefig(dest/(filename+'.svg'))
    plt.close(fig)


def waves():
    for folder in (BASE/'03_仿真波形与日志/新增波形').iterdir():
        if not folder.is_dir():continue
        series,widths,end=parse_vcd(folder/'trace.vcd')
        with (folder/'events.csv').open('w',encoding='utf-8-sig',newline='') as f:
            w=csv.writer(f);w.writerow(['time_ns','signal','value_decimal','value_hex'])
            for time,key,val in sorted((t,k,v) for k,events in series.items() for t,v in events):
                w.writerow([f'{time:.3f}',key,'X' if val is None else val,'X' if val is None else hex(val)])
    wave('measurement','超声测距：有效距离、报警分档与无回波超时','50MHz真实时钟；20/199/200/800/1200/4000mm输入；不强制内部计数器。',
         [('echo','ECHO','bit'),('trig','TRIG','bit'),('busy','busy','bit'),('bcd','距离BCD\n十进制','bcd'),('valid','valid','bit'),('level','level','bus')],'01_测距全程')
    wave('measurement','199mm / 200mm边界的测距提交','50MHz；TRIG设定15us；ECHO脉宽按294时钟/mm构造；等级5→4，每次提交后留200us观察。',
         [('echo','ECHO','bit'),('trig','TRIG','bit'),('done','done','bit'),('bcd','距离BCD\n十进制','bcd'),('level','level','bus')],'02_测距报警边界',(0,3.4))
    for mode,title in [('scan_basic','基本模式：状态、45°快走与PWM'),('scan_continuous','连续模式：60ms/1°调度与PWM')]:
        wave(mode,title,'50MHz；SELF/STANDBY=2ms；基本SLOT=20ms、SETTLE=3ms（压缩）；连续STEP=60ms（未压缩）。',
             [('state','system_state','bus'),('angle','角度BCD\n十进制','bcd'),('servo','servo PWM','bit'),('measure_start','measure_start','bit'),('sample_event','sample_event','bit'),('fast','fast_busy','bit')],
             '03_基本扫描_压缩调度' if mode=='scan_basic' else '04_连续扫描_60ms步进')
    wave('beam','LCD任务顺序：撤旧线 → A → B → 画新线','50MHz、真实LCD事务延迟；初始化tick压缩；任务码0空闲/1撤线/2恢复/3目标/4新线/5初始化。',
         [('angle_bcd','请求角度BCD','bcd'),('report_task','任务码','task'),('beam_valid','beam_valid','bit'),('beam_angle','已画角度\n二进制数值','bus'),('done','done','bit'),('quiescent','quiescent','bit')],'05_XOR扫描线任务')
    wave('beam','单次更新放大：撤旧线、恢复背景、目标、画新线','被动任务码来自冻结RTL：1撤线、2 A恢复、3 B目标、4画新线；beam_valid完成撤线变0、画新线后变1。',
         [('report_task','任务码','task'),('beam_valid','beam_valid','bit'),('beam_angle','已画角度','bus'),('done','done','bit')],'07_XOR单次任务放大',(9.68,10.72))
    wave('scan_continuous','连续扫描：先更新逻辑角度，再等PWM帧应用并测距','50MHz；连续步进60ms；自检/待机已压缩。此图放大55..85ms，采样回应为控制层模型。',
         [('angle','角度BCD','bcd'),('servo','servo PWM','bit'),('measure_start','measure_start','bit'),('sample_angle','测量绑定角度','bcd'),('sample_event','sample_event','bit')],'08_连续PWM与测距绑定',(55,85))
    wave('alarm','LCD近距离报警：A7 / A6切换与解除恢复','本专项物理时钟1MHz，250ms相位为真实物理时间；不能当成50MHz吞吐结果。',
         [('current_level','current_level','bus'),('current_valid','current_valid','bit'),('alarm_active','alarm_active','bit'),('inverse_phase','250ms相位','bit'),('last_inverse','last_inverse','bit'),('report_command','命令字节\n十六进制','hex')],'06_报警反显_250ms')


def main():
    architecture();tables();reports();waves()
    print('Generated architecture, pin/module tables, original-report excerpt, and eight VCD waveform figures (PNG+SVG).')


if __name__=='__main__':main()
