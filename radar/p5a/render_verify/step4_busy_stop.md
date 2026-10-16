# 第 4 项忙中撤线验证

候选：`design/step4_source/radar_lcd_micro.v`。完整长扫结果单独生成；本文件只记录 stop/quiescent 专项。

两种模式各测试 5 个 stop 到达阶段，全部 PASS：

1. 请求已接受，尚未撤旧扫描线。
2. 正在撤旧扫描线。
3. A 恢复背景中。
4. B 目标绘制中。
5. 正在画新扫描线。

每个阶段先完成一个有扫描线的 warmup，再触发下一请求并在目标阶段拉高 `stop_request`，持续保持到 `quiescent`。前两个阶段允许在撤旧线后取消本请求；后三个阶段完成本次 A/B 后保留无扫描线图像。参考图由独立 Python Minsky 模型预先生成，撤线后逐字节比较。

两种模式各比较 **10560 字节**，均无 XOR 残留；`quiescent` 时 `beam_valid=0`、`pending=0`，继续保持 stop 20 个时钟未出现任何显存读写。此行为适配上层“锁存切换请求 → 持续 stop → quiescent 后 reset”的模式切换协议。

证据：`runs/step4_busy_stop1/{basic,continuous}/simulation.log`。复现：`run_busy_stop.ps1 -RunName <新名称> -SourceDir <候选RTL目录>`。
