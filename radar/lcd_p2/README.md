# P2 修正版：端区清除与后方保护

状态：按用户修订的验收口径，后方穷举命中为0，P2通过；用户已授权直接进入P3。通用 ENABLE_READBACK 默认保持0，未下载硬件，电气安全未验收。

## 本轮仅修改两处

1. k=180且新方向向下时，先依次清170..180°；k=0且新方向向上时，先清0..10°。每条清除射线仍跳过第16/32/48步。该批次替代该更新的普通A，批次结束再B画本次端点目标/圈，随后正常A/B。复用ray_angle作批次计数，不存历史半径；初始0°也执行同一端点流程。
2. MIN_RADIUS=6：A从6..48步清除；B的有效目标r<6夹到6，r>48或无效不画。距离圈仍16/32/48。只改液晶绘图，不修改mm测量、DISP距离或报警。

## 后方穷举

遍历k=0..180、两方向、目标角a=0..180、原始r=0..48。后方为up时a<k/down时a>k，且未来10个实际1°移动位置（含端点反向）不访问a。目标有效半径max(m,r)；擦除包含普通k±10和端点11条批次，步m..48跳过16/32/48。前方即将重测的点被提前清除符合设计，原172°r26例不再视为缺陷。

| 最小步m | 原始半径命中事件 | 按有效半径去重 | 最小原始r | 最小有效r |
|---|---:|---:|---:|---:|
| 4 | 488 | 168 | 0（夹到4） | 4 |
| 5 | 528 | 88 | 0（夹到5） | 5 |
| 6 | **0** | **0** | 无 | 无 |

m从4递增验证，6是恰好零命中的最小值，不必提高到7。原始r=0..m−1夹到同一位置，所以原始事件数大于有效半径去重数；这不是唯一屏幕像素数。m4/m5为同一夹取规则下的阈值对照。定义、全量命中CSV、JSON在results/exhaustive/；脚本为radar/sim/lcd_p2/exhaustive_erase.py。水平镜像保持坐标相等关系，结论对MIRROR_X两值相同。

## Quartus实测及相对3231197增量

2026-10-15，Quartus II 64-Bit9.1 Build222，EPM1270T144C5，50MHz。

| 方案 | LE（增量） | 寄存器（增量） | I/O | UFM | Setup / Hold ns（增量） | Fmax MHz（增量） |
|---|---:|---:|---:|---:|---|---|
| case | 656（+68） | 261（+1） | 22/116（不变） | 0（不变） | 1.785 / 1.078（−0.681 / 0） | 54.90（−2.13） |
| UFM（继续选用） | 640（+70） | 288（+1） | 22/116（不变） | 1（不变） | 2.370 / 1.078（+0.185 / +0.023） | 56.72（+0.59） |
| 默认安全版 | 171（0） | 84（0） | 22/116 | 0 | 3.619 / 1.078 | 61.05 |

本轮UFM比case少16LE。两个read_test工程显式ENABLE_READBACK=1仅用于离线比较；默认顶层只初始化清屏，不执行依赖回读的绘图。独立工程不能与雷达LE直接相加。

逐模块Fitter自身LE（不能重复累加父子总数）：

| 模块 | case | UFM |
|---|---:|---:|
| 读测试包装 | 1 | 1 |
| 自动激励顶层自身 | 70 | 69 |
| lcd_p2_core自身 | 4 | 4 |
| reset_ctrl | 17 | 17 |
| lcd_init | 99 | 99 |
| lcd_bus | 85 | 85 |
| radar_lcd_ctrl自身 | 180 | 180 |
| ray_engine自身 | 131 | 127 |
| lcd_sin_lut | 69 | 58 |
| 总计 | 656 | 640 |

case/UFM全编译均0 errors/21 warnings，均为默认范围内可容纳的常量截位；safe32 warnings另含恒使能OE/恒高RD。三个TimeQuest均0 errors/0 warnings，LCD端口和路径setup/hold均已约束。原始日志未屏蔽。

## 仿真和图像

case/UFM各602次更新、27371个像素RMW、218968笔总线事务，每次更新后全部1056字节真实模型RAM与独立参考一致。包含完整0→180→0、端区批次、valid/ready反压、半径0/1/3/4/5/6/7/48/49/63及无效、输入锁存、默认回读关闭。两种实现三张显存PBM逐文件SHA256一致。

全部181角×49半径×3实现=26607坐标通过，实际输出6..48共7783组合。8869个未镜像组合对圆整参考8435误差0、434最大单轴误差1；对未取整浮点最大单轴0.5830331204px、最大欧氏误差0.7364662031px。系数/定点格式仍为单张91项Q1.8和Q6.8累加器，sin/cos分时查同一表，无运行时乘除或取模。

真实总线最小端区场景为正常170→180→174，去程r20、返程r35：原版174°旧r20=(44,61)与新r35=(29,59)同时亮；修后旧点0、新点1。已人工查看前后图，未补绘像素：

- results/simulation/endpoint_turnaround_original.png：原规格端区双点。
- results/simulation/endpoint_turnaround.png：修后端区图。
- results/simulation/multiple_targets_turnaround_original.png：原多目标换向。
- results/simulation/multiple_targets_turnaround.png：修后多目标换向。

PNG只是实际PBM最近邻放大，原/新图均与各自算法的独立RAM参考逐像素一致。前方和圈像素仍可能取整重合，本轮不追求消除所有重合。原六套雷达回归全部通过。未改动sin表，sin_lut目录保留3231197的91项单元测试记录；本轮完整几何与总线测试重新验证了两种表路径。

## 引脚时序与复现

LCD输出预算max5/min0ns；输入max110/min0ns包含14ns clock-to-RD + 70ns×1.3 + 5ns板级预算，只对8个read_data捕获寄存器设置setup9/hold8多周期。新UFM方案LCD输入setup/hold为66.777/1.321ns；串行UFM到系数捕获setup/hold为608.559/10.887ns。UFM时钟640ns，控制相位320ns、输出620ns采样，详细约束依据仍见ufm_notes.md及timing_details.rpt。

两方案LCD Tco最坏全引脚包络差为4.136ns；加板级5ns预算后，写低/读低/建立/恢复分别至少110.864/190.864/70.864/110.864ns，超过30%余量后的104/182/52/104ns。含必要ready/done握手的最短同类周期至少340ns，保守减9.136后330.864ns≥312ns。最大LCD Tco13.215ns低于14ns预算。板级预算和实际电气仍待实物验收。

```powershell
powershell -ExecutionPolicy Bypass -File radar/lcd_p2/compile.ps1
powershell -ExecutionPolicy Bypass -File radar/sim/lcd_p2/run_p2.ps1 -IverilogBin <Icarus的bin目录>
python radar/sim/lcd_p2/exhaustive_erase.py radar/lcd_p2/results/exhaustive
```

原3231197结果原样保留baseline_3231197.zip。results.zip为本轮完整结果；精确编译快照/哈希、源码、测试、报告、显存图均在目录内。未烧录，通用回读默认值0，P1电气核对清单继续适用。
