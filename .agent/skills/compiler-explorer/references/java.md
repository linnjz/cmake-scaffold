# Java ("java")

- 语言 ID: `java`
- 扩展名: `.java`
- 编译器/解释器数量: 24
- 编辑器: `java`
- 数据来源: https://compiler-explorer.com/api/compilers/java  抓取时间: 2026-08-11 00:25

| 编译器 ID | 名称 | 版本(semver) | 指令集 | 类型 |
|---|---|---|---|---|
| `java1002` | jdk 10.0.2 | 10.0.2 | java | java |
| `java1102` | jdk 11.0.2 | 11.0.2 | java | java |
| `java1201` | jdk 12.0.1 | 12.0.1 | java | java |
| `java1202` | jdk 12.0.2 | 12.0.2 | java | java |
| `java1302` | jdk 13.0.2 | 13.0.2 | java | java |
| `java1402` | jdk 14.0.2 | 14.0.2 | java | java |
| `java1502` | jdk 15.0.2 | 15.0.2 | java | java |
| `java1601` | jdk 16.0.1 | 16.0.1 | java | java |
| `java1700` | jdk 17.0.0 | 17.0.0 | java | java |
| `java1702` | jdk 17.0.2 | 17.0.2 | java | java |
| `java1800` | jdk 18.0.0 | 18.0.0 | java | java |
| `java1802` | jdk 18.0.2 | 18.0.2 | java | java |
| `java1902` | jdk 19.0.2 | 19.0.2 | java | java |
| `java2000` | jdk 20.0.0 | 20.0.0 | java | java |
| `java2002` | jdk 20.0.2 | 20.0.2 | java | java |
| `java2100` | jdk 21.0.0 | 21.0.0 | java | java |
| `java2102` | jdk 21.0.2 | 21.0.2 | java | java |
| `java2200` | jdk 22.0.0 | 22.0.0 | java | java |
| `java2202` | jdk 22.0.2 | 22.0.2 | java | java |
| `java2301` | jdk 23.0.1 | 23.0.1 | java | java |
| `java2400` | jdk 24.0.0 | 24.0.0 | java | java |
| `java2501` | jdk 25.0.1 | 25.0.1 | java | java |
| `java8u402b06` | jdk 8.402.6 | 8.402.6 | java | java |
| `java904` | jdk 9.0.4 | 9.0.4 | java | java |

> 提交请求时编译器 ID 为: `POST {base}/api/compiler/{id}/compile`

## 可设置参数（userArguments）参考

> 整理自 javac 手册 https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html （2026-08-11）。CE 的 Java 流程：先用 javac 编译（用户参数给 javac），再按 compilerOptions 执行。手册按 JDK 21；老 JDK 实例（8/9/10…）选项子集更小。

**语言版本**: `--release 8|11|17|21|25`（一条命令同时定语法规则、平台 API 与 class 目标版本，推荐）；`-source N`/`-target N` 需成对使用且 target 不得低于 source；`--release` 自 JDK 9 才有，java8 实例只能用 `-source 8 -target 8`
**预览功能**: `--enable-preview`（必须搭配 `--release N` 或 `-source N` 使用）
**优化/生成**: `-g`（完整调试信息，含局部变量；默认只有行号+源文件）、`-g:none`、`-g:lines,vars,source`、`-parameters`（保留方法形参名供反射）、`-O`（javac 完全忽略，无效果）、`-d <目录>`（class 输出目录）、`-encoding UTF-8`（源文件编码，中文不乱码的关键）
**警告**: `-Xlint:all`（全部推荐警告）、`-Xlint:none` / `-nowarn`（关闭）、单项如 `-Xlint:unchecked,deprecation,preview`、`-Werror`（警告即编译失败）、`-deprecation`、`-Xdiags:verbose`（详细诊断）、`-Xmaxerrs N`/`-Xmaxwarns N`
**特殊**: `-proc:none`（禁用注解处理，加速且避免意外触发处理器）、`-proc:only`、`-XDstringConcat=inline`（JDK 9+ 未文档化内部选项，字符串拼接改用内联 StringBuilder，微小性能优化）、`--module-path`/`-p <路径>`（模块路径）、`--add-modules`、`-cp`/`-classpath <路径>`、`--source-path`、`--system`、`@argfile`（参数文件）
**常用组合**:
- 常规: `--release 21 -Xlint:all`
- 严格: `--release 17 -Xlint:all -Werror`
- 预览功能: `--release 21 --enable-preview`
- 老 JDK (8): `-source 8 -target 8 -Xlint:all`
