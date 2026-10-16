# 第 4 项 XOR 候选验证

本报告只说明候选的功能/吞吐验证，资源和时序是否接纳由整机 Fitter 结果决定，不代表此项已经保留。

候选 `design/step4_source/radar_lcd_micro.v` SHA-256 为 `730FF8302DB0AFD4E52103F81BDFF8A9F2AF55B4645503F811A94DA8C36045BD`，两模式运行快照一致。

|完整验证|基本|连续|
|---|---:|---:|
|请求数 / 往返|1091 / 3|1091 / 3|
|逐帧 RAM 字节比较|1,152,096 PASS|1,152,096 PASS|
|撤线后无 beam 参考比较|666 PASS|666 PASS|
|合并次数|0|0|
|最大 abstract 帧 cycles|274175|274168|
|保守真实帧上界|7.48900 ms|7.48886 ms|
|距 60 ms 步进余量|52.51100 ms|52.51114 ms|

每帧检查 `beam_valid`、binary angle 和 length；覆盖近端不画线、无效/超界目标全长线和有效目标 r_t−2 长度。像素按字节 OR 掩码后 XOR，LCD 每射线每字节读/写唯一，UFM 只允许 A 恢复背景读取。每次实际撤线后与上一帧的“背景 + 历史目标、无扫描线”参考逐字节相同；末尾 stop/quiescent 同样清除扫描线。

两模式各五个忙中 stop 阶段均通过，见 `step4_busy_stop.md`。完整运行证据为 `runs/step4_full1/`，具体逐项数字见 `timing_summary.json`；该运行使用 abstract LCD，两模式真实上界加入每读 39 clocks、每写 15 clocks 和每次 UFM 最多 15 clocks 相位增量。

绘制完成后的预览来自实际 RAM dump。最后案例是 0° 全长线，XOR 与底线重叠会表现为白色缺口，属于指定 XOR 行为；撤线检查会确认原底线完整恢复。
