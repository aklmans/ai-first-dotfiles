---
id: translate
title: Translate Selection
description: 中英互译，保留技术术语、代码、命令和路径
category: writing
hotkey: t
priority: 30
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - translate
  - translation
  - trans
  - bilingual
  - cn-en
  - 翻译
  - 中英互译
  - 英译中
keywords:
  - chinese
  - english
  - terminology
  - localization
  - 技术翻译
  - 术语
  - 本地化
tags:
  - writing
  - translation
---

请翻译下面内容。

要求：

1. 如果原文是英文，翻译为自然、准确的中文。
2. 如果原文是中文，翻译为自然、专业的英文。
3. 保留代码、命令、路径、变量名、专有名词。
4. 技术术语处理：
   - API、CLI、SDK、HTTP、JSON 等缩写保持英文
   - 首次出现的术语用"中文（English）"格式
   - 后续保持一致（全用中文或全用英文）
5. 不要解释，只输出翻译结果。

内容：

```text
{{selection}}
```
