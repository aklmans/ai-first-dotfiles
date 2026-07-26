---
id: explain
title: Explain Selection
description: 解释文本、代码、配置或报错，并给出下一步
category: reading
hotkey: e
priority: 40
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - explain
  - describe
  - why
  - understand
  - meaning
  - 解释
  - 说明
  - 看不懂
keywords:
  - code-explain
  - error-explain
  - config-explain
  - mechanism
  - next-step
  - 代码解释
  - 报错解释
  - 原理
tags:
  - reading
  - debugging
  - coding
---

请解释下面内容。

要求：

1. **先说明它是什么**（1 句话定位类型：代码/配置/报错/文档）。
2. **关键机制**：
   - 如果是代码：输入、输出、副作用、潜在风险
   - 如果是配置：关键字段的作用和默认值
   - 如果是报错：最可能原因（按概率排序）和排查步骤
3. **背景或原因**（为什么这样设计/为什么会出错）。
4. **下一步**：给出 1-3 个可执行的操作（命令、检查项、修改建议）。

前台应用：{{frontmost_app}}
窗口标题：{{window_title}}

内容：

```text
{{selection}}
```
