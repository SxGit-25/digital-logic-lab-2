# 阶段回归

`run_stage.py --run-name NAME --source-dir PATH --step1 --jobs 4` 从指定 RTL 目录保存一份不可变快照，使用 4 个独立进程并行执行原有全部回归及第 1 项新增测试。删去 `--step1` 仅执行原有回归；后续阶段仍须另跑该阶段的功能模型测试。所有 50 MHz/production 参数、运行时长、逐周期检查、原参考模块均保持原值，没有压缩测试。

Windows 沙箱内 Icarus 编译器在 code generation 完成后可能以 `0xC0000005` 崩溃。此环境已验证同一工具和源快照在普通本机环境可正常完成，须通过工具平台的 `require_escalated` 运行。使用 `pwsh` 防止 Windows PowerShell 5.1 将无 BOM 脚本中的中文路径误解码。Icarus 在 ASCII 临时目录内使用相对源文件名和输出路径。

每个测试保留独立的 compile/simulation 日志；父目录保留 RTL 的 SHA-256 清单和总体 status.csv。测试快照另存，并在阶段结束时断言测试源未发生变化。失败的测试不得以更改标记或忽略退出码的方式判定通过。

第 1 项的合同变化仅有：P5_FIXES=1 的 request 先写入最新数据，下一拍在 pending && !request 时接受；busy 丢弃改为 pending 被覆盖的合并计数；生产 SW7 输出门控在未消抖的第二级同步寄存器更新后关闭。P5_FIXES=0 直接绘图参考、原 radar_top 的 raw SW7 检查均保持原状。
