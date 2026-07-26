---
id: optimize-prompt
title: Optimize Prompt
description: 优化 AI prompt，提升清晰度、约束性和输出稳定性
category: prompt-engineering
hotkey: "="
priority: 120
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - prompt
  - enhance-prompt
  - optimize
  - prompt-engineering
  - improve-prompt
  - 提示词
  - 提示词增强
  - 优化提示词
keywords:
  - system-prompt
  - instruction
  - constraints
  - output-format
  - few-shot
  - 约束
  - 输出格式
  - 指令优化
tags:
  - prompt-engineering
  - optimization
---

请优化下面的 AI prompt。

要求：

1. **增强约束性**：
   - 明确禁止 AI 常见坏习惯（夸张、编造、空话）
   - 定义输出格式（用结构化模板）
   - 限制长度或范围

2. **提升清晰度**：
   - 任务边界明确（做什么 / 不做什么）
   - 优先级清晰（如果有多个要求）
   - 用加粗标记关键指令

3. **添加示例**（如果任务复杂）：
   - 给 1-2 个 Few-Shot 示例
   - 格式：输入 → 输出

4. **输出优化后的 prompt**，不要解释改了什么。

原 prompt：

```text
{{selection}}
```
