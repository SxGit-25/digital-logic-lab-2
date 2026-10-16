# 第 3 项反显验证

候选：`design/step3_source/radar_lcd_micro.v`，测试显式启用 `P5_INVERT=1`。

`tb_alarm_inverse.v` 使用生产 `radar_global_timebase_alarm` 支持的 `CLK_HZ=1_000_000` 设置，物理时钟周期 1 µs，因而 `rhythm_phase[1]` 在仿真时间上真实每 **250 ms** 翻转；未强制内部计数器，也未修改生产逻辑。这用于验证报警的时间语义，50 MHz 的生产约束和总线物理时序仍由整机编译及既有回归覆盖。

`runs/step3_alarm_concurrent1/simulation.log` 全部 PASS：

- 最高报警条件为 enabled、run 状态、current_valid、current_level=5；0–4 级、无效测量、禁用输出和非 run 状态不产生报警命令。
- 持续报警的四次相位边沿交替发 A7/A6，相邻命令严格相隔 250 ms。
- 解除报警时，不论最后状态为 A6 或 A7，均补发一次 A6；解除后的相位翻转不再发命令。
- 空闲报警期间全部 1056 字节与背景快照一致，LCD 显存读/写次数不增加；所有反显事务均为 command，未发送 A5。
- 实际 UFM A/B 帧提前 10 µs 启动，使 250 ms 边沿落在绘制中；A7 延至绘制完成后发送。随后另一帧绘制中解除报警，A6 同样延后至绘制完成。两帧共 **2112 字节**与独立 Python 累积显存参考一致，命令前后逐字节不变。
- 合计 **9 条反显命令、7 个相位边沿、2 个并发绘图请求**通过。

复现：`run_alarm.ps1 -RunName <新名称> -SourceDir <候选RTL目录>`。Icarus 需在已批准的普通本机环境执行，沙箱内该旧版工具会访问异常。
