# AI Workflow Router

AI Workflow Router 是 CapsLock AI Lite 的下一层：它不以“打开哪个 AI 工具”为中心，而以“我要完成什么工作流”为中心。

调用链：

```text
CapsLock Hyper
  -> Karabiner 输出稳定全局快捷键
  -> Hammerspoon 接收快捷键和显示菜单
  -> ai-router.sh 收集上下文、渲染 prompt、选择 provider
  -> Provider / Agent / Clipboard / Output File
```

Karabiner 不在本层修改。

## 快捷键

| 快捷键 | 行为 |
|---|---|
| CapsLock + Space | 快速 AI Command Palette，不动态扫描 |
| CapsLock + A/S/T/E/W/F/X/R/G/D | 渲染对应 Prompt，把选中文本嵌进去并复制到剪贴板 |
| CapsLock + Y | 渲染 `translate-to-en` Prompt，把中文选区翻译成英文 |
| CapsLock + = | 渲染 `optimize-prompt` Prompt，增强选中的提示词 |
| CapsLock + C | Coding Agent 菜单 |

Agent 菜单会新开 Warp tab 并粘贴命令，不自动执行。

Provider 直跑热键已移除。需要调用 Provider 时，用命令行或后续外部 UI 显式触发，例如 `~/.config/ai-router/ai-router.sh run summarize`。

## Direct Launch 层

`CapsLock + Ctrl + 首字母` 是 Karabiner 直达启动层，不经过 Hammerspoon 菜单。

| 快捷键 | 行为 |
|---|---|
| CapsLock + Ctrl + W | 打开 Warp |
| CapsLock + Ctrl + I | 打开 IntelliJ IDEA |
| CapsLock + Ctrl + G | 打开 GoLand |
| CapsLock + Ctrl + X | 打开 Codex App |
| CapsLock + Ctrl + H | 打开 ChatGPT |
| CapsLock + Ctrl + C | 新开 Warp tab 并启动 Codex CLI |
| CapsLock + Ctrl + L | 新开 Warp tab 并启动 Claude Code |

## 概念

| 类型 | 含义 |
|---|---|
| Prompt | 指挥 AI 如何处理当前输入的 Markdown 模板 |
| Snippet | 可复制/插入的固定资料或模板 |
| Skill | Agent 能力说明或调用规范 |
| Plugin | 工具扩展、集成能力或插件配置 |
| Agent | 长任务执行者，如 Codex CLI、Claude Code、Junie |
| Provider | 具体 AI 后端或客户端，如 Kimi、Gemini、Claude |

## 目录结构

```text
~/.config/ai-router/
  config.json
  ai-router.sh
  lib/
    router_tools.py
  prompts/
  snippets/
  providers/
  catalogs/
  exports/
  tests/
  cache/
    selection.txt
    selection-meta.env
    last-output.md
  state/
    usage.json
    favorites.json
  logs/
    events.jsonl
    errors/
```

## 常用命令

```bash
~/.config/ai-router/ai-router.sh render summarize
~/.config/ai-router/ai-router.sh run summarize
~/.config/ai-router/ai-router.sh run translate
~/.config/ai-router/ai-router.sh palette
~/.config/ai-router/ai-router.sh agent-menu
~/.config/ai-router/ai-router.sh favorite list
~/.config/ai-router/ai-router.sh favorite toggle prompt summarize "Summarize Selection"
~/.config/ai-router/ai-router.sh tool last-error
~/.config/ai-router/ai-router.sh index
~/.config/ai-router/ai-router.sh export-snippets all
~/.config/ai-router/ai-router.sh list providers
bash ~/.config/ai-router/tests/run.sh
```

## 新增 Prompt

在 `prompts/` 下新增 Markdown 文件，使用 YAML Frontmatter：

```markdown
---
id: my-action
title: My Action
description: 这个 prompt 的用途
category: writing
hotkey: z
priority: 300
default_provider: kimi
fallback_provider: gemini
input: selection
output: clipboard
allow_replace: false
aliases:
  - alias-a
  - 中文别名
keywords:
  - search-word
  - 场景词
tags:
  - writing
---

处理下面内容：

{{selection}}
```

新增后运行：

```bash
~/.config/ai-router/ai-router.sh index
```

