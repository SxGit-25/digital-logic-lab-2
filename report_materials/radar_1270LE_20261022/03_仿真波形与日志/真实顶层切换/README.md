# 真实顶层 mode / off 撤线握手专项

**四种场景全部PASS。** 仿真源固定为 `radar/beam_min/design/byte_a_source`，全部源文件SHA-256见 `source_manifest.json`。未修改生产RTL、候选源或QSF；无force/deposit、无内部请求/模式/系统状态注入。SW6、SW7均由真实引脚经过原两级同步及两次采样消抖；几何请求由真实顶层scan自然产生。

运行：`powershell -ExecutionPolicy Bypass -File radar/beam_min/test/run_top_quiesce.ps1`。便携Icarus在本机通过平台许可在沙箱外运行。测试代码 `tb_top_quiesce.v`；完整日志 `simulation.log`。

实际实例为 `radar_unified_top`，与BCD wrapper相同地设置 `ENABLE_READBACK=1`、`MEASUREMENT_BCD=1`、`P5_BEAM=1`、`P5_UFM=1`、`P5_UFM_BYTE=1`、`P5_INVERT=1`，Minsky参数保持原默认值。仅调度参数改为 `CLK_HZ=1000000`、`SELF_TEST_MS=1`、`STANDBY_MS=1`、`SWITCH_MS=1`、`SETTLE_MS=1`、`SLOT_MS=1000`、`CONTINUOUS_STEP_MS=1000`、`FAST_STEP_US=500000`；物理仿真时钟仍为20ns。这样压缩初始化/消抖等待并留出真实画线的观测窗口。**这些参数与周期数不能用于最终50MHz产品吞吐或帧耗时结论。**

LCD读操作使用引脚层固定零值响应器，不建立像素RAM参考；本测试仅验证控制时序，完整显存逐字节正确性由独立RAM参考测试验证。

| 场景 | 真实停止条件到达时的状态 | system_state=0 | 结果 |
|---|---|---:|---|
| 1 SW6连续切基本 | IDLE且beam_valid=1 | 恰1个时钟 | pending保持至撤线完成，再复位LCD |
| 2 SW6基本切连续 | 新扫描线绘制中 | 恰1个时钟 | 完成本次画线并撤线，再复位LCD |
| 3 SW7关闭 | IDLE且beam_valid=1 | 关闭期间持续 | 撤线完成后复位；外设先于消抖门控 |
| 4 SW7关闭 | 新扫描线绘制中 | 关闭期间持续 | 完成本次画线并撤线；外设先于消抖门控 |

所有场景都断言：停止请求到达的阶段确实符合所选场景；`lcd_restart_pending`跨过单拍OFF状态并持续保持；`beam_remove_done`已发生才允许LCD复位；复位上升时 `beam_valid=0`、`quiescent=1`、core为IDLE、LCD bus ready、draw_request=0、RD/WR/CS均释放。每场景恰好观察到一次撤线完成。

核心在时钟沿处理 `beam_remove_done`，同沿NBA更新 `beam_valid`及state后，组合 `lcd_reset`才上升；因此日志中remove_done/reset是相同时钟周期编号，实际事件顺序及复位时安全条件均已通过断言，并非在撤线结束前复位。

SW7关闭还逐时钟断言：两级同步后的SW7为0时，trig、servo、buzzer、LED、七段和矩阵列全部关闭，位选及矩阵行均释放；且存在 `system_on`尚未消抖变0的明确提前门控窗口（场景3为1627周期，场景4为1178周期）。这证明没有把即时门控退化为等待消抖或等待LCD撤线。
