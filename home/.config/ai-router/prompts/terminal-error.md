---
id: terminal-error
title: Terminal Error Analysis
description: Diagnose a terminal error and give the smallest fix that resolves it
category: debugging
priority: 260
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - terminal
  - error
  - shell-error
  - cli-error
  - command-error
  - stacktrace
  - command-failed
keywords:
  - stderr
  - exit-code
  - command-output
  - shell
  - minimal-fix
  - destructive-command
  - verification
tags:
  - terminal
  - debugging
---

Diagnose this terminal error and give me the smallest fix that resolves it.

System context:
- Frontmost app: {{frontmost_app}}
- Date: {{date}}

Requirements:

1. Identify the most likely root cause. If the error names a path or a command, say what it is for.
2. Give the smallest command that confirms the root cause.
3. Give the smallest fix.
4. Mark any destructive step (`rm -rf`, `--force`, anything that overwrites) with a warning sign.
5. Say how I confirm the fix worked.

Output format:

## Root cause
The most likely explanation

## Verify
```bash
# run this to confirm the root cause
command
```

## Fix
```bash
# step 1
command
# step 2 (destructive - review before running)
command
```

## Confirm
Re-run the original command. Expected output: ...

Command and output:

```text
{{selection}}
```
