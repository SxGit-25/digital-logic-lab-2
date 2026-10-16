# 第 1 项失败候选：验证记录

候选最终仍因 setup 0.970 ns < 1 ns 不获保留。以下仿真/CDC 检查不能替代整机时序门槛，也不构成第 1 项通过。

## 已完成

| 范围 | 结果及证据 |
|---|---|
| 原有 6 套 | servo_pwm、ultrasonic、radar_ctrl、radar_top、alarm_ctrl、counter_equivalence 全 PASS；`../runs/step1_failed_regression/` |
| 生产 units 3 套 | global timebase、alarm_global、switch_pair 全 PASS；同上 |
| 生产测距 | PASS，20 样本及 5301 个余数/半径范围穷举；同上 measurement |
| 共享显示 | PASS，41088 次 oracle 检查；同上 display |
| 矩阵延迟基线探针 | exit 0，输出既有 `CONFIRMED_BOUND_EXCEEDED`，20 ms 历史更新变化可使可见延迟变化 23.25 ms；这不是新候选引入的回归，也不是该边界满足。新 runner 首次错误要求 PASS 字样而停止；已修正为检查原探针标志，未重跑已通过套件 |
| 生产扫描控制与两模式 | scan_control、production_basic、production_continuous 全 PASS；basic 8.31 s 覆盖 3 样本/3 提交/90 步/316 帧，continuous 4.17 s 覆盖 0/1/2° 三样本、60 ms 间隔、109 帧；均无中间舵机脉冲；`../runs/step1_failed_regression_remaining/` |
| 生产整机 | PASS，1275548 cycles，17 次超声触发、基本/连续 7/8 样本、2 次模式切换、3966 次 LCD 读取；基本快走合并 176 次，连续合并 0；同上 top |
| 原 direct-draw | PASS，375 请求、17807 像素、416 A / 375 B、142456 笔事务，逐字节参考一致；保留原测试主动饱和注入的 dropped=255（兼容路径 P5_FIXES=0），不是新生产模式合并次数；同上 draw/budget_f15 |
| 新 basic 绘图 | PASS，375 请求、18567 像素、435 A / 375 B、148536 笔事务，逐字节 RAM、向量、地址/空读/读改写次序、快照检查；merged=0；`../runs/step1_failed_new/basic/` |
| 新 continuous 绘图 | PASS，375 请求、17807 像素、416 A / 375 B、142456 笔事务，同上完整检查；merged=0；`../runs/step1_failed_new/continuous/` |
| 新 pending directed | PASS，接受 10°/r12 后忙时注入 20°/r22、30°/r32，随后只绘制最新 30°/r32；merged=1，未请求的外部输入扰动不改变当前快照；`../runs/step1_failed_new/pending/` |
| 真实 Fitter 网表 CDC | PASS：sw7/sw6/echo 各自原始端口只扇出至 meta，meta 只扇出至 sync，两个对象均为独立寄存器；`cdc/cdc_assertions.txt` |
| 未约束增减 | 输入 1 口/140 路径降为 0；输出仍 58 口、456 路径，setup/hold 均相同，相对冻结输出基线增减为 0；`cdc/unconstrained.rpt` |

两种新绘图测试最坏均 127239 cycles = 2.544780 ms；无 UFM，读取 0 ms，LCD 读 0.710400 ms、写 0.852480 ms、其余状态机/算术/握手 0.981900 ms。相对连续模式 60 ms 的 1° 步进间隔余量 57.455220 ms。这是上述覆盖场景的实测最坏值。

pending 测试首次 watchdog 是测试台竞态：第二次 pending 接受与第一次 done 同拍，接受分支的 `#1` 后才检查 done，会漏掉被 DUT 清除的完成脉冲。将完成脉冲采样移到 `#1` 前，同一候选 RTL 独立重测 PASS；未修改候选 RTL。原失败保存在 `pending/testbench_race_original_failure.log`。

## 运行入口与边界

`radar/p5a/run_regression.ps1 -RunName <唯一名>` 使用隔离输出运行有效生产套件；不运行已淘汰的资源实验分支。`radar/p5a/verification/run_step1.ps1 -RunName <唯一名>` 生成两种 A 角度政策的独立整数参考并检查实际 LCD 模型。

`assert_cdc.tcl` 在编译工程的 db/ 上运行 TimeQuest `get_fanouts`，未用 RTL 文本正则替代网表检查，也没有用 false path 过滤后的 timing path 代替实际扇出。Quartus 9.1 需要 ASCII 暂存脚本、输出路径及 SUBST 工程路径。命令为 `quartus_sta -t assert_cdc.tcl radar_unified_bcd cdc_evidence`。它检查三个允许异步端口的实际连接，不能证明模拟亚稳态概率或板外电气行为。

所有结果仅针对失败候选，不把回退后原版 SW7 的原始输入扇出重新描述为此 CDC 检查通过。实物统一验收仍未执行。

上述既有生产回归及新增第 1 项验证均已完成，没有观察到新的功能回归。整机 setup 门槛失败仍是拒收和回退原因。生产扫描原测试保留精确 us/ms 节拍，DENSE=0 在每 us 保留 3 个真实时间戳的 50 MHz 上升沿以覆盖使能和握手，未追加 dense/实验分支。
