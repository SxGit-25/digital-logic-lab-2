# LE 账：1089 → 1253 → 上轮 1321 扫描线候选

**当前实际保留版本为 1253 LE；相对原 1089 增加 164 LE。旧扫描线候选的失败 Fitter 确认需求 1321 LE，较 1253 增加 68，超器件 1270 上限 51。**

## 口径与证据

- 1089、1253 均取成功 Fitter 的 `Fitter Resource Utilization by Entity`，括号内数为模块自身 LE。
- 1321 虽然 Fitter 失败，仍有上述层级资源表（fit.rpt:443，表格首行:447），可提取打包后的 LE 需求；未完成放置布线，不能称为成功 fit 或给出有效 postfit slack。
- 同一失败报告的 `Fitter Resource Usage Summary`（:139）总 LE 写 `Not available`，但 Fitter Summary（:60）和层级总计（:447）明确为1321。报错（:770）为1321 logic cells超过1270。
- 旧 `p5a/restart/step4/candidate_modules.csv` 来自 MAP，综合总数1404、draw self516；本账不用它冒充 Fitter LE。实际失败 Fitter 为1321、draw self468。

|模块（自身，不重复算子层）|1089成功FIT|1253成功FIT|变化|1321失败FIT需求|较1253|
|---|---:|---:|---:|---:|---:|
|radar_unified_bcd_top|1|1|0|1|0|
|radar_unified_top:system|15|9|-6|14|5|
|alarm_global:u_alarm|15|15|0|14|-1|
|lcd_bus_phase:bus|62|57|-5|56|-1|
|radar_display_gated:u_display|31|31|0|31|0|
|radar_display_shared:core|120|120|0|121|1|
|radar_global_timebase_alarm:u_timebase|67|67|0|67|0|
|radar_lcd_micro:draw|283|391|108|468|77|
|minsky_serial_registers:datapath|112|111|-1|108|-3|
|p5_ufm_reader:g_background.background_reader|0|69|69|69|0|
|altufm_none:flash|0|0|0|0|0|
|altufm_none_1km:auto_generated|0|0|0|0|0|
|radar_unified_scan:scan|229|229|0|223|-6|
|reset_ctrl:u_reset|8|8|0|8|0|
|switch_pair_sampled:u_switch_pair|9|9|0|9|0|
|ultrasonic_bcd_budget_compact:g_bcd_measurement.u_ultrasonic|137|136|-1|132|-4|
|合计|1089|1253|+164|1321|+68|

绘图整个子树（含 datapath、reader）395 → 571 → 645，分别 +176、+74；自身 draw 283 →391 →468。1253 至旧 beam：draw自身+77、其datapath-3、reader不变，子树净+74；绘图子树以外模块净-6，故全机净+68。若只排除draw自身，其余全机模块合计为-9。

## 旧扫描线尝试

|build|seed|Fitter需求LE|Fitter|MAP综合cells|反显 P5_INVERT|
|---|---:|---:|---|---:|---:|
|p5r_step4_initial|1|1321|失败|1404|1|
|p5r_step4_shared|1|1328|失败|1387|1|
|p5r_step4_area|1|1368|失败|1451|1|
|p5r_step4_seed2|2|1321|失败|1404|1|
|p5r_step4_seed3|3|1321|失败|1404|1|
|p5r_step4_seed4|4|1321|失败|1404|1|
|p5r_step4_seed5|5|1321|失败|1404|1|
|p5r_step4_seed6|6|1321|失败|1404|1|
|p5r_step4_seed7|7|1321|失败|1404|1|
|p5r_step4_seed8|8|1321|失败|1404|1|

初版1321；共享地址/返回角尝试1328；USER-ENCODED FSM + AREA尝试1368。初版为 seed1，其后 seed2–8均1321。全部保留 `P5_UFM=1`、`P5_INVERT=1`、`P5_BEAM=1`，没有通过删除反显来得到1321。

## 寄存器账

|旧beam新增RTL字段|位数|用途|
|---|---:|---|
|radar_lcd_micro.draw_mode|1|本次请求的模式快照|
|radar_lcd_micro.beam_valid|1|上次线存在标志|
|radar_lcd_micro.beam_drawn_angle|8|撤线角度|
|radar_lcd_micro.request_angle_bin|8|撤旧线期间保存新请求角度|
|radar_lcd_micro.beam_len|6|旧方案动态线长|
|radar_lcd_micro.beam_phase|2|撤旧/正常/画新阶段|
|radar_unified_top.lcd_restart_pending|1|模式切换stop锁存直至可复位|

上述新增命名字段共27 RTL位（draw26，top1）。Fitter全机寄存器统计437 →528 →557；旧beam较1253多29个寄存器需求，其中draw自身112→140（+28）、top自身0→1。命名RTL位不能逐位当成最终LE；另外2个寄存器差异可能来自FSM实现/优化，尚无逐节点网表归因，不作确定归属。失败版本未完成物理布局。

当前1253至1270仅余17 LE。旧beam的68 LE增量包含动态长度、请求返回角和停止协议的控制，不是新最简固定线长方案的实测预测；新候选仍须整机Fitter测量。

## 源报告

- `radar/unified_scan/results/p5a0_audit/bcd/radar_unified_bcd.fit.rpt:481`；保存的综合/MAP与源QSF分别在同一build目录。
- `radar/unified_scan/results/p5r_step3_alarm_gate/bcd/radar_unified_bcd.fit.rpt:481`；保存的综合/MAP与源QSF分别在同一build目录。
- `radar/unified_scan/results/p5r_step4_initial/bcd/radar_unified_bcd.fit.rpt:447`；保存的综合/MAP与源QSF分别在同一build目录。

提取脚本 `ledger_extract.py` 仅读保存报告与源快照，未编译、未改生产RTL。JSON保留所有模块的来源行号、Fitter状态、原始MAP口径及报告SHA-256。