`index` 会生成：

- `catalogs/prompts.json`: prompt 元数据、别名、keywords、标签、provider 设置。
- `catalogs/hotkeys.json`: Hammerspoon 直接热键绑定数据。
- `catalogs/palette.json`: Hammerspoon chooser 和未来外部 App 的搜索数据。
- `catalogs/agents.json`: 从 `config.json` 生成的 agent 菜单数据。

Hammerspoon 会优先读取这些缓存；缓存不存在时才回退到内置静态列表。

`ai-router.sh palette` 也读取 `catalogs/palette.json`，只在缓存缺失时才重建索引或回退到动态扫描。后续 Raycast、外部 Mac App 或其他 UI 应优先接这个缓存入口。

## Favorites / Recent / Ranking

Chooser 排序由两个本地状态文件控制：

- `state/usage.json`: 自动记录使用次数和最近使用时间，只记录 `kind/value/title/count/time`，不记录 selection、prompt 或 output。
- `state/favorites.json`: 手动收藏项，收藏项会显示在 chooser 顶部。

使用方式：

- 打开 `CapsLock + Space`，选择任意 prompt/snippet/skill/plugin/agent/tool 后会自动更新 recent 和 usage count。
- 在 chooser 里右键某一项可以切换 favorite。
- Chooser 标题会按 `Pinned / Recent / Prompt / Snippet / Agent / Skill / Plugin / Tool` 显示分组语义。
- 副标题会显示分类、使用次数、最近使用时间，以及 aliases / keywords / tags 组成的预览摘要。
- 命令行也可以管理 favorite：

```bash
~/.config/ai-router/ai-router.sh favorite list
~/.config/ai-router/ai-router.sh favorite add prompt summarize "Summarize Selection"
~/.config/ai-router/ai-router.sh favorite remove prompt summarize "Summarize Selection"
```

## 新增 Snippet

在 `snippets/` 下新增 Markdown 文件。Snippet 可以使用 `{{selection}}`、`{{clipboard}}`、`{{frontmost_app}}`、`{{window_title}}` 变量。

Snippet 也支持和 Prompt 类似的 Frontmatter，便于 palette 搜索：

```markdown
---
id: my-snippet
title: My Snippet
description: 这个 snippet 的用途
category: writing
priority: 300
aliases:
  - alias-a
  - 中文别名
keywords:
  - search-word
  - 场景词
tags:
  - snippet
  - writing
---

# My Snippet

{{selection}}
```

## 导出到 Snippet 工具

静态 Prompt / Snippet 可以导出给外部 snippet 工具使用；动态选区读取、前台应用、窗口标题等仍然保留在 `CapsLock + 字母` 快捷键里。

```bash
~/.config/ai-router/ai-router.sh export-snippets all
```

生成文件：

- `exports/raycast-snippets.json`: Raycast Snippets 可导入格式，字段为 `name`、`text`、`keyword`。
- `exports/ai-router-snippets.json`: 中立 JSON，保留 metadata、aliases、keywords、原始模板、Raycast 版本文本和变量列表，后续可给 HapiGo 或自研 Mac App 做转换。

导出规则：

- 关键字统一为 `;` + 2-3 个字母，便于 Raycast Snippets 里快速触发。
- 示例：`;sm` 总结、`;tr` 翻译、`;ex` 解释、`;rw` 改写、`;fx` 修复、`;qa` 问答。
- Snippet 示例：`;mt` 会议纪要、`;rv` PR Review、`;sq` SQL Debug、`;er` 终端错误。
- Raycast 导出会把 `{{selection}}` 和 `{{clipboard}}` 转成 `{clipboard}`，把 `{{date}}` 转成 `{date}`。
- HapiGo 当前公开文档描述的是导入/导出 `.hasnp` 文件，没有稳定公开 JSON schema；需要拿到一份 HapiGo 导出的 `.hasnp` 样本后再做精确转换。

## 新增 Provider

在 `providers/` 下新增可执行脚本。约定：

- 从 stdin 接收完整 prompt。
- 向 stdout 输出结果。
- 失败时写 stderr 并返回非 0。

当前可用文本 Provider：

- `kimi`: `kimi --quiet --prompt`
- `gemini`: `gemini --prompt --output-format text`

