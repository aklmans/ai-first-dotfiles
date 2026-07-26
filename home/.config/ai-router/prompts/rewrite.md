---
id: rewrite
title: Rewrite Selection
description: Keep the meaning, rewrite it clearer and more direct
category: writing
hotkey: w
priority: 50
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - rewrite
  - polish
  - improve
  - edit
  - refine
  - tighten
  - clarify
keywords:
  - clarity
  - tone
  - concise
  - professional
  - wording
  - plain-language
  - de-jargon
tags:
  - writing
  - rewrite
---

Rewrite the text below.

Requirements:

1. **Keep the meaning.** Do not change facts, conclusions or commitments.
2. **Tone**: clearer, more direct, professional. Cut filler modifiers.
3. **Add nothing** that is not already established in the text.
4. **No hype, no corporate voice** (avoid "delighted to", "deep dive", "empower", "leverage").
5. If the original is genuinely ambiguous, give two candidates labelled "Version A" and "Version B".
6. Output the rewrite only. No commentary.

Original:

```text
{{selection}}
```
