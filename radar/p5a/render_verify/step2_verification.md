# 第 2 项显存与节拍验证

生产候选 `design/step2_source/radar_lcd_micro.v` SHA-256：`FA1F6B9B9767EFBB988888D2FCE628E737D68C065EBEE33E5DA3CDD1717F95EC`。以下结果只说明该候选功能与帧吞吐，不替代整机 Fitter/TimeQuest。

|验证|基本模式|连续模式|
|---|---:|---:|
|完整请求数（各三往返 + 补充案例）|1091|1091|
|逐字节 RAM 比较|1,152,096 字节 PASS|1,152,096 字节 PASS|
|忙时合并次数|0|0|
|每条 A 射线每字节一次 LCD 读改写、一次 UFM 读|PASS|PASS|
|每条 B 射线只画目标、不读 UFM|PASS|PASS|
|上电 1024 可见背景字节 + 32 隐藏零字节|PASS|PASS|
|UFM 上电顺序读取 512 words|PASS|PASS|

独立 Python F15/K7 整数 Minsky 模型按历史增量维护 RAM；每条射线的像素先合并为字节掩码。LCD BFM 保留设址后空读、读缓冲与列自增，实际 dump 与参考由 Verilog 和 Python 分别比较。完整结果位于 `runs/step2_full1/{basic,continuous}/`。

长扫使用两时钟 LCD 事务模型。以真实 `lcd_bus_phase` 的读 40、写 16 个忙时钟替换，并对每次 UFM 加上最多 15 个时钟的相位等待，全部已测请求的保守真实帧上界为 **338665 clocks = 6.77330 ms**，距连续模式 **60 ms** 步进余量 **53.22670 ms**。其中基本模式缺独立 UFM 次数列，按所有 RMW 字节都读取一次 UFM 计入，上界更保守。完整分类数据和推导见 `runs/step2_full1/timing_summary.json`、`summarize_timing.py`。

真实事务延迟 smoke 两模式各 7 个代表请求，最大实测帧：基本 **6.70398 ms**、连续 **6.70416 ms**。连续最坏帧分类：UFM **202048 clocks**，LCD 读 **38540 clocks**、LCD 写 **47940 clocks**、状态机其余 **46680 clocks**，合计 **335208 clocks**。结果位于 `runs/step2_smoke_real3/`。

真实 50 MHz ÷ 50000 毫秒节拍的上电测试，两模式均 PASS：总初始化 **2373268 clocks = 47.46536 ms**（含 5 个 reset 时钟）；UFM 读取占 **153221 clocks = 3.06442 ms**、LCD 写占 **18513 clocks = 0.37026 ms**、其余复位/电源等待和状态机占 **2201529 clocks = 44.03058 ms**。首个 UFM 请求到整屏复制并 display-on 为 **173137 clocks = 3.46274 ms**。分别见 `runs/step2_production_init/` 与 `runs/step2_production_copy2/basic/`。

新增地址节拍单元测试覆盖全部 16 个请求相位、32 次随机/顺序读取：第一次 ARCLK 上升沿最早在请求后 **40 ns**；ARDIN/ARSHFT 最小 setup **40 ns**、最小 hold **160 ns**，全部 PASS。证明与范围说明见 `UFM地址节拍证明.md`。

最终候选预览分别为 `runs/step2_full1/basic/final_preview.png`、`runs/step2_full1/continuous/final_preview.png`。已检查可见圈、刻度和标签，无竖条或地址错位。此阶段尚未启用 XOR 扫描线。
