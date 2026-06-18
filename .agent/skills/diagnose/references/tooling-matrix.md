# 多语言工具矩阵

反馈回路、插桩、性能基线、回归测试的六语言工具映射。目标平台优先标注 Windows。原则部分语言无关，见 SKILL.md 主体。

## 跨语言通用

- **二分**：`git bisect run <回路脚本>` 对所有语言通用——脚本在状态 X 下构建并运行回路，非零退出即失败。数据/配置二分同理，换脚本输入即可。
- **Sanitizers 优先**：C/C++（ASan/UBSan）与 Rust（unsafe 代码）先开，常一步暴露内存类根因。
- **确定性**：锁定时钟与随机种子是所有语言的通用手法（下表给出各语言实现）。

## C / C++

| 用途 | 工具 |
|------|------|
| 测试框架 | GoogleTest / Catch2；CMake 用 CTest 聚合（`ctest --output-on-failure`） |
| 调试器 | GDB / LLDB；MSVC 用 Visual Studio 调试器或 VS Code C/C++ 扩展 |
| 性能剖析 | Linux: `perf record` + `perf report`、`valgrind --tool=callgrind`；Windows: VS Profiler / WPA；Intel VTune |
| 属性/模糊测试 | RapidCheck（属性）；libFuzzer / AFL++（模糊）；ASan/UBSan 必开 |
| 时间控制 | 抽象时钟注入（`std::chrono` + mock clock）；测试环境避免真实 sleep |

回路要点：`-DCMAKE_BUILD_TYPE=Debug` + ASan 快速暴露内存类根因；CTest 支持 `--repeat until-fail:N` 治偶发失败。

## Rust

| 用途 | 工具 |
|------|------|
| 测试框架 | 内置 `cargo test`；`cargo nextest` 提速并行 |
| 调试器 | rust-gdb / rust-lldb；VS Code codelldb |
| 性能剖析 | `perf` + `cargo flamegraph`；基准用 `criterion` |
| 属性/模糊测试 | `proptest`（属性）；`cargo-fuzz`（libFuzzer） |
| 时间控制 | tokio: `tokio::time::pause()` + `advance`；std 环境用注入时钟 |

回路要点：`RUST_BACKTRACE=full` 看完整栈；`cargo test -- --nocapture` 保留插桩输出。

## Java

| 用途 | 工具 |
|------|------|
| 测试框架 | JUnit 5；Maven Surefire / Gradle 集成 |
| 调试器 | `jdb`（CLI）；IntelliJ / VS Code Java 调试器 |
| 性能剖析 | JFR（`-XX:StartFlightRecording`）+ JMC 分析；async-profiler |
| 属性/模糊测试 | jqwik（属性）；Jazzer（模糊） |
| 时间控制 | `java.time.Clock` 注入；测试用固定 Clock / Mockito，避免 Thread.sleep |

回路要点：JUnit 5 `@RepeatedTest` 复跑治偶发；jqwik 随机输入扩大覆盖。

## .NET

| 用途 | 工具 |
|------|------|
| 测试框架 | xUnit / NUnit / MSTest；`dotnet test` |
| 调试器 | Visual Studio / VS Code C# 调试器；`dotnet run` 后附加 |
| 性能剖析 | `dotnet-trace collect`（CPU 采样）；`dotnet-counters`（运行时指标）；`dotnet-gcdump`（内存） |
| 属性/模糊测试 | FsCheck（属性）；SharpFuzz（模糊） |
| 时间控制 | .NET 8+ 注入 `TimeProvider` + `Microsoft.Extensions.TimeProvider.Testing` 的 `FakeTimeProvider` |

回路要点：`dotnet test --filter` 缩小范围；`--blame-crash` 定位崩溃源。

## Python

| 用途 | 工具 |
|------|------|
| 测试框架 | pytest；`pytest -x --tb=short`；`pytest-repeat` 复跑 |
| 调试器 | pdb / ipdb；debugpy（VS Code 附加） |
| 性能剖析 | cProfile；py-spy（在线采样、零侵入）；scalene |
| 属性/模糊测试 | Hypothesis（`@given` 随机输入） |
| 时间控制 | freezegun（`@freeze_time`）；生产代码注入时钟 |

回路要点：venv 隔离环境；`-p no:cacheprovider` 去缓存副作用；pytest fixture 可注入确定性时间。

## JS / TS

| 用途 | 工具 |
|------|------|
| 测试框架 | jest / vitest；Playwright（e2e） |
| 调试器 | `node --inspect-brk` + Chrome DevTools / VS Code |
| 性能剖析 | `node --cpu-prof` / `--prof`；Chrome DevTools Performance |
| 属性/模糊测试 | fast-check（属性） |
| 时间控制 | jest `useFakeTimers` / vitest `vi.useFakeTimers`；sinon fake timers；Playwright `page.clock` |

回路要点：UI bug 的无头浏览器脚本是本语言标配反馈回路（断言 DOM/console/network）。