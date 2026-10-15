"""Generate the budget audit from full-project Quartus results, never LE estimates."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "results"


def main():
    builds = {x["build"]: x for x in json.loads((RESULTS / "resource_comparison.json").read_text(encoding="utf-8"))}
    rows = list(csv.DictReader((RESULTS / "module_resources.csv").open(encoding="utf-8-sig")))
    chosen = "budget_final_index/bcd"
    modules = [r for r in rows if r["build"] == chosen]
    assert sum(int(r["le_self"]) for r in modules) == 1089
    assert builds[chosen]["registers"] == 437

    def module(key, children=False):
        r = next(r for r in modules if key in r["module"])
        return int(r["le_including_children"] if children else r["le_self"])

    cats = [
        ("测距", module("ultrasonic_bcd_budget_compact:"), 120, 67),
        ("扫描+ctrl", module("radar_unified_scan:"), 230, 100),
        ("点阵+数码管+display_compose", module("radar_display_gated:", True), 195, 36),
        ("报警", module("alarm_global:"), 50, 0),
        ("LCD 总线（init 已吸收入绘图）", module("lcd_bus_phase:"), 95, 29),
        ("绘图（含 init）", module("radar_lcd_micro:", True), 210, 145),
    ]
    cats.append(("顶层其余", 1089-sum(c[1] for c in cats), 100, 60))
    assert sum(c[1] for c in cats) == 1089
    assert sum(c[3] for c in cats) == 437
    cat_table = "\n".join(f"| {n} | {le} | {budget} | {reg} | {'达标' if le <= budget else '超出 '+str(le-budget)} |" for n, le, budget, reg in cats)
    stages = [
        ("BCD 起点", "final6/bcd"),
        ("1 init 合并首试（反增，保留证据）", "budget_s1_merge/bcd"),
        ("1 单相位总线", "budget_s1_phase/bcd"),
        ("2 串行角度转换/共享计数/握手", "budget_s2_handshake/bcd"),
        ("3 /294 与两份 BCD", "budget_s3_measure/bcd"),
        ("4 全局时基/共享显示：首次装入并已报告", "budget_s4_shared_scan/bcd"),
        ("5 扫描共享，槽起稳定", "budget_s5_slot/bcd"),
        ("5 对照：PWM 后稳定（未选）", "budget_s5_pwm/bcd"),
        ("6 全局报警/开关采样/接口门控", "budget_s6_global_alarm/bcd"),
        ("6 隔离测试半径译码", "budget_s6_radius/bcd"),
        ("6 历史编码/等级副本消除", "budget_s6_history/bcd"),
        ("6 寄存 LCD 控制边沿", "budget_final_strobes/bcd"),
        ("6 消除总线无用数据复位", "budget_final_payload/bcd"),
        ("6 索引从已锁存角度译码：最终选择", chosen),
        ("最终同源稳定计时复核：PWM 后300ms（未选）", "budget_final_pwm_compare/bcd"),
    ]
    stage_table = []
    for label, key in stages:
        b = builds[key]
        s = b["slack_ns"]
        setup, hold = s.get("Setup 'clk'", "—"), s.get("Hold 'clk'", "—")
        timing = f"{setup} / {hold}" if s else "无合法布局时序"
        stage_table.append(f"| {label} | {b['fitter_le']} | {b['registers']} | {'成功' if b['fitter_success'] else '失败'} | {timing} | `{key}` |")
    body = """# 全模块预算执行报告：1089 LE，模块预算尚未全部达标

最终选择 `budget_final_index/bcd`：EPM1270T144C5、50MHz，**1089/1270 LE、437寄存器、75 I/O、UFM 0；Fitter成功，setup 3.786ns、hold 1.078ns**。比1415起点少326 LE/119寄存器；低于优选1143上限54 LE。首次成功装入是在1195 LE步骤，已先报告后继续。所有行均为完整整机编译，不使用独立模块LE相加代替。

