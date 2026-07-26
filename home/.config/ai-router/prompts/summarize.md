---
id: summarize
title: Summarize Selection
description: Summarize the selection and separate facts from inferences and recommendations
category: reading
hotkey: s
priority: 20
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - summarize
  - summary
  - tl;dr
  - recap
  - brief
  - digest
  - condense
keywords:
  - key-points
  - conclusion
  - facts
  - inference
  - action-items
  - takeaways
  - next-step
tags:
  - reading
  - summary
---

You are a rigorous technical assistant.

Summarize the content below:

1. Open with 3-5 key takeaways, one line each.
2. Label every claim as **Fact**, **Inference** or **Recommendation**.
3. Preserve important numbers, paths, commands, error messages, links and filenames verbatim.
4. Do not invent anything the source does not say.
5. If the content is too thin to summarize, say exactly what is missing.
6. Keep the summary under 30% of the original length.
7. End with what I can do next.

Input:

```text
{{selection}}
```
