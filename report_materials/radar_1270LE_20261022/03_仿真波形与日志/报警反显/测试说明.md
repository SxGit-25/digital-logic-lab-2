# beam + UFM byte 环境下的报警反显专项

**PASS。** 本目录从原 `radar/p5a/render_verify` 报警测试复制而来；原测试文件未修改，避免改变原回归源SHA。

运行 `powershell -ExecutionPolicy Bypass -File radar/beam_min/test/alarm/run_alarm.ps1`，使用冻结的 `radar/beam_min/design/byte_a_source`，实际core显式设置 `P5_BEAM=1/P5_UFM_BYTE=1/P5_INVERT=1`、`ENABLE_READBACK=1/P5_UFM=1/P5_FIXES=1`，`stop_request=0`。便携Icarus需本机平台沙箱外执行许可。

Python期望值来自 `radar/beam_min/test/render/reference.py` 的 `Reference(...,continuous=True,beam=True)`，扫描线固定r6..48。两帧分别为90度/r24、91度/r31，各1056字节，共2112字节逐字节一致。第2帧明确先等待core的accept，再等待该帧非beam的A/RMW阶段解除报警，避免把accept之前的撤旧线误当成已接受请求的绘图阶段。

保留原测试的最高报警等级/有效性/enable/system_state条件、真实物理250ms交替、报警解除A6（包括原本已是A6的情形）、无报警不发命令、A5禁止、忙中延后反显及两帧显存比较。额外为每条A6/A7在执行沿前后检查全部1056字节以及显存读写计数，9条命令全部通过，无显存变化。

| 实际测量项 | 周期 | 本测试物理时间（1MHz） |
|---|---:|---:|
| 空闲的相位边沿至命令完成，4次均相同 | 19 | 19 us |
| 第1帧忙中相位边沿至A7完成 | 24845 | 24.845 ms |
| 第2帧已accept且A/RMW中解除至A6完成 | 15836 | 15.836 ms |

这是原测试支持的1MHz物理时钟（周期1us）及1MHz global timebase，故phase边沿和交替命令的实际间隔均为250ms，不通过缩放tick伪造该间隔。LCD总线BFM保留原REAL_TIMING=1的周期数，UFM保留180ns串行输出稳定压力延迟。这些数值是该专项实际事件的延迟，并非50MHz产品所有角度的最坏帧/吞吐结论。仅作周期换算时，19/24845/15836周期在50MHz分别对应0.38us/0.49690ms/0.31672ms，仍不得把换算称为一次全速实测。

证据 `runs/beam_byte_a_alarm/simulation.log`：9条反显命令、7个相位边沿、250000000ns相位周期、2112字节两帧参考和9次逐命令RAM检查均PASS。测试在物理仿真时间1.810920秒结束；源SHA见同目录 `sources_sha256.csv`。无生产修改、无烧录、未提交Git。