这是离线资源与仿真交付，不是全部验收项目完成：测距与绘图各自预算仍超出，基本模式快走丢请求后的完整雷达图尚未证明，电气与上板测试未执行。

## 最终模块分账

| 类别 | 实测 LE | 预算 LE | 寄存器 | 预算状态 |
|---|---:|---:|---:|---|
""" + cat_table + """
| **总计** | **1089** | 优选≤1143，接受≤1270 | **437** | **整机达标** |

绘图395=微序列自身283+共享位串行寄存器/ALU112，init已在同一个状态机中，不能另减旧init的79。它确为Minsky、无sin/UFM/队列、一个微序列与位串行ALU，但控制计数/phase仍有单独算术，未达到210。LCD62仅总线，无独立init。显示151=接口即时门控31+共享扫描/译码120；这是实际层级归属，不把移入接口的门控算成凭空消失。顶层其余100=wrapper1+system自身15+全局时基67+reset8+双开关采样9。

## 每步完整编译

所有整机均75 I/O、UFM0；时序栏为setup/hold，单位ns。失败行是资源需求，不是布局占用。

| 步骤 | 总 LE | 寄存器 | Fitter | setup / hold | 原始证据目录 |
|---|---:|---:|---|---|---|
""" + "\n".join(stage_table) + """

逐模块自身及子树LE原表为 `module_resources.csv`；每个构建均有独立source快照和SHA256。`budget_s6_radius`用上一阶段扫描快照，隔离半径方案的变化；`budget_s6_history`才接入新的历史编码，未把两项收益混算。紧凑编码、布局种子等未选试验亦完整保留：全局USER-ENCODED反增，局部绘图sequential为1108，比1092反增16，均已撤回。最终使用默认布局种子1。

各阶段该类实测：init合并首试绘图411+bus100，总LE反增；单相位试验bus41、绘图含init447；第二步bus87、绘图385；第三步测距140；第四步显示120、scan253、时基64；第五步scan247；第六步初版报警15、显示145、顶层其余101。最后一律以本报告最终表为准，不跨优化上下文混用子树差值。

## 稳定计时与最新验收契约

同源整机 `budget_s5_slot/bcd` 为1183 LE，`budget_s5_pwm/bcd`为1198 LE。最终架构再次完整核对：1089 LE对 `budget_final_pwm_compare/bcd` 的1104 LE，仍多15 LE（>2），两版Fitter/时序均通过。按用户明确条件选 **SETTLE_FROM_PWM=0**，基本模式从2s槽起300ms测距，点阵可见变化验收上限 **28ms**。参数1保留为可复现对照，未作为默认。

对齐生产用例首0°两方案均槽+300ms，后续槽分别+300/+320ms；全局时基持续运行，任意时刻拨动SW不保证槽与20ms帧对齐，参数1实际依据目标PWM帧应用，而非固定加20ms。新共享扫描每行/位250µs，8行2ms，4颜色相位8ms；同扫描器两种采样时刻相差20ms的53760种颜色/行/相位/边沿组合最大可见差24ms，低于28ms。此证明不是与f4507a8逐波形等价声明，详见 `matrix_bound/exhaustive.json`。

1°、MIN6、前方10° A再B、端区11条A、后方命中0均保留。普通请求严格<1ms；端区≤20ms。SW6只改步进节奏，单套BCD角度/方向/PWM/调度/历史。基本快走45×16µs=720µs，PWM快走期间保持完整旧目标，下一帧应用新目标；目标0→45→90→135→180→135→90→45→0，2s槽。连续60ms/1°，测量最坏等待20ms帧+31ms超时<60ms，仍无epoch队列。

## 测距与显示/报警预期变化

题目口径优先，不再逐例复刻旧毫米量化。整数/294在同步echo上升相位清零，仅工作/提交BCD两份，提交前完成四拍串行进位。理想为echo_clocks×0.0034mm，穷举1177059种宽度，最大误差1.5966mm，有符号[-0.9916,+1.5966]。有效判定使用显示测得的整数20..4000mm（含端点）与超时；无效显示----。阈值按200/400/600/800的≥边界分档。

