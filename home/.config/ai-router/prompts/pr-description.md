---
id: pr-description
title: Generate PR Description
description: 根据改动生成 PR 描述、测试说明和风险
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
  - PR描述
  - 合并请求
  - PR说明
keywords:
  - summary
  - changes
  - testing
  - risks
  - review-notes
  - 改动说明
  - 测试说明
  - 风险说明
tags:
  - coding
  - git
  - pull-request
---

请根据下面材料生成 PR 描述。

输出结构：

## Summary
- 1-2 句话说明这个 PR 做了什么和为什么

## Changes
- 按文件或模块列出主要改动
- 每条说明改了什么，不要只列文件名

## Testing
- 如何验证这个改动（手动测试步骤或自动化测试）
- 测试了哪些场景（正常路径 + 边界条件）

## Risks
- 可能影响的现有功能
- 需要特别注意的部署步骤
- 如果无风险，写"None"

示例：

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

材料：

```text
{{selection}}
```
