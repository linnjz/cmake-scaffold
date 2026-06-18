# Conventional Commits 1.0.0[3]

## 结构

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## type 语义表

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

## 写法要领

- **标题行**：祈使句，动词开头（`add` 而非 `added`），不超过 50 个字符。  
  Git 官方文档也建议：第一行用一行简短（不超过 50 字符）文字概括变更，空行后接更详细的描述[4]。

- **正文**：写 **Why**，不写 **What**。diff 已经展示了 What；正文要回答“为什么现在改、为什么这么改、有什么权衡”，并关联 issue 号。

- **footer**：放 `BREAKING CHANGE: <说明>`、`Refs: #123` 等结构化信息，遵循 Git trailer 格式。

---

## 好的写法示例

```
示例1：
feat(parser): support array type annotations

Add support for parsing array type annotations
like ^string[], which previously raised a
syntax error. This unblocks the type checker
work in #247.

Refs: #247
```

```
示例2：
fix(login): reject empty password on submit

The client previously allowed empty passwords,
causing an extra round-trip to the server.
Validate locally before sending.
```

```
示例3：
perf(cache): reduce lock contention in hot path

The global lock serialized all cache reads.
Switch to per-shard locks; benchmark shows
~40% fewer stalls under concurrent load.
```

---

## 提示词

```
你是一位严格遵守 Conventional Commits 1.0.0 规范的提交信息写手。
请根据下面的 git diff 输出，生成一条 commit message，要求：

1. 第一行格式：type(scope): description
   - type 只能从 feat/fix/docs/refactor/perf/test/chore 中选择
   - description 用祈使句（如 "add" 而非 "added"），不超过 50 个字符
2. 空一行，正文说明“为什么”做这个改动（动机、约束、权衡），
   不要复述 diff 里的代码内容（那是 What，diff 自己已经写了）
3. 若存在破坏性变更，正文后加 footer：BREAKING CHANGE: <说明>
4. 严格基于 diff 内容，不虚构 diff 中不存在的信息
5. 只输出 commit message 本身，不要任何解释

<diff>
【粘贴 git diff --cached 的输出】
</diff>
```