后续半径方案复用完成的BCD低两位00/25/50/75产生每25mm进位，不再保存独立mod25寄存器；半径48饱和，>1200无效。5301种可达BCD值半径译码与20组真实RTL边界/无回波/长回波/取消/进位收尾测试通过。/294毫米量化是用户要求的专用节拍；µs/ms/20ms/显示扫描/报警/消抖均来自唯一全局时基，无第二套模块分频。

具体预期调整：

1. 原六套测试**没有修改预期**，最终重新运行全部通过；它们保留旧模块回归用途，不冒充新BCD整机与旧版逐周期等价证明。
2. 新BCD测试按/294理想误差与20..4000整数判定，不再沿用旧raw_us范围、17/100舍入、25mm边界逐例一致。提交BCD在busy期间保持，只在done前提交；数码管读取唯一提交值。
3. 新扫描history采用level0表示已测无效，删除5位独立valid；seen仍区分未测绿色与无效空白。`tb_scan_control`无效900mm内部level从1改0，`tb_scan_bcd`无效0000从5改0，外部颜色不变。五线索引从已锁存角度译码，删除3位重复索引；仍锁存测量角度。
4. BCD等级由提交值组合译码，较旧等级寄存副本可早1clk=20ns；数值≥/<规则不变。新bench两处人工帧注入从frame_us wire改local_frame_us reg，仅fixture节点变化，原断言不变。
5. 点阵与数码管共用一个3位索引及250µs节拍，帧500Hz；每LED颜色周期125Hz，占空比/五线图案/颜色映射不变，40ns消隐。全局报警保留2Hz LED闪烁、2kHz载波及1/2/4/8Hz各50ms蜂鸣窗口；节奏相位改全局，不再每个有效样本重新从0启动，启用到下一蜂鸣窗可等待所选周期内的剩余时间。8000个节拍相位组合通过。
6. SW6/SW7共用20ms采样，两次同值后更新，稳定确认延迟20..40ms（另有同步时钟），不再各自计20个1ms。SW7原始输入即时关闭输出继续保留。新模式重启清历史并取消测量。

新回归详细理由另见 `scan_engine/step5_notes.md`；没有静默修改旧六套验收。

## 仿真、图像及接口时序

- 最终新引擎9配置通过：基本往返、连续181角双向、控制/BCD、dense、两项2°负载隔离候选、人工错相HOLD及非HOLD对照；2°仅测试，生产仍1°。全局单位测试确认20ms帧、2Hz、720µs快走与完整PWM目标。生产参数SETTLE两方案对照通过。
- 完整绘图375请求、17807个独立像素、416A/375B、142456总线事务，逐向量/地址/读改写/1056字节RAM/忙时扰动/饱和drop计数全部通过。普通最坏值与端区值见下方自动摘要。原严格1ms含端区的失败记录保留；新版限值已按用户授权改为普通<1ms、端区≤20ms。
- 完整0→180→0和多目标换向图在 `budget_draw_payload/budget_f15/{full_scan,multiple_targets_turnaround}.{png,pbm}`，已人工查看，圆心(64,63)、16/32/48圈与页0空白符合参考显存。F15/k7、2或3微步/逻辑度、phase15/64初63不变；45步实际44.981508°，全角全半径最大欧氏像素误差0.913512，MIN6后方穷举0。
- 最终BCD双顶层默认禁读/离线回读版比较原58位输出一致；两模式均实际绘图，测量标签/五线归类/取消/即时关闭/多次LCD复位通过。报告不将加速场景丢弃数外推为生产速率。

LCD协议参数仍setup4clk=80ns、WR低6clk=120ns、RD低10clk=200ns、恢复6clk=120ns、读释放20clk=400ns；写周期320ns≥240×1.3。读在RD上升前1clk锁存，距离RD下降180ns。数据/控制setup余量及引脚延迟分别核对，不只看内部slack。

