# UFM 8位读取候选 a / b

两份候选均定义 `p5_ufm_byte_reader`，只能择一编入；不替换旧 `p5_ufm_reader`，旧16位模块及原测试保持独立。

- a：`radar/beam_min/design/p5_ufm_byte_reader.v`，地址寄存器 `addr_shift[8:0]` 独立于 `value[7:0]`，先测数据位宽从16降为8的资源变化。
- b：`radar/beam_min/design/p5_ufm_byte_reader_shared.v`，再将地址/数据共用 `work[8:0]`，组合输出 `value=work[7:0]`；单独测量第二步资源变化。寄存器减少不等于实际LE节省，整机Fitter才是结论。

## API

输入 `clk,rst,request,operation[1:0],address[8:0],low_byte`；输出 `busy,done,value[7:0]`。request只在busy=0时接受；done是单个50MHz周期；value在done后有效，直至下一次接受request。忙时请求忽略，调用者负责排队。

| operation | 操作 | low_byte | 完成时数据 | ARCLK脉冲 | DRCLK脉冲 |
|---|---|---|---|---:|---:|
| 00 | 装入9位随机地址 | 0 | word高字节 | 9 | 8 |
| 00 | 装入9位随机地址 | 1 | word低字节 | 9 | 16 |
| 01 | UFM地址自增一次 | 0 | 新word高字节 | 1 | 8 |
| 01 | UFM地址自增一次 | 1 | 新word低字节 | 1 | 16 |
| 10 | 从前一次高字节接续 | 忽略，建议1 | 同word低字节 | 0 | 8 |

operation=11保留，当前等同10，调用者不用。10之前必须是已经完成的高字节读取（00/01且low_byte=0），两者间可以任意等待，但不得插入其他UFM读取或复位。10不装载Flash数据寄存器，只继续移出余下8位。低字节随机读取可直接用00/low_byte=1，不需要调用者先读高字节。两个模块都不等待任何UFM busy/rtpbusy/osc信号。

背景映射保持 `address={page[2:0],col[6:1]}`，偶列高字节、奇列低字节；结果的bit0是页内最上行。A恢复的每个合并字节只发一次00请求，low_byte=col[0]，done时直接使用value8。

顺序初始化：第一个偶列用00/address0/low_byte0，其对应奇列用10；其后每个偶列用01/low_byte0，奇列用10。最终总共1024次8位请求，512个word全部覆盖。调用者只需保存一个8位背景字节并写LCD。已有奇偶列计数可生成operation，无须再维护9位UFM地址计数器。端区恢复仍使用随机00。

## 时序 / SDC

两候选均自由运行/16相位，ARCLK/DRCLK不超过3.125MHz，周期至少320ns、高/低各至少160ns；ARDIN首地址建立最小40ns，其后至少160ns；ARSHFT首建立最小40ns；DRSHFT建立/保持160ns。DRCLK上升后300ns在phase15采样。地址操作结束后仍有固定访问等待槽。硬件使用ALTUFM_NONE，硬件MIF默认background.mif；仿真同源background.mem仅经单个串行输出位传给FSM，并注入180ns输出稳定延迟。没有新增false path。

ARCLK、DRCLK寄存器Q各创建主时钟/16 generated clock。a的地址数据发起点仍为 `addr_shift[8]`，DRCLK接收端为此实例的 `value[*]`。b的地址发起点为 `work[8]`，DRCLK接收端为此实例的 `work[*]`。仅DRCLK到这些采样寄存器采用setup15/hold14 `-end`（300ns）；DRSHFT到UFM数据寄存器保留原按phase8变化的setup8/hold15 `-start`。首地址ARDIN/ARSHFT只有40ns建立，不能扩大成160ns路径。要核对实际fitted端点及匹配数，不将不存在的value寄存器套到b上。

测得延迟（50MHz周期）：随机高289..304、随机低417..432、地址自增高161..176、接续低129..144。保守整屏纯UFM事务上界为 `304+511*176+512*144=163968` 周期，即3.27936ms；另加调用状态机及LCD写入开销。最终帧和初始化耗时须重新实测，不能沿用16位模块结果。

## 独立验证

运行 `powershell -ExecutionPolicy Bypass -File radar/beam_min/test/run_ufm_bytes.ps1`，便携Icarus在本机需要平台沙箱外执行。每份候选均完成2146字节检查：所有512word两字节乱序独立读；整屏high/tail顺序读；511到0地址回卷；00、01、10全部16个请求相位（包含自增直接读低字节）；所有返回字节与同一background.mem一致。检查MSB-first地址、装载次数、DR脉冲数及done后的超过1个串行周期的停止状态，确保高字节严格8个DRCLK就早停、随机低字节16个、tail不发ARCLK且不重新load。建立/保持及脉宽断言全部通过，最小建立ARDIN40/ARSHFT40/DRSHFT160ns、保持ARDIN160/DRSHFT160ns。

日志：`ufm_a/simulation.log`、`ufm_b/simulation.log`。未修改生产core、旧reader或QSF，未提交Git；未声明整机资源/时序已通过。
