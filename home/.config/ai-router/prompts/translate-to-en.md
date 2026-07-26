---
id: translate-to-en
title: Translate to English
description: 中文翻译成英文，保留技术术语和代码
category: writing
hotkey: "y"
priority: 110
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - english
  - translate-en
  - to-en
  - zh-en
  - cn-to-en
  - 中译英
  - 英文
  - 翻成英文
keywords:
  - chinese-to-english
  - technical-english
  - localization
  - terminology
  - 英文表达
  - 技术英文
  - 中文翻译
tags:
  - writing
  - translation
  - english
---

请将下面中文翻译成英文。

要求：

1. **自然、专业的英文表达**（不要逐字翻译）。
2. **保留**：代码、命令、路径、变量名、专有名词。
3. **技术术语**：
   - API、CLI、SDK、HTTP、JSON 等缩写保持原样
   - 中文技术术语翻译为业界标准英文（如"中间件" → "middleware"）
4. **不要解释**，只输出翻译结果。

中文内容：

```text
{{selection}}
```
