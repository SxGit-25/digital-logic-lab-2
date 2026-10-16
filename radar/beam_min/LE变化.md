# 最简扫描线整机实测 LE 变化

| 阶段 | LE | Fitter | setup ns | hold ns |
|---|---:|---|---:|---:|
| p5r_step3_alarm_gate | 1253 | 成功 | 3.361 | 1.078 |
| beam_min_initial | 1272 | 失败，仅打包需求 | 不可得 | 不可得 |
| beam_min_byte_a | 1270 | 成功 | 2.994 | 1.078 |

步骤a：UFM只保留8位数据，随机高字节8个DRCLK早停；随机低字节跳过前8位；初始化低字节接续前次高字节。地址9位独立，未实施地址/数据共享。

整机1272→1270净省2LE。UFM读器69→68（-1），绘图控制413→414（+1），测距模块因Fitter重新打包133→131（-2）；其余不变。不能把8个数据寄存器的减少冒称为节省8LE，也未修改测距功能。

步骤b、c未实施：步骤a已达到硬门槛，按“够了就停”结束资源化简。LCD报警反显、LED及蜂鸣器报警全部保留。

| 模块自身LE | delivery-1253 | 最简初版 | 步骤a | 初版增量 | a增量 | 最终增量 |
|---|---:|---:|---:|---:|---:|---:|
| `radar_unified_bcd_top` | 1 | 1 | 1 | 0 | 0 | 0 |
| `radar_unified_top:system` | 9 | 12 | 12 | 3 | 0 | 3 |
| `alarm_global:u_alarm` | 15 | 15 | 15 | 0 | 0 | 0 |
| `lcd_bus_phase:bus` | 57 | 56 | 56 | -1 | 0 | -1 |
| `radar_display_gated:u_display` | 31 | 31 | 31 | 0 | 0 | 0 |
| `radar_display_shared:core` | 120 | 120 | 120 | 0 | 0 | 0 |
| `radar_global_timebase_alarm:u_timebase` | 67 | 67 | 67 | 0 | 0 | 0 |
| `radar_lcd_micro:draw` | 391 | 413 | 414 | 22 | 1 | 23 |
| `minsky_serial_registers:datapath` | 111 | 115 | 115 | 4 | 0 | 4 |
| `UFM reader` | 69 | 69 | 68 | 0 | -1 | -1 |
| `altufm_none:flash` | 0 | 0 | 0 | 0 | 0 | 0 |
| `altufm_none_1km:auto_generated` | 0 | 0 | 0 | 0 | 0 | 0 |
| `radar_unified_scan:scan` | 229 | 223 | 223 | -6 | 0 | -6 |
| `reset_ctrl:u_reset` | 8 | 8 | 8 | 0 | 0 | 0 |
| `switch_pair_sampled:u_switch_pair` | 9 | 9 | 9 | 0 | 0 | 0 |
| `ultrasonic_bcd_budget_compact:g_bcd_measurement.u_ultrasonic` | 136 | 133 | 131 | -3 | -2 | -5 |

差异为Fitter实际层级自身LE，不重复累计父子。1272未完成布局布线；其时序分析调用被工具拒绝，日志见initial_failed_timing。1270成功后最差10条路径与CDC/未约束基线核对见postfit。

最坏setup路径：bit_index[2]→position_count[0]，9逻辑级，布线占66%，setup=2.994ns；来自共享绘图/任务计数控制路径。同步SW7不是该候选最坏路径。门槛已满足，无须进一步流水化或seed扫描，QSF固定seed1。
