---
id: commit-message
title: Generate Commit Message
description: 根据改动生成简洁英文 commit message
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
  - 提交信息
  - commit-msg
  - 提交说明
keywords:
  - changelog
  - diff-summary
  - conventional
  - type-scope-subject
  - git
  - 变更摘要
  - 提交标题
  - 英文提交
tags:
  - coding
  - git
---

请根据下面改动生成提交信息。

要求：

1. 使用英文。
2. 标题不超过 72 字符，格式：`type(scope): subject`
3. body 简明说明 why 和 what，每行不超过 80 字符。
4. 不要夸张，不要营销语气。

示例：

**改动**：添加了用户认证中间件，修复了 session 过期后的重定向问题
**输出**：
```
fix(auth): redirect to login on expired session

Previously users saw a 401 error page. Now they're
redirected to /login with a flash message explaining
the session expired.
```

**改动**：重构了配置文件解析逻辑，提取了公共函数
**输出**：
```
refactor(config): extract parse_frontmatter helper

Reduces duplication across 3 files. No behavior change.
```

改动：

```text
{{selection}}
```
