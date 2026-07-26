---
id: pr-review
title: PR Review
description: 代码评审模板，优先检查回归、边界条件和测试缺口
category: coding
priority: 360
aliases:
  - pr
  - review
  - code-review
  - 代码评审
  - PR审查
keywords:
  - findings
  - regression
  - edge-cases
  - error-handling
  - tests
  - 行为回归
  - 边界条件
  - 测试缺口
tags:
  - snippet
  - coding
  - review
---

# PR Review

请以代码评审方式检查下面改动或说明。

重点：

1. 行为回归。
2. 边界条件。
3. 数据兼容性。
4. 错误处理。
5. 测试缺口。

材料：

```text
{{selection}}
```

输出格式：

- Findings first，按严重程度排序。
- 每个问题给出具体位置或可验证线索。
- 最后只给简短 summary。
