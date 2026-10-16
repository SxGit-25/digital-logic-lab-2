# P5 显存参考与仿真

`reference.py` 用独立 Python 整数实现 F15/K7 Minsky 向量和可逆相位调度，按像素集合合并字节掩码；不会从被测 RTL 导出预期结果。RAM 为 8 页 × 132 列，前 128 列可见，其余 32 字节初始化为零。

`lcd_ram_bfm.v` 是事务级 LCD 模型，保留设址后的空读、读缓冲、列自增及地址命令。每个事务用两个时钟完成，适合至少三往返的逐帧验证；它的运行周期不可用作真实 LCD 帧耗时，真实总线时序由既有 `lcd_bus` 回归验证。

生产第 2 项接入后运行：

```powershell
& radar/p5a/render_verify/run_render.ps1 -RunName step2_smoke -Smoke
& radar/p5a/render_verify/run_render.ps1 -RunName step2_full
& radar/p5a/render_verify/run_render.ps1 -RunName step2_real -Smoke -RealTiming
& radar/p5a/render_verify/run_render.ps1 -RunName step2_boot -Smoke -RealTiming -ProductionInit
```

两模式各 1091 次请求，覆盖三次往返、端点批量恢复、无效/近端/越界距离、同角度重复目标。每请求结束后 testbench 逐字节断言，并保存 1056 字节；Python 对整个 dump 再逐字节比较并输出放大预览图。`initial_expected.mem` 单独检查 UFM 全屏复制后的 1024 可见字节和 32 个隐藏字节。

`selftest_reference.py` 验证整数反向角度可逆、所有请求的 XOR 撤线恢复与无扫描线参考逐字节一致、隐藏列初值和像素去重。它只验证参考模型本身，不能代替 RTL 通过。

当前 testbench 预留 `BEAM_ENABLE` fixture 定义；生产扫描线参数确定后再连接，不能把未启用扫描线的仿真当作第 4 项已通过。

`-RealTiming` 把 LCD 请求接受至 done 的间隔设为读 40 clocks、写 16 clocks，与 `lcd_bus_phase` 的默认相位相同；仍使用独立 RAM 语义模型，真实电气时序继续由既有逐沿测试覆盖。`timing.csv` 逐帧分开记录 UFM、LCD 读、LCD 写和状态机周期，分类之和必须等于帧总周期。

默认 `tick_ms=1` 用于加速长扫，因此快速初始化周期不能当作实物上电总耗时。`-ProductionInit` 在初始化时生成真实 50 MHz ÷ 50000 毫秒节拍，单独验证复位、电源等待和顺序背景复制的完整时间。

`summarize_timing.py <run目录>` 对 real 模式报告实测时间，对 abstract 模式报告保守上界：每个读事务补 39 clocks、写事务补 15 clocks、每次 UFM 读取额外允许最多 15 clocks 相位等待。该上界只用于帧吞吐分析，不替代 Fitter/TimeQuest。
