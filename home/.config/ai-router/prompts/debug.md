---
id: debug
title: Debug Issue
description: 系统化分析 bug，给出排查路径和验证方法
category: coding
priority: 230
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - debug
  - bug
  - troubleshoot
  - diagnose
  - root-cause
  - 调试
  - 排查
  - 定位问题
keywords:
  - issue-analysis
  - repro
  - hypothesis
  - verification
  - fix-plan
  - 根因
  - 复现
  - 验证方法
tags:
  - debugging
  - coding
---

请帮我调试这个问题。

输出格式：

## 问题分析
- **现象**：实际发生了什么
- **预期**：应该发生什么
- **差异**：关键差异点

## 可能原因（按概率排序）
1. **[70%] 原因 A**
   - 验证方法：具体命令或检查步骤
   - 如果是这个，修复方法：...

2. **[20%] 原因 B**
   - 验证方法：...
   - 如果是这个，修复方法：...

3. **[10%] 原因 C**
   - ...

## 最小复现步骤
1. 前置条件（环境、数据状态）
2. 操作步骤
3. 观察到的错误

## 需要的额外信息（如果材料不足）
- [ ] 日志文件路径
- [ ] 环境变量配置
- [ ] ...

前台应用：{{frontmost_app}}
日期：{{date}}

问题描述：

```text
{{selection}}
```
