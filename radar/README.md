# 简易雷达报警系统 RTL

本目录实现《雷达系统代码分层实现计划.md》的基础功能：开机自检、待机、五方向往返扫描、HC-SR04 测距、数码管与双色点阵显示，以及 LED/蜂鸣器报警。

## 上板前必须确认

1. 查看实验板时钟选择指示灯。默认 `CLK_HZ=50_000_000`，`constraints/radar.sdc` 也按 50MHz 编写；若实物不是 50MHz，必须同步修改二者。时钟须为不低于 1MHz 的整 MHz 频率。
2. `alarm_ctrl.v` 集中定义 `BLUE_MASK/GREEN_MASK/YELLOW_MASK/RED_MASK`。板卡手册的文字只给出 LD 引脚，彩色分组图不够清晰；默认按 `LD15..12/LD11..8/LD7..4/LD3..0` 对应蓝/绿/黄/红，首次上板应执行 LED 分组检查并按实物调整。
3. `reset_ctrl.v` 依赖 MAX II 寄存器上电初值。Quartus 工程已关闭 `POWER_UP_DONT_CARE`；完整编译后仍应检查 reset 寄存器的 Power-Up Level 和相关警告。
4. 舵机信号占用 51 脚并与数码管 AP 硬件复用。设计没有 AP 输出端口，不能消除舵机脉冲可能造成的小数点亮光。
5. HC-SR04 按题目要求接 3.3V；仍应核对实发模块 ECHO 电平是否可由 EPM1270T144C5 安全接收。
6. 点阵坐标按题目图 2-1 的观察方向编码；首次上板若发现左右或上下镜像，应按实物丝印调整 `radar.qsf` 中对应行/列引脚顺序，不要改扫描业务逻辑。

## Quartus 工程

以 `constraints/` 为工程目录，创建工程后导入 `radar.qsf`，顶层为 `radar_top`，器件为 `EPM1270T144C5`。完整编译后重点检查：

- 引脚与 I/O 电平；
- reset 上电初值；
- 乘除常数逻辑的资源占用；
- 时序未约束路径与同步器 false path 范围；
- 意外锁存器或多驱动。

## 目录

- `rtl/`：可综合 Verilog-2001 RTL。
- `sim/`：Icarus Verilog 测试平台。
- `constraints/`：引脚与时钟约束。

运行仿真：

```sh
cd radar
./sim/run_tests.sh
```
