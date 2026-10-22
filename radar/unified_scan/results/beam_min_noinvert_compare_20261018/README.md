# 关闭 LCD 报警反显的资源对照

此目录只保存独立暂存工程的资源对照编译，不是当前交付或板上运行版本。主工程源码未修改，交付POF未替换，未烧录此候选，未运行关闭反显版本的完整功能回归。

编译命令：`radar/unified_scan/compile.ps1 -RunName beam_min_noinvert_compare_20261018 -Variants bcd -DefineParameters 'P5_INVERT=0' -Seed 1`。

| 指标 | 当前交付版 | 关闭反显对照版 |
|---|---:|---:|
| 总LE | 1270 | 1266 |
| setup slack/ns | 2.994 | 3.456 |
| hold slack/ns | 1.078 | 1.078 |
| Fitter | 成功 | 成功 |

整机实际净省4LE，保留扫描线、UFM背景、LED及蜂鸣器报警。同步器首级例外断言通过，未约束输出58个/456路径，相对冻结基线增减0，见 `postfit/`。编译输入、源SHA、POF和报告见 `bcd/`。

当前板上及交付仍为 `beam-min-1270`（保留反显）；已烧录POF SHA256为 `45963657dbc6975a83e8de8b566d6ee072bb1a34025de2c2e890bc1647ee71f3`。实物烧录回读记录位于 `radar/beam_min/programming/20261017_084443/`。
