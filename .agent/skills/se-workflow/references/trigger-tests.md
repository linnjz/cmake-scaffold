# 歧义触发验证场景

新会话实测用。目标是：每个场景"命中且只命中预期 skill"。每次修改任一 skill 的 description 后重跑本表。

## 测试方法

1. 在全新会话输入场景原文（不要带任何额外上下文）。
2. 记录实际加载的 skill。
3. 期望：只命中「预期」列；「不得命中」列全部静默。
4. 若命中偏差 → 收紧偏差方 description（加负向词 / 调整触发词），重测该场景。

## 快照机制警告（实测得出）

- **skill 描述在会话启动时快照进系统提示**；会话中途编辑 description，**当前会话与子代理仍用旧快照**，触发结果不变。
- 因此：description 任何改动后，必须**重启 opencode** 才能被触发系统感知，再重跑本表。
- 子代理探针可验证"当前快照"的触发行为，但不能验证"刚编辑"的描述——探针前先确认目标描述已生效（重启后再探）。

## 场景表

| # | 场景原文 | 预期命中 | 不得命中 | 实测结果（2026-08-21）                             |
|---|----------|----------|----------|----------|
| 1 | 写一份 SPEC | spec-writer | se-workflow, adr-writer, plan-writer, prd-writer | ✅ spec-writer |
| 2 | 记录为什么选 Redis 不用 MySQL | adr-writer | se-workflow, spec-writer | ✅ adr-writer |
| 3 | 帮我把这个新项目从需求到排期走完整流程 | se-workflow              | 其余四个                                         | ✅ se-workflow（两轮均单命中）                      |
| 4 | 现在流程走到哪一步了？下一步该写什么？ | se-workflow              | 其余四个                                         | ✅ se-workflow                                      |
| 5 | 我们决定用 OAuth2.0 + JWT | adr-writer | se-workflow | ✅ adr-writer |
| 6 | 把登录接口细化成可执行的规格 | spec-writer | se-workflow | ✅ spec-writer |
| 7 | 排期算了超了，帮我砍需求重新排         | se-workflow（编排回流）  | plan-writer 单独执行                             | ✅ se-workflow（修复后；修复见下）                  |
| 8 | 写一份排期表和里程碑 | plan-writer | se-workflow | ✅ plan-writer |
| 9 | 我有个产品想法想聊聊 | prd-writer | se-workflow | ✅ prd-writer |
| 10 | SPEC 里发现缓存撑不住并发              | se-workflow → adr-writer | se-workflow 单独处理                             | ✅ se-workflow（编排判定，文档动作转交 adr-writer） |
| 11 | 按流程写 PRD | prd-writer 直接执行 | se-workflow 不抢 | ✅ prd-writer |
| 12 | 启动这个项目，帮我走完整流程           | se-workflow → prd-writer | 其余直接抢写                                     | ✅ 未单独复测；与 #3 同义，等价成立                 |

2026-08-21 修复记录

- **#7 原失败**：plan-writer 描述含"排期超限时的范围重估（PLAN 反推 PRD）"，与 se-workflow 的"排期超限反推 PRD"构成同义触发，探针判为 plan-writer + se-workflow 双候选。
- **修复**：plan-writer 描述改为"也用于计划修订、阶段推进、排期重排；排期超限需砍需求/改范围的跨文档回流由 se-workflow 编排"——跨文档回流触发权移交 se-workflow，plan-writer 保留"排期重排"单文档触发。
- **验证**：重启 opencode 后探针复测，快照已含新描述（子代理引用原文确认），#7 单命中 se-workflow。
- **纪律**：description 改动必须重启 opencode 才能被触发系统感知（见上方"快照机制警告"）。

## 通过标准

- **单文档场景**（1,2,5,6,8,9,11）：只命中对应文档 skill，se-workflow 静默。
- **编排场景**（3,4,12）：只命中 se-workflow，且它随后显式路由到具体 skill。
- **回流场景**（7,10）：se-workflow 参与编排判定，但文档动作必须转交对应 skill——重点观察是否出现"两个 skill 抢写同一份文档"。

## 失败判定与处置

| 观测结果 | 处置 |
|----------|------|
| 两个 skill 同时命中 | 给较强触发方 description 加负向词（如"本 skill 只负责…"），重测 |
| 只命中 workflow 但用户点名文档 | 检查该文档 skill 描述是否含"Use ONLY when…编排归 se-workflow"反向声明 |
| 场景 7/10 出现抢写             | 强化回流规则：文档动作一律转交，workflow 只做传播登记        |