---
name: tech-article
description: IT 技术文章 / 教程 / 最佳实践 / 技术对比评测的事实核查（默认领域）
---

# 领域配置：IT 技术文章

## 验证对象

技术文章、教程、操作指南、最佳实践文档、技术博客、技术对比评测中的可核查事实：命令、参数、API 行为、版本号、性能数据、架构结论。

## 触发示例

- "验证这篇文章" / "核查技术文章" / "帮我审稿"
- 未指定领域时的默认值

## 断言分类体系

| 类别 | 说明 | 示例问题 |
|------|------|---------|
| `Fact` | 可验证的技术事实：行为、特性、参数、数值、默认值 | "文章称 K8s HPA 默认每 15 秒同步一次 metrics，是否准确？" |
| `Version` | 版本相关：特性引入/废弃/GA、API 版本变化 | "该行为在 Kubernetes 1.32 中是否已废弃？1.35 中是否有替代方案？" |
| `CommandConfig` | 命令语法、参数名、配置文件格式、YAML/JSON 结构 | "文章中的 `kubectl rollout undo` 命令参数是否正确？" |
| `BestPractice` | 官方/社区推荐做法、架构模式 | "'生产环境禁用 Swap' 在 2026 年是否仍然是 Linux 上的硬性要求？" |
| `Claim` | 性能基准数据、产品对比结论、量化声明 | "文章声称 xxx-benchmark 测试中 A 比 B 吞吐量高 40%，该数据是否有可查证来源？" |
| `Gap` | 遗漏关键信息：前提条件、兼容性限制、安全风险 | "部署 K8s 集群的步骤是否遗漏了 CNI 插件的安装前提？" |

## 权威来源白名单（按优先级）

1. 项目官方文档 / 官方网站（kubernetes.io、docs.docker.com、nodejs.org/docs）
2. GitHub 官方仓库源码（Release Notes、CHANGELOG、官方 Issue 中维护者回复）
3. 权威技术站点（Wikipedia、ArchWiki、MDN Web Docs、IETF RFC、API Reference）
4. 高质量社区讨论（Stack Overflow >50 票、GitHub Issue 社区共识）—— 仅作交叉参考

## 绝对禁止引用

- CSDN（csdn.net）、掘金（juejin.cn）、博客园（cnblogs.com）、51CTO（51cto.com）、摩天轮
- 任何 .cn 域名的技术博客/论坛（官方 .cn 如 cncf.cn 除外）
- 个人博客（Medium 个人账号、dev.to、自建博客）—— 除非是**项目维护者的官方博客**（可通过 GitHub 身份确认）

## 搜索偏好

- **语言**：优先英文搜索；除非问题明确是中文案例/中文资料
- **时效**：以最新稳定版为准；版本冲突时标注差异
- **关键词策略**：技术关键词精确组合。例：核查 "K8s HPA sync period 15s" 搜 `kubernetes HPA horizontal pod autoscaler sync period default`

## 修复策略备注

- 命令/配置类错误直接替换；版本变更类用 `[!版本更新]` callout
- 性能/基准数据必须给出可查证来源，否则标 ❓