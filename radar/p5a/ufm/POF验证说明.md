# POF 中 UFM 有效数据的验证

运行示例（替换实际候选 POF 和同次编译的 MIF）：

```powershell
python radar/p5a/ufm/check_pof_ufm.py candidate.pof background.mif --baseline-pof radar/p5a/delivery/p5a0_original_SW6_readback_1089LE.pof --out radar/p5a/ufm/candidate_pof_check
```

工具进行两条独立解码，并逐字比较：

1. 解析实际 POF 记录。仅接受已验证的 Quartus 9.1 / EPM1270T144C5 格式：tag `0x18`、1036 字节（固定 12 字节记录头及 1024 字节有效 UFM 数据）；有效数据按小端还原为 512 个 16 位字。遇到其他格式立即报错，绝不搜索任意字节序列后假定成功。
2. 使用本机官方 `quartus_cpf -c -q 4.5MHz -g 3.3 -n p image.pof image.svf` **只转换文件**。从官方输出中提取 ISP 地址 `0001` 选择的 UFM 区及 `2F4` 编程指令后的 512 个 `SDR 16 TDI` 字，逆转 JTAG 字内串行位序还原逻辑字，确认与直接解析的 POF 有效数据全部一致。这里没有执行 SVF，没有调用 Programmer，也没有连接 JTAG。
3. 把上述 512 个字逐字与指定的完整 MIF 比较。所有字必须完全一致；任一不等退出码为 1。

输出 `verification.json`、实际解码的 `pof_ufm.mem/.bin`、官方路径解码的 `official_ufm.mem`、官方 UFM 编程片段 `official_ufm_program.svf` 和转换日志。报告含实际 POF/MIF/UFM 有效数据 SHA-256、每个记录的位置与长度、官方完整 SVF 的 SHA-256、差异字数和前 16 个差异。只有 `pass=true` 才能声称该实际 POF 包含对应背景。

已有正对照 `pof_parser_positive/`：P2 的真实 UFM POF 与其 Q8 正弦 MIF **512 字全部相等**，官方转换与直接解析全部相等。阴性对照 `pof_parser_negative/`：P5a-0 原 POF 的 UFM 数据为 **512×FFFF 擦除态**，与正弦 MIF 的 91 个有效表字不同，按预期拒绝。原版不是缺少 `0x18` 记录；“未使用 UFM”在实际文件中表现为擦除态记录。后续阶段使用实际背景 MIF 时会对全部 512 字检查。

本机 `quartus_cpf --help=rpd`、`--help=isc` 虽列出转换能力，但实际转换均明确拒绝 EPM1270；因此没有用它们证明 UFM 存在。JAM 转换成功且可看到 8192 位 UFM 数组，但其数组经过压缩，SVF 是更直接的官方交叉验证路径。

本工具证明的是交付 POF 内包含正确 UFM 内容，不能替代对板上 UFM 的烧录和 Verify。Programmer 仍需同时勾选 CFM/UFM 并校验。
