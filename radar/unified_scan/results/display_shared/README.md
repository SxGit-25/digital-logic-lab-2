# 共享点阵与数码管扫描独立验证

`radar_display_shared.v` 吸收 display_compose、matrix_scan、seg_scan，只有一个 3 位扫描索引；外部输入 `tick_250us` 和 `color_phase[1:0]`，模块中不分频。颜色相位应每 8 个扫描节拍递增，而非每个扫描节拍递增，以免一行始终固定某个相位。相位计数由全局时基负责。

接口：`clk/rst/enable/tick_250us/color_phase/system_state/blink_2hz/angle_bcd[11:0]/current_distance_bcd[15:0]/current_valid/hist_level0..4[2:0]/hist_valid[4:0]/hist_seen[4:0]`。输出 `seg[6:0]/cat_n[7:0]/row_n[7:0]/col_r[7:0]/col_g[7:0]/scan_idx[2:0]`。统一角度直接使用 BCD，不再接收 angle_idx 或模式 mux。

数码管位周期和点阵行周期均为 250 us，整帧 2 ms，即各 500 Hz。四相颜色混合周期为 8 ms，即每个 LED 125 Hz；红/绿 1:3、2:2、3:1 占空比与旧颜色定义一致。每次外部节拍先关闭行和位，下一 50 MHz 周期更新数据，再下一周期开启行和位，消隐 40 ns。数据更新到行/位打开有 20 ns 建立时间。

独立 Quartus II 9.1 Build222、EPM1270T144C5、50 MHz、AREA 编译：137 LE、36 寄存器、UFM0，Fitter 成功；setup 3.732 ns、hold 0.805 ns、Fmax 61.47 MHz。为避免虚拟接口影响引脚预算，只有 clk 为真实 PIN18，其余104输入输出位使用虚拟引脚；各输入、输出 max5/min0ns 约束。完整 qsf/sdc/rpt/source 同目录保存。整机上下文会重优化，因此不可直接把 230-137 当作整机节省。

仿真使用保留的原 display_compose 作为独立组成参考，独立 decode/红绿 PWM oracle 逐行对比；覆盖全部4系统状态、两种闪烁、4颜色相位、level0..7、seen/valid四种语义、全部32×32历史位掩码、每个数字编码0..15以及关闭/消隐状态。复现：`radar/sim/unified_scan/run_display_shared.ps1`。原 display_compose 与原扫描模块均未修改。
