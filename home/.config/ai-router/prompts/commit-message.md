---
id: commit-message
title: Generate Commit Message
description: Turn a diff into a short conventional commit message
category: coding
priority: 220
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - commit
  - commit-message
  - git-message
  - conventional-commit
  - git-commit
  - commit-msg
  - changelog-entry
keywords:
  - changelog
  - diff-summary
  - conventional
  - type-scope-subject
  - git
  - subject-line
  - commit-body
tags:
  - coding
  - git
---

Write a commit message for the change below.

Requirements:

1. Write it in English.
2. Subject under 72 characters, in the form `type(scope): subject`.
3. Body explains why and what, wrapped at 80 characters.
4. No hype, no marketing voice.

Examples:

**Change**: added authentication middleware, fixed the redirect after session expiry
**Output**:
```
fix(auth): redirect to login on expired session

Previously users saw a 401 error page. Now they're
redirected to /login with a flash message explaining
the session expired.
```

**Change**: refactored config parsing, extracted a shared helper
**Output**:
```
refactor(config): extract parse_frontmatter helper

Reduces duplication across 3 files. No behavior change.
```

Change:

```text
{{selection}}
```