当前占位或谨慎启用：

- `codex`: 默认禁用 text provider，建议从 Coding Agent 菜单进入。
- `junie`: 默认禁用 text provider，建议从 Coding Agent 菜单进入。
- `warp-agent`: 占位。

## 输出和日志

- 所有运行结果保存到 `cache/last-output.md`。
- `output: clipboard` 的 prompt 会把结果复制到剪贴板。
- `output: preview` 的 prompt 只保存结果并通知，可从 palette 的 `Tool: Open Last Output` 打开。
- 日志写入 `logs/events.jsonl`，新事件带 `request_id`、`input_source`、`selection_source`、`selection_ms` 等元信息。
- Provider 不可用或执行失败时，默认把 sanitized/capped 错误复制到剪贴板并写入 `logs/errors/<request_id>.log`。
- 如需调试原始 provider 错误，显式设置 `AI_ROUTER_DEBUG_FULL_LOG=1`，原始错误会写入 `logs/errors/<request_id>.raw.log`。
- 最近一次错误会复制到 `logs/errors/latest.log`，可从 palette 的 `Tool: Open Last Error` 打开。
- 日志只记录元信息，不记录完整 selection、prompt 或 output。

Agent 菜单数据来自 `config.json` 的 `agents` 字段。Hammerspoon chooser 会优先读取 `ai-router.sh agent-menu`，读取失败时才使用内置 fallback。

## 可靠性参数

读取选中文本时会临时保存剪贴板、写入 sentinel、触发 `Cmd+C`，然后短间隔轮询剪贴板；一旦检测到新内容就继续，不再固定等待完整延迟。最后会恢复原剪贴板，并把读取来源和耗时写入 `cache/selection-meta.env` 与 `logs/events.jsonl`。

可通过环境变量微调：

```bash
AI_ROUTER_SELECTION_COPY_DELAY=0.28
AI_ROUTER_SELECTION_ATTEMPTS=2
AI_ROUTER_SELECTION_POLLING=1
AI_ROUTER_SELECTION_POLL_INTERVAL=0.03
AI_ROUTER_SELECTION_POLL_COUNT=10
AI_ROUTER_SELECTION_STRICT=0
AI_ROUTER_PROVIDER_TIMEOUT_SECONDS=60
```

默认最多重试 2 次，每次轮询 10 次、间隔 `0.03s`。如果关闭轮询，则回退到 `AI_ROUTER_SELECTION_COPY_DELAY=0.28` 的固定等待。`AI_ROUTER_SELECTION_STRICT=1` 时，如果读不到选区会直接失败并通知，不会静默使用剪贴板。

正常模式下，如果读不到选区，会回退到剪贴板输入，并在通知和日志里标记 `clipboard input`。Provider 默认 60 秒超时。Provider 调用失败时会继续尝试 fallback chain；全部失败后不会再把输入 prompt 覆盖到剪贴板，而是复制错误信息。

## 测试

核心测试在 `tests/` 下：

```bash
bash ~/.config/ai-router/tests/run.sh
```

覆盖：

- prompt render 和 UTF-8 文本
- selection 读取元信息
- catalog / hotkeys / cached palette 生成
- provider 失败后的 fallback
- usage / favorites 状态文件

## 回滚

本轮改造前的备份：

- `~/.config/ai-router.backup-workflow-router-20260427-210229`
- `~/.hammerspoon/ai_hotkeys.lua.backup-ai-router-20260427-210229`
- `~/.hammerspoon/init.lua.backup-ai-router-20260427-210229`

恢复 ai-router：

```bash
rm -rf ~/.config/ai-router
cp -R ~/.config/ai-router.backup-workflow-router-20260427-210229 ~/.config/ai-router
```

恢复 Hammerspoon AI 热键：

```bash
cp ~/.hammerspoon/ai_hotkeys.lua.backup-ai-router-20260427-210229 ~/.hammerspoon/ai_hotkeys.lua
hs -c 'hs.reload()'
```

## Hammerspoon Reload

```bash
hs -c 'hs.reload()'
```

## 后续路线图

未完成工作、设计原则、验收命令和后续 Agent 交接提示词见：

- `~/.config/ai-router/ROADMAP.md`
