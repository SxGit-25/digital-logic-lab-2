# P5 背景资产

运行 `python radar/p5a/background/generate_background.py` 生成 `base/`。
选项 `--include-digits-header` 增加 page0 的 DEG/mm，
`--include-level-header` 增加 page1 的 LV；`--output PATH` 指定输出目录。
`digits/`、`level/`、`digits_level/` 是相应预生成版本。
`--input PATH.png` 可将既有 128×64 二值 PNG 编码；拒绝灰阶、透明及交错 PNG，避免静默阈值化改变像素。

黑像素 = 显存 bit 1；白像素 = bit 0。坐标原点为左上角。
圆采用整数 midpoint circle，保留完整上半圆，不裁剪文字下方的圈点；文字作为静态背景叠加。
不平滑、不缩放输入。放大预览使用 8×最近邻。

每套资产含：

- `background.png`：原始二值图。
- `background.mif`：512×16，Quartus `altufm_none.lpm_file` 初始化文件。
- `background.hex`：Altera 字寻址 Intel HEX。每条数据记录的数据长度以字节计，地址以 16-bit word 计，高字节先；这是器件 HEX，不能直接 `$readmemh`。
- `background.mem`：512 行 16-bit 纯文本 `$readmemh` 文件。
- `background_bytes.mem`：1024 行 8-bit LCD 顺序参考，每页左至右、各页上至下。
- `decoded_mif.png` / `decoded_hex.png`：分别读取实际写出的 MIF / HEX 后反向解码的图。
- `validation.json`：逐像素比较、区域所有权和全部 181×43 个射线位置的检查结果。
- `preview_8x.png`：放大预览。

地址为 `page * 64 + col // 2`，偶列取高字节，奇列取低字节；bit0 是页内最上面一行。
无 page0 非静态像素；page1 y8..15 的 x≤32 和 x≥100 除指定 LV 静态字外必须为 0。
所有权检查报错即终止，不裁剪冲突像素。

已用本机 `E:\quartus\QuartusII91\quartus\bin\mif2hex.exe` 转换 base MIF，结果存为
`base/quartus_mif2hex.hex`；其记录长度不同，但解码后 512 个 word 与脚本 HEX 完全相同。

本机 Quartus 9.1 的 `eda/sim_lib/maxii_atoms.v` 第 1405 行之后明确显示：器件仿真 UFM
不在运行时读取 `init_file` 字符串，而由 Quartus 把初始化文件内容展开到 `mem1..mem16` 参数。
因此直接使用这个底层模型且仅传同一文件名不能正确初始化；独立 RTL 仿真使用从同一 PNG
编码得到的 `.mem` 行为模型，或使用 Quartus 生成且包含上述参数的仿真网表。
硬件仍需核对 DEG 是否镜像、相邻两列是否互换。

烧录时 Programmer 必须同时勾选 CFM 和 UFM 的 Program/Configure，并对两区执行 Verify。
