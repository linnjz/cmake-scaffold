---
name: git-setup-pre-commit
description: 为仓库搭建 pre-commit 钩子（format/lint/typecheck/test）并生成 GitHub Actions CI。自动检测 JS/TS、Python、Java、C/C++、.NET、Rust 项目语言，选择对应 runner（纯 Node 用 Husky、纯 Python 用 pre-commit 框架、其余或混合语言用 lefthook），并生成匹配的 .github/workflows/ci.yml。用于用户要求添加 pre-commit 钩子、配置 Husky/lefthook/pre-commit、lint-staged、提交时格式化/类型检查/测试，或为任意语言项目配置 CI/CD 自动化时。
---

# 搭建 Pre-Commit 钩子 + CI

## 1. 检测语言

在仓库根目录 Glob 各清单文件，每命中一个就增加一种语言：

| 清单文件 | 语言 |
|---|---|
| `package.json` | JS/TS |
| `pyproject.toml`, `requirements.txt`, `Pipfile`, `setup.py`, `poetry.lock`, `uv.lock` | Python |
| `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle(.kts)` | Java |
| `Cargo.toml` | Rust |
| `*.sln`, `*.csproj`, `Directory.Build.props`, `global.json` | .NET |
| `CMakeLists.txt`, `Makefile`, `*.vcxproj` | C/C++ |

一个都没命中 → 停下来问用户这个仓库属于哪个技术栈。

## 2. 选择钩子运行器

- 只有 JS/TS → **Husky**（`npx husky init`）
- 只有 Python → **pre-commit 框架**（`pipx install pre-commit` 或 `uv tool install pre-commit`）
- 其他情况（C/C++、Java、Rust、.NET 或任何多语言混合）→ **lefthook**（一份 YAML 配置，语言无关）。只要 Node 不是唯一技术栈，就优先用 lefthook 而非 Husky。

## 3. 每种语言选择工具链

从 [REFERENCE.md](./references/REFERENCE.md) 的矩阵中，为检测到的每种语言挑选 formatter + linter + typechecker + test 命令。规则：

- **复用已有配置**——绝不覆盖仓库已有的 `.prettierrc`、`[tool.ruff]`、`.clang-format`、`.eslintrc` 等，根据仓库现状适配命令（如 build 目录、包管理器）。
- 至少运行 **format + lint + test**；只有该语言有 typechecker 时才加 typecheck。
- 仓库没有的命令就省略（没有 `test` 脚本、没有 typechecker 等），并告知用户。

## 4. 编写钩子配置

- Husky → `.husky/pre-commit` + `.lintstagedrc` + `.prettierrc`（仅当缺失时）
- pre-commit → `.pre-commit-config.yaml` + `pre-commit install`
- lefthook → `.lefthook.yml` + `lefthook install`

用机器上可用的方式安装运行器（npm / winget / scoop / brew / go install / 直接下载二进制）。具体内容见 REFERENCE.md。

## 5. 生成 GitHub Actions CI

创建 `.github/workflows/ci.yml`，为每种检测到的语言生成一个 job，运行与本地钩子**相同**的 format/lint/typecheck/test 步骤。使用 `actions/checkout@v4`、合适的 `actions/setup-*` / `dtolnay/rust-toolchain`，并按 REFERENCE.md 中每种语言的模板。删掉不适用于该仓库的步骤。

## 6. 验证

- [ ] 钩子文件存在（`.husky/pre-commit`、`.pre-commit-config.yaml` 或 `.lefthook.yml`）
- [ ] 已有的 formatter/linter 配置未被改动
- [ ] 运行器已安装（`husky init`、`pre-commit install` 或 `lefthook install`）
- [ ] 试运行钩子：`npx lint-staged`、`pre-commit run --all-files` 或 `lefthook run pre-commit`
- [ ] 可选冒烟测试：做一次无意义的小提交来触发钩子

## 7. 提交

暂存改动的文件，用 **Conventional Commits** 消息提交，例如：

```
chore(hooks): add pre-commit hooks (<runner>) + CI workflow
```

若需要更严格的格式合规，将 diff 交给 `git-commit` 技能处理。

## 进阶

完整工具链矩阵、钩子文件内容与 CI job 模板：[REFERENCE.md](REFERENCE.md)
