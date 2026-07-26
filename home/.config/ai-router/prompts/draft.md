---
id: draft
title: Draft Message
description: 根据材料起草邮件、IM、文档、评论或计划
category: writing
hotkey: d
priority: 100
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - draft
  - compose
  - message
  - email
  - reply
  - 起草
  - 草稿
  - 写消息
keywords:
  - email-draft
  - im-message
  - comment
  - plan
  - action-items
  - 邮件
  - 即时消息
  - 回复
tags:
  - writing
  - draft
---

请基于下面材料起草一份可直接发送或继续编辑的内容。

要求：

1. **先判断最合适的文体**：邮件、IM、文档、评论、计划或说明。
2. **语气**：直接、清楚、不过度客套（避免"希望这封邮件找到你时一切安好"等）。
3. **行动项**：如果有，明确负责人、时间和下一步。
4. **输出正文**，不要写"以下是草稿"等多余解释。

材料：

```text
{{selection}}
```
