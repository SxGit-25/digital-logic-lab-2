# 第1项失败构建证据

此目录和 `radar/unified_scan/results/p5_step1_candidate/bcd/` 保存必须回退的第1项候选，**不是发布目录**。

- 实测：1109LE、455寄存器，Fitter成功；setup0.970ns、hold1.078ns。用户门槛为setup≥1ns，故失败。
- 最差路径：`radar_unified_scan:scan|sample_event` -> `radar_lcd_micro:draw|position_count[5]`；6级逻辑，data delay18.697ns。setup正值仅表示20ns时钟要求通过，未达到本轮额外1ns余量要求。
- 实际构建源、QSF/SDC、各模块LE、逐路径时序与原始POF：`radar/unified_scan/results/p5_step1_candidate/bcd/`。
- `candidate.patch`：第1项RTL及其必要测试期望变化；最终工作树已回退，补丁不处于生效状态。
- `FAILED_step1_pending_basicA0_syncSW7_1109LE_setup0p970ns.pof`：明确标记未达门槛，不应烧录。
- `cdc/`：实际post-fit网表三组同步器断言及全部未约束路径。
- 新旧回归输出：`radar/p5a/runs/step1_failed_regression/` 与 `step1_failed_new/`。

为不改原direct-draw几何测试预期，候选 `radar_lcd_micro` 增加常量参数 `P5_FIXES`；旧直接实例默认0保持旧行为，生产顶层显式传1。新独立测试使用1并分别检查基本A=0和连续A=±10。对原顶层测试唯一必要的语义变化是将SW7异步即时关断改为用户明确要求的两级同步延迟，以及将旧drop计数预期更新为pending替换计数；原六套基础测试预期未改。

待验证全部收尾后，最终状态记录见 `verification_results.md`。后续若重新尝试，须使用失败快照或补丁恢复候选，不应直接拿回退后的工作树运行这些“新功能应通过”的测试并宣称候选已验证。
