# TypeScript Native ("typescript")

- 语言 ID: `typescript`
- 扩展名: `.ts`, `.d.ts`
- 编译器/解释器数量: 10
- 编辑器: `typescript`
- 数据来源: https://compiler-explorer.com/api/compilers/typescript  抓取时间: 2026-08-11 00:25

| 编译器 ID | 名称 | 版本(semver) | 指令集 | 类型 |
|---|---|---|---|---|
| `tsc_0_0_20_gc` | TypeScript Native Compiler 0.0.pre20 JIT (GC) | 0.0.20 | amd64 | typescript |
| `tsc_0_0_20_nogc` | TypeScript Native Compiler 0.0.pre20 JIT (No GC) | 0.0.20 | amd64 | typescript |
| `tsc_0_0_26_gc` | TypeScript Native Compiler 0.0.pre26 JIT (GC) | 0.0.26 | amd64 | typescript |
| `tsc_0_0_26_nogc` | TypeScript Native Compiler 0.0.pre26 JIT (No GC) | 0.0.26 | amd64 | typescript |
| `tsc_0_0_27_gc` | TypeScript Native Compiler 0.0.pre27 JIT (GC) | 0.0.27 | amd64 | typescript |
| `tsc_0_0_27_nogc` | TypeScript Native Compiler 0.0.pre27 JIT (No GC) | 0.0.27 | amd64 | typescript |
| `tsc_0_0_33_gc` | TypeScript Native Compiler 0.0.pre33 JIT (GC) | 0.0.33 | amd64 | typescript |
| `tsc_0_0_33_nogc` | TypeScript Native Compiler 0.0.pre33 JIT (No GC) | 0.0.33 | amd64 | typescript |
| `tsc_0_0_35_gc` | TypeScript Native Compiler 0.0.pre35 JIT (GC) | 0.0.35 | amd64 | typescript |
| `tsc_0_0_35_nogc` | TypeScript Native Compiler 0.0.pre35 JIT (No GC) | 0.0.35 | amd64 | typescript |

> 提交请求时编译器 ID 为: `POST {base}/api/compiler/{id}/compile`

## 可设置参数（userArguments）参考
> ⚠ 本实例编译器是 TypeScript Native Compiler（Microsoft 实验性原生 JIT，tsc_0_0_xx），多数环境下仅有少量原生选项。以下为标准 tsc 常用参数（用于了解 TS 编译器能力全貌，与具体支持情况以实例行为为准；优先用 JIT 相关开关如 GC 与否由编译器 ID 选择）：
标准 tsc: --target ES2022、--strict、--module esnext|commonjs、--lib、--outDir、--declaration、--noEmit、--skipLibCheck、--esModuleInterop、--jsx
来源: https://www.typescriptlang.org/tsconfig/
