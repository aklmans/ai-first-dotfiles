---
id: fix
title: Fix Selection
description: 修复文本、格式或小范围代码问题
category: editing
hotkey: f
priority: 60
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - fix
  - correct
  - repair
  - grammar
  - typo
  - 修复
  - 纠错
  - 改错
keywords:
  - spelling
  - punctuation
  - formatting
  - syntax
  - small-fix
  - 错别字
  - 标点
  - 格式修复
tags:
  - writing
  - coding
  - fix
---

请修复下面内容。

要求：

1. **文本**：修复错别字、语法、标点、格式问题。保留原意。
2. **代码**：只修复明显的语法错误、拼写错误、缩进问题、未闭合括号。
3. **不修复**：逻辑 bug、性能问题、安全漏洞（这些需要更多上下文）。
4. 如果发现严重问题但不确定如何修，在输出后用 `<!-- 注意：发现 X 问题但未修复 -->` 说明。
5. 输出修复后的内容，不要额外解释。

内容：

```text
{{selection}}
```
