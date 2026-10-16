# 可选 UI core 候选验证

候选 `radar/p5a/design/radar_lcd_micro_ui.v` 基于 `radar_lcd_micro_step3.v`，模块名仍为 `radar_lcd_micro`，替换编入，不能并行编入。生产 RTL、wrapper 和 QSF 未改。

新增默认关闭参数 `P5_DIGITS`、`P5_MODE`、`P5_LEVEL`，新增 `distance_bcd[15:0]`、`level[2:0]` 输入。wrapper 需把现有距离 BCD 和报警等级传入，并传递所选参数；QSF 需添加 `p5_ui_columns.v`。几何测试之外，须继续运行原有整机回归和 Fitter；本目录不作资源、时序或上板通过的声明。

只有几何 B 步结束才进入 UI_START=23/UI_WRITE=24。仍由 core 原有 bus_request/read/data/write 接口统一串行执行，UI 事务仅含 page/high-column/low-column/write-byte 四步，绝不读取 LCD。复用 bit_index 的低2位作为事务、上3位作为字符列，micro_left 作为字符索引，position_count 作为实际 LCD 列，flush_left 作为区域索引。没有新增重复地址计数器。

数字采用请求一致的双层快照：request 捕获 latest_distance，accept 锁存 active_distance 和 active_angle，几何和 UI 期间保持；pending 替换只改变最新请求，不能改变当前画面数字。等级同样捕获 latest_level/active_level；模式在 accept 时锁定。关闭参数后相应寄存器应由综合裁剪。数字完整实现新增 44 位 RTL 快照寄存器（latest_distance16、active_distance16、active_angle12），最终 LE 以整机 Fitter 为准。

`run_core.ps1` 在完整几何流水执行过程中测试每种可选 UI 组合：三个请求，包含忙时请求合并（中间请求被最新请求取代），接受后改变实时角度/距离/等级，验证快照稳定。UI 总线断言只写不读、命令/数据方向及页列指令正确。Python 用独立 segment-name 集合生成全部最终写列，逐字节且逐顺序比较，不只检查几个采样点。测试覆盖连续/基本模式词及等级2/5/0；字符生成器另有1160向量的全字形检查。
