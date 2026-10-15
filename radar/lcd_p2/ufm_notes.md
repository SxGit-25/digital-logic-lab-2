# P2 单象限正弦表与 UFM

`lcd_sin_lut.v` 的 `USE_UFM=0/1` 选择 case 或 UFM，外部均使用 request/done 握手。角度地址为 0～90，数值为 `round(sin(angle)*256)`，9 位 Q1.8，90° 对应 256。只有一张表，余弦由调用方分时查询 `90-angle`。单项误差不超过 1/512，半径 48 时单轴累加量化误差不超过 0.09375 像素。

生成或更新：`python radar/lcd_p2/generate_sin_lut.py`。脚本同时更新 RTL case、512×16 MIF 和 91 项参考 hex。MIF 每字高 9 位存表值、低 7 位补 1，91～511 地址为 FFFF。Quartus 工程必须能在编译目录找到 `lcd_sin_q8.mif`。

## 硬件与串行协议

使用 Quartus 9.1 的 `altufm_none`，即 ALTUFM 的原始串行接口。此版本 Quartus 自动定义 `ALTERA_RESERVED_QIS`，并不自动定义 `SYNTHESIS`；RTL 同时兼容两宏。正常 Icarus 仿真使用串行行为模型，仿真表函数不会被 Quartus 综合为第二张表。实际 Quartus map 已确认生成 1 个 UFM。

地址寄存器 9 位、数据寄存器 16 位，均 MSB-first。先送 9 位地址，等待一个串行周期，DRSHFT=0 装载完整字，再通过 DRSHFT=1 移位读出高 9 位，不需要读低 7 位。PROGRAM、ERASE、OSCENA 固定为 0，此设计不在运行期间编程或擦除 UFM。

`phase[4:0]` 持续运行，事务等待相位对齐；ARCLK/DRCLK 都在 phase=0 拉高、phase=16 拉低。每个有效串行周期 640 ns，高低各 320 ns。门控只跳过完整时钟脉冲，不改变相位。ARDIN 在 ARCLK 下降时更新；DRSHFT 在等待周期及装载周期的 phase=16 更新，通常建立保持各 320 ns。第一次地址的建立至少 40 ns。

接收 request 后对齐等待 1～32 个主时钟周期；9 个地址周期、1 个访问等待周期、1 个装载周期、8 个移位周期，共 608 个主时钟周期。因此 done 延迟为 609～640 周期，即 12.18～12.80 μs。接收期间请求忽略；调用者等待 done 后再请求。

## 时序与约束依据

依据 [MAX II Device Handbook](https://cdrdv2-public.intel.com/655094/max2_mii5v1.pdf) 第 9 章 UFM 串行接口及第 5 章表 5–21：地址/数据时钟周期至少 100 ns，ARDIN 建立保持至少 20 ns，DRSHFT 建立至少 60 ns、保持至少 20 ns，flash read access 最多 65 ns。本实现 640 ns 周期以及 320 ns 控制建立保持满足要求。注意表中的 `tDCO` 最大 5 ns 与另列的 `tOE=180 ns` 不是同一参数，不能把 180 ns 写成最大 tDCO。

DRDOUT 在 DRCLK 上升后 31 个主时钟周期，即 620 ns 时采样。模型额外注入 180 ns 输出稳定延迟，用来验证采样裕量；这不代表将 180 ns 当作器件的最大 tDCO。地址移位结束后亦额外等待完整 640 ns 周期，再装载 flash 字。

完整工程实际综合网表的寄存器名为 `*|g_ufm.arclk`、`*|g_ufm.drclk`，在其 Q 上创建源自主时钟的 `/32` generated clock。它们只有完整周期的门控，phase 不因事务重置。DRCLK 到 `*|lcd_sin_lut:lut|value[*]` 的采样路径在 phase=31 才使用，使用 setup 31 / hold 30、`-end` 多周期，实际 setup 关系为 620 ns。ARDIN/DRSHFT 在 phase=16 改变，到下一次相位0采样相隔320 ns，之后320 ns才有下一次变化；仅对地址移位最高位→UFM地址寄存器、DRSHFT→UFM数据寄存器两类路径使用 setup 16 / hold 31、`-start` 例外，实际 setup/hold 关系为 +320/−320 ns。完整工程 TimeQuest 已逐个匹配集合，详细路径见 `results/ufm/lcd_p2_ufm.timing_details.rpt`，未加宽泛 false path。ARDIN、DRSHFT 的固定更新相位另由协议测试检查，不能仅凭内部 slack 推导全部宏接口时序。

## 可复现验证

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File radar/sim/lcd_p2/run_sin_lut.ps1
```

可用 `-IverilogBin` 指定包含 `iverilog.exe`、`vvp.exe` 的目录。测试覆盖全部 91 个地址，分别将 case/UFM 输出与脚本独立计算的 Python 浮点 sin 参考比较，检查 done 单拍、609～640 周期延迟范围，以及 ARDIN、DRSHFT 建立保持和串行周期的 30% 裕量。结果写入 `radar/lcd_p2/results/sin_lut/sin_lut.log`。此项为 RTL 串行协议仿真；UFM 硬件生成另由 Quartus map 和完整工程 Fitter/TimeQuest 报告确认。

本次 Codex 沙箱中的便携 Icarus 编译器子进程异常退出，连最小示例也会返回 `-1073741819`；同一调用经平台许可在沙箱外正常通过。脚本保留严格非零返回码检查，不把编译器异常当作成功。若在相同沙箱重现，应通过平台的执行权限处理，不应忽略返回码继续仿真。
