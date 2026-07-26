---
id: research
title: Research Plan
description: Break a question into executable research tasks and a verification checklist
category: research
hotkey: r
priority: 80
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - research
  - search
  - investigate
  - lookup
  - verify
  - fact-check
  - dig-in
keywords:
  - fact-check
  - web-search
  - sources
  - validation
  - query-plan
  - evidence
  - unknowns
tags:
  - research
  - search
---

Turn the question below into an executable research task.

Requirements:

1. **State the goal and the bar for done** - what counts as "answered".
2. **List the facts that need verifying**, ranked by how much they matter.
3. **Suggest search terms** or source types: official docs, GitHub issues, papers, changelogs.
4. **Flag what cannot be answered from memory** - version numbers, API changes, current policy - and must be checked online.
5. **Give me a short findings template** to fill in as I go.

Output format:

## Research goal
The core question to answer

## Facts to verify (ranked)
1. [ ] Fact A (search terms: ...)
2. [ ] Fact B (source type: ...)

## Must be verified online
- Current version of project X
- ...

## Findings template
```
Key findings:
-
Evidence:
-
Recommendation:
-
```

Question or material:

```text
{{selection}}
```
