# Javascript ("javascript")

- 语言 ID: `javascript`
- 扩展名: `.mjs`
- 编译器/解释器数量: 2
- 编辑器: `typescript`
- 数据来源: https://compiler-explorer.com/api/compilers/javascript  抓取时间: 2026-08-11 00:25

| 编译器 ID | 名称 | 版本(semver) | 指令集 | 类型 |
|---|---|---|---|---|
| `v8113` | v8 11.3 | 11.3 | amd64 | v8 |
| `v8trunk` | v8 (trunk) | (trunk) | amd64 | v8 |

> 提交请求时编译器 ID 为: `POST {base}/api/compiler/{id}/compile`

## 可设置参数（userArguments）参考
> ⚠ 本实例是 V8 的 d8 shell（v8113/v8trunk），不是 node.js。来源: https://v8.dev/docs/d8
**优化/调试追踪**: --trace-opt、--trace-deopt、--print-opt-code、--prof、--log-deopt
**特殊功能**: --allow-natives-syntax（% 内部函数）、--expose-gc（全局 gc()）、--harmony（开关实验特性）、--jitless、--turbo-fast-api-calls
**内存**: --max-old-space-size=N、--stack-size=N
**常用**: `--allow-natives-syntax --trace-opt` 调试 JIT；`--harmony` 实验特性；`--jitless` 禁用 JIT
