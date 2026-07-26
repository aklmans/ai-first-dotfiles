---
id: translate-to-en
title: Translate to English
description: Translate into English, keeping technical terminology and code intact
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
  - into-english
  - anglicize
keywords:
  - technical-english
  - localization
  - terminology
  - idiomatic
  - native-english
  - jargon
  - rewrite-in-english
tags:
  - writing
  - translation
  - english
---

Translate the content below into English.

Requirements:

1. **Idiomatic, professional English.** Translate the meaning, not the words.
2. **Preserve** code, commands, paths, variable names and proper nouns exactly as written.
3. **Terminology**:
   - Keep acronyms such as API, CLI, SDK, HTTP and JSON as they are.
   - Map technical jargon to the standard industry term, not a literal gloss (an "intermediate layer" between services is *middleware*).
4. Output the translation only. No commentary.

Content:

```text
{{selection}}
```
