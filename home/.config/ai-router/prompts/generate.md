---
id: generate
title: Generate Content
description: 基于需求生成可直接使用的文本、结构或步骤
category: writing
hotkey: g
priority: 90
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - generate
  - create
  - write
  - make
  - produce
  - 生成
  - 创作
  - 写作
keywords:
  - content
  - draft-output
  - template
  - structure
  - requirements
  - 内容生成
  - 结构生成
  - 可直接使用
tags:
  - generation
  - writing
---

请基于下面需求生成内容。

要求：

1. **先确认**（如果需求不明确，列出假设）：
   - 目标：要达成什么
   - 受众：给谁看
   - 约束：长度、格式、语气限制
2. **给出一个可直接使用的版本**（不要只给大纲）。
3. 如果有多种合理方向，最多给 2 个备选，标记为"方案 A"和"方案 B"。
4. **避免空话**，优先给具体文本、结构或步骤。

需求：

```text
{{selection}}
```
