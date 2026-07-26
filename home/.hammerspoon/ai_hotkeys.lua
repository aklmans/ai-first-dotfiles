local configDir = os.getenv("HOME") .. "/.config/ai-router"
local router = configDir .. "/ai-router.sh"

-- Runtime data moved out of ~/.config in router 2.4.0. Prefer the new location
-- and fall back to the old one so a Hammerspoon reload before the first router
-- run still finds the catalogs.
local function stateRoot()
  local override = os.getenv("AI_ROUTER_STATE_HOME")
  if override and override ~= "" then
    return override
  end

  local xdg = os.getenv("XDG_STATE_HOME")
  if xdg and xdg ~= "" then
    return xdg .. "/ai-router"
  end

  return os.getenv("HOME") .. "/.local/state/ai-router"
end

-- Resolved per call, not once at load: a Hammerspoon session that started
-- before the router first ran should still find the data afterwards.
local function runtimeDir(name)
  local candidate = stateRoot() .. "/" .. name
  if hs.fs.attributes(candidate, "mode") == "directory" then
    return candidate
  end
  return configDir .. "/" .. name
end

local function catalogPath(name)
  return runtimeDir("catalogs") .. "/" .. name
end

local function statePath(name)
  return runtimeDir("state") .. "/" .. name
end

local paletteChooser = nil
local agentChooser = nil
local suppressAgentChooserUntil = 0
local modifierReleaseWatcher = nil
local modifierReleaseTimeout = nil
local pendingRouterCall = nil

-- Keep the short suppression window because CapsLock+C shares a physical key
-- path with prompt shortcuts while Karabiner modifiers are still up.
local agentChooserSuppressSeconds = 0.8
local modifierReleaseFallbackSeconds = 0.9
local chooserWidth = 60
local chooserRows = 14
local runPreviewChars = 140

-- hotkeys.hyper in config.json, so the modifier set is not hard-coded in two
-- places. Falls back to the Karabiner default this repository ships.
local defaultHyper = { "ctrl", "alt", "cmd", "shift" }
local modifierAliases = {
  ctrl = "ctrl",
  control = "ctrl",
  alt = "alt",
  opt = "alt",
  option = "alt",
  cmd = "cmd",
  command = "cmd",
  shift = "shift",
  fn = "fn",
}

