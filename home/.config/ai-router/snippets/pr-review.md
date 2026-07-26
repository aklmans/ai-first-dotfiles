---
id: pr-review
title: PR Review
description: Code review template that leads with regressions, edge cases and test gaps
category: coding
priority: 360
aliases:
  - pr
  - review
  - code-review
  - pr-feedback
  - diff-review
keywords:
  - findings
  - regression
  - edge-cases
  - error-handling
  - tests
  - compatibility
  - severity
tags:
  - snippet
  - coding
  - review
---

# PR Review

Review the change or description below as a code reviewer would.

Focus on:

1. Behavioral regressions.
2. Edge cases.
3. Data compatibility.
4. Error handling.
5. Test gaps.

Material:

```text
{{selection}}
```

Output format:

- Findings first, ordered by severity.
- Every finding names a location or a verifiable clue.
- End with a short summary and nothing more.
