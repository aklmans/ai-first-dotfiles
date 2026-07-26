---
id: terminal-error
title: Terminal Error Analysis
description: 分析终端错误并给出最小修复步骤
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
  - 终端错误
  - 报错
  - 命令报错
keywords:
  - stderr
  - exit-code
  - command-output
  - shell
  - minimal-fix
  - 错误输出
  - 退出码
  - 最小修复
tags:
  - terminal
  - debugging
---

请分析这个终端错误，并给出最小修复步骤。

系统信息：
- 前台应用：{{frontmost_app}}
- 日期：{{date}}

要求：

1. 判断最可能根因（如果错误信息提到路径/命令，说明它们的作用）。
2. 给出最小验证命令（用于确认根因）。
3. 给出最小修复步骤。
4. 明确哪些操作有破坏性（如 `rm -rf`、`--force`），标记为 ⚠️。
5. 给出如何确认修复成功。

输出格式：

## 根因
最可能原因

## 验证
```bash
# 运行这个命令确认根因
command
```

## 修复
```bash
# 步骤 1
command
# 步骤 2（⚠️ 破坏性操作）
command
```

## 确认成功
重新运行原命令，预期输出：...

命令和输出：

```text
{{selection}}
```
