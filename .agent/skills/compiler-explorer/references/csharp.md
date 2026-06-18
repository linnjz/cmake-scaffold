# C# ("csharp")

- 语言 ID: `csharp`
- 扩展名: `.cs`
- 编译器/解释器数量: 39
- 编辑器: `csharp`
- 数据来源: https://compiler-explorer.com/api/compilers/csharp  抓取时间: 2026-08-11 00:25

| 编译器 ID | 名称 | 版本(semver) | 指令集 | 类型 |
|---|---|---|---|---|
| `dotnet100csharpcoreclr` | .NET 10.0 CoreCLR |  | amd64 | dotnetcoreclr |
| `dotnet100csharpcrossgen2` | .NET 10.0 Crossgen2 |  | amd64 | dotnetcrossgen2 |
| `dotnet100csharpildasm` | .NET 10.0 ILDasm |  | amd64 | dotnetildasm |
| `dotnet100csharpilspy` | .NET 10.0 ILSpy |  | amd64 | dotnetilspy |
| `dotnet100csharpmono` | .NET 10.0 Mono |  | amd64 | dotnetmono |
| `dotnet100csharpnativeaot` | .NET 10.0 NativeAOT |  | amd64 | dotnetnativeaot |
| `dotnet6011csharp` | .NET 6.0.110 |  | amd64 | dotnetlegacy |
| `dotnet6014csharp` | .NET 6.0.113 |  | amd64 | dotnetlegacy |
| `dotnet6018csharp` | .NET 6.0.116 |  | amd64 | dotnetlegacy |
| `dotnet60csharpcoreclr` | .NET 6.0 CoreCLR |  | amd64 | dotnetcoreclr |
| `dotnet60csharpcrossgen2` | .NET 6.0 Crossgen2 |  | amd64 | dotnetcrossgen2 |
| `dotnet60csharpildasm` | .NET 6.0 ILDasm |  | amd64 | dotnetildasm |
| `dotnet60csharpilspy` | .NET 6.0 ILSpy |  | amd64 | dotnetilspy |
| `dotnet60csharpmono` | .NET 6.0 Mono |  | amd64 | dotnetmono |
| `dotnet701csharp` | .NET 7.0.100 |  | amd64 | dotnetlegacy |
| `dotnet703csharp` | .NET 7.0.102 |  | amd64 | dotnetlegacy |
| `dotnet707csharp` | .NET 7.0.105 |  | amd64 | dotnetlegacy |
| `dotnet70csharpcoreclr` | .NET 7.0 CoreCLR |  | amd64 | dotnetcoreclr |
| `dotnet70csharpcrossgen2` | .NET 7.0 Crossgen2 |  | amd64 | dotnetcrossgen2 |
| `dotnet70csharpildasm` | .NET 7.0 ILDasm |  | amd64 | dotnetildasm |
| `dotnet70csharpilspy` | .NET 7.0 ILSpy |  | amd64 | dotnetilspy |
| `dotnet70csharpmono` | .NET 7.0 Mono |  | amd64 | dotnetmono |
| `dotnet80csharpcoreclr` | .NET 8.0 CoreCLR |  | amd64 | dotnetcoreclr |
| `dotnet80csharpcrossgen2` | .NET 8.0 Crossgen2 |  | amd64 | dotnetcrossgen2 |
| `dotnet80csharpildasm` | .NET 8.0 ILDasm |  | amd64 | dotnetildasm |
| `dotnet80csharpilspy` | .NET 8.0 ILSpy |  | amd64 | dotnetilspy |
| `dotnet80csharpmono` | .NET 8.0 Mono |  | amd64 | dotnetmono |
| `dotnet90csharpcoreclr` | .NET 9.0 CoreCLR |  | amd64 | dotnetcoreclr |
| `dotnet90csharpcrossgen2` | .NET 9.0 Crossgen2 |  | amd64 | dotnetcrossgen2 |
| `dotnet90csharpildasm` | .NET 9.0 ILDasm |  | amd64 | dotnetildasm |
| `dotnet90csharpilspy` | .NET 9.0 ILSpy |  | amd64 | dotnetilspy |
| `dotnet90csharpmono` | .NET 9.0 Mono |  | amd64 | dotnetmono |
| `dotnettrunkcsharp` | .NET (main) |  | amd64 | dotnetlegacy |
| `dotnettrunkcsharpcoreclr` | .NET (main) CoreCLR |  | amd64 | dotnetcoreclr |
| `dotnettrunkcsharpcrossgen2` | .NET (main) Crossgen2 |  | amd64 | dotnetcrossgen2 |
| `dotnettrunkcsharpildasm` | .NET (main) ILDasm |  | amd64 | dotnetildasm |
| `dotnettrunkcsharpilspy` | .NET (main) ILSpy |  | amd64 | dotnetilspy |
| `dotnettrunkcsharpmono` | .NET (main) Mono |  | amd64 | dotnetmono |
| `dotnettrunkcsharpnativeaot` | .NET (main) NativeAOT |  | amd64 | dotnetnativeaot |

> 提交请求时编译器 ID 为: `POST {base}/api/compiler/{id}/compile`

## 可设置参数（userArguments）参考

> 整理自 https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-options/ （2026-08-11）。CE 的 .NET 编译器：userArguments 传给 csc（`-option` 前缀形式）；toolchain 决定执行方式——CoreCLR（JIT）、Mono（解释执行）、NativeAOT（静态 AOT 编译）、Crossgen2（预编译 JIT 映像）、ILDasm/ILSpy（查看 IL 反汇编输出）。

**优化**: `-optimize+` / `-optimize-`（开启/关闭优化；release 默认开、debug 默认关，建议显式指定）、`-debug+` / `-debug-`（生成 PDB 调试信息，可 `-debug:full|pdbonly`）、`-deterministic+`
**语言版本**: `-langversion:preview|latest|latestMajor|default|15.0|14.0|13.0|12.0|11.0|10.0|...`；C# 语言版本与 SDK 绑定：.NET 6→C# 10、.NET 7→C# 11、.NET 8→C# 12、.NET 9→C# 13、.NET 10→C# 14、main→C# 15；老 SDK 不认更高版本号（报 CS9057 并回退默认），跨 SDK 直接写 `latest`
**nullable**: `-nullable:enable|disable|warnings|annotations`（可空引用类型上下文）
**特殊**: `-unsafe`（允许 unsafe 代码）、`-define:SYMBOL`（条件编译符号，逗号分隔多个）、`-checked+` / `-checked-`（整数溢出检查）、`-nowarn:NNNN`（按编号抑制警告）、`-warnaserror+`（警告当错误，可 `-warnaserror+:NNNN` 限定）、`-warn:0..4`（警告级别）、`-platform:x64|x86|anycpu`（目标平台）、`-nostdlib+`（不自动引用标准库）、`-r:程序集.dll`（附加程序集引用，可多次）、`-doc:file.xml`、`-main:类型`
**常用组合**:
- 严格: `-optimize+ -nullable:enable -langversion:latest -warnaserror+`
- 快速: `-unsafe -define:DEBUG`
- 调试: `-debug+ -optimize-`
- IL 查看: 直接选 ILDasm / ILSpy 工具链，无需用户参数
