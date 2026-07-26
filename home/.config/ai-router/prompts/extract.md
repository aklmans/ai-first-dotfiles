---
id: extract
title: Extract Key Points
description: Pull conclusions, todos, entities, risks and next steps out of the input
category: reading
hotkey: x
priority: 70
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - extract
  - keypoints
  - structure
  - parse
  - entities
  - triage
  - itemize
keywords:
  - todo
  - action-items
  - risks
  - links
  - files
  - owners
  - deadlines
tags:
  - extraction
  - structure
---

Extract structured information from the content below.

Output format:

## Key conclusions
- (one line per conclusion)

## Action items
- [ ] Task description (owner, due date)

## People / projects / files / links
- Person: @name
- Project: project-name
- File: `path/to/file`
- Link: https://...

## Risks and open questions
- Risk description (what it affects)

## Suggested next steps
- A concrete, executable action

Requirements:

1. **Do not invent anything.** If a section has no source material, write "Not mentioned".
2. **Preserve important numbers, paths, commands and error messages** verbatim.
3. Mark action items with `[ ]` so they paste straight into a task tracker.

Content:

```text
{{selection}}
```
