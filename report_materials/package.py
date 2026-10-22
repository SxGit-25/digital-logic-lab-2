"""Validate collected report sources and build independently usable ZIPs."""
from pathlib import Path
import csv
import hashlib
import json
import shutil
import sys
import zipfile

sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'report_materials/radar_1270LE_20261022'


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def put(path,text):
    path=BASE/path;path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text.strip()+'\n',encoding='utf-8')


def guide():
    put('03_仿真波形与日志/波形选图与分析线索.md','''# 波形选图索引（数据和观察点，不是报告正文）

所有图从本包真实VCD事件导出，配有输入测试源、source_hashes.json、run.json和PASS日志。PNG适合粘贴，SVG可无损缩放，VCD可用GTKWave打开。原始VCD单位1ps，PNG横轴统一换成ms。

| 图 | 观察信号与事实 | 写分析时核对什么 |
|---|---|---|
| 01 测距全程 | ECHO/TRIG/busy/BCD/valid/level；20、199、200、800、1200、4000mm以及无回波 | 测距提交后BCD与等级同步；超时有效标志撤销，不能把旧数字当有效距离 |
| 02 测距报警边界 | 放大前3.4ms，199mm等级5、200mm等级4 | 阈值使用严格<200mm进入最高等级；图中时间是50MHz真实RTL仿真 |
| 03 基本扫描 | 状态1/2/3，45度步进、fast_busy、PWM、测距事件 | SELF/STANDBY各2ms、SLOT20ms、SETTLE3ms为采集压缩值，不能写成题目生产参数 |
| 04 连续扫描 | 角度0、1、2、3，60ms逻辑间隔；20ms PWM帧 | 连续STEP保留60ms；启动SELF/STANDBY压缩；sample_angle对应测量绑定，不是任意瞬间显示角 |
| 05 XOR任务全程 | 请求角、任务码、beam_valid/beam_angle、done、quiescent | 7个定向请求含0/1/45/90/179/180/0，含无效和超显示半径目标；端区恢复较长 |
| 06 报警反显 | alarm_active、250ms相位、last_inverse、命令A7/A6 | 1MHz物理时钟专项真实250ms节拍；9次命令不改显存；解除返回A6 |
| 07 XOR单次放大 | 任务1→2→3→4：撤旧线/A恢复/B目标/画新线 | 旧线有效到撤完才置0，画新线完才置1；beam_angle在valid=0期间可已更新成下一条角度 |
| 08 连续PWM绑定 | 55..85ms放大角度步进与PWM帧应用/measure_start | 逻辑角可先变，实际PWM在帧边界采用；测量等待应用，不能说逻辑角改变即舵机机械到位 |

## 采集边界

- measurement：冻结ultrasonic_bcd_budget_compact，50MHz时钟，六个有效ECHO宽度和无回波超时，新增测试没有force/deposit。
- scan_basic/continuous：冻结radar_unified_scan，50MHz时钟；控制层测距完成回应模型为5us，固定600mm，未接ECHO物理传感器模型。基本模式定时压缩仅为了选图，不能据此宣称舵机已经充分稳定。生产默认2s/45度、300ms等结论来自另存的生产回归日志。
- beam：冻结radar_lcd_micro及8位UFM，真实LCD读41/写17周期事务延迟、原有独立Python显存参考；只将初始化tick压缩。7帧共7392字节比对通过，任务码是测试端从状态和任务计数被动译出的观测信号，不是生产RTL新增状态。
- alarm：沿用已验收专项，只增加被动VCD和最后一条A6/A7观测寄存器；1MHz时钟是该测试的支持设置，不能用其周期直接表示50MHz实际帧时间。测试相位取rhythm_phase[1]，生产blink_2hz取其反相，初始相位不同，250ms间隔与解除行为相同。
- 新增采集均只用于报告选图，既有20项和双模式各3往返完整参考日志仍另存，并未用7帧冒烟替代1091帧回归。

原测距回归：20个样本，理想换算最大误差1.596600mm；另穷举5301个可达十进制值的mod25/半径判定。这是理想RTL量化验证，不是HC-SR04实物误差实验。原生产连续日志样本0/1/2度测量间隔均60ms，PWM高电平500/511/522us；基本生产日志存在45个逻辑中间步，但没有中间角PWM脉冲。

`新增波形/*/events.csv`保存逐事件时间和数值，`源代码`位于08冻结工程，测试注入/监测见每组input_tb.v。编译命令和参数见run.json。新增波形状态汇总status.json共5组PASS。
''')
    put('02_系统设计/定量公式与参数卡片.md','''# 定量参数卡片

| 项目 | 值/公式 | 出处/边界 |
|---|---|---|
| 系统时钟 | 50MHz，T=20ns | QSF/SDC与生产参数 |
| 自检/待机 | 各2000ms | radar_unified_scan默认，图采集有压缩 |
| 基本扫描 | 每2s进入下一45度停靠，往返 | 共享逻辑1度计数，45×16us=720us快走；非机械时间 |
| 连续扫描 | 60ms/1度，单程180步约10.8s | 逻辑调度，实物速度需校准 |
| PWM | 帧20ms；0°0.5ms、90°1.5ms、180°2.5ms | 角度每1度约11.111us余数累加 |
| 超声理想公式 | d_mm = 0.17×t_echo_us | 声速340m/s、往返除2 |
| RTL量化 | 294×20ns=5.88us约1mm | 每294周期串行BCD加1，边沿同步有量化 |
| 测距范围 | 20..4000mm；TIMEOUT_US=30000 | ms超时实现有刻度量化，别声称每次正好30.000ms |
| 半径映射 | floor(mm/25)，≤1200mm可见，绘图最小r6 | 有效近点钳位r6；r48对应1200mm |
| 背景 | 128×64=1024字节，8page | LCD模型含132列×8page=1056字节，32隐藏列归零 |
| UFM | 512word×16位=8192bit | word={page,col[6:1]}；偶列高/奇列低；bit0页顶 |
| 静态图 | 圆心(64,63)，圈r16/32/48，外刻度r52 | 对应0.4/0.8/1.2m；最终没有DEG/mm/LV头文字 |
| 扫描线 | 固定r6..48 XOR | 不遇目标截短，不使用OR替代 |
| 反显 | 最高等级且valid时A7/A6每250ms交替 | 周期500ms=2Hz；解除强制A6 |
| LCD帧时间 | 保守6.88354ms，加1条反显6.88394ms | 完整仿真加事务/相位保守余量，详见验证总结 |
| 初始化 | 47.62916ms；首UFM请求至display-on3.62654ms | LCD子系统，不含两段2s系统启动 |
| 最坏报警等待 | ≤7.39402ms | 计入忙中pending优先撤线，初始化完成后 |

资源：1270/1270LE，自身LE相加；75/116管脚；UFM1/1。setup2.994ns、hold1.078ns。1266LE仅是关闭反显的隔离对照。
''')


