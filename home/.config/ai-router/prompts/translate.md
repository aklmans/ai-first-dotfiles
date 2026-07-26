---
id: translate
title: Translate Selection
description: Two-way translation between English and Chinese, preserving technical terms, code, commands and paths
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
  - en-zh
  - zh-en
keywords:
  - chinese
  - english
  - terminology
  - localization
  - technical-translation
  - glossary
  - bidirectional
tags:
  - writing
  - translation
---

Translate the content below.

Requirements:

1. If the input is English, translate it into natural, professional Chinese.
2. If the input is in any other language, translate it into natural, accurate English.
3. Preserve code, commands, paths, variable names and proper nouns exactly as written.
4. Terminology:
   - Keep acronyms such as API, CLI, SDK, HTTP and JSON in English.
   - On first use of a translated technical term, give it as `translation (Original)`.
   - Stay consistent afterwards - do not alternate between the two forms.
5. Output the translation only. No commentary.

Content:

```text
{{selection}}
```
