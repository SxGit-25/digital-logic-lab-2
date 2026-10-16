此目录是沙箱内 Icarus 失败的初始工具探针，不是 RTL 功能判定。

首轮 Windows PowerShell 5.1 将中文工具路径误解码。改用 pwsh 后，沙箱内 Icarus 在 code generation 完成后以 0xC0000005 崩溃；同一工具、同一 RTL 源快照经平台批准在普通本机环境编译及仿真正常。有效回归目录为 ../p5r_step1_full 及该前缀的各测试目录。source_snapshot 是正式回归使用的候选源文件。
