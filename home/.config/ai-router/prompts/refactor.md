---
id: refactor
title: Refactor Code
description: Restructure code for maintainability without changing its behavior
category: coding
priority: 250
default_provider: claude
fallback_provider: codex
input: selection
output: clipboard
allow_replace: false
aliases:
  - refactor
  - cleanup
  - restructure
  - simplify
  - maintainability
  - tidy
  - deduplicate
keywords:
  - behavior-preserving
  - duplicate-code
  - long-function
  - naming
  - maintainable
  - magic-numbers
  - extract-function
tags:
  - coding
  - refactor
---

Refactor the code below.

Requirements:

1. **Preserve external behavior exactly**: inputs, outputs, side effects, performance characteristics.
2. **Improve, in priority order**:
   - Duplicated code (extract a shared function)
   - Over-long functions (split them up)
   - Unclear names (make them descriptive)
   - Magic numbers (lift them into named constants)
3. **Do not change**: architecture, dependencies or the public API.
4. Output the refactored code plus a one- or two-sentence note on what changed.

Example:

**Input**:
```python
def process(data):
    if data["type"] == "A":
        return data["value"] * 2
    elif data["type"] == "B":
        return data["value"] * 3
    else:
        return data["value"]
```

**Output**:
```python
MULTIPLIERS = {"A": 2, "B": 3}

def process(data):
    multiplier = MULTIPLIERS.get(data["type"], 1)
    return data["value"] * multiplier
```
Note: replaced the if-elif chain with a lookup table and lifted the magic numbers into a constant.

Code:

```text
{{selection}}
```
