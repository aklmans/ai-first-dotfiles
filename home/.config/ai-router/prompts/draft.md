---
id: draft
title: Draft Message
description: Draft an email, chat message, doc, comment or plan from the material
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
  - dm
  - write-back
keywords:
  - email-draft
  - im-message
  - comment
  - plan
  - action-items
  - follow-up
  - announcement
tags:
  - writing
  - draft
---

Draft something from the material below that I can send as-is or keep editing.

Requirements:

1. **Pick the right form first**: email, chat message, doc, comment, plan or status note.
2. **Tone**: direct and clear, not over-polite (skip "I hope this email finds you well").
3. **Action items**: if there are any, name the owner, the date and the next step.
4. **Output the message body only.** No "here is a draft" preamble.

Material:

```text
{{selection}}
```
