# P3：基本/连续扫描同工程拨码切换

状态：P2修正版通过后按用户授权完成P3；RTL、整机Quartus实测和仿真已完成，待用户阶段确认后进入P4。本工程尚未接入LCD/绘图引擎，未下载硬件。

## 使用与实现

- SW7（PIN_125）为原总开关，原异步关闭门控保留。
- SW6（PIN_127）下拨0为基本模式，上拨1为连续模式。引脚依据仓库MAXII数字实验板手册第7页第9节：SW0..7依次134/133/132/131/130/129/127/125。
- SW6经过双触发器同步与20ms消抖，模式改变后取消未完成测量、清当前有效/历史，重新执行2s自检、2s待机回零，再进入运行。SW7重启同样保持原行为。
- 共用一个reset_ctrl/timebase、PWM帧计数、超声、距离串行BCD、数码管/点阵扫描、历史数据及报警；没有并列两套雷达系统。
- 连续PWM每20ms帧从500us增减5us，端点2500/500us立即反向，单程400步/8s。待机阶段保持500us，用原2s待机回零。
- 连续角度binary/BCD并行递增/递减，以5位余相位初值10累加±9/20度，等于round((pulse_us−500)*0.09)。400步准确180°，端点强制相位10消除漂移；没有新增二进制转BCD，原串行距离转换器仍82LE。显示的是已应用舵机指令的标称角度，不是机械位置反馈。
- 连续模式默认每60ms调度测距；busy或等待结果时跳过该周期，下次60ms再尝试。measure_start为注册脉冲，在ultrasonic实际接受start的同一时钟沿锁存已应用角度、方向和最近线编号，避免PWM边界的一拍错绑；回波完成仅用锁存编号写历史，报警用当前测量结果。
- 点阵最近线：整数角0..22/23..67/68..112/113..157/158..180分别归到0/45/90/135/180°。DISP7..5实时使用角度BCD，距离位、SELF/STANDBY规则和报警仍使用原通路。

## 保持基础版行为

仅扩展servo_pwm、radar_ctrl、display_compose，新增SUPPORT_CONTINUOUS默认0；原radar_top、原constraints、ultrasonic、bin12_to_bcd等源码未修改。原实例默认基本分支完整保留；新增radar_mode_top启用支持，SW6=0时同样走原基本逻辑。

原基本顶层重新完整编译仍843LE/385寄存器、setup4.944ns/hold1.078ns、Fmax66.42MHz，与原实测完全相同。一条编译警告来自三处旧实例没有连接新增且被禁用的连续模式端口（Connectivity Checks），不是功能或时序失败。新模式顶层完整编译0 errors/0 warnings。

## 整机Quartus实测（2026-10-15）

Quartus II64-Bit9.1 Build222，EPM1270T144C5，50MHz。

| 指标 | 原基本版复编 | P3拨码工程 | 增量 |
|---|---:|---:|---:|
| LE | 843/1270 | 1033/1270（81%） | +190 |
| 寄存器 | 385 | 431 | +46 |
| I/O | 61/116 | 62/116 | +1（SW6） |
| UFM | 0/1 | 0/1 | 0 |
| Setup slack | 4.944ns | 3.501ns | −1.443ns |
| Hold slack | 1.078ns | 1.380ns | +0.302ns |
| Fmax内部同钟路径 | 66.42MHz | 60.61MHz | −5.81MHz |

P3为整个双模式工程真实编译，不能用独立continuous_scan的152LE相加。P2为LCD独立工程，与P3不是同一工程，亦不相加。P3总占用小于1143硬上限；后续P4必须合并后再实测，当前值不能代表LCD已容纳。

逐模块Fitter自身LE（原基本→P3）：顶层54→56；alarm56→55；bin12_to_bcd82→82；display_compose69→87；matrix81→82；radar_ctrl184→212；reset16→16；seg75→73；servo42→173；SW7filter12→12；新增SW6filter11；timebase39→39；ultrasonic133→135。未修改模块也可能因布局/上下文改变占用，不能据LE变化推断RTL有改动。完整层级CSV和原报告在results/。

P3 TimeQuest0 errors/0 warnings，最小脉宽slack9.734ns。延续基础工程外部I/O边界：1个输入端口/125路径、58个输出端口/382路径未完整约束（setup/hold相同），时序通过限于已约束内部路径；仅对SW7/SW6/ECHO双触发器同步器第一阶段使用false path，未隐藏外设路径。

## 验证

- 与不可变3231197对比：原基本top、修改后radar_top、新top基本模式，所有外部输出及控制器/显示核心信号逐周期一致，50万周期随机回波和SW7重启。
- servo默认分支和SUPPORT=1/mode0各10万随机周期与原版一致；连续模式801个完整20000 tick_us帧，实际检查500..2500us脉宽、全程0→180→0及每帧binary/BCD/方向。测试按逻辑微秒使能加速，不替代50MHz器件时序或实物波形。
- 181角×双方向共362个采样，验证最近线阈值、跨角回波期间锁存、历史不串线、实时BCD、距离等级与无效显示；另验证默认60ms节奏、busy跳过、LED及蜂鸣器载波。
- 实际590us回波、无回波、测量中SW6双向切换取消/重启SELF→STANDBY→RUN、SW7异步关闭所有外部输出通过。
- 原六套基础回归全部通过，含610000周期计数器差分。

summary.json及所有编译/仿真日志在results/simulation，原六套日志为results/regression.log。sample_angle/sample_direction_up在RTL与测试中锁存正确，本阶段未接LCD的消费者可能使它们在Fitter中优化移除；P4消费时必须重新实测资源。

## 复现与后续

```powershell
powershell -ExecutionPolicy Bypass -File radar/p3_modes/compile.ps1
python radar/sim/p3_modes/run_modes.py --bin <Icarus的bin目录>
powershell -ExecutionPolicy Bypass -File radar/sim/run_tests.ps1 -IverilogBin <Icarus的bin目录>
```

compile脚本在ASCII/SUBST隔离目录分别完整编译modes与basic，保留全部报告、POF、引脚表及源码SHA256；不自动烧录。测试脚本从Git3231197提取只读基线，因此复现测试需要仓库历史；结果包另附基线四个源文件便于审阅。

P3未加LCD、不改默认回读安全门槛。P4应以实时方向翻转通知端区清除，不能假设60ms测量必然采到0/180°；同帧测距角与方向继续使用锁存值。待用户确认本阶段后，才进行LCD与全工程合并及1143LE验收。
