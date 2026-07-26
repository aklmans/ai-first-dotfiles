---
id: optimize-prompt
title: Optimize Prompt
description: Sharpen an AI prompt - clearer instructions, harder constraints, more stable output
category: prompt-engineering
hotkey: "="
priority: 120
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - prompt
  - enhance-prompt
  - optimize
  - prompt-engineering
  - improve-prompt
  - tighten-prompt
  - rewrite-prompt
keywords:
  - system-prompt
  - instruction
  - constraints
  - output-format
  - few-shot
  - guardrails
  - determinism
tags:
  - prompt-engineering
  - optimization
---

Optimize the AI prompt below.

Requirements:

1. **Harden the constraints**:
   - Rule out the usual failure modes explicitly: hype, invented facts, empty filler
   - Define the output format as a structured template
   - Bound the length or the scope

2. **Sharpen the instructions**:
   - Make the task boundary explicit: what to do, and what not to do
   - Rank the requirements when there is more than one
   - Bold the load-bearing instructions

3. **Add examples** when the task is complex:
   - One or two few-shot examples
   - Format: input -> output

4. **Output the optimized prompt only.** Do not explain what you changed.

Original prompt:

```text
{{selection}}
```
