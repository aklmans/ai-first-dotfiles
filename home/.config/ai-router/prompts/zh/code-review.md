---
id: code-review
title: Code Review
description: 以代码评审方式检查改动、风险和测试缺口
category: coding
priority: 210
default_provider: claude
fallback_provider: codex
input: selection
output: preview
allow_replace: false
aliases:
  - review
  - code-review
  - cr
  - review-code
  - inspect
  - 代码评审
  - 审查
  - 代码审查
keywords:
  - findings
  - regression
  - edge-cases
  - test-gaps
  - risk-review
  - 行为回归
  - 边界条件
  - 测试缺口
tags:
  - coding
  - review
---

请以代码评审方式检查下面内容。

要求：

1. Findings first，按以下优先级排序：
   - **P0**: 数据丢失、安全漏洞、生产故障
   - **P1**: 行为回归、边界条件未处理、数据兼容性
   - **P2**: 错误处理不完整、测试缺口
   - **P3**: 可读性、命名（仅在严重影响理解时提）

2. 每个问题包含：
   - 具体位置（行号、函数名、文件名）
   - 问题描述
   - 影响范围
   - 建议修复方法

3. 不要做无关风格建议。
4. 最后给出简短 summary（1-2 句话）。

输出格式：

## P0 Issues
- [位置] 问题描述 → 建议

## P1 Issues
- ...

## Summary
总体评价和主要风险

材料：

```text
{{selection}}
```
