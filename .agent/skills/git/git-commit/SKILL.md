---
name: git-commit
description: 生成符合 Conventional Commits 1.0.0 规范的 Git 提交信息。根据 git diff 输出自动写出规范化的 commit message（type/scope/description + Why 正文 + BREAKING CHANGE footer），type 限定 feat/fix/docs/refactor/perf/test/chore。用于用户要求写 commit message、提交信息、commit 规范或 /git-commit 时。
---

------

# Conventional Commits 提交信息生成技能

## 规范依据

本技能严格按照 [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) 规范执行。

### 提交信息结构

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### type 语义表

| type     | 含义             | 对应 SemVer |
| -------- | ---------------- | ----------- |
| feat     | 引入新功能       | MINOR       |
| fix      | 修复 bug         | PATCH       |
| docs     | 只改文档         | 无          |
| refactor | 重构，不改行为   | 无          |
| perf     | 性能优化         | 无          |
| test     | 测试相关         | 无          |
| chore    | 构建、工具等杂项 | 无          |

**BREAKING CHANGE**（破坏性变更）在 footer 中声明，或在 type 后加 `!`，对应 MAJOR 版本号。  
`scope` 用括号放在 type 后，指明影响范围，如 `feat(parser)`。

### 写法要领

- **标题行**：祈使句，动词开头（`add` 而非 `added`），不超过 50 个字符。  
  Git 官方文档也建议：第一行用一行简短（不超过 50 字符）文字概括变更，空行后接更详细的描述。

- **正文**：写 **Why**，不写 **What**。diff 已经展示了 What；正文要回答“为什么现在改、为什么这么改、有什么权衡”，并关联 issue 号。

- **footer**：放 `BREAKING CHANGE: <说明>`、`Refs: #123` 等结构化信息，遵循 Git trailer 格式。

---

## 优秀示例

示例1：

```
feat(parser): support array type annotations

Add support for parsing array type annotations
like ^string[], which previously raised a
syntax error. This unblocks the type checker
work in #247.

Refs: #247
```
示例2：

```
fix(login): reject empty password on submit

The client previously allowed empty passwords,
causing an extra round-trip to the server.
Validate locally before sending.
```
示例3：

```
perf(cache): reduce lock contention in hot path

The global lock serialized all cache reads.
Switch to per-shard locks; benchmark shows
~40% fewer stalls under concurrent load.
```

---

## 执行指令

当用户提供 `git diff --cached` 的输出时，请严格按以下步骤生成 commit message：

1. **分析 diff**：识别变更类型（新增功能、修复、重构等），判断是否有破坏性变更（如 API 签名改变、删除公共函数等）。
2. **确定 type**：从 `feat/fix/docs/refactor/perf/test/chore` 中选择最匹配的一项。
3. **确定 scope（可选）**：如果变更影响特定模块/组件，用括号包裹，如 `(parser)`。
4. **撰写标题行**：用祈使句动词开头，简洁概括（不超过 50 字符）。
5. **撰写正文**：说明**为什么**做这个改动（动机、约束、权衡、关联 issue），绝不复述 diff 中的代码细节（那是 What，diff 已展示）。
6. **添加 footer**：如有破坏性变更，添加 `BREAKING CHANGE: <说明>`；如有关联 issue，添加 `Refs: #123` 等。
7. **仅输出最终 commit message**，不要任何额外解释、分析或问候语。

### 输出格式

```text
<type>(<scope>): <description>

<body>

<footer>
```

如果无 body 或 footer，可省略对应部分，但标题与 body 之间必须保留空行（当 body 存在时）。

---

## 约束条件

- 严格基于 diff 内容，不虚构 diff 中不存在的信息。
- 不输出除 commit message 以外的任何内容（包括“这是您生成的提交信息”等）。
- 若 diff 为空，提示“无变更可提交”并停止。

---

## 触发方式

用户粘贴 `git diff --cached` 的输出后，本技能自动激活，生成符合规范的提交信息。