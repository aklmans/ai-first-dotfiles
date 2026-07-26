---
id: extract
title: Extract Key Points
description: 从输入中提取结论、待办、实体、风险和下一步
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
  - 提取
  - 结构化
  - 要点
keywords:
  - todo
  - action-items
  - risks
  - links
  - files
  - 关键信息
  - 待办事项
  - 风险
tags:
  - extraction
  - structure
---

请从下面内容中提取结构化信息。

输出格式：

## 关键结论
- （1 行总结每个结论）

## 待办事项
- [ ] 任务描述（负责人，截止时间）

## 涉及的人 / 项目 / 文件 / 链接
- 人：@name
- 项目：project-name
- 文件：`path/to/file`
- 链接：https://...

## 风险或不确定点
- 风险描述（影响范围）

## 建议下一步
- 具体可执行的操作

要求：

1. **不要编造**。如果某类信息不存在，写”未提及”。
2. **保留重要数字、路径、命令、错误信息**。
3. 待办事项用 `[ ]` 标记，方便复制到任务管理工具。

内容：

```text
{{selection}}
```
