# P4 极坐标继续优化：1530 LE，仍未通过预算

基线 `f4507a8`；用户授权“继续优化极坐标”。保留基本功能、SW6双模式、极坐标规格、最小绘制半径6、后方命中0及1143 LE上限。回读默认0，没有下载硬件。

本轮进行了五组全工程编译，共17个候选构建。最省完整绘图候选由1664降至1530 LE，减少134（8.05%），寄存器739降至624，I/O仍75，UFM1。**仍比1143多387、比EPM1270容量多260，无法布局，没有有效布局后时序或极坐标POF。** 本轮只交付优化进展，P4未验收通过。

| 最终方案 | Fitter LE需求/占用 | 寄存器 | I/O | UFM | 对同存储方案上一版LE变化 | Setup / Hold ns |
|---|---:|---:|---:|---:|---:|---|
| UFM Q7，并行累加 | 1550 | 617 | 75 | 1 | −114 | Fitter失败，无 |
| case Q7，并行累加 | 1553 | 590 | 75 | 0 | −122 | Fitter失败，无 |
| UFM Q7，串行累加 | **1530** | 624 | 75 | 1 | **−134** | Fitter失败，无 |
| case Q7，串行累加 | 1548 | 597 | 75 | 0 | −127 | Fitter失败，无 |
| safe，回读关闭，无绘图 | 1079 | 418 | 75 | 1 | −107 | 1.409 / 1.649 |

safe Fmax53.79MHz，最小脉宽slack9.734ns。它在预算内且完成布局，但只有液晶初始化/清屏，**不能充当完整极坐标方案**。所有数字均来自完整工程实测；失败方案的数字只表示Fitter装箱需求，不表示成功放置布线。

## 保留的优化

- ray：在累加初值中预加半LSB，删除输出舍入加法器；cos复用LUT稳定输出；追加可选逐位累加，坐标不变，步间增加F+6拍。pixel_valid期间保持坐标，背压合同不变。默认ray仍Q8、并行；最省候选显式Q7/串行。
- LCD：像素被ray持有期间直接复用其坐标/掩码；改写结果直接使用总线读锁存器；P4 bridge保持请求参数，ctrl据此省掉第二份参数锁存；bus可选使用稳定写数据。P1/P2默认仍锁存请求/写数据，新增init时基输入在旧core固定为1。
- bridge：待处理beam复用seen角度与方向，保留忙时参数稳定、两队列优先级、端区换向epoch和旧回波抑制。
- init：命令序号与清屏页号复用3bit寄存器，清屏计数复用延时计数器；P4生产配置使用现有tick_ms，长延时计数从20bit降为8bit。为任意tick相位额外预留一个间隔，复位/电源等待不短于请求值。独立P1/P2及加速参数仍逐主时钟计数。
- servo：方向运算共享；BCD百位仅0/1；帧以mod5和商计时，脉宽改为5us单位，保持每20ms帧±5us与0→180→0，生产路径没有乘法器。
- ctrl：SELF/STANDBY和RUN槽计时互斥，复用计数器及增量器；history/current_distance提取公共commit/expire事件，保留同拍完成/槽结束优先级。
- ultrasonic：保留原17/100毫米累加，使用work/rem推导118..23529us有效范围，删除重复echo_us计数器；started排除无回波旧数据，overflow粘滞位防长回波回绕。mod25/6bit半径路径及数码管毫米结果不变。
- reset：上电16拍移位链改为有初值计数器，复位释放时刻相同；覆盖1/2/16/17/257参数。
- Quartus：最优候选使用MAXII_OPTIMIZATION_TECHNIQUE=AREA、AUTO_RESOURCE_SHARING=ON、MUX_RESTRUCTURE=ON。紧凑FSM编码也测过，最终采用默认编码；全部中间轮结果和精确源码快照保留。

原有串行bin12_to_bcd保持不动，未宣称其可大幅节省。文字/扫描高亮仍未启用；Q6仍因最大欧氏误差超过1像素排除。

## 验证与时序限制

- servo对f4507a8原版16140007周期、参数0/1全输出逐周期相同，含120000随机周期、801完整帧、400帧单程。
- ctrl九组参数1080000 cycle-pairs，全部61bit输出及计时别名与f4507a8相同；P3控制器362样本通过。
- ultrasonic十六组参数及半径配置3678378 cycle-pairs全输出相同，含TIMEOUT100000、多次work回绕、无回波、取消/复位/暂停、1200/1201mm；半径15场景167746周期通过。
- 原六套基础回归全部通过，日志`regression.log`。通过测试未替换原预期行为。
- 并行/串行各六组合case/UFM×Q8/Q7/Q6，每组91系数、8869坐标、主动背压、浮点误差和后方命中检查。Q7最大欧氏误差0.856159像素，后方命中0；Q6保留为失败精度实验。
- LCD并行/串行均使用真实ST7565模型：181角、两端区批量清除、最小半径夹6、无效目标和B-only不擦除；顶层readback0、readback1以及串行readback1逐周期对比旧P3顶层引脚。各场景日志见`integration_final`。
- 粗时基测试覆盖所有7个tick相位，检查复位、复位后等待、电源等待均满足最小值，完整清8×132字节并开显示；复位边界另有单元测试。

读写总线脉宽参数、LCD引脚和输入/输出延迟约束继承上一阶段。串行累加只增加步骤间等待，不缩短任何总线脉宽。完整回读方案尚无合法布局，不能签核RD输出延迟、读数据捕获路径或50MHz时序。safe已约束路径通过，基本雷达仍有既有1输入/58输出外部约束缺口。

电气门槛未变化：默认ENABLE_READBACK=0；回读包装仅供离线比较，没有电气安全批准、没有下载。旧P1/P2/P3/P4结果目录和ZIP保留。

## 复现

```powershell
& ./radar/lcd_p4_opt/compile.ps1 -RunName final5 -Variants serial7,serial_case7,ufm7,case7,safe -Area
python ./radar/lcd_p4_opt/summarize_results.py
& ./radar/sim/lcd_p4/run_servo_optimized.ps1 -ToolDirectory <Icarus-bin>
& ./radar/sim/lcd_p4/run_ctrl_counter.ps1 -ToolDirectory <Icarus-bin>
& ./radar/sim/lcd_p4/run_ultra_counter.ps1 -ToolDirectory <Icarus-bin>
& ./radar/sim/lcd_p4/run_misc_optimized.ps1 -ToolDirectory <Icarus-bin>
& ./radar/sim/lcd_p4/run_integration.ps1 -ToolDirectory <Icarus-bin> -ResultsDirectory <absolute-output-directory>
python ./radar/sim/lcd_p4/coefficients_run.py --iverilog-bin <Icarus-bin>
python ./radar/sim/lcd_p4/coefficients_run.py --iverilog-bin <Icarus-bin> --serial
& ./radar/sim/run_tests.ps1 -IverilogBin <Icarus-bin>
```

旧Quartus/Icarus需ASCII临时路径；编译脚本已处理，原通用回归可在ASCII副本执行。编译脚本会保留全部失败结果并最终抛错，这是如实报告超资源。

`results/`和`results.zip`包含五轮报告、逐模块CSV、对比JSON、验证日志、源快照、复现脚本及SHA256。下一步若仍保留1143上限和全部功能，需要进一步做控制器/算术单元的架构共享；现有结果不能证明该目标必然可达。
