---
id: fix
title: Fix Selection
description: Fix text, formatting or small localized code problems
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
  - proofread
  - lint
keywords:
  - spelling
  - punctuation
  - formatting
  - syntax
  - small-fix
  - typos
  - indentation
tags:
  - writing
  - coding
  - fix
---

Fix the content below.

Requirements:

1. **Prose**: fix typos, grammar, punctuation and formatting. Preserve the meaning.
2. **Code**: fix only obvious syntax errors, misspellings, indentation and unclosed brackets.
3. **Do not fix**: logic bugs, performance problems or security holes - those need more context than a selection.
4. If you spot a serious problem you are not confident fixing, append `<!-- Note: found X but did not fix it -->` after the output.
5. Output the fixed content only. No commentary.

Content:

```text
{{selection}}
```
