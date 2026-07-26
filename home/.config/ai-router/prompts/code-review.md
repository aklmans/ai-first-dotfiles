---
id: code-review
title: Code Review
description: Review a change for defects, risk and missing test coverage
category: coding
priority: 210
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - review
  - code-review
  - cr
  - review-code
  - inspect
  - critique
  - audit
keywords:
  - findings
  - regression
  - edge-cases
  - test-gaps
  - risk-review
  - severity
  - data-loss
tags:
  - coding
  - review
---

Review the content below as a code reviewer would.

Requirements:

1. Findings first, in this severity order:
   - **P0**: data loss, security holes, production outages
   - **P1**: behavioral regressions, unhandled edge cases, data compatibility
   - **P2**: incomplete error handling, missing test coverage
   - **P3**: readability and naming - only when it genuinely blocks understanding

2. Every finding carries:
   - Where it is (line number, function, file)
   - What is wrong
   - What it affects
   - How to fix it

3. No unrelated style opinions.
4. Close with a short summary, one or two sentences.

Output format:

## P0 Issues
- [location] what is wrong -> the fix

## P1 Issues
- ...

## Summary
Overall assessment and the main risk

Material:

```text
{{selection}}
```
