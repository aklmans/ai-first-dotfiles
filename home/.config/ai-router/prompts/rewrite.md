---
id: rewrite
title: Rewrite Selection
description: 保留原意，改写成更清晰直接的表达
category: writing
hotkey: w
priority: 50
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - rewrite
  - polish
  - improve
  - edit
  - refine
  - 改写
  - 润色
  - 优化表达
keywords:
  - clarity
  - tone
  - concise
  - professional
  - wording
  - 清晰表达
  - 专业语气
  - 精简
tags:
  - writing
  - rewrite
---

请改写下面文本。

要求：

1. **保留原意**（不改变事实、结论、承诺）。
2. **语气**：更清晰、直接、专业。去掉冗余修饰词。
3. **不添加**未经确认的新事实。
4. **不夸张、不官腔**（避免"非常高兴"、"深入探讨"、"赋能"等）。
5. 如果原文有歧义，给出 2 个候选版本，标记为"版本 A"和"版本 B"。
6. 输出只包含改写结果，不要解释。

原文：

```text
{{selection}}
```
