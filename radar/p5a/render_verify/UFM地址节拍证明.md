# UFM 地址与控制的计数节拍余量

被测生产文件：`radar/rtl/p5_ufm_reader.v`。独立测试：`tb_ufm_address_margins.v`。本测试仅使用原有 reader 请求/结果接口驱动，不修改 RTL。

对 `request` 接受时的全部 16 个 free-running phase 分别测试随机设址与顺序递增，共 32 次读取，数据与同一背景 word mem 一致。仿真实测：

|项目|最低时间|
|---|---:|
|请求被接受至第一次 ARCLK 上升沿|40 ns|
|ARDIN / ARSHFT 至 ARCLK 上升沿的 setup|40 ns|
|ARCLK 上升沿后 ARDIN / ARSHFT 的 hold|160 ns|
|请求相位覆盖|0–15 全覆盖（0xffff）|

完整输出见 `ufm_address_margins/simulation.log`，结论为 PASS。

请求只在 IDLE 接受并更新地址移位寄存器和 ARSHFT。随后先进入 ALIGN；必须等到 phase=15 才进入 ADDR，再等 phase=0 才拉高 ARCLK。因此最快的首次上升沿也在请求后两个 50 MHz 周期，即 40 ns 后；若错过该边界，只会增加等待。

串行地址读取期间，ARCLK 在 phase=0 上升，在 phase=8 下降；ARDIN 的移位更新也在 phase=8。上升沿后下一次可能改变 ARDIN 的时刻相隔八个 50 MHz 周期，即 160 ns；随后到下一次 ARCLK 上升沿也相隔 160 ns。ARSHFT 只在新请求开始时改变，当前请求完成需经过后续固定 ACCESS/LOAD/SHIFT，因而其上升沿后保持时间更长。

因此，地址/ARSHFT 路径的计数语义允许以 50 MHz 源时钟为单位的 setup 2-cycle `-start` 和对应 hold 9-cycle `-start` 约束：最低 setup 窗口 40 ns，最低 hold 窗口 160 ns。约束必须仅指向上述 reader 地址/ARSHFT 至其 UFM 地址寄存器，不应扩展至其他数据路径。最终仍需由完整 Fitter/TimeQuest 确认物理延迟后的 setup、hold 均为正；本节拍证明不代替 STA。

既有 reader 单元测试另检查 ARCLK/DRCLK 最小周期 320 ns、高低电平各 160 ns（3.125 MHz），以及 MSB-first 地址和 180 ns 输出稳定延迟。
