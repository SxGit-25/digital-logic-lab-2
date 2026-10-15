# Minsky LCD 绘制独立验证

**绘图功能三组全部通过；严格每请求 `<1 ms` 的端区时限三组全部失败。** 未改生产 RTL、LCD 总线时序、ST7565 模型或 1 ms 约束。

| 版本 | 请求覆盖 | 功能 | 普通请求最大 busy | endpoint 最大 busy | 超过时限 |
|---|---|---|---:|---:|---:|
| compact F15/k7，phase6/add15/init63/base2 | 完整 0→180→0，另加目标/换向，共375次 | PASS | 0.569860 ms | **2.544740 ms** | 6次 |
| 初稿 F15/k7，同一 schedule | 同上375次 | PASS | 0.440880 ms | **2.572600 ms** | 6次 |
| 初稿 F17/k8，phase5/add15/init16/base4 | 26次定向请求 | PASS | 0.665040 ms | **3.009560 ms** | 6次 |

每组仿真保留严格 deadline 检查，最终均退出 **1**；日志分别含 `PASS_FUNCTIONAL` 与 `DEADLINE_FAIL`，未将功能通过冒充整体通过。

## 功能检查

- 连接原始 `lcd_init`、`lcd_bus` 与未修改的 `st7565_model`，实际完成 LCD 初始化、1056 字节清零及全部物理读写，模型检查 dummy read、自增列、总线归属和原始时序。
- 独立坐标来自 Minsky agent 的 `minsky_schedule_search.evaluate`。对每条 A/B 射线检查 canonical c/s；期望像素由整数公式 `64+floor((r*c+half)/Q)`、`63-floor((r*s+half)/Q)` 生成，不读取 DUT 坐标状态。
- 比对每次 RMW 的八个命令/读写类别/页列地址/最终字节，检查 A 先于 B、端区 11 条 A、每次恰好一条 B，并在每个请求后逐字节检查全部 1056 字节 RAM，包含邻居与不可见列。
- F15 两组分别验证 17807 个 RMW 像素、142456 次总线事务、416 条 A 和375条 B。F17 定向组验证3454像素、27632次总线事务、84条 A 和26条 B。
- 覆盖重复角度多目标保留、r=0/2 夹到6、r=48 valid代表1200-mm半径、r=48 invalid代表超距/noecho、r=49 valid仍拒绝目标。绘制接口只有 radius/valid，不把此项冒充上游超声换算验证。
- 接受请求后立即污染外部角度、方向和半径；在 busy 内插入额外请求，验证图像仍绑定原请求、随后跨角度/方向重同步正确，`dropped` 精确计数并最终饱和255。
- compact 每次请求从零向量重建，其 F15 两张 PBM 与初稿 F15 对应图像逐字节 SHA256 一致。

## 端区延迟

compact 的6次端区 busy 为：2.281300、2.540900、2.277460、2.544740、2.277460、2.544740 ms。计时从请求被接受的50MHz时钟沿开始，到 done 实际置位的时钟沿结束；没有扣除向量重建、XY移动、握手或总线等待。

当前 `lcd_bus` 的每次 RMW 包含6次写和2次读，仅配置阶段就需要：

`6×(4 setup+6 write+6 hold)+2×(20 turn+4 setup+10 read+6 hold)=176 clocks`。

端区至少11×40+3=443个RMW，因此**仅总线配置阶段的下界为443×176×20ns=1.55936ms**，尚未包含请求握手、Minsky旋转或XY串行加法。减少 Minsky 计算周期本身不足以达到现有端区 `<1ms` 要求。

## 图像和证据

- compact 完整扫：`compact_f15/full_scan.pbm`、`compact_f15/full_scan.png`。
- compact 多目标与换向：`compact_f15/multiple_targets_turnaround.pbm`、`compact_f15/multiple_targets_turnaround.png`。
- 两张 PNG 已实际打开检查；从128×64 RAM无插值放大6倍，未作图像修饰。
- 其它两组也保留对应PBM/PNG；F17是定向 baseline 图，不是181角度完整扫。
- 每请求记录：各组 `busy_walltime.csv`。完整状态与端区明细：`summary.json`、`status.csv`。独立像素/向量夹具、源码SHA256、编译与仿真日志均保留在对应组目录。

复现：

```powershell
& radar/sim/unified_scan/run_minsky_draw.ps1
& 'C:/Users/Metro/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' radar/sim/unified_scan/analyze_minsky_draw.py
```

第一个命令应因原样保留的端区1ms断言退出非0，并继续留下三组全部功能、时延和图像证据；第二个命令分别汇总功能与 deadline 状态。
