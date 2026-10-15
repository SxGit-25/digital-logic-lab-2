# 极坐标资源预算执行：整机1089 LE，分项仍有两项超预算

最终完整离线回读候选：**1089/1270 LE、437寄存器、75 I/O、UFM0**，Quartus9.1 Fitter成功，50MHz setup **3.786ns** / hold **1.078ns**。相对1415基线少326LE；已低于1143，剩余54LE。首次装入1195LE时已向用户先报告，再继续其余步骤。

**测距137>120、绘图含init395>210；未称所有分项预算完成。** 基本快走丢请求后的图形完整性及上板电气测试也仍未完成。

- [完整预算、逐步实测、时序及预期调整报告](results/BUDGET_REPORT.md)
- [逐模块原始汇总](results/module_resources.csv)
- [最终完整候选原始Quartus报告与源快照](results/budget_final_index/bcd/)
- [默认禁读候选报告](results/budget_final_index/bcd_safe/)
- [全部结果包](results.zip)
- [验收契约](验收契约与资源基线.md)

| 类别 | LE | 预算 |
|---|---:|---:|
| 测距 | 137 | 120 |
| 扫描+ctrl | 229 | 230 |
| 点阵+数码管+compose（含即时门控） | 151 | 195 |
| 报警 | 15 | 50 |
| LCD bus | 62 | 95 |
| 绘图（吸收init） | 395 | 210 |
| 顶层其余 | 100 | 100 |
| **总计** | **1089** | **优选1143** |

稳定计时最终同源对照为1089与1104LE，PWM后稳定多15>2，按授权选槽起300ms并记录28ms点阵上限；53760相位组合最大24ms。1°、最小半径6、前方10°、端区批量、后方命中0均保留。普通绘图<1ms，端区最坏约2.545ms≤20ms。

每个.pof内部均包含SW6双模式，沿用用户之前接受的MAXII原生格式。源码ENABLE_READBACK默认0；离线readback1候选不是电气上板批准。默认禁读版927LE/407寄存器、setup3.146/hold1.078，只初始化清屏，不替代完整极坐标验收。未烧录设备。

复现入口见完整报告；最终整机：

```powershell
& ./radar/unified_scan/compile.ps1 -RunName reproduce_final -Variants bcd,bcd_safe -Area
& ./radar/sim/unified_scan/run_budget_top.ps1 -RunName reproduce_top
& ./radar/sim/unified_scan/run_budget_draw.ps1 -RunName reproduce_draw
& ./radar/sim/unified_scan/run_budget_units.ps1
& ./radar/sim/unified_scan/run_budget_regression.ps1
```

旧阶段成功与失败证据全部保留。`results/HISTORICAL_UNIFIED_README.md`仅为预算调整前历史说明，里面的旧顶层命令不能直接用于当前接口。
