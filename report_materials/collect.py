"""Collect cited source material, not a finished experiment report."""
from pathlib import Path
import csv
import hashlib
import json
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'report_materials/radar_1270LE_20261022'
BUILD = ROOT/'radar/unified_scan/results/beam_min_byte_a/bcd'
FROZEN_SHA = '45963657dbc6975a83e8de8b566d6ee072bb1a34025de2c2e890bc1647ee71f3'
copied = []


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')


def write(name, content):
    path = OUT/name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.strip()+'\n', encoding='utf-8')


def copy(source, name):
    source = ROOT/source
    dest = OUT/name
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest)
    copied.append(dict(file=dest.relative_to(OUT).as_posix(), source=source.relative_to(ROOT).as_posix(), sha256=sha(source)))


def tree(source, name, extensions=None):
    for path in sorted((ROOT/source).rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts and (extensions is None or path.suffix.lower() in extensions):
            copy(path.relative_to(ROOT), str(Path(name)/path.relative_to(ROOT/source)))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pof = ROOT/'radar/beam_min/delivery/beam_min_full_r6-48_XOR_UFM8_keepInverse_1270LE.pof'
    assert sha(pof) == FROZEN_SHA
    for row in csv.DictReader(read(BUILD/'source_sha256.csv').splitlines()):
        assert sha(BUILD/'source'/row['File']) == row['SHA256'].lower(), row
    physical = json.loads(read(ROOT/'radar/beam_min/programming/20261017_084443/readback_verification.json'))
    assert physical['result'] == 'PASS' and physical['source_sha256'] == FROZEN_SHA

    docs = ['2026秋季学期数字电路与逻辑设计实验（下）实验题目.pdf', 'MAXII数字实验板（LCM12864液晶版）.pdf',
            'LCM12864_14图形点阵液晶数据手册.pdf', '简易雷达报警系统初步设计方案.pdf']
    for doc in docs:
        copy(doc, '01_任务要求与原始资料/'+doc)
    attachment=Path('.codex-remote-attachments/01a142d5-954a-7dc3-9d60-b3b6f77321f5/5dbc3a86-1ea9-44fe-aa63-a6d56f68fac5/1-1000005094.jpg')
    if (ROOT/attachment).exists():
        copy(attachment, '01_任务要求与原始资料/用户提供_报告评分表.jpg')
    else:
        image=OUT/'01_任务要求与原始资料/用户提供_报告评分表.jpg'
        assert image.exists(), 'Original grading attachment or retained copy required'
        copied.append(dict(file=image.relative_to(OUT).as_posix(),source=attachment.as_posix(),sha256=sha(image)))
    from pypdf import PdfReader
    pages = PdfReader(ROOT/docs[0]).pages
    write('01_任务要求与原始资料/题目原文_第4至5页.txt', '\n\n'.join(f'--- PDF第{i+1}页 ---\n'+pages[i].extract_text() for i in [3, 4]))
    write('01_任务要求与原始资料/要求与证据对应.csv', '''要求,资料及实现位置,证据边界
基本1_SW7和2Hz自检,完整工程/rtl/radar_unified_top.v及radar_unified_scan.v和显示报警模块,仿真日志及设计参数；实物照片待补
基本2_两秒后待机,radar_unified_scan.v状态SYS_SELF到SYS_STANDBY,生产参数仿真日志
基本3_两秒45度停靠与角度数码管,radar_unified_scan.v与radar_display_shared.v,基本模式生产测试日志；真实PWM保持规则见分块资料
基本4_超声测距及无效显示,ultrasonic_bcd_budget_compact.v与radar_display_shared.v,测距原始回归及新导出波形
基本5_五条角度历史颜色,radar_unified_scan.v五线历史与radar_display_shared.v,颜色分档及点阵复用资料；颜色实物照片待补
基本6_LED蜂鸣器分档报警,alarm_global.v与radar_global_timebase_alarm.v,原始报警测试；LED物理颜色需对板标识核对
提高1_连续扫描LCD雷达图,连续60ms每1度及UFM背景/XOR扫描线,双模式各1091帧显存参考对比通过；实物匀速效果需验收
提高2_自拟其他功能,近距离最高等级LCD反显250ms交替A7/A6,9条反显命令及显存不变专项；可作为自拟增强说明
''')

    tree('radar/unified_scan/results/beam_min_byte_a/bcd/source', '08_顶层代码与完整工程/完整工程')
    for f in ['radar_unified_bcd.fit.rpt', 'radar_unified_bcd.fit.summary', 'radar_unified_bcd.sta.rpt',
              'radar_unified_bcd.sta.summary', 'radar_unified_bcd.map.rpt', 'radar_unified_bcd.flow.rpt',
              'radar_unified_bcd.pin', 'radar_unified_bcd.asm.rpt', 'radar_unified_bcd.compile.log', 'source_sha256.csv']:
        copy((BUILD/f).relative_to(ROOT), '04_功能与资源/原始编译报告/'+f)
    copy(pof.relative_to(ROOT), '08_顶层代码与完整工程/完整工程/lcd_p4/beam_min_1270LE.pof')
    tree('radar/beam_min/postfit', '04_功能与资源/postfit')
    tree('radar/beam_min/programming/20261017_084443', '04_功能与资源/芯片烧录与回读')
    tree('radar/beam_min/pof_verified', '04_功能与资源/POF_UFM离线校验')
    for file in ['candidate_modules.csv', 'candidate_metrics.json', 'LE账.md', 'LE变化.md', '设计说明.md']:
        copy('radar/beam_min/'+file, '04_功能与资源/'+file if file!='设计说明.md' else '02_系统设计/扫描线实现资料.md')
    copy('radar/beam_min/delivery/verification.json', '04_功能与资源/交付验证_编译时历史状态.json')
    copy('radar/beam_min/delivery/verified_frame_052.png', '04_功能与资源/仿真显存52度预览_非实物.png')
    tree('radar/p5a/background/base', '02_系统设计/UFM背景')
    copy('radar/p5a/background/generate_background.py', '02_系统设计/generate_background.py')

    # Compact authoritative logs, not every obsolete intermediate project.
    tree('radar/p5a/runs/beam_min_a_full', '03_仿真波形与日志/原始20项回归', {'.csv', '.json', '.txt', '.log'})
    for d in sorted((ROOT/'radar/p5a/runs').glob('beam_min_a_full_*')):
        tree(d.relative_to(ROOT), '03_仿真波形与日志/原始20项回归分项/'+d.name.removeprefix('beam_min_a_full_'), {'.csv', '.json', '.txt', '.log'})
    for mode in ['basic', 'continuous']:
        tree('radar/beam_min/test/render/runs/byte_a_full/'+mode,
             '03_仿真波形与日志/完整显存参考/'+mode, {'.csv', '.json', '.log', '.png'})
        tree('radar/beam_min/test/render/runs/byte_a_busy_stop/'+mode,
             '03_仿真波形与日志/忙中停止/'+mode, {'.csv', '.json', '.log'})
    for file in ['timing_summary.json', '验证总结.md']:
        copy('radar/beam_min/test/render/'+file, '03_仿真波形与日志/'+file)
    tree('radar/beam_min/test/top_quiesce_results', '03_仿真波形与日志/真实顶层切换', {'.csv', '.json', '.log', '.md'})
    tree('radar/beam_min/test/ufm_a', '03_仿真波形与日志/UFM8读取', {'.csv', '.json', '.log', '.md'})
    tree('radar/beam_min/test/alarm/runs/beam_byte_a_alarm', '03_仿真波形与日志/报警反显', {'.csv', '.json', '.log'})
    copy('radar/beam_min/test/alarm/README.md', '03_仿真波形与日志/报警反显/测试说明.md')
    copy('radar/p5a/runs/beam_min_a_full/test_snapshot/radar/p5a/verification/tb_step1_pending.v', '03_仿真波形与日志/测试源/tb_step1_pending.v')
    for f in ['tb_ultrasonic_bcd_budget_compact.v', 'tb_scan_engine.v', 'tb_scan_control.v', 'tb_alarm_global.v', 'tb_display_shared.v']:
        copy('radar/p5a/runs/beam_min_a_full/test_snapshot/radar/sim/unified_scan/'+f, '03_仿真波形与日志/测试源/'+f)
    for f in ['tb_render.v', 'lcd_ram_bfm.v', 'reference.py']:
        copy('radar/beam_min/test/render/'+f, '03_仿真波形与日志/波形复现输入/'+f)
    for f in ['tb_alarm_inverse.v', 'prepare_alarm.py']:
        copy('radar/beam_min/test/alarm/'+f, '03_仿真波形与日志/波形复现输入/'+f)

    for src, dest in [
        ('radar/p5a/step1_failed/README.md','05_故障与问题/历史_step1时序未达1ns.md'),
        ('radar/p5a/restart/delivery/本轮总结.md','05_故障与问题/历史_1253LE阶段总结_已被后续扫描线取代.md'),
        ('radar/beam_min/initial_failed_timing/postfit_execution.log','05_故障与问题/1272LE失败_无法建立网表.log'),
        ('radar/unified_scan/results/beam_min_initial/bcd/radar_unified_bcd.fit.rpt','05_故障与问题/1272LE初版_Fitter.rpt'),
        ('radar/unified_scan/results/beam_min_noinvert_compare_20261018/README.md','05_故障与问题/关闭反显对照_未采用.md'),
        ('radar/unified_scan/results/beam_min_noinvert_compare_20261018/bcd/radar_unified_bcd.fit.summary','05_故障与问题/关闭反显对照1266LE.fit.summary'),
        ('radar/unified_scan/results/beam_min_noinvert_compare_20261018/bcd/radar_unified_bcd.sta.summary','05_故障与问题/关闭反显对照1266LE.sta.summary')]:
        copy(src, dest)

    wrapper = read(BUILD/'source/lcd_p4/radar_unified_variants.v')
    top = wrapper.split('module radar_unified_bcd_top', 1)[1].split('endmodule', 1)[0]
    write('08_顶层代码与完整工程/顶层入口_阅读注释版.v', '''// REPORT READING COPY: comments added; use 完整工程 for the compiled inputs.
// Quartus top entity: radar_unified_bcd_top. QSF sets P5_UFM/P5_UFM_BYTE/
// P5_INVERT/P5_BEAM to 1; parameter defaults alone are not production settings.
// clk: 50 MHz. sw7: system enable; sw6: basic/continuous mode; echo: sonar input.
// lcd_data: bidirectional 8080 bus. Peripheral pin numbers are in the QSF.
// ENABLE_READBACK=1; KEEP_END_BATCH=1; MEASUREMENT_BCD=1.
module radar_unified_bcd_top'''+top+'endmodule')
    system = read(BUILD/'source/rtl/radar_unified_top.v')
    write('08_顶层代码与完整工程/系统顶层_阅读注释版.v', '''// REPORT READING COPY: the byte-identical compiled source is in 完整工程/rtl.
// Flow: reset/timebase -> switch synchronizers -> scan/PWM -> sonar -> displays/alarm.
// LCD requests use committed measurement/angle snapshots and a single drawing FSM.
// Mode/off restart waits for XOR beam removal and LCD bus release.
'''+system)
    write('08_顶层代码与完整工程/工程使用说明.md', '''# 冻结工程资料

实际Quartus顶层是 `radar_unified_bcd_top`（lcd_p4/radar_unified_variants.v），不是旧radar_top。系统连接主体为rtl/radar_unified_top.v；两份阅读注释版仅用于理解和报告附录，未替换编译输入。

`完整工程/`逐字节复制成功1270LE编译时的source快照。使用Quartus II 9.1，打开lcd_p4/radar_unified_bcd.qpf。建议将完整工程复制到纯英文路径（例如D:/radar_report/），保持rtl和lcd_p4同级；命令行为 `quartus_sh --flow compile radar_unified_bcd`（工作目录lcd_p4）。器件EPM1270T144C5、50MHz、seed1。

QSF定义P5_UFM=1、P5_UFM_BYTE=1、P5_INVERT=1、P5_BEAM=1。wrapper固定ENABLE_READBACK=1和BCD测距。不要只看模块默认参数判定功能。

beam_min_1270LE.pof是已烧录并回读验证的单一文件，包含CFM和UFM。Programmer同时编程并Verify两区。这里不提供失败候选烧录文件。此资料整理不执行编译、换版或烧录。
''')

    write_notes()
    with (OUT/'来源索引.csv').open('w', encoding='utf-8-sig', newline='') as f:
        w=csv.DictWriter(f, fieldnames=['file','source','sha256']);w.writeheader();w.writerows(copied)
    meta=dict(collection_date='2026-10-22',timezone='Asia/Shanghai',
              repository_head=subprocess.check_output(['git','rev-parse','beam-min'],cwd=ROOT).decode().strip(),
              firmware_tag='beam-min-1270', firmware_build_commit='0881d4c',programming_commit='ac95e38',
              pof_sha256=FROZEN_SHA,le=1270,setup_ns=2.994,hold_ns=1.078,
              actual_source='radar/unified_scan/results/beam_min_byte_a/bcd/source',
              worktree_rtl_modified=True,uncommitted_rtl_used=False,
              original_report_written=False,physical_acceptance='not comprehensively confirmed',
              raw_sources_copied=len(copied))
    write('版本与证据边界.json', json.dumps(meta, ensure_ascii=False, indent=2))
    print('Collected', len(copied), 'source files; bundle:', OUT)


def write_notes():
    write('README.md', '''# 雷达实验报告资料包（不是报告成稿）

使用顺序：先看本页→01题目和评分表→02设计资料→03波形及分析线索→04编译/烧录证据→05问题记录。06仅提供结论所需事实和待补实验；07为AI使用与真实提示词摘录；08为带阅读注释的顶层及完整冻结工程。

| 评分表项目 | 分值 | 目录 |
|---|---:|---|
| 设计课题的任务要求 | 5 | 01_任务要求与原始资料 |
| 系统设计（思路、总体框图、分块） | 20 | 02_系统设计 |
| 仿真波形及分析 | 25 | 03_仿真波形与日志 |
| 功能与资源利用（编译报告截图） | 5 | 04_功能与资源 |
| 故障及问题分析 | 15 | 05_故障与问题 |
| 总结和结论 | 10 | 06_结论所需事实与待补材料 |
| AI工具使用（工具、提示词） | 10 | 07_AI使用资料 |
| 顶层HDL代码（注释，工程单独提交） | 10 | 08_顶层代码与完整工程 |

## 版本务必一致

资料主体对应已经烧录的1270LE版：固定r6–48 XOR扫描线、8位UFM读器、保留LCD报警反显；setup2.994ns、hold1.078ns。实际编译输入为冻结source快照，非存在未提交改动的工作区文件。2026-10-17已Program/Verify并JTAG回读CFM、UFM一致。1266LE关闭反显只属于对照试验，不是当前交付。

不要直接把历史1253LE总结中的“扫描线回退”“尚未烧录”写成现状；历史记录保留用于问题分析，最终版本以本页、实际1270LE编译报告及烧录记录为准。

## 图和证据怎么用

仿真图是由真实Icarus VCD导出的波形，有对应测试、日志、参数和原始VCD；不标成实物测量或ModelSim截图。背景/雷达预览来自初始化图或已比对的仿真RAM，均非实物照片。编译摘要图从原始Quartus文本报告直接排版，标注“非Quartus界面截图”；若老师要求软件界面截图，请在Quartus打开本包工程/报告补拍。

实物全功能验收没有完整照片和记录，不虚构完成。待补清单见06目录。AI材料仅整理本对话可见的工具和提示词，没有伪造完整聊天导出或未知模型版本。

来源逐文件可查 `来源索引.csv`；全包文件SHA见 `SHA256SUMS.json`。离线使用优先解压资料包，完整工程另附独立zip便于按评分表提交。
''')
    write('02_系统设计/设计事实与接口索引.md', '''# 设计事实卡片（供自行组织正文）

## 运行流程与调度

- 输入50MHz，单一全局时基提供us、ms、20ms舵机帧、250us显示扫描和报警节拍。reset_ctrl产生上电复位。
- SW6/SW7先两级同步，按20ms采样消抖。系统状态0=OFF、1=SELF、2=STANDBY、3=RUN。SELF和STANDBY各2000ms。
- SW7同步但未消抖信号用于即时外设关闭；消抖后的system_on用于状态机。避免异步引脚直接扇出到内部状态寄存器。
- 基本模式停靠0/45/90/135/180再返回，每槽2000ms。内部45个1度逻辑步、每步16us，720us完成快走；真实舵机PWM在20ms帧边界应用最终角度，不是机械舵机720us完成转动。
- 当前SETTLE_FROM_PWM=0：按槽起点300ms发测距，不能写成所有情况都在PWM更新后稳定300ms；这是已保留的资源/时序取舍。历史点阵相位变化上界28ms，不等于所有脚位逐周期等同旧版。
- 连续模式60ms/1度，0→180→0。PWM帧20ms，0度0.5ms、90度1.5ms、180度2.5ms高电平，计数/余数法产生约11/12us步进；实际机械匀速需实物确认。

## 测距与输出映射

- HC-SR04：TRIG默认15us；ECHO两级同步后计宽。50MHz下294时钟约1mm，四位BCD用一个4位加法器串行轮转，减少二进制转十进制电路。
- 有效20..4000mm，超时/无效显示----；理想换算误差实验约束≤2mm，不代表传感器实物测量误差≤2mm。
- LCD半径floor(distance_mm/25)，有效画点范围≤1200mm/r48；绘图最小半径6，小于r6的有效点钳位r6。超出LCD显示半径仍可在数码管显示。
- 当前距离等级：≥800为1、600..799为2、400..599为3、200..399为4、<200为5。无效为0。
- 五条历史角线颜色保持到相应下次更新；绿色/黄绿色/黄色/橙色/红色由双色点阵红绿占空配比合成，原图案与实际板色需核对。
- 八位数码管与8行点阵共用扫描序号，约250us切一位/行、全帧约2ms；有消隐阶段抑制串扰。
- LED与蜂鸣器：alarm_global复用全局节拍；蜂鸣载波2kHz、节奏按等级加急。LCD最高等级报警250ms切换A7/A6，不改显存，解除A6。

## LCD数据通路

- 8080并口：8位双向数据、A0、RD/WR、CS、RST。每次重设地址后先空读，再有效读；回写前重设列地址，方向切换由lcd_bus_phase统一执行。
- 所有显存操作串行经radar_lcd_micro一个FSM。射线坐标由共享位串行Minsky/累加数据通路生成，F15/K7参数；同字节像素先OR成mask再一次读改写。
- UFM映射word={page[2:0],col[6:1]}，偶列高字节、奇列低字节，bit0为页顶。ALTUFM_NONE存512×16位=1024字节屏幕背景；读器数据寄存器8位。AR/DR时钟≤3.125MHz，非等待器件握手。
- 初始化顺序复制1024个可见字节，另32隐藏列清零；A与端区批量清除执行(old & ~mask)|(bg & mask)。B在目标像素置1。
- 新请求先撤旧扫描线→A恢复→B目标→画新扫描线。beam_valid+beam_angle记录旧线；固定r6–48，不做遇目标截短。整数位变化标志去重，不另存上一坐标。
- pending合并忙时请求，空闲接收最新角度/距离；绘制期间快照稳定。基本快走可合并；连续步进应无合并。端区清除、模式切换、关闭前先撤线再复位LCD。

模块与引脚表为源QSF自动导出，见模块表.csv、引脚表.csv；总体框图另提供PNG和Mermaid原文。所有参数最终以08冻结工程为准。
''')
    write('04_功能与资源/使用资源数据时注意.md', '''# 资源证据使用说明

主版本：EPM1270T144C5，1270/1270 LE、75/116管脚、UFM1/1；Fitter成功，clk setup2.994ns、hold1.078ns，seed1。

模块LE取Fitter实体表括号中的自身值，不把父模块子树和子模块重复相加。不同布局中的打包变化不能全归因于某个RTL位数变化。a步骤整机1272→1270净省2LE，不是16→8位直接省8LE。

一级异步输入同步器例外经过三项网表断言：≥2级、原始引脚只到首级、首级只到第二级。未约束输出58个/456路径，相对接受基线增减0。不得在报告写“所有路径均已约束”或“无任何未约束路径”。SDC计数节拍接口关系及裕量解释见postfit和冻结SDC。

编译报告摘录PNG来自原始报告文本排版，数值与原始文件一致，非Quartus窗口截图。若必须提交GUI截图，打开冻结工程的Compilation Report，截图Flow Summary、Fitter Resource Usage、TimeQuest Setup/Hold，并保留器件、版本和工程名。

编程验证证明CFM/UFM写入一致，不能证明舵机机械动作、测距精度或LCD实物画面全部合格。芯片烧录与回读目录为2026-10-17实际记录；交付验证JSON中的hardware_programmed=false是编译交付时历史快照。
''')
    write('05_故障与问题/问题事实索引.md', '''# 问题事实和可引用证据（自行选择分析）

| 问题/现象 | 原因证据 | 处理/最终状态 | 可引用资料 |
|---|---|---|---|
| 基本模式擦除前方偏移导致旧目标残留风险 | 基本A原采用前方10度，快走请求可能忙中跳过 | 基本A偏移0；pending最新请求及快照 | 设计资料、step1_pending日志 |
| 异步SW7大扇出及新选择逻辑影响时序 | 初轮1109LE setup0.970ns，曾不达额外1ns目标 | 同步SW7；门槛修订后定向修复，最终1270版setup2.994ns | 历史_step1资料、最终postfit |
| 原圈点混入目标擦除 | 恢复纯黑无法保留圈/刻度 | UFM保存静态背景，掩码恢复；B不再画圈 | UFM背景和LCD设计源码 |
| 旧扫描线方案资源超限 | 旧最好1321LE，超51；共享地址/返回角1328、Area1368、seed1–8仍超 | 固定全长、去掉长度/额外角度状态、复用射线任务 | LE账与历史1253阶段总结 |
| 最简扫描线初版仍超2LE | Fitter需要1272LE，无成功postfit网表 | UFM8位数据读取，整机1270LE成功 | 1272失败报告、最终编译报告 |
| 同一离散像素被重复XOR会抵消/断线 | 相邻半径有相同整数坐标 | 比较串行加法整数位变化；r6首点强制包含 | 106918变化校验/模式、完整帧参考 |
| 模式切换可能留下旧线 | 顶层OFF可能仅一个时钟，直接复位来不及撤线 | lcd_restart_pending保持停止条件，撤线且总线释放后复位 | 真实顶层4场景日志 |
| 两端附近背景黑白交替（用户实物反馈） | 代码允许有效距离<200mm时A7/A6每250ms交替 | 符合报警反显的可能表现；是否因测到支架/桌沿尚未实测确认 | 最高级报警条件源码、报警专项；不能写成已定位硬件故障 |
| 去反显能否省很多资源 | 独立对照整机1266LE，setup3.456ns、hold1.078ns | 实测只省4LE，未采用/未烧录，非最终方案 | 关闭反显对照资料 |
| 动态数字/模式字/等级条放不下 | 历史最少1395/1311/1307LE | 回退未交付；数码管仍提供角度/距离，LCD不含动态数字 | 历史1253阶段总结 |

历史报告中的上板状态、LE和扫描线回退结论仅适用于当时版本，不可拼接成当前版本结果。该表是原始问题材料索引，不是代写的故障分析正文。
''')
    write('06_结论所需事实与待补材料/事实与待补清单.md', '''# 可供结论引用的事实

- 最终单一POF：1270LE、Fitter通过、setup2.994ns、hold1.078ns；SW6双模式，ENABLE_READBACK=1，1度逻辑步进，r6最小半径。
- 原有20项回归通过；两种模式各3往返、1091请求、1152096字节参考对比；各1091撤线和106918整数变化检查通过。
- 最坏帧保守6.88354ms，含一次反显6.88394ms；连续60ms间隔余量53.11606ms。不是所有帧都经过全真实引脚时序仿真；长测试抽象事务加保守补偿，另有真实节拍冒烟。
- LCD初始化47.62916ms含原等待与5周期reset，UFM首次请求至display-on3.62654ms；不是完整2秒自检+2秒待机开机总响应。
- 2026-10-17已CFM/UFM Program/Verify及回读一致，原1253回退POF保留。
- 资源100%占用；关闭反显独立对照只省4LE，未部署。LCD动态数字、模式字、等级条未实现。

# 需要你补充的实物材料（目前没有，不能编造）

1. 板卡/舵机/HC-SR04接线全景，标注电源地、TRIG/ECHO、舵机、LCD。
2. 开机自检和待机照片/视频，记录各2秒及2Hz现象；SW7关闭时显示和声响状态。
3. 基本模式五个角度的数码管/点阵/目标，连续模式及折返视频。
4. 用尺测若干已知距离，记录“实际距离/数码管/误差/等级/LED/蜂鸣”，含200/400/600/800mm边界附近与超范围。
5. LCD圈完整、单点目标、相邻列正确、无竖条错位；换向/模式切换后扫描线无残留。
6. <200mm报警反显及解除恢复；若端点误报警，记录朝向、支架/桌沿距离、数码管和LED状态，先区分真实近物和误回波。
7. 如果老师指定Quartus界面截图，按04说明补Flow Summary、资源表和时序窗口截图；已有原始报告摘录图可供数值参考。

# 自己组织总结时可思考

哪些取舍换来单芯片双模式？为什么采用BCD串行计数/共享时基/字节掩码？仿真验证和实物验证各证明什么？100%LE限制哪些扩展？这些是写作线索，不是预写的个人心得。
''')
    write('07_AI使用资料/工具和证据边界.md', '''# 已知工具使用事实

| 工具 | 本项目中用途 | 可引用证据 |
|---|---|---|
| Codex桌面AI编程助手 | RTL方案、修改、定位资源与时序问题、生成验证脚本、整理资料 | 本目录真实用户提示词摘录；Git提交与代码 |
| Quartus II 9.1 Build222 | MAX II整机综合/Fitter/TimeQuest/POF及编程校验 | 原始compile/fit/sta/Programmer日志 |
| Icarus Verilog / vvp | RTL与LCD/UFM行为模型仿真 | 20项回归、显存比对、波形新增采集日志 |
| Python | PNG/MIF/HEX生成与反解、独立显存参考、统计、波形图和资料打包 | background生成器、reference.py、波形脚本 |
| Git / GitHub CLI | 版本、回退标签、提交与远端交付 | beam-min、delivery-1253、beam-min-1270及提交记录 |

未从可靠记录确认每轮实际AI模型的具体型号，不猜写GPT版本。未获取完整聊天导出，本目录摘录只覆盖当前对话可见消息，不等同全部历史交互。编译器、仿真器、Python属于验证工具，不能全部叫AI模型。

AI产出经过Fitter、时序、参考模型与回读验证；最终实物判断和报告结论由本人核实。可分别记录AI参与的环节、你提出的约束、接受/回退的方案、你自己的修改与复核。不要把AI给出的LE预测写成实测。
''')
    write('07_AI使用资料/真实用户提示词摘录.txt', '''来源：本对话可见的用户原消息摘录，按原文抄录。不是完整聊天记录，不包含系统/开发者指令。

【最简扫描线任务原文】
当前 1253 LE 版本冻结为交付候选（打标签 delivery-1253），POF 保持不变。另开分支 beam-min，只尝试一项：最简扫描线。

1. 先出一张 LE 账：
   - 当前各模块 LE 与 1089 基线逐模块对比；
   - 上一轮扫描线最好候选的 LE、各模块增量，以及已经试过的优化。

2. 最简扫描线规格（比上一轮简化）：
   - 全长 r6–48，XOR 绘制；不做遇目标截短（不需要 beam_len 和比较器）。
   - 只新增 beam_valid 和 beam_angle 两个状态。
   - 去重：利用射线步进累加的整数位变化标志，x、y 整数位都没变就跳过该步；不另存上一像素坐标。
   - 复用 A 步和端区清除用的同一射线引擎，只新增"撤旧线""画新线"两个任务和 XOR 运算。
   - 顺序：撤旧线 → A → B → 画新线；端区批量清除、模式切换前先撤线；上电时 beam_valid=0。

3. 腾 LE（按顺序做，够了就停）：
   a. UFM 读只保留需要的 8 位：高字节取前 8 位后停止，低字节跳过前 8 位；移位寄存器由 16 位减为 8 位。
   b. 其他功能等价的化简，逐项列出节省的 LE。
   c. 仍不够时，删除 LCD 报警反显（自拟增强），LED/蜂鸣器报警保持不变。
   不得删除题目要求的任何功能。

4. 门槛：
   - LE ≤ 1270，Fitter 成功，setup > 0，hold > 0；
   - 原有仿真全部通过；
   - 扫描线参考模型比对：两种模式各至少 3 个往返，撤线后显存与"无扫描线"模型逐字节一致；
   - 未达标时按之前的修复流程处理（最差路径分析、seed 1–8）。

5. 结果：
   - 通过：出新 POF，写明与 delivery-1253 的差异（是否删除了反显）。
   - 不通过：报告还差多少 LE，然后停止，不再尝试其他功能。

【后续实际消息】
烧录
接入了
为什么现在雷达到正负180°的时候，背景会黑白交替闪烁
这个报警反显是什么功能
如果去除这个功能，能节省多少资源
目前还剩多少资源
先把当前版本提交到git
推送远端

【本次资料收集原文】
我现在需要写一个报告，你不用给我写，你把我报告上面需要的资料收集一下，把这个报告的资料打包推送到GitHub，然后我自己根据这些资料来进行报告撰写
''')


if __name__ == '__main__':
    main()
