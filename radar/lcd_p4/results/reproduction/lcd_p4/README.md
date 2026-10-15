# P4：已集成并验证功能，资源门槛未通过

基线 P3 `ca8ec99`；器件 EPM1270T144C5；Quartus II 9.1 Build 222；50 MHz。
用户已确认 P3，授权 P4。按资源降级顺序完成实测后，停止等待下一步取舍。

| 方案 | 综合 LE | Fitter LE 需求 | 寄存器 | I/O | UFM | 相对 P3 LE | Setup/Hold ns |
|---|---:|---:|---:|---:|---:|---:|---|
| UFM Q8 | 1734 | 1668 | 744 | 75 | 1 | +635 | 无，Fitter 失败 |
| case Q8 | 1747 | 1691 | 717 | 75 | 0 | +658 | 无，Fitter 失败 |
| UFM Q7 | 1727 | 1664 | 739 | 75 | 1 | +631 | 无，Fitter 失败 |
| case Q7 | 1729 | 1675 | 712 | 75 | 0 | +642 | 无，Fitter 失败 |
| safe，回读关闭 | 1203 | 1186 | 491 | 75 | 1 | +153 | 3.245 / 1.377 |

前四项是**全工程实际运行 Fitter 得到的装箱资源需求**，并非成功布局占用，也不是独立工程估算相加。最省的有效方案 UFM Q7 比 1143 LE 上限多 521，比器件容量多 394。不能生成合法极坐标烧录文件或宣称时序通过。safe 有 POF，但只有雷达及 LCD 初始化/清屏，没有极坐标绘图；1186 LE 仍超过预算，不能作为替代验收。safe Fmax 59.68 MHz，仅适用于该安全版本。

已执行降级顺序：文字原本未启用；case/UFM 两种表、Q8/Q7 两种精度均全编译；扫描线高亮原本未启用。继续降低到 Q6 的全角度/半径坐标最大欧氏误差 1.153526 像素，超过 1 像素要求，因此不作为合格资源候选。Q8/Q7 分别为 0.736466 / 0.856159 像素；最小半径 6 时两者穷举后方命中均为 0。现有基本功能没有删除，未擅自改用柱状图。

## 实现与验证

- `radar_lcd_top` 保留 P3 同工程 SW6 双模式，原 `radar_top`、`radar_mode_top` 不变。LCD 引脚遵循 P1 分配和 3.3-V LVTTL。
- `ultrasonic` 新增默认关闭的 `ENABLE_RADIUS`、mod-25 分频和饱和 6 位半径。原毫米计算 FSM 不变；1200 mm 有效半径 48，1201 mm 半径饱和但目标无效。数码管、报警继续使用原毫米结果。
- `radar_lcd_bridge` 按实时整数角度逐条请求 A/B；测量完成按采样时锁存角度补 B-only 目标，避免 60 ms 测量节拍跳过射线。方向翻转独立触发端区清除；旧方向延迟回波不向已清端区补旧点。参数在忙时保持稳定。
- `FRACTION_BITS` 默认 8，支持 7/6 对比；只用一张 91 项 sin 表，cos 分时查同表，case/UFM 均有对应测试。最小半径 6，近距离目标夹到 6。
- 桥接队列、181 角度、双端区清除、最小半径夹紧、无效目标、B-only 不擦除均通过真实 ST7565 行为模型。189 次更新、205 次 A、189 次 B、17538 次读。
- 顶层 READBACK=0/1 各 925030 周期，与 P3 原有 58 位输出逐周期一致，覆盖 basic/continuous、模式切换和关闭。回读版 11 次 beam、8 次 target，检查测量角度/方向/半径绑定，1802 次实际模型读；安全版 0 次读，RD/OE 恒 1。
- 半径独立测试 15 场景、167746 周期，对比 P3 原输出；含最小回波、分频边界、1200/1201 mm、无回波、取消与超时。
- 原有六套回归通过。前五套见 `regression.log`；第六套原位置实例因新增两个输出端口编译失败，补未连接输出后单独运行 610000 周期通过，见 `regression_counter_equivalence.log`。保留初始失败日志，不将其隐去。
- 六组系数 RTL（case/UFM × Q8/Q7/Q6），每组检查 91 系数及 8869 坐标，与独立 Python 浮点参考比较；误差和后方命中详见 `coefficients/coefficients_report.json`。

## LCD 外部时序与电气状态

50 MHz 下参数默认：建立 4 拍=80 ns（要求40，余量100%）；WR 低6拍=120 ns（要求80，50%）；RD低10拍=200 ns（要求140，42.9%）；保持/恢复6拍=120 ns。写事务建立+有效+恢复至少320 ns（周期要求240，33.3%），读还增加400 ns总线释放；读采样在 RD 上升前一拍，距下降180 ns。

LCD 输出约束 max5/min0 ns；输入访问预算110 ns=14 ns RD输出延迟预留+70×1.3 ns读取访问+5 ns板级偏差；仅实际读捕获寄存器使用 setup9/hold8 多周期。UFM 串行时钟和仅相关寄存器使能关系沿用 P2 精确约束。**回读全工程未能布局，故 RD 输出延迟上限和外部读路径不能签核**；协议仿真通过不能替代真实布局时序。safe 已约束路径通过，但基本雷达原有 1 输入/58 输出端口仍未完整外部约束。

所有可复用 RTL 和默认安全顶层 `ENABLE_READBACK=0`。safe 的 RD 恒高、数据口始终输出；读功能只在明确命名的离线比较包装顶层中启用，不改变默认值。没有下载硬件。用户尚未确认回读电气安全：仍需检查液晶背面稳压芯片、板上缓冲/电平转换，并在隔离/保护条件下测量读取 0xFF 的数据高电平。不能把离线回读编译当作上板许可。

## 复现与交付

在仓库根目录：

```powershell
& ./radar/lcd_p4/compile.ps1 -QuartusBin E:/quartus/QuartusII91/quartus/bin64
python ./radar/lcd_p4/summarize_results.py
& ./radar/sim/lcd_p4/run_radius.ps1 -ToolDirectory <Icarus-bin>
& ./radar/sim/lcd_p4/run_integration.ps1 -ToolDirectory <Icarus-bin>
python ./radar/sim/lcd_p4/coefficients_run.py --iverilog-bin <Icarus-bin>
& ./radar/sim/run_tests.ps1 -IverilogBin <Icarus-bin>
```

旧版 Quartus/Icarus 对中文路径存在兼容性问题，编译脚本已使用 ASCII 临时目录；原通用 `run_tests.ps1` 可在 ASCII 副本运行。四项 Fitter 失败后，`compile.ps1` 仍收集所有方案并最终抛错，属于本阶段的真实结果。

`results/` 含每方案完整 map/fit/flow 报告、成功安全方案 STA/POF、各方案准确源码快照和 SHA256、逐模块资源 CSV、测试日志。`results.zip` 为整个目录打包，另附复现源文件与测试。下一步需用户选择：批准柱状图备选，或明确进一步极坐标优化允许的取舍；不得把本阶段标为通过。