def reproducibility():
    for f in ['capture_waves.py','make_figures.py']:
        target=BASE/'复现脚本'/f;target.parent.mkdir(exist_ok=True)
        shutil.copy2(ROOT/'report_materials'/f,target)
    put('复现脚本/requirements.txt','numpy\npillow\nmatplotlib\npypdf')
    put('复现脚本/使用方法.md','''# 数据和图的复核

查看资料不需要运行任何脚本。VCD可用GTKWave打开；PNG/SVG可直接插图。

重新导出新增5组波形，需要Python、Icarus Verilog（iverilog.exe及vvp.exe）和Pillow；生成图另需Matplotlib/NumPy。Windows PowerShell示例：

```powershell
$env:RADAR_REPORT_BUNDLE = (Resolve-Path '解压后的radar_1270LE_20261022').Path
$env:IVERILOG_BIN = 'C:/tools/iverilog/bin'
python "$env:RADAR_REPORT_BUNDLE/复现脚本/capture_waves.py"
python "$env:RADAR_REPORT_BUNDLE/复现脚本/make_figures.py"
```

建议先复制整份资料到另一个目录，避免覆盖原始证据；脚本将更新新增波形目录。图脚本使用Windows微软雅黑和Consolas；其他平台需要替换字体。生产RTL始终从08完整工程的冻结rtl读取，不从活动开发目录读取。UFM行为模型读取相同background.mem。

完整1091帧参考的原始测试源在03/波形复现输入，reference.py的prepare默认生成3往返，--smoke仅7帧。修改采集脚本去掉--smoke即可生成完整参考，但可能耗时较长；原有完整PASS日志已提供。原有20项回归含旧实现和独立模块验证，源码与参数以各自原始日志/哈希为准，不能把全部测试都称为1270LE顶层全引脚实物测试。

完整工程单独压缩文件用于按评分表另交，使用说明在08目录。编译/重绘不等于重新烧录；本收集过程未烧录。
''')


