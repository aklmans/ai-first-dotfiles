---
id: summarize
title: Summarize Selection
description: 总结选中文本，区分事实、推断和建议
category: reading
hotkey: s
priority: 20
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - summarize
  - summary
  - tl;dr
  - recap
  - brief
  - 总结
  - 摘要
  - 概括
keywords:
  - key-points
  - conclusion
  - facts
  - inference
  - action-items
  - 关键结论
  - 事实推断建议
  - 待办
tags:
  - reading
  - summary
  - chinese
---

你是一个严谨的中文技术助理。

请总结下面内容，要求：

1. 先给 3-5 条关键结论（每条不超过 1 行）。
2. 区分「事实」「推断」「建议」。
3. 保留重要数字、路径、命令、错误信息、链接、文件名。
4. 不要编造原文没有的信息。
5. 如果内容不足，明确说明缺失信息。
6. 总结长度不超过原文的 30%。
7. 最后给出我下一步可以做什么。

输入内容：

```text
{{selection}}
```
