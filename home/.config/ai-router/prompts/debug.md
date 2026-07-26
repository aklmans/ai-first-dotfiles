---
id: debug
title: Debug Issue
description: Work a bug systematically - hypotheses, how to check each, how to verify the fix
category: coding
priority: 230
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - debug
  - bug
  - troubleshoot
  - diagnose
  - root-cause
  - investigate
  - triage
keywords:
  - issue-analysis
  - repro
  - hypothesis
  - verification
  - fix-plan
  - minimal-repro
  - missing-info
tags:
  - debugging
  - coding
---

Help me debug this.

Output format:

## Analysis
- **Observed**: what actually happens
- **Expected**: what should happen
- **Delta**: the part that differs

## Likely causes (ranked by probability)
1. **[70%] Cause A**
   - How to check: the exact command or inspection step
   - If it is this, the fix is: ...

2. **[20%] Cause B**
   - How to check: ...
   - If it is this, the fix is: ...

3. **[10%] Cause C**
   - ...

## Minimal reproduction
1. Preconditions (environment, data state)
2. Steps
3. Observed failure

## Information I still need (if the material is not enough)
- [ ] Log file path
- [ ] Environment variables
- [ ] ...

Frontmost app: {{frontmost_app}}
Date: {{date}}

Problem:

```text
{{selection}}
```
