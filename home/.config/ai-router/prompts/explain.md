---
id: explain
title: Explain Selection
description: Explain text, code, config or an error, and say what to do next
category: reading
hotkey: e
priority: 40
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - explain
  - describe
  - why
  - understand
  - meaning
  - what-is-this
  - walkthrough
keywords:
  - code-explain
  - error-explain
  - config-explain
  - mechanism
  - next-step
  - side-effects
  - rationale
tags:
  - reading
  - debugging
  - coding
---

Explain the content below.

Requirements:

1. **Say what it is first** - one line identifying the kind of thing: code, config, error output or prose.
2. **Explain the mechanism**:
   - Code: inputs, outputs, side effects, latent risks
   - Config: what each key does and its default
   - Error: most likely causes ranked by probability, plus how to investigate each
3. **Give the background**: why it is built this way, or why it went wrong.
4. **Say what to do next**: 1-3 concrete actions - a command, a thing to check, a change to make.

Frontmost app: {{frontmost_app}}
Window title: {{window_title}}

Content:

```text
{{selection}}
```
