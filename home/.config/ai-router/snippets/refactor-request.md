---
id: refactor-request
title: Refactor Request
description: Low-risk refactor request template - behavior preserved, validated in stages
category: coding
priority: 370
aliases:
  - refactor
  - cleanup
  - refactor-plan
  - restructure
  - tech-debt
keywords:
  - behavior-preserving
  - staged-plan
  - risk
  - validation
  - maintainability
  - small-commits
  - abstraction
tags:
  - snippet
  - coding
  - refactor
---

# Refactor Request

Propose a low-risk refactor for the code or requirement below.

## Current problem

{{selection}}

## Constraints

- Existing behavior must not change.
- Prefer small commits.
- Do not introduce abstractions that are not needed yet.

## Please output

1. The goal of the refactor.
2. The staged steps.
3. The risks.
4. How to validate each stage.
