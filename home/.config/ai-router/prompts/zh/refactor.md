---
id: refactor
title: Refactor Code
description: 重构代码，保持行为不变但提升可维护性
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
  - 重构
  - 优化代码
  - 清理代码
keywords:
  - behavior-preserving
  - duplicate-code
  - long-function
  - naming
  - maintainable
  - 保持行为
  - 重复代码
  - 可维护性
tags:
  - coding
  - refactor
---

请重构下面代码。

要求：

1. **保持外部行为完全不变**（输入输出、副作用、性能特征）。
2. **优先改进**：
   - 重复代码（提取公共函数）
   - 过长函数（拆分为小函数）
   - 不清晰命名（改为描述性名称）
   - 魔法数字（提取为常量）
3. **不改变**：架构、依赖、公共 API。
4. 输出重构后的代码 + 简短说明（1-2 句话说明改了什么）。

示例：

**输入**：
```python
def process(data):
    if data["type"] == "A":
        return data["value"] * 2
    elif data["type"] == "B":
        return data["value"] * 3
    else:
        return data["value"]
```

**输出**：
```python
MULTIPLIERS = {"A": 2, "B": 3}

def process(data):
    multiplier = MULTIPLIERS.get(data["type"], 1)
    return data["value"] * multiplier
```
重构说明：用字典替换 if-elif 链，提取魔法数字为常量。

代码：

```text
{{selection}}
```
