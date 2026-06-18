---
name: data-storytelling
description: 数据汇报模式。把数据讲成故事：叙事框架、可视化技巧、汇报模板。
---

# 数据汇报 (Data Storytelling)

向利益相关者展示分析、写数据报告、做高管/投资人汇报时使用。

## 叙事弧线

```
1. Hook: 用反直觉的洞察抓住注意力
2. Context: 建立基线
3. Rising Action: 用数据点推进
4. Climax: 关键洞察
5. Resolution: 建议
6. Call to Action: 下一步
```

### 三支柱

| 支柱 | 用途 | 组成 |
|---|---|---|
| **数据** | 证据 | 数字、趋势、对比 |
| **叙事** | 意义 | 语境、因果、含义 |
| **可视化** | 清晰 | 图表、图示、强调 |

## 框架

### 框架 1：问题—解决型

```
# 客户流失分析
## The Hook        "我们正因可预防的流失每年损失 $2.4M"
## The Context     - 流失率 8.5%（行业均值 5%）
                  - 平均客户终身价值 $4,800
## The Problem     73% 在前 90 天流失；共性：< 3 次支持互动
## The Insight     [可视化] 前 14 天未互动的客户流失概率高 4 倍
## The Solution    1. 14 天引导序列 2. 第 7 天主动触达 3. 功能采用追踪
## Expected Impact 减少早期流失 40%，年省 $960K
## Call to Action  批准 $50K 自动化预算
```

### 框架 2：趋势型

```
# Q4 表现分析
## Where We Started    Q3 以 $1.2M MRR 结束，低于目标 15%
## What Changed        [时间线] 10 月自助定价 / 11 月降低注册摩擦 / 12 月成功电话
## The Transformation  [前后对比表] 试用→付费 8%→15%；见效时间 14→5 天
## Key Insight         自助 + 高接触创造复合增长
## Going Forward       目标 Q2 达 $1.8M MRR
```

### 框架 3：对比型

```
# 市场机会分析
## The Question      先扩 EMEA 还是 APAC？
## The Comparison    [并排分析] EMEA: $4.2B, 8%, 高竞争, 复杂监管
                    APAC: $3.8B, 15%, 中等竞争, 监管多样
## The Analysis      [加权评分矩阵] 增长 30%、市场 25%、难度 25%、竞争 20%
## The Recommendation APAC 优先（新加坡起步）
## Risk Mitigation   时区支持/本地伙伴/多币种
```

## 可视化技巧

- **渐进揭示**：从简单开始逐层加信息——先"收入在增长"，再加"但增速放缓"，再加"由一个细分驱动"，最后"该细分正趋于饱和"。
- **对比并置**：before/after、this/that 强调差异。
- **标注与高亮**：用 `annotate` 标注关键事件、`axvspan` 高亮区间、`axhline` 画阈值线（Python/matplotlib 示例）。

## 汇报模板

### 高管摘要页

```
┌──────────────────────────────────────────────┐
│ KEY INSIGHT                                    │
│ "第 1 周完成引导的客户终身价值高 3 倍"          │
├──────────────────────┬───────────────────────┤
│ THE DATA             │ THE IMPLICATION        │
│ 第 1 周完成: LTV $4.5K │ ✓ 优先引导 UX           │
│ 其他: LTV $1.5K       │ ✓ 投资 $75K, ROI 8x     │
└──────────────────────┴───────────────────────┘
```

### 数据故事流程（7 页）

```
1 THE HEADLINE  → 2 THE CONTEXT → 3 THE DISCOVERY → 4 THE DEEP DIVE
→ 5 THE RECOMMENDATION → 6 THE IMPACT → 7 THE ASK
```

### 一页仪表盘故事

```
# 月度经营回顾
## THE HEADLINE        收入 +15% 但 CAC 增速快于 LTV
## KEY METRICS         四项核心指标一眼看齐（MRR/NRR/CAC/LTV）
## WHAT'S WORKING      企业细分 +25% MoM；推荐计划占 30% 新客户
## WHAT NEEDS ATTENTION SMB 获客成本 +40%；试用转化 -5 点
## ROOT CAUSE          [迷你图] SMB 付费广告效率下降：CPC +35% 而转化持平
## RECOMMENDATION      1. $20K/月从付费转向内容 2. 推 SMB 自助试用 3. A/B 缩短引导
## NEXT MONTH'S FOCUS  内容营销试点 / 自助 MVP / 见效时间 < 7 天
```

## 写作技巧

- **标题公式**：`[具体数字] + [商业影响] + [可行动语境]`。例："Q4 销售超目标 23%——原因在此"优于"Q4 销售分析"。
- **过渡短语**：推进叙事（"这引我们发问…""深入下去…""对比来看…"）、引入洞察（"数据显示…""让我们惊讶的是…""关键发现是…"）、转向行动（"这一洞察表明…""基于此分析…""结论不言自明…"）。
- **处理不确定性**：承认局限（"95% 置信度下…""相关性强但因果需…"）、给出区间（"$400K–$600K""最佳情况 X，保守 Y"）。

## 最佳实践

**Do：** 以"so what"开头、用规则三、展示而非告知、连接受众目标、以行动收尾。
**Don't：** 数据倾倒（狠心策展）、埋没洞察（前置关键发现）、堆术语（匹配受众词汇）、先摆方法论（先语境后方法）、忘掉叙事（数字需要意义）。

## 参考资源

- [Storytelling with Data (Cole Nussbaumer)](https://www.storytellingwithdata.com/)
- [The Pyramid Principle (Barbara Minto)](https://www.amazon.com/Pyramid-Principle-Logic-Writing-Thinking/dp/0273710516)
- [Resonate (Nancy Duarte)](https://www.duarte.com/resonate/)