local function parseHyper(spec)
  if type(spec) ~= "string" or spec == "" then
    return nil
  end

  local modifiers = {}
  for part in spec:gmatch("[^%+%s]+") do
    local name = modifierAliases[part:lower()]
    if not name then
      return nil
    end
    modifiers[#modifiers + 1] = name
  end

  if #modifiers == 0 then
    return nil
  end

  return modifiers
end

local kindLabels = {
  prompt = "Prompt",
  snippet = "Snippet",
  agent = "Agent",
  skill = "Skill",
  plugin = "Plugin",
  tool = "Tool",
}

local kindOrder = {
  prompt = 10,
  snippet = 20,
  agent = 30,
  skill = 40,
  plugin = 50,
  tool = 60,
}

local function notify(title, message)
  hs.notify.new({ title = title, informativeText = message }):send()
end

-- Decodes any JSON file (arrays and objects alike).
local function readJsonArray(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  if not content or content == "" then
    return nil
  end

  local ok, decoded = pcall(hs.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return nil
  end

  return decoded
end

local function loadConfig()
  local config = readJsonArray(configDir .. "/config.json")
  if type(config) ~= "table" then
    return {}
  end
  return config
end

local hyper = defaultHyper
do
  local config = loadConfig()
  local hotkeys = config.hotkeys
  if type(hotkeys) == "table" then
    hyper = parseHyper(hotkeys.hyper) or defaultHyper
  end
end

local function compactText(text)
  return tostring(text or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function truncateText(text, maxChars)
  text = compactText(text)
  maxChars = maxChars or 220

  if not utf8 or not utf8.len or not utf8.offset then
    if #text > maxChars then
      return text:sub(1, maxChars) .. "..."
    end
    return text
  end

  local ok, length = pcall(utf8.len, text)
  if not ok or not length or length <= maxChars then
    return text
  end

  local byteIndex = utf8.offset(text, maxChars + 1)
  if not byteIndex then
    return text
  end

  return text:sub(1, byteIndex - 1) .. "..."
end

local function kindLabel(kind)
  return kindLabels[kind] or tostring(kind or "Item")
end

local function stripCatalogPrefix(text)
  text = compactText(text)
  return text:gsub("^Prompt:%s*", "")
    :gsub("^Snippet:%s*", "")
    :gsub("^Agent:%s*", "")
    :gsub("^Skill:%s*", "")
    :gsub("^Plugin:%s*", "")
    :gsub("^Tool:%s*", "")
end

local function relativeTime(ts)
  ts = tonumber(ts) or 0
  if ts <= 0 then
    return ""
  end

  local diff = math.max(0, hs.timer.secondsSinceEpoch() - ts)
  if diff < 60 then
    return "just now"
  end
  if diff < 3600 then
    return tostring(math.floor(diff / 60)) .. "m ago"
  end
  if diff < 86400 then
    return tostring(math.floor(diff / 3600)) .. "h ago"
  end
  return os.date("%m-%d %H:%M", ts)
end

local function choiceFromRecord(record)
  if type(record) ~= "table" then
    return nil
  end

  local kind = record.kind or record.type
  local value = record.value or record.name or record.path
  if not kind or not value then
    return nil
  end

  local text = record.text or record.title or record.name or value
  local subText = record.subText or record.description or record.searchText or ""

  return {
    text = text,
    subText = subText,
    kind = kind,
    value = value,
    title = record.title or record.text or record.name or value,
    category = record.category or "",
    hotkey = record.hotkey or "",
    searchText = record.searchText or "",
    _rawText = text,
    _rawSubText = subText,
  }
end

local function runRouter(args, options)
  options = options or {}

  if hs.fs.attributes(router, "mode") ~= "file" then
    notify("AI Router", "Missing router: " .. router)
    return
  end

  hs.task.new(router, function(exitCode, stdout, stderr)
    if exitCode ~= 0 then
      local message = stderr
      if not message or message == "" then
        message = stdout or "Unknown error"
      end
      notify(options.failTitle or "AI Router failed", truncateText(message, 240))
      return
    end

    if options.doneTitle then
      local preview = truncateText(stdout or "", runPreviewChars)
      if preview == "" then
        preview = options.doneMessage or "Done"
      end
      notify(options.doneTitle, preview)
    end
  end, args):start()
end

-- CapsLock is one physical key, so "the same shortcut, but actually call the
-- model" has to be a second modifier held on top of it. Karabiner emits Hyper
-- as the four right-side modifiers, so any modifier on the *left* side is a
-- key the user pressed deliberately and Hyper did not send. That is the run
-- gesture: Hyper + (left) Shift, or left Cmd, whichever the hand reaches.
--
-- checkKeyboardModifiers only names the device-independent modifiers, so the
-- left/right split has to be decoded from the raw flag word. Plain arithmetic
-- rather than Lua 5.3 bitwise operators: a syntax error here would take the
-- whole file - every AI hotkey - down on an older runtime.
--
-- Everything fails towards render. Unreadable flags, an unknown mask table, or
-- an ambiguous modifier state all mean "copy the prompt", never "spend a model
-- call the user did not ask for".
local hyperSideFlags = {
  right = { "deviceRightCommand", "deviceRightControl", "deviceRightAlternate", "deviceRightShift" },
  left = { "deviceLeftCommand", "deviceLeftControl", "deviceLeftAlternate", "deviceLeftShift" },
}

local function rawFlagHeld(raw, name)
  if type(raw) ~= "number" then
    return false
  end

  local masks = hs.eventtap.event.rawFlagMasks
  if type(masks) ~= "table" then
    return false
  end

  local mask = masks[name]
  if type(mask) ~= "number" or mask < 1 then
    return false
  end

  return math.floor(raw / mask) % 2 == 1
end

local function hyperSideHeld(raw, side)
  return rawFlagHeld(raw, side[1]) and rawFlagHeld(raw, side[2]) and rawFlagHeld(raw, side[3])
end

local function runGestureHeld()
  local ok, mods = pcall(hs.eventtap.checkKeyboardModifiers, true)
  if not ok or type(mods) ~= "table" then
    return false
  end

  local raw = mods._raw
  local rightHyper = hyperSideHeld(raw, hyperSideFlags.right)
  local leftHyper = hyperSideHeld(raw, hyperSideFlags.left)

  if rightHyper == leftHyper then
    -- Neither side is holding a Hyper: this is the chooser, where a plain
    -- Shift+Enter is the alternate action. Both sides at once is ambiguous.
    if rightHyper or mods.cmd or mods.ctrl or mods.alt then
      return false
    end
    return mods.shift == true
  end

  local extras = leftHyper and hyperSideFlags.right or hyperSideFlags.left
  for _, name in ipairs(extras) do
    if rawFlagHeld(raw, name) then
      return true
    end
  end

  return false
end

local function hotkeyModifiersReleased()
  local modifiers = hs.eventtap.checkKeyboardModifiers()
  return not (modifiers.cmd or modifiers.ctrl or modifiers.alt or modifiers.shift)
end

local function stopModifierReleaseWatcher()
  if modifierReleaseWatcher then
    modifierReleaseWatcher:stop()
    modifierReleaseWatcher = nil
  end

  if modifierReleaseTimeout then
    modifierReleaseTimeout:stop()
    modifierReleaseTimeout = nil
  end
end

local function flushPendingRouterArgs()
  local call = pendingRouterCall
  pendingRouterCall = nil
  stopModifierReleaseWatcher()

  if call then
    runRouter(call.args, call.options)
  end
end

local function runRouterAfterModifiersReleased(args, options)
  pendingRouterCall = { args = args, options = options }
  suppressAgentChooserUntil = hs.timer.secondsSinceEpoch() + agentChooserSuppressSeconds

  if hotkeyModifiersReleased() then
    flushPendingRouterArgs()
    return
  end

  stopModifierReleaseWatcher()
  modifierReleaseWatcher = hs.eventtap.new({
    hs.eventtap.event.types.flagsChanged,
    hs.eventtap.event.types.keyUp,
  }, function()
    if hotkeyModifiersReleased() then
      flushPendingRouterArgs()
    end
    return false
  end)
  modifierReleaseWatcher:start()

  modifierReleaseTimeout = hs.timer.doAfter(modifierReleaseFallbackSeconds, flushPendingRouterArgs)
end

local fallbackPromptBindings = {
  { key = "a", prompt = "ask", title = "Ask AI", desc = "复制通用问答 prompt" },
  { key = "s", prompt = "summarize", title = "Summarize", desc = "复制总结 prompt" },
  { key = "t", prompt = "translate", title = "Translate", desc = "复制翻译 prompt" },
  { key = "e", prompt = "explain", title = "Explain", desc = "复制解释 prompt" },
  { key = "w", prompt = "rewrite", title = "Rewrite", desc = "复制改写 prompt" },
  { key = "f", prompt = "fix", title = "Fix", desc = "复制修复 prompt" },
  { key = "x", prompt = "extract", title = "Extract", desc = "复制提取 prompt" },
  { key = "r", prompt = "research", title = "Research", desc = "复制研究 prompt" },
  { key = "g", prompt = "generate", title = "Generate", desc = "复制生成 prompt" },
  { key = "d", prompt = "draft", title = "Draft", desc = "复制起草 prompt" },
  { key = "y", prompt = "translate-to-en", title = "Translate to English", desc = "复制中译英 prompt" },
  { key = "=", prompt = "optimize-prompt", title = "Optimize Prompt", desc = "复制提示词增强 prompt" },
}

-- Only used when catalogs/agents.json is missing; the real list comes from
-- config.json, including which terminal the command is pasted into.
local fallbackAgentChoices = {
  { text = "Codex CLI", subText = "新开终端标签页并粘贴 codex --disable apps", kind = "agent", value = "codex" },
  { text = "Claude Code", subText = "新开终端标签页并粘贴 claude", kind = "agent", value = "claude" },
  { text = "Junie", subText = "新开终端标签页并粘贴 junie", kind = "agent", value = "junie" },
  { text = "Gemini CLI", subText = "新开终端标签页并粘贴 gemini", kind = "agent", value = "gemini" },
  { text = "Kimi CLI", subText = "新开终端标签页并粘贴 kimi", kind = "agent", value = "kimi" },
  { text = "Warp Agent", subText = "新开终端标签页并放置 Warp Agent 占位命令", kind = "agent", value = "warp-agent" },
  { text = "Codex App", subText = "打开 Codex App", kind = "agent", value = "codex-app" },
}

local toolChoices = {
  { text = "Open Last Output", subText = "打开 cache/last-output.md", kind = "tool", value = "last-output" },
  { text = "Open Last Error", subText = "打开最近一次错误日志", kind = "tool", value = "last-error" },
  { text = "Provider Status", subText = "查看 providers/ 下每个 provider 的状态", kind = "tool", value = "provider-status" },
  { text = "Open AI Router Config", subText = "打开 ~/.config/ai-router", kind = "tool", value = "config" },
  { text = "Open Prompt Folder", subText = "打开 prompts 目录", kind = "tool", value = "prompts" },
  { text = "Open Logs", subText = "打开 logs 目录", kind = "tool", value = "logs" },
  { text = "Rebuild Catalog Index", subText = "重新生成 catalogs/*.json", kind = "tool", value = "index" },
}

local function stateKey(kind, value)
  return tostring(kind or "") .. ":" .. tostring(value or "")
end

local function loadUsageItems()
  local data = readJsonArray(statePath("usage.json"))
  if not data or type(data.items) ~= "table" then
    return {}
  end
  return data.items
end

local function loadFavoriteSet()
  local data = readJsonArray(statePath("favorites.json"))
  local set = {}
  if not data or type(data.items) ~= "table" then
    return set
  end

  for _, item in ipairs(data.items) do
    if item.kind and item.value then
      set[stateKey(item.kind, item.value)] = item
    end
  end

  return set
end

local function annotateChoice(choice, index, usageItems, favoriteSet)
  local key = stateKey(choice.kind, choice.value)
  local usage = usageItems[key] or {}
  local favorite = favoriteSet[key] ~= nil
  local count = tonumber(usage.count) or 0
  local lastUsed = tonumber(usage.last_used_ts) or 0
  local kind = choice.kind or "item"
  local label = kindLabel(kind)
  local title = stripCatalogPrefix(choice.title or choice._rawText or choice.text or choice.value)
  local rawSubText = choice._rawSubText or choice.subText or ""
  local status = {}

  choice._baseIndex = index
  choice._favorite = favorite
  choice._usageCount = count
  choice._lastUsed = lastUsed
  choice._kindOrder = kindOrder[kind] or 999

  if favorite then
    choice.text = "Pinned / " .. label .. " / " .. title
    status[#status + 1] = "pinned"
  elseif lastUsed > 0 then
    choice.text = "Recent / " .. label .. " / " .. title
  else
    choice.text = label .. " / " .. title
  end

  if lastUsed > 0 then
    status[#status + 1] = "used " .. tostring(count) .. "x"
    status[#status + 1] = relativeTime(lastUsed)
  end
  if choice.category and choice.category ~= "" then
    status[#status + 1] = choice.category
  end

  local preview = truncateText(rawSubText, 260)
  if #status > 0 and preview ~= "" then
    choice.subText = table.concat(status, " | ") .. " - " .. preview
  elseif #status > 0 then
    choice.subText = table.concat(status, " | ")
  else
    choice.subText = preview
  end

  return choice
end

local function rankChoices(choices)
  local usageItems = loadUsageItems()
  local favoriteSet = loadFavoriteSet()

  for index, choice in ipairs(choices) do
    annotateChoice(choice, index, usageItems, favoriteSet)
  end

  table.sort(choices, function(a, b)
    if a._favorite ~= b._favorite then
      return a._favorite
    end
    if a._lastUsed ~= b._lastUsed then
      return a._lastUsed > b._lastUsed
    end
    if a._usageCount ~= b._usageCount then
      return a._usageCount > b._usageCount
    end
    if a._kindOrder ~= b._kindOrder then
      return a._kindOrder < b._kindOrder
    end
    return (a._baseIndex or 0) < (b._baseIndex or 0)
  end)

  return choices
end

local function loadPromptBindings()
  local records = readJsonArray(catalogPath("hotkeys.json"))
  if not records then
    return fallbackPromptBindings
  end

  local bindings = {}
  for _, record in ipairs(records) do
    if record.key and record.prompt then
      bindings[#bindings + 1] = {
        key = record.key,
        prompt = record.prompt,
        title = record.title or record.prompt,
        desc = record.desc or record.description or "",
      }
    end
  end

  if #bindings == 0 then
    return fallbackPromptBindings
  end

  return bindings
end

local function promptChoices()
  local choices = {}

  for _, binding in ipairs(loadPromptBindings()) do
    choices[#choices + 1] = {
      text = "Prompt: " .. binding.title,
      subText = binding.desc,
      kind = "prompt",
      value = binding.prompt,
    }
  end

  return choices
end

local function loadAgentChoicesFromCatalog()
  local records = readJsonArray(catalogPath("agents.json"))
  if not records then
    return nil
  end

  local choices = {}
  for _, record in ipairs(records) do
    choices[#choices + 1] = {
      text = record.title or record.name,
      subText = record.description or "",
      kind = "agent",
      value = record.name,
    }
  end

  if #choices == 0 then
    return nil
  end

  return rankChoices(choices)
end

local function loadAgentChoices()
  local catalogChoices = loadAgentChoicesFromCatalog()
  if catalogChoices then
    return catalogChoices
  end

  local choices = {}
  for _, choice in ipairs(fallbackAgentChoices) do
    choices[#choices + 1] = {
      text = choice.text,
      subText = choice.subText,
      kind = choice.kind,
      value = choice.value,
    }
  end

  return rankChoices(choices)
end

local function loadPaletteChoices()
  local records = readJsonArray(catalogPath("palette.json"))
  if not records then
    return nil
  end

  local choices = {}
  for _, record in ipairs(records) do
    local choice = choiceFromRecord(record)
    if choice then
      choices[#choices + 1] = choice
    end
  end

  if #choices == 0 then
    return nil
  end

  return rankChoices(choices)
end

local function allPaletteChoices()
  local cachedChoices = loadPaletteChoices()
  if cachedChoices then
    return cachedChoices
  end

  local choices = promptChoices()

  for _, choice in ipairs(loadAgentChoices()) do
    choices[#choices + 1] = choice
  end

  for _, choice in ipairs(toolChoices) do
    choices[#choices + 1] = choice
  end

  return rankChoices(choices)
end

local function toggleFavorite(choice)
  if not choice or not choice.kind or not choice.value then
    return
  end

  local title = choice.title or choice.text or choice.value
  title = title:gsub("^Pinned / [^/]+ / ", ""):gsub("^Recent / [^/]+ / ", "")
  runRouter({ "favorite", "toggle", choice.kind, choice.value, title })
end

-- render: instant, the result is the clipboard, the router notifies.
-- run: seconds long and spends a model call, so this side owns the whole
-- story - "Running ..." now, the answer (or the failure) when it lands. The
-- router is told to stay quiet so there is exactly one notification per state.
local function startPromptRun(prompt, title)
  title = stripCatalogPrefix(title or prompt)
  notify("AI Router", "Running " .. title .. " ...")
  runRouterAfterModifiersReleased({ "run", prompt, "--from", "selection", "--quiet" }, {
    doneTitle = "AI Router · " .. title,
    doneMessage = "Done, copied to clipboard",
    failTitle = "AI Router failed · " .. title,
  })
end

local function executeChoice(choice)
  if not choice then
    return
  end

  if choice.kind == "prompt" then
    if runGestureHeld() then
      startPromptRun(choice.value, choice.title or choice.text)
    else
      runRouterAfterModifiersReleased({ "render", choice.value, "--from", "selection" })
    end
  elseif choice.kind == "snippet" then
    runRouterAfterModifiersReleased({ "snippet", choice.value, "--from", "selection" })
  elseif choice.kind == "skill" then
    runRouterAfterModifiersReleased({ "skill", choice.value })
  elseif choice.kind == "plugin" then
    runRouterAfterModifiersReleased({ "plugin", choice.value })
  elseif choice.kind == "agent" then
    runRouter({ "agent", choice.value })
  elseif choice.kind == "tool" then
    runRouter({ "tool", choice.value })
  end
end

local function showPalette()
  paletteChooser = hs.chooser.new(executeChoice)
  paletteChooser:placeholderText("AI Router - Enter copies the prompt, Shift+Enter runs it")
  paletteChooser:searchSubText(true)
  pcall(function() paletteChooser:width(chooserWidth) end)
  pcall(function() paletteChooser:rows(chooserRows) end)
  paletteChooser:choices(allPaletteChoices())
  pcall(function() paletteChooser:rightClickCallback(toggleFavorite) end)
  paletteChooser:show()
end

local function showAgents()
  if hs.timer.secondsSinceEpoch() < suppressAgentChooserUntil then
    return
  end

  agentChooser = hs.chooser.new(executeChoice)
  agentChooser:placeholderText("AI Coding Agents")
  agentChooser:searchSubText(true)
  pcall(function() agentChooser:width(chooserWidth) end)
  pcall(function() agentChooser:rows(10) end)
  agentChooser:choices(loadAgentChoices())
  pcall(function() agentChooser:rightClickCallback(toggleFavorite) end)
  agentChooser:show()
end

for _, binding in ipairs(loadPromptBindings()) do
  local key = binding.key
  local prompt = binding.prompt
  local title = binding.title or binding.prompt

  hs.hotkey.bind(hyper, key, function()
    -- Hyper + key       -> render the prompt to the clipboard (unchanged).
    -- Hyper + Shift + key -> send it to a provider and notify with the answer.
    if runGestureHeld() then
      startPromptRun(prompt, title)
    else
      runRouterAfterModifiersReleased({ "render", prompt, "--from", "selection" })
    end
  end)
end

hs.hotkey.bind(hyper, "space", showPalette)
hs.hotkey.bind(hyper, "c", showAgents)
