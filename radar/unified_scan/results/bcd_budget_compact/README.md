# 测距去除独立 mod-25 计数器候选

独立新模块 `ultrasonic_bcd_budget_compact.v`，原 `ultrasonic_bcd_budget.v` 未修改。保留 `/294` echo上升沿相位清零、工作/提交两份BCD、31个全局ms tick超时及全部接口。

每次4拍BCD递增在 `phase==4` 完成后，检测低两位为00/25/50/75（排除初始工作值0），使半径加1并在48饱和；不再使用5位mod25计数器或over1200标志。COMMIT直接用工作BCD<=1200决定半径有效。下降沿恰逢串行BCD更新的情形仍等最后一位完成后再提交。

独立Quartus 9.1 EPM1270T144C5：**138 LE、67寄存器、37 I/O、UFM 0，Fitter成功，50MHz setup 2.348 ns / hold 1.078 ns**。对比原独立模块144 LE/73寄存器，省6 LE/6寄存器；仍超过120 LE子预算。此差值不能代替整机编译。

原20组完整pin-level边界/超时/取消测试PASS，理想mm最大误差1.5966。新增0..5300共5301个BCD值穷举检查半径进位、48饱和及20..1200有效范围全部PASS。前者同时检查下降沿在BCD四拍收尾三个不同位置时结果正确；后者以内部状态注入隔离验证替代mod25译码，并非代替pin-level测试。

复现：`radar/sim/unified_scan/run_bcd_budget_compact.ps1 -Quartus`。

最终RTL SHA256：`7066E1D485DC6916CC678F0EC99694F9573B37CA44E5974F5C930920F2BA2401`。
