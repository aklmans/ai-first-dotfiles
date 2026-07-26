---
id: pr-description
title: Generate PR Description
description: Turn a change into a PR description with testing notes and risks
category: coding
priority: 240
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - pr
  - pull-request
  - pr-description
  - merge-request
  - mr
  - pr-body
  - changelog
keywords:
  - summary
  - changes
  - testing
  - risks
  - review-notes
  - deploy-notes
  - rollout
tags:
  - coding
  - git
  - pull-request
---

Write a PR description from the material below.

Structure:

## Summary
- One or two sentences: what this PR does and why

## Changes
- Main changes, grouped by file or module
- Say what changed in each - a bare file list is not a change log

## Testing
- How to verify this change (manual steps or automated tests)
- Which scenarios were covered (happy path plus edge cases)

## Risks
- Existing behavior this could affect
- Deployment steps that need attention
- Write "None" if there is genuinely no risk

Example:

## Summary
- Add rate limiting to `/api/users` endpoint to prevent abuse

## Changes
- `middleware/rate_limit.go`: new rate limiter (100 req/min per IP)
- `routes/users.go`: apply rate limit middleware
- `config/default.yaml`: add `rate_limit.enabled` flag

## Testing
- Manual: sent 150 requests in 1 min, got 429 after 100th
- Unit tests: `TestRateLimitMiddleware` covers edge cases
- Verified existing `/api/posts` endpoint unaffected

## Risks
- If Redis is down, rate limiting fails open (allows all requests)
- Need to monitor 429 error rate after deploy

Material:

```text
{{selection}}
```
