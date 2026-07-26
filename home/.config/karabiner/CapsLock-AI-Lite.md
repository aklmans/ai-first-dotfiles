# CapsLock AI Lite

## 改造目标

把原来复杂的 CapsLock Hyper 配置简化成轻量、稳定、适合 AI 工作流的 Karabiner profile。

保留：

- CapsLock 单击 Escape，按住 Hyper
- Vim 风格导航
- 少量删除快捷键
- AI / 应用 / 截图入口全局快捷键

不迁移：

- MouseKey
- 鼠标移动和滚轮
- 数字多剪贴板
- 大量窗口管理
- 桌面切换控制平面
- 多层复杂 modifier plane
- F1-F15 功能键重映射
- Shifter 符号转换
- 大量应用启动器

## 安装方式

这套键位以 complex modification 规则包的形式发布，安装是**追加**，不覆盖你现有的
Karabiner 配置：

```text
~/.config/karabiner/assets/complex_modifications/capslock-ai-lite.json
```

`./bootstrap/install/karabiner.sh` 只写这一个文件。你的 `karabiner.json`
（profile、设备设置、已启用的规则）不会被读写。

启用：

```text
Karabiner-Elements -> Complex Modifications -> Add rule
-> "CapsLock AI Lite (ai-first-dotfiles)" -> Enable All
```

规则默认**不自动启用**。启用某条规则会重写 Karabiner 正在运行的 profile，
那是键盘驱动的活配置，只能由你自己在 GUI 里确认。

## 回滚

在同一个界面里 Remove 掉对应规则即可，你原来的 profile 一直没被动过。

仓库里的 `home/.config/karabiner/karabiner.json` 是这套规则生成的 profile 的
**参考副本**，不参与部署。它不含任何设备 id，因此对所有键盘生效。

## Hyper 定义

- 单击 CapsLock -> Escape
- 按住 CapsLock -> Hyper
- Hyper = `right_command + right_control + right_option + right_shift`
- Hyper + Escape -> toggle CapsLock

## 核心导航

| 触发 | 输出 |
|---|---|
| Hyper + H | Left Arrow |
| Hyper + J | Down Arrow |
| Hyper + K | Up Arrow |
| Hyper + L | Right Arrow |
| Hyper + U | Page Up |
| Hyper + I | Home |
| Hyper + O | End |
| Hyper + P | Page Down |
| Hyper + Option + H | Option + Left Arrow |
| Hyper + Option + L | Option + Right Arrow |
| Hyper + Command + H/J/K/L | Shift + Arrow |
| Hyper + Command + Option + H/L | Option + Shift + Left/Right Arrow |

## 删除层

| 触发 | 输出 |
|---|---|
| Hyper + M | Delete / Backspace |
| Hyper + , | Forward Delete |
| Hyper + N | Option + Delete |
| Hyper + . | Option + Forward Delete |
| Hyper + Command + N | Command + Delete |
| Hyper + Command + . | Control + K |

## AI 全局快捷键

| 触发 | 输出 |
|---|---|
| Hyper + A | Control + Option + Command + Shift + A |
| Hyper + S | Control + Option + Command + Shift + S |
| Hyper + W | Control + Option + Command + Shift + W |
| Hyper + T | Control + Option + Command + Shift + T |
| Hyper + E | Control + Option + Command + Shift + E |
| Hyper + R | Control + Option + Command + Shift + R |
| Hyper + G | Control + Option + Command + Shift + G |
| Hyper + F | Control + Option + Command + Shift + F |
| Hyper + X | Control + Option + Command + Shift + X |
| Hyper + C | Control + Option + Command + Shift + C |
| Hyper + D | Control + Option + Command + Shift + D |
| Hyper + Z | Control + Option + Command + Shift + Z |
| Hyper + Space | Control + Option + Command + Shift + Space |

## 应用入口

| 触发 | 输出 |
|---|---|
| Hyper + B | Control + Option + Command + Shift + B |
| Hyper + V | Control + Option + Command + Shift + V |
| Hyper + Q | Control + Option + Command + Shift + Q |
| Hyper + ; | Control + Option + Command + Shift + Semicolon |
| Hyper + ' | Control + Option + Command + Shift + Quote |

## 条件分流

已移除 Warp 和 JetBrains 的特殊条件分流。

现在 `CapsLock AI Lite` 的原则是：除导航、删除、截图层以外，AI / 应用入口都统一发出 `Control + Option + Command + Shift + key`，由 Hammerspoon、Raycast、Keyboard Maestro 或其他工具接管。

这意味着：

- 在 Warp 中，CapsLock + C 不再等同 Ctrl + C，而是进入 AI Router 的 agent 选择器。
- 在 JetBrains 中，CapsLock + F 不再直接格式化代码，而是进入 AI Router 的 Fix 动作。
- 原生命令仍然用系统快捷键直接触发，例如 Ctrl + C、Cmd + Option + L 等。

## 截图 / OCR / 截图美化

| 触发 | 输出 |
|---|---|
| Hyper + ` | Control + Option + Command + Shift + ` |
| Hyper + Command + ` | Control + Option + Command + Shift + 1 |
| Hyper + Shift + ` | Control + Option + Command + Shift + 2 |

## 外部工具绑定建议

| 全局快捷键 | 建议绑定 |
|---|---|
| Control + Option + Command + Shift + A | Raycast AI Chat / ChatGPT / Claude |
| Control + Option + Command + Shift + S | Summarize Selected Text |
| Control + Option + Command + Shift + W | Rewrite Selected Text |
| Control + Option + Command + Shift + T | Translate Selected Text |
| Control + Option + Command + Shift + E | Explain Selected Text / Explain Code |
| Control + Option + Command + Shift + R | Perplexity / ChatGPT Search / Google Search |
| Control + Option + Command + Shift + G | Generate Content |
| Control + Option + Command + Shift + F | Fix Text |
| Control + Option + Command + Shift + X | Extract Key Points |
| Control + Option + Command + Shift + C | Code with AI |
| Control + Option + Command + Shift + D | Draft / Dictate |
| Control + Option + Command + Shift + Space | AI Command Palette |
| Control + Option + Command + Shift + ` | Screenshot |
| Control + Option + Command + Shift + 1 | OCR Screenshot |
| Control + Option + Command + Shift + 2 | Beautify Screenshot |
