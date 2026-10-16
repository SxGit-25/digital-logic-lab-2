# 独立 UFM 地址/数据寄存器复用候选

候选位于 `radar/p5a/design/p5_ufm_reader_shared.v`，模块名仍为 `p5_ufm_reader`，用于替换而非并行编入生产 reader。本次未修改生产 reader 或 SDC。

地址阶段将 `value={address,7'b0}` 并在 ARCLK 下降沿左移；ARDIN 为 `value[15]`。保留组合别名 `addr_shift=value[15:7]` 以运行原测试。读取阶段仍把全部 16 个串行位移入 value。输出只有 done 后有效，因此地址阶段覆盖 value 不改变公开接口语义。地址存储由 9 个寄存器降为零；实际 LE 变化必须由整机 Fitter 确认。

运行 `powershell -ExecutionPolicy Bypass -File radar/p5a/ufm/run_shared.ps1`。原 1025 字回归全部通过，随机读取 417..432 周期、顺序 289..304 周期。额外覆盖随机加载/顺序自增各 16 个请求相位，覆盖掩码均为 FFFF；每次随机加载都强制首地址输入位实际切换。32 个返回字全部与背景一致。

实测最小建立时间：ARDIN 40 ns、ARSHFT 40 ns、DRSHFT 160 ns。实测最小保持时间：ARDIN 160 ns、ARSHFT 5800 ns、DRSHFT 160 ns。ARCLK/DRCLK 周期不低于 320 ns，高低脉宽不低于 160 ns；数据模型继续注入 180 ns 输出稳定延迟。

若整合：SDC 中原 `addr_shift[8]` 发起端应匹配改后的 `value[15]`，并核对实际综合网表匹配数。ARCLK/DRCLK 的 /16 generated clock、DRCLK 到 value 的 setup15/hold14 -end、DRSHFT 的固定相位均不变。不得因为 value 也承担地址移位就扩大已有数据采样多周期的起点；它仍只允许 DRCLK 到该 reader 的接收 value 寄存器。首地址 ARDIN/ARSHFT 只有 40 ns 建立时间，不能施加 160 ns 假定。
