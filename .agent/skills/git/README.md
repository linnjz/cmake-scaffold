# Git 技能集

本目录下三个 Git 相关技能，作用互不重叠，可独立使用：

| 技能 | 作用 |
| --- | --- |
| [git-commit](git-commit/SKILL.md) | 根据 `git diff` 生成符合 **Conventional Commits 1.0.0** 规范的 commit message（type/scope/body/footer），仅产出文本，不执行 git 命令。 |
| [git-setup-pre-commit](git-setup-pre-commit/SKILL.md) | 为仓库**搭建 pre-commit 钩子 + GitHub Actions CI**：自动检测语言、选 runner（Husky/pre-commit/lefthook）、生成配置，最后以 Conventional Commits 消息提交。 |