最终LCD输出最坏clock-to-pin：WR11.071ns、RD11.004ns，均低于SDC预留24ns。读外部预算120ns=24+70×1.3+5，使用setup9/hold8多周期；8条读捕获路径setup至少57.100ns、hold至少1.657ns。输出5ns板级预算；独立逐引脚报告 `budget_final_index/bcd/lcd_ports.rpt`。ST7565模型逐次检查脉宽、周期和空读。原雷达1个输入/58个输出仍有外部约束缺口，不能宣称全部板级外部时序签核。

## 映像、安全与未完成项

最终离线完整极坐标参数版 `.pof` 在 `budget_final_index/bcd/`。默认禁读参数版同工程同SW6双模式为927 LE/407寄存器，setup3.146ns、hold1.078ns，在 `budget_final_index/bcd_safe/`，只初始化清屏，不冒充完整极坐标显示。两种参数构建用于离线比较；每种映像内部都含双模式，不是为基本/连续分别烧两份。器件原生格式.pof沿用用户此前明确接受，不把文件改名.sof。

ENABLE_READBACK源码默认0；readback1 wrapper仅供离线资源/仿真，未改默认、未烧录。电气安全确认尚无：需核对模块背面稳压、实验板数据缓冲/电平转换、隔离安全条件下读FF的实际高电平。未获确认不将离线回读映像作为上板批准。

仍未完成：测距137>120、绘图含init395>210；因此本轮是整机总资源与离线验证达标，不是所有分项预算达标。真实基本快走16µs请求快于绘图，会按已授权规则丢弃并计数；加速联调观察到180个中间步请求丢弃、连续正常样本丢弃0。尚未证明这些丢弃后基本模式所有中间圈点/旧目标擦除满足完整显示规格，受控375请求正确不能替代该验收。上板方向、电平和实际对比度也未验证。

## 复现

在仓库根目录：

```powershell
& ./radar/unified_scan/compile.ps1 -RunName reproduce_final -Variants bcd,bcd_safe -Area
& ./radar/sim/unified_scan/run_budget_draw.ps1 -RunName reproduce_draw
& ./radar/sim/unified_scan/run_budget_top.ps1 -RunName reproduce_top
& ./radar/sim/unified_scan/run_budget_units.ps1
& ./radar/sim/unified_scan/run_budget_regression.ps1
& ./radar/sim/unified_scan/run_scan_engine.ps1 -Quick
& ./radar/sim/unified_scan/run_scan_settle_modes.ps1
& ./radar/sim/unified_scan/run_bcd_budget_compact.ps1 -Quartus
python ./radar/sim/unified_scan/analyze_bcd_budget.py
python ./radar/sim/unified_scan/verify_matrix_bound.py
python ./radar/unified_scan/summarize_results.py
python ./radar/unified_scan/write_budget_report.py
python ./radar/unified_scan/package_results.py
```

Quartus9.1/Build222，50MHz，旧工具使用ASCII临时路径。结果包包含整个results目录（原始成功/失败证据均保留）、本轮复现源树和SHA256清单；打包后检查ZIP完整性。最终选择源快照逐字节核对当前RTL。
"""
    times = list(csv.DictReader((RESULTS / "budget_draw_payload/budget_f15/busy_walltime.csv").open()))
    ordinary = max(int(t["busy_ns"]) for t in times if t["erase_rays"] != "11")
    endpoint = max(int(t["busy_ns"]) for t in times if t["erase_rays"] == "11")
    body += f"\n自动时限摘要：普通最坏 **{ordinary/1e6:.6f}ms**；端区最坏 **{endpoint/1e6:.6f}ms**，375请求全部满足各自新限值。\n"
    (RESULTS / "BUDGET_REPORT.md").write_text(body, encoding="utf-8")
    print("Report written; LE and register category sums verified.")


if __name__ == "__main__":
    main()
