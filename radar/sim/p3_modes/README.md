# P3 模式与兼容性回归

执行 `python radar/sim/p3_modes/run_modes.py`；`--bin` 可指定包含 `iverilog.exe`、`vvp.exe` 的目录，`--stage` 可指定 ASCII 临时目录。Windows 上临时目录的写入/执行权限需满足当前沙箱要求。结果保存在 `radar/p3_modes/results/simulation/`。

- `tb_equivalence`：从固定提交 `3231197` 提取旧 RTL、重命名后并行实例化。500000 个时钟逐周期比较旧顶层、现有基本顶层和新增双模式顶层的 mode 0；比较全部外部输出、控制器状态/测量/历史和显示合成结果。包含随机回波、SW7 关机与重启。
- `tb_continuous_servo`：100000 个带伪随机 tick、角度输入、enable 与复位的周期，比较默认分支及启用连续功能但 mode 0 的分支与旧版。然后保持 tick_us 每周期有效，完整运行 801 个 20000 tick 帧，逐帧累计真实 servo 输出高电平 tick 数，核对 500..2500..500 us、二进制角度、十进制 BCD、方向与端点。
- `tb_continuous_ctrl`：默认 60 ms 采样间隔；遍历 181 个角度 × 两个方向，核对四个就近阈值，测量期间让实时角度跨越另一条点阵线，确认结果仍更新锁存线。覆盖各距离等级、无效回波、实时 BCD、历史不串写、busy 时跳过采样、LED 与蜂鸣器载波。
- `tb_modes_integration`：真实 `ultrasonic` 590 us 回波和无回波超时；SW6 两种方向切换均在测量进行时触发，检查取消测量、清历史和 SELF→STANDBY→RUN；在非时钟边沿关闭 SW7，检查全部外部输出立即关闭。

顶层仿真通过 `CLK_HZ=1000000` 加速，并缩短自检/待机/切换消抖参数；超声回波宽度、超时和 PWM 的微秒计数保持原协议值。servo 单测将每个 tick_us 压缩为一个仿真周期，帧与脉宽计数没有缩短。控制器单测将 tick_ms 压缩为一个周期，其 60 tick 采样间隔没有改小。仿真验证逻辑及协议计数，不替代 Quartus 实测时序和实物验收。
