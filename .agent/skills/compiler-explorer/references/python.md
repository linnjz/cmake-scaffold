# Python ("python")

- 语言 ID: `python`
- 扩展名: `.py`
- 编译器/解释器数量: 28
- 编辑器: `python`
- 数据来源: https://compiler-explorer.com/api/compilers/python  抓取时间: 2026-08-11 00:25

| 编译器 ID | 名称 | 版本(semver) | 指令集 | 类型 |
|---|---|---|---|---|
| `codon0192` | Codon 0.19.2 | 0.19.2 | python | codon |
| `micropython-preview` | MicroPython 1.28.0-preview | 1.28.0-preview | mpy | micropython |
| `micropython1200` | MicroPython 1.20.0 | 1.20.0 | mpy | micropython |
| `micropython1210` | MicroPython 1.21.0 | 1.21.0 | mpy | micropython |
| `micropython1220` | MicroPython 1.22.0 | 1.22.0 | mpy | micropython |
| `micropython1221` | MicroPython 1.22.1 | 1.22.1 | mpy | micropython |
| `micropython1222` | MicroPython 1.22.2 | 1.22.2 | mpy | micropython |
| `micropython1230` | MicroPython 1.23.0 | 1.23.0 | mpy | micropython |
| `micropython1240` | MicroPython 1.24.0 | 1.24.0 | mpy | micropython |
| `micropython1241` | MicroPython 1.24.1 | 1.24.1 | mpy | micropython |
| `micropython1250` | MicroPython 1.25.0 | 1.25.0 | mpy | micropython |
| `micropython1260` | MicroPython 1.26.0 | 1.26.0 | mpy | micropython |
| `micropython1261` | MicroPython 1.26.1 | 1.26.1 | mpy | micropython |
| `micropython1270` | MicroPython 1.27.0 | 1.27.0 | mpy | micropython |
| `pypy310` | PyPy 3.10 | 3.10 | python | python |
| `pypy311` | PyPy 3.11 | 3.11 | python | python |
| `pypy39` | PyPy 3.9 | 3.9 | python | python |
| `python310` | Python 3.10 | 3.10 | python | python |
| `python311` | Python 3.11 | 3.11 | python | python |
| `python312` | Python 3.12 | 3.12 | python | python |
| `python313` | Python 3.13 | 3.13 | python | python |
| `python314` | Python 3.14 | 3.14 | python | python |
| `python35` | Python 3.5 | 3.5 | python | python |
| `python36` | Python 3.6 | 3.6 | python | python |
| `python37` | Python 3.7 | 3.7 | python | python |
| `python38` | Python 3.8 | 3.8 | python | python |
| `python39` | Python 3.9 | 3.9 | python | python |
| `pythran015` | Pythran 0.15 | 0.15 | amd64 | pythran |

> 提交请求时编译器 ID 为: `POST {base}/api/compiler/{id}/compile`

## 可设置参数（userArguments）参考
> 整理自 https://docs.python.org/3/using/cmdline.html（2026-08-11）。CE 上 userArguments 作为解释器命令行参数（编译阶段也会传给编译器配置）。
**优化**: -O（移除 assert 与 __debug__）、-OO（再移除 docstring）
**特殊**: -B（不写 .pyc）、-S（不预加载 site）、-E（忽略环境变量）、-I（隔离模式）、-q、-u（无缓冲）
**运行时特性**: -X utf8、-X dev（开发模式）、-X int_max_str_digits=N、-X frozen_modules=off、-W ignore|error（警告控制）
**模块用**: -m 模块名、-c 命令（CE 执行时一般直接跑源码，注明）
**常用**: `-O` 快速性能（去断言）；`-X dev` 开发诊断；`-W error` 警告即报错
