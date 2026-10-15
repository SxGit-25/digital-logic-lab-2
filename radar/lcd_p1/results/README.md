# P1 独立液晶接口测试结果

编译日期：2026-10-15。工具：Quartus II 64-Bit 9.1 Build 222，器件 EPM1270T144C5，主时钟 50 MHz。本次未修改仓库 RTL 或约束，源码提交见 commit.txt。

## Quartus 实测

| 指标 | write | read |
|---|---:|---:|
| 总 LE | 443 / 1270（35%） | 218 / 1270（17%） |
| 寄存器 | 91 | 104 |
| I/O 引脚 | 22 | 22 |
| Fmax（内部同钟路径） | 58.99 MHz | 53.89 MHz |
| Setup slack | 3.049 ns | 1.445 ns |
| Hold slack | 1.078 ns | 0.966 ns |
| Minimum pulse width slack | 9.734 ns | 9.734 ns |
| Errors / Warnings | 0 / 20 | 0 / 19 |
| 未约束时钟、输入/输出端口及路径（setup/hold） | 均 0 | 均 0 |

## 逐模块 LE（Fitter，模块自身占用）

| 模块 | write | read |
|---|---:|---:|
| 顶层自身 | 1 | 1 |
| reset_ctrl | 17 | 17 |
| lcd_p1_core 自身 | 56 | 29 |
| lcd_bus | 48 | 73 |
| lcd_init | 98 | 98 |
| lcd_p1_pattern | 223 | 0（被优化移除） |
| 合计 | 443 | 218 |

原始 fit.rpt 的 Resource Utilization by Entity 同时列出包含子模块的总数及括号内模块自身数，不应重复累加父子层级。另附 module_resources.csv。write 的固定图案逻辑占 223 LE，不能作为 P2 最终绘图器预算；这里的总占用为独立 P1 工程，未接入 radar_top。

## 警告核对

write：18 条 10230 常量赋值截位警告，加 1 条常量输出汇总及 1 条 13410（lcd_rd_n 恒高）。read：19 条 10230。当前默认参数下，状态值 0..9 能放入 4 位，初始化计时值 49999/999999 能放入 20 位，总线计时值能放入 5 位；只写 RD 恒高符合工程设计。原始警告全部保留，未通过屏蔽警告或修改 RTL 改变此次测量。

## 仿真与交付内容

- p1_simulation.log：本次 Icarus 12 仿真通过；检查两种总线策略、1056 字节清零、图案逐字节比对、隐藏列、空读及 FF 回读、协议时序和总线交接。
- p1_rings.pbm：本次从仿真 LCD 显存导出的图案。
- regression.log：本次六套基础与差分回归全部通过，含 610000 周期差分测试。
- write/、read/：完整 map/fit/sta/asm/flow 报告、summary、编译日志、引脚表、POF、编译源码 SHA256。
- source/：与编译 SHA256 逐文件核对一致的 RTL、QPF、QSF、SDC 快照。QSF 来自编译暂存目录，包含 Quartus 自动追加的 LAST_QUARTUS_VERSION 和 RESERVE_ALL_UNUSED_PINS_NO_OUTPUT_GND；仓库原 QSF 未改动。
- manifest_sha256.csv：整个结果目录的文件校验清单（清单自身除外）。

## 验证边界

已完成离线综合、布局布线、TimeQuest 和仿真检查；尚未进行硬件下载、示波器测量或液晶实物验收。TimeQuest 正 slack 表示当前 SDC 下通过，不能代替 LCD 引脚间时序、电气电平和实物方向验收。read 上板前的电气确认沿用项目 README 的既有要求。未进入 P2。
