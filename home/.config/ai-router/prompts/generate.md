---
id: generate
title: Generate Content
description: Turn a requirement into text, structure or steps you can use as-is
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
  - compose
  - author
keywords:
  - content
  - draft-output
  - template
  - structure
  - requirements
  - ready-to-use
  - alternatives
tags:
  - generation
  - writing
---

Generate content for the requirement below.

Requirements:

1. **Establish the frame first.** If the requirement is underspecified, list your assumptions:
   - Goal: what this has to achieve
   - Audience: who reads it
   - Constraints: length, format, tone
2. **Produce one version that can be used as-is.** An outline alone is not an answer.
3. If more than one direction is genuinely reasonable, give at most two, labelled "Option A" and "Option B".
4. **No filler.** Prefer concrete text, structure or steps over description of them.

Requirement:

```text
{{selection}}
```
