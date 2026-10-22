# 雷达系统：1270 LE 交付版

本分支只保留固定 r6–48 XOR 扫描线、8 位 UFM 背景读取、报警反显的最终交付工程。器件为 EPM1270T144C5，时钟 50 MHz，Quartus II 9.1 Build 222，布局 seed 1。

## 从这里开始

- **讲解代码**：`rtl/`，共 14 个文件。测距模块是 `ultrasonic_bcd_budget_compact.v`。
- **打开工程**：`quartus/radar_unified_bcd.qpf`。唯一顶层为 `radar_unified_bcd_top`，参数已在 QSF 固定为交付配置。
- **烧录文件**：`delivery/radar_1270LE.pof`。Programmer 同时选择 CFM、UFM，并执行 Verify。
- **交付证据**：`verification/`，含原构建报告、时序报告及 2026-10-17 的烧录/回读日志。
- **硬件资料**：`docs/`，仅保留实验板和液晶手册。

## 模块阅读顺序

| 文件 | 作用 |
|---|---|
| `radar_unified_bcd_top.v` | 交付顶层封装，启用 BCD 测距 |
| `radar_unified_top.v` | 整机连接、输出门控、LCD 停止握手 |
| `reset_ctrl.v` | 上电复位 |
| `radar_global_timebase_alarm.v` | 共用时基、扫描节拍、报警节拍 |
| `switch_pair_sampled.v` | SW6/SW7 同步与采样 |
| `ultrasonic_bcd_budget_compact.v` | 超声波触发、回波计时、BCD 距离及半径 |
| `radar_unified_scan.v` | 模式、舵机扫描、测量调度和历史数据 |
| `radar_display_gated.v` | 数码管和点阵输出门控 |
| `radar_display_shared.v` | 数码管和双色点阵扫描 |
| `alarm_global.v` | LED 与蜂鸣器报警 |
| `radar_lcd_micro.v` | LCD 初始化、背景恢复、目标和 XOR 扫描线 |
| `minsky_serial_datapath.v` | 绘图串行运算与寄存器 |
| `p5_ufm_byte_reader.v` | UFM 背景字节读取 |
| `lcd_bus_phase.v` | LCD 总线读写时序 |

保留的主体 RTL 与原成功构建快照逐字节一致；顶层封装从原多版本文件中原样提取。主体中仍存在由常量参数关闭的兼容分支，它们不参与本交付工程综合，对应旧版源码已移除。不要直接以通用模块 `radar_unified_top` 的默认参数另建工程。

## 编译与复核

```powershell
./build.ps1
python ./verify.py
```

Quartus 安装目录不同时使用 `./build.ps1 -QuartusBin '你的Quartus路径/bin64'`。脚本在英文临时路径编译，结果保存在忽略跟踪的 `build/`。旧版 Quartus 直接打开中文路径失败时也使用此脚本。

`verify.py` 检查交付 POF 哈希、保留文件哈希、工程引用、背景 MIF、历史 CFM/UFM 回读；存在 `build/` 时，还检查重新编译的 1270 LE、时序余量，以及 CFM/UFM 记录与原交付文件逐字节一致。

原交付结果：1270 / 1270 LE，75 引脚，UFM 1 / 1，setup 2.994 ns、hold 1.078 ns。原时序检查中有 58 个未约束输出端口、456 条输出路径；本次整理沿用原约束，不扩大时序签核范围。

2026-10-22 精简后的工程已完整重编译：0 错误、12 条原有警告；LE 和时序余量与原交付一致，CFM/UFM 记录逐字节一致。结果保存在 `verification/clean_build/`。

唯一交付 POF SHA256：

```text
45963657dbc6975a83e8de8b566d6ee072bb1a34025de2c2e890bc1647ee71f3
```

## 来源与状态

来源为 `beam-min-1270` 标签（`0881d4c`）及 `beam-min` 分支的烧录验证/归档提交（整理前 `647be69`）。2026-10-17 已完成 Program + Verify、Examine，CFM/UFM 回读与交付 POF 一致；实物画面验收仍未记录完成。本次仅整理和编译，没有重新烧录硬件。

`verification/original_delivery.json` 等原始证据保留原路径及生成时状态，路径用于追溯，不是本分支的运行依赖；其中早期“未烧录”状态由后续 `verification/programming/readback_verification.json` 更新。

历史版本仍可通过原分支及标签找回。清理前整个工作目录（含未提交内容和报告材料）另有工作区外 ZIP 备份，位置记录在本次整理的聊天交付信息中。