def zip_tree(root, dest):
    with zipfile.ZipFile(dest,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=7) as z:
        for f in sorted(root.rglob('*')):
            if f.is_file():z.write(f,root.name+'/'+f.relative_to(root).as_posix())
    with zipfile.ZipFile(dest) as z:
        assert z.testzip() is None
        assert all('..' not in Path(n).parts for n in z.namelist())


def main():
    guide();reproducibility()
    originals=list(csv.DictReader((BASE/'来源索引.csv').open(encoding='utf-8-sig')))
    for row in originals:assert sha(BASE/row['file'])==row['sha256'],row['file']
    frozen=BASE/'08_顶层代码与完整工程/完整工程/rtl'
    statuses=json.loads((BASE/'03_仿真波形与日志/新增波形/status.json').read_text())
    assert len(statuses)==5 and all(s['pass_'] for s in statuses)
    for state in statuses:
        folder=BASE/'03_仿真波形与日志/新增波形'/state['name']
        hashes=json.loads((folder/'source_hashes.json').read_text())
        for f in frozen.glob('*.v'):assert hashes[f.name]==sha(f),(state['name'],f.name)
        assert (folder/'trace.vcd').stat().st_size>1000
    old=list(csv.DictReader((BASE/'03_仿真波形与日志/原始20项回归/status.csv').open()))
    assert len(old)==20 and all(r['Pass']=='True' for r in old)
    for mode in ['basic','continuous']:
        d=BASE/'03_仿真波形与日志/完整显存参考'/mode
        assert '1091 requests, 1152096 bytes' in (d/'comparison.log').read_text()
        assert 'BEAM_REMOVE_PASS comparisons=1091' in (d/'simulation.log').read_text()
    pof=BASE/'08_顶层代码与完整工程/完整工程/lcd_p4/beam_min_1270LE.pof'
    assert sha(pof)=='45963657dbc6975a83e8de8b566d6ee072bb1a34025de2c2e890bc1647ee71f3'
    from PIL import Image
    pngs=list(BASE.rglob('*.png'))
    for f in pngs:
        with Image.open(f) as img:img.verify()
    assert len(list((BASE/'03_仿真波形与日志/波形图').glob('*.png')))==8
    project_zip=ROOT/'report_materials/radar_1270LE_project_20261022.zip'
    zip_tree(BASE/'08_顶层代码与完整工程/完整工程',project_zip)
    shutil.copy2(project_zip,BASE/'08_顶层代码与完整工程/完整工程_1270LE.zip')
    verification=dict(result='PASS',reference_version='beam-min-1270',source_files_verified=len(originals),
                      old_regressions=20,new_vcd_runs=5,waveform_figures_png=8,
                      full_modes_each_frames=1091,full_modes_each_bytes=1152096,
                      project_pof_sha256=sha(pof),original_report_written=False,
                      physical_photos_provided=False,quartus_gui_screenshot_provided=False,
                      quartus_text_excerpt_provided=True,source_code_from_frozen_build=True)
    put('资料包校验.json',json.dumps(verification,ensure_ascii=False,indent=2))
    sums={f.relative_to(BASE).as_posix():sha(f) for f in sorted(BASE.rglob('*')) if f.is_file() and f.name!='SHA256SUMS.json'}
    put('SHA256SUMS.json',json.dumps(sums,ensure_ascii=False,indent=2))
    archive=ROOT/'report_materials/radar_1270LE_20261022.zip'
    zip_tree(BASE,archive)
    with zipfile.ZipFile(archive) as z:
        for file,digest in sums.items():
            assert hashlib.sha256(z.read(BASE.name+'/'+file)).hexdigest()==digest,file
    result=dict(result='PASS',file_count=len(sums)+1,all_file_checksums_match=True,
                archives=[dict(file=p.name,bytes=p.stat().st_size,sha256=sha(p)) for p in [archive,project_zip]])
    (ROOT/'report_materials/package_verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))


if __name__=='__main__':main()
