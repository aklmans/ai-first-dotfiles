---
id: research
title: Research Plan
description: 把问题拆成可执行的研究任务和验证清单
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
  - 研究
  - 搜索
  - 调研
keywords:
  - fact-check
  - web-search
  - sources
  - validation
  - query-plan
  - 事实核查
  - 联网搜索
  - 资料来源
tags:
  - research
  - search
---

请把下面问题拆成一个可执行的研究任务。

要求：

1. **明确研究目标和判断标准**（什么算"找到答案"）。
2. **列出需要验证的事实点**（按优先级排序）。
3. **给出推荐搜索关键词**或资料来源类型（官方文档、GitHub issue、论文等）。
4. **标注哪些结论必须联网验证**（如版本号、API 变更、最新政策）。
5. **输出一个简短的研究结论模板**，方便我填充结果。

输出格式：

## 研究目标
要回答的核心问题

## 需要验证的事实（按优先级）
1. [ ] 事实 A（搜索关键词：...）
2. [ ] 事实 B（资料来源：...）

## 必须联网验证
- 项目 X 的最新版本号
- ...

## 结论模板
```
核心发现：
- 
证据来源：
-
建议：
-
```

问题或材料：

```text
{{selection}}
```
