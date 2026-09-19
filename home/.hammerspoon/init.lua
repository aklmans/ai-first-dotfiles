hs.window.animationDuration = 0

local aiFirstConfigDir = os.getenv("AI_FIRST_CONFIG_DIR")
  or (os.getenv("HOME") .. "/.config/ai-first")
local aiFirstProfilePath = os.getenv("AI_FIRST_PROFILE_PATH")
  or (aiFirstConfigDir .. "/profile.conf")

local function readAiFirstProfileFile(path, values)
  local file = io.open(path, "r")
  if not file then
    return values
  end
  for line in file:lines() do
    local key, value = line:match('^([A-Z0-9_]+)="([^"$`]*)"%s*$')
    if key then
      values[key] = value
    end
  end
  file:close()
  return values
end

-- Keep this in step with the two bash copies of the same rule: the overlay
-- directory is modules/<AI_FIRST_PRESET>, an unusable name falls back to
-- "custom", and overlays load after profile.conf in sorted order. See
-- ai_first_profile_load in ~/.config/ai-first/lib/profile.sh, and
-- resolve_overlay_scope in bootstrap/setup.sh, which decides where they are
-- written in the first place.
local function readAiFirstProfile()
  local values = readAiFirstProfileFile(aiFirstProfilePath, {})
  local scope = values["AI_FIRST_PRESET"] or "custom"
  if scope == "" or scope:match("[^%w_-]") then
    scope = "custom"
  end
  local moduleDir = aiFirstConfigDir .. "/modules/" .. scope
  local moduleFiles = {}
  if hs.fs.attributes(moduleDir, "mode") == "directory" then
    for name in hs.fs.dir(moduleDir) do
      if name:match("%.conf$") then
        moduleFiles[#moduleFiles + 1] = name
      end
    end
  end
  table.sort(moduleFiles)
  for _, name in ipairs(moduleFiles) do
    readAiFirstProfileFile(moduleDir .. "/" .. name, values)
  end
  return values
end

local aiFirstProfile = readAiFirstProfile()
local function aiFirstFeatureEnabled(key, defaultValue)
  local value = os.getenv(key) or aiFirstProfile[key]
  if value == nil or value == "" then
    return defaultValue
  end
  value = value:lower()
  return value == "1" or value == "true" or value == "yes" or value == "on" or value == "enabled"
end

local aiFirstAIHotkeysEnabled = aiFirstFeatureEnabled("AI_FIRST_FEATURE_AI_HOTKEYS", true)
local aiFirstNotificationsEnabled = aiFirstFeatureEnabled("AI_FIRST_FEATURE_NOTIFICATIONS", true)
local aiFirstRecordingEnabled = aiFirstFeatureEnabled("AI_FIRST_FEATURE_RECORDING", true)
local aiFirstWindowAutomationEnabled = aiFirstFeatureEnabled("AI_FIRST_FEATURE_WINDOW_AUTOMATION", true)
local aiFirstAppRoutingEnabled = aiFirstFeatureEnabled("AI_FIRST_APP_ROUTING", true)
local aiFirstRoutingPack = os.getenv("AI_FIRST_ROUTING_PACK")
  or aiFirstProfile["AI_FIRST_ROUTING_PACK"]
  or "author"
local aiFirstWorkspaceInheritanceEnabled = aiFirstWindowAutomationEnabled
  and aiFirstAppRoutingEnabled and aiFirstRoutingPack == "author"
local aiFirstNotificationApps = os.getenv("AI_FIRST_NOTIFICATION_APPS")
  or aiFirstProfile["AI_FIRST_NOTIFICATION_APPS"]
if aiFirstNotificationApps == nil then
  aiFirstNotificationApps = "warp codex idea goland"
end

local function aiFirstListContains(list, needle)
  for value in list:gmatch("%S+") do
    if value == needle then
      return true
    end
  end
  return false
end

local aerospace = "/opt/homebrew/bin/aerospace"
local aerospaceCommandTimeoutSeconds = 2.5
local sketchybar = "/opt/homebrew/bin/sketchybar"
local sketchybarUpdater = os.getenv("HOME") .. "/.config/sketchybar/plugins/aerospace_spaces_refresh.sh"
local sketchybarNotifications = os.getenv("HOME") .. "/.config/sketchybar/plugins/ai_app_notifications.sh"
-- Session-only opt-in; diagnostics are deliberately not a portable preference.
-- From the Console: wowDiagnosticsUntil = os.time() + 900 (15 minutes).
-- The writer accepts only fixed event codes, never titles or raw tool output.
local diagnosticWriter = os.getenv("HOME") .. "/.hammerspoon/diagnostics.py"
local inheritWindowSeconds = 10
local jetbrainsDefaultWorkspace = "2"
local jetbrainsInheritWindowSeconds = 120
local defaultInheritRetryDelays = { 0.15, 0.45, 0.9 }
local jetbrainsInheritRetryDelays = { 0.15, 0.45, 0.9, 1.6, 2.8, 4.5 }
local lastFocusedByBundle = {}
local focusHistoryByBundle = {}
local pendingTargetsByWindow = {}
local queryingWindows = {}
local movingWindows = {}
local movedWindows = {}
local focusRefreshTimer = nil
local focusQueryRunning = false
local focusQueryQueued = false
local workspaceSettleTimer = nil
local aiNotificationRefreshRunning = false
local aiNotificationRefreshStartedAt = 0
local aiNotificationClearTimers = {}
local aiNotificationLastClearAt = {}
local aiAttentionAppByBundle = {}
if aiFirstListContains(aiFirstNotificationApps, "warp") then aiAttentionAppByBundle["dev.warp.Warp-Stable"] = "warp" end
if aiFirstListContains(aiFirstNotificationApps, "codex") then aiAttentionAppByBundle["com.openai.codex"] = "codex" end
if aiFirstListContains(aiFirstNotificationApps, "idea") then aiAttentionAppByBundle["com.jetbrains.intellij"] = "idea" end
if aiFirstListContains(aiFirstNotificationApps, "goland") then aiAttentionAppByBundle["com.jetbrains.goland"] = "goland" end

local fixedWorkspaceAppByBundle = {}
if aiFirstAppRoutingEnabled and aiFirstRoutingPack == "author" then
  fixedWorkspaceAppByBundle = {
    ["com.blade.shadow-macos"] = "2",
    ["com.obsproject.obs-studio"] = "11",
    ["com.bilibili.bilibiliPC"] = "10",
  }
elseif aiFirstAppRoutingEnabled and aiFirstRoutingPack == "creator" then
  fixedWorkspaceAppByBundle = {
    ["com.obsproject.obs-studio"] = "stage",
  }
end

local routePolicyByBundle = {}
local routePolicyByName = {}
local function loadRoutePolicies(path, allowLayoutOnly)
  local file = io.open(path, "r")
  if not file then
    return
  end
  for line in file:lines() do
    if not line:match("^%s*#") and line:match("%S") then
      local fields = {}
      for field in (line .. "|"):gmatch("(.-)|") do
        fields[#fields + 1] = field
      end
      local kind, value, target = fields[1], fields[2], fields[3]
      local policy = fields[5] and fields[4]
        or (target == "current" and "follow" or (target == "-" and "inherit" or "fixed"))
      if policy ~= "inherit" or not allowLayoutOnly then
        if kind == "id" and value and value ~= "" then
          routePolicyByBundle[value] = policy
        elseif kind == "name" and value and value ~= "" then
          routePolicyByName[value] = policy
        end
      end
    end
  end
  file:close()
end

if aiFirstAppRoutingEnabled then
  loadRoutePolicies(
    os.getenv("HOME") .. "/.config/aerospace/routing-packs/" .. aiFirstRoutingPack .. ".conf",
    false
  )
  -- Increasing priority: shipped pack < install advisor < captured desktop <
  -- handwritten app-routes. Later exact records replace earlier policy hints.
  loadRoutePolicies(os.getenv("HOME") .. "/.config/ai-first/advisor-routes.conf", false)
  loadRoutePolicies(os.getenv("HOME") .. "/.config/ai-first/captured-routes.conf", false)
  loadRoutePolicies(os.getenv("HOME") .. "/.config/aerospace/app-routes.conf", true)
end
local workspaceLocalAppByBundle = {
  ["com.apple.finder"] = true,
  ["com.apple.Preview"] = true,
}
local terminalMasterStackAppByBundle = {
  ["dev.warp.Warp-Stable"] = true,
  ["fun.tw93.kaku"] = true,
}
local terminalMasterStackMaxWindows = 4
local terminalNewWindowPassthroughUntil = 0

local function isJetBrainsBundle(bundleID)
  return bundleID == "com.google.android.studio" or (bundleID and bundleID:match("^com%.jetbrains%.") ~= nil)
end

local function isTerminalMasterStackBundle(bundleID)
  return terminalMasterStackAppByBundle[bundleID] == true
end

local function isLikelyJetBrainsSecondaryTitle(title)
  if not title or title == "" then
    return true
  end

  -- Lua patterns do not support regex alternation. Require a word boundary so
  -- a project called SettingsService or CommitTool is not mistaken for a dialog.
  for _, prefix in ipairs({
    "Welcome to", "Settings", "Preferences", "Project Structure",
    "Run/Debug Configurations", "Edit Configuration", "Plugins", "Tip of the Day",
    "New Project", "Open File or Project", "Attach Directory", "About", "Licenses",
    "Choose", "Select", "Import", "Export", "Find", "Replace", "Search Everywhere",
    "Local History", "Commit", "Push", "Pull", "Merge", "Rebase", "Checkout",
    "Branch", "Clone Repository", "Delete", "Rename", "Remove", "Move", "Copy",
    "Add File to Git", "Edit Commit Message", "Confirm", "Discard", "Overwrite",
    "File Already Exists", "Resolve Conflicts",
  }) do
    if title:sub(1, #prefix) == prefix then
      local nextChar = title:sub(#prefix + 1, #prefix + 1)
      local suffix = title:sub(#prefix + 1)
      if nextChar == "" or nextChar:match("[%s:%-%(]") or suffix:match("^—") or suffix:match("^–") then return true end
    end
  end
  return false
end

local function appendWorkspaceCandidate(result, seen, workspace)
  if workspace and workspace ~= "" and not seen[workspace] then
    result[#result + 1] = workspace
    seen[workspace] = true
  end
end

local function log(event, exitCode)
  if type(_G.wowDiagnosticsUntil) ~= "number" or os.time() >= _G.wowDiagnosticsUntil then return end
  local task = hs.task.new("/usr/bin/python3", nil,
    { diagnosticWriter, event, tostring(tonumber(exitCode) or 0) })
  if task then task:start() end
end

local function parseFirstWindowLine(line)
  if not line or line == "" then
    return nil
  end

  local workspace, bundleID, appName, title = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
  if not workspace or workspace == "" or not bundleID or bundleID == "" then
    return nil
  end

  return {
    workspace = workspace,
    bundleID = bundleID,
    appName = appName or "",
    title = title or "",
  }
end

local function runAerospace(args, callback)
  local finished = false
  local timeoutTimer = nil
  local task = nil

  task = hs.task.new(aerospace, function(exitCode, stdout, stderr)
    if finished then
      return
    end

    finished = true
    if timeoutTimer then
      timeoutTimer:stop()
      timeoutTimer = nil
    end

    if exitCode ~= 0 then
      log("aerospace-failed", exitCode)
      callback(nil, exitCode, stderr)
      return
    end

    callback(stdout or "", exitCode, stderr)
  end, args)

  timeoutTimer = hs.timer.doAfter(aerospaceCommandTimeoutSeconds, function()
    if finished then
      return
    end

    finished = true
    if task and task:isRunning() then
      task:terminate()
    end
    log("aerospace-timeout", 124)
    callback(nil, 124, "timeout")
  end)

  task:start()
end

local function focusedAeroWindowAsync(callback)
  runAerospace({
    "list-windows",
    "--focused",
    "--format",
    "%{workspace}%{tab}%{app-bundle-id}%{tab}%{app-name}%{tab}%{window-title}",
  }, function(output)
    callback(parseFirstWindowLine((output or ""):match("([^\r\n]+)")))
  end)
end

local function rememberFocusedWindowState(focused)
  if not focused then
    return
  end

  local history = focusHistoryByBundle[focused.bundleID] or {}
  local latest = history[1]
  if not latest or latest.workspace ~= focused.workspace then
    table.insert(history, 1, {
      workspace = focused.workspace,
      appName = focused.appName,
      title = focused.title,
      at = os.time(),
    })
    while #history > 5 do
      table.remove(history)
    end
    focusHistoryByBundle[focused.bundleID] = history
  end

  lastFocusedByBundle[focused.bundleID] = {
    workspace = focused.workspace,
    appName = focused.appName,
    title = focused.title,
    at = os.time(),
  }
end

local scheduleRememberFocusedWindow

local function rememberFocusedWindow()
  if focusQueryRunning then
    focusQueryQueued = true
    return
  end

  focusQueryRunning = true
  focusedAeroWindowAsync(function(focused)
    focusQueryRunning = false
    rememberFocusedWindowState(focused)

    if focusQueryQueued then
      focusQueryQueued = false
      scheduleRememberFocusedWindow(0.05)
    end
  end)
end

scheduleRememberFocusedWindow = function(delay)
  if focusRefreshTimer then
    focusRefreshTimer:stop()
  end

  focusRefreshTimer = hs.timer.doAfter(delay or 0.05, function()
    focusRefreshTimer = nil
    rememberFocusedWindow()
  end)
end

local function recentWorkspaceCandidates(bundleID)
  local now = os.time()
  local maxAge = inheritWindowSeconds
  local result = {}
  local seen = {}

  if isJetBrainsBundle(bundleID) then
    maxAge = jetbrainsInheritWindowSeconds
  end

  for _, item in ipairs(focusHistoryByBundle[bundleID] or {}) do
    if now - item.at <= maxAge then
      appendWorkspaceCandidate(result, seen, item.workspace)
    end
  end

  local remembered = lastFocusedByBundle[bundleID]
  if remembered and now - remembered.at <= maxAge then
    appendWorkspaceCandidate(result, seen, remembered.workspace)
  end

  return result
end

local function parseWindowList(output)
  local windows = {}

  for line in (output or ""):gmatch("[^\r\n]+") do
    local id, workspace, bundleID, title = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
    if id and workspace and bundleID then
      windows[#windows + 1] = {
        id = id,
        workspace = workspace,
        bundleID = bundleID,
        title = title or "",
      }
    end
  end

  return windows
end

local function parseWindowListWithLayout(output)
  local windows = {}

  for line in (output or ""):gmatch("[^\r\n]+") do
    local id, workspace, bundleID, layout, title = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
    if id and workspace and bundleID and layout then
      windows[#windows + 1] = {
        id = id,
        workspace = workspace,
        bundleID = bundleID,
        layout = layout,
        title = title or "",
      }
    end
  end

  return windows
end

local function listAeroWindowsAsync(callback)
  runAerospace({
    "list-windows",
    "--all",
    "--format",
    "%{window-id}%{tab}%{workspace}%{tab}%{app-bundle-id}%{tab}%{window-title}",
  }, function(output)
    if not output then
      callback(nil)
      return
    end

    callback(parseWindowList(output))
  end)
end

local function listAeroWindowsWithLayoutAsync(callback)
  runAerospace({
    "list-windows",
    "--all",
    "--format",
    "%{window-id}%{tab}%{workspace}%{tab}%{app-bundle-id}%{tab}%{window-layout}%{tab}%{window-title}",
  }, function(output)
    if not output then
      callback(nil)
      return
    end

    callback(parseWindowListWithLayout(output))
  end)
end

local function focusedWorkspaceAsync(callback)
  runAerospace({
    "list-workspaces",
    "--focused",
  }, function(output)
    callback((output or ""):match("([^\r\n]+)"))
  end)
end

local function runAerospaceSequence(commands, callback)
  local index = 1

  local function nextCommand()
    local command = commands[index]
    if not command then
      if callback then
        callback(true)
      end
      return
    end

    runAerospace(command, function(_, exitCode)
      if exitCode ~= 0 then
        log("aerospace-sequence-failed")
        if callback then
          callback(false)
        end
        return
      end

      index = index + 1
      nextCommand()
    end)
  end

  nextCommand()
end

local function findAeroWindowAsync(win, bundleID, title, callback)
  local directID = tostring(win:id())
  listAeroWindowsAsync(function(windows)
    local fallback = nil
    if not windows then
      callback(nil)
      return
    end

    for _, item in ipairs(windows) do
      if item.id == directID then
        callback(item, windows)
        return
      end

      if item.bundleID == bundleID and item.title == title then
        fallback = fallback or item
      end
    end

    callback(fallback, windows)
  end)
end

local function windowKey(win, bundleID, title)
  return tostring(win:id()) .. "\t" .. bundleID .. "\t" .. title
end

local function chooseTargetWorkspace(item, workspaceCandidates)
  local targetWorkspace = workspaceCandidates[1]
  if not item then
    return targetWorkspace
  end

  if item.workspace == targetWorkspace and #workspaceCandidates > 1 then
    return workspaceCandidates[2]
  end

  for index = 2, #workspaceCandidates do
    if item.workspace == workspaceCandidates[index] then
      return item.workspace
    end
  end

  return targetWorkspace
end

local function chooseJetBrainsTargetWorkspace(item, workspaceCandidates)
  if not item then
    return workspaceCandidates[1]
  end

  for _, workspace in ipairs(workspaceCandidates) do
    if item.workspace == workspace and workspace ~= jetbrainsDefaultWorkspace then
      return workspace
    end
  end

  for _, workspace in ipairs(workspaceCandidates) do
    if workspace ~= jetbrainsDefaultWorkspace then
      return workspace
    end
  end

  return chooseTargetWorkspace(item, workspaceCandidates)
end

local function mergeJetBrainsOpenWindowCandidates(bundleID, item, workspaceCandidates, windows)
  if not isJetBrainsBundle(bundleID) or not windows then
    return workspaceCandidates
  end

  local result = {}
  local seen = {}
  for _, workspace in ipairs(workspaceCandidates) do
    appendWorkspaceCandidate(result, seen, workspace)
  end

  local currentID = item and item.id
  for _, other in ipairs(windows) do
    if other.bundleID == bundleID and other.id ~= currentID and other.workspace ~= jetbrainsDefaultWorkspace then
      appendWorkspaceCandidate(result, seen, other.workspace)
    end
  end

  for _, other in ipairs(windows) do
    if other.bundleID == bundleID and other.id ~= currentID then
      appendWorkspaceCandidate(result, seen, other.workspace)
    end
  end

  return result
end

local function refreshSketchyBar()
  if hs.fs.attributes(sketchybarUpdater, "mode") == "file" then
    hs.task.new(sketchybarUpdater, nil, {}):start()
  end
end

local function refreshAINotifications()
  if hs.fs.attributes(sketchybarNotifications, "mode") ~= "file" then
    return
  end

  if aiNotificationRefreshRunning then
    if hs.timer.secondsSinceEpoch() - aiNotificationRefreshStartedAt < 15 then
      return
    end

    if _G.wowAINotificationRefreshTask and _G.wowAINotificationRefreshTask:isRunning() then
      _G.wowAINotificationRefreshTask:terminate()
    end

    log("notification-timeout")
    aiNotificationRefreshRunning = false
    _G.wowAINotificationRefreshTask = nil
  end

  aiNotificationRefreshRunning = true
  aiNotificationRefreshStartedAt = hs.timer.secondsSinceEpoch()
  _G.wowAINotificationRefreshTask = hs.task.new(sketchybarNotifications, function(exitCode, stdout, stderr)
    aiNotificationRefreshRunning = false
    _G.wowAINotificationRefreshTask = nil
    if exitCode ~= 0 then
      log("notification-refresh-failed", exitCode)
    end
  end, { "paint" })
  _G.wowAINotificationRefreshTask:start()
end

local function triggerAINotificationSync()
  if hs.fs.attributes(sketchybar, "mode") == "file" then
    hs.task.new(sketchybar, nil, { "--trigger", "ai_notification_sync" }):start()
  end
end

local function requestClearAINotification(app)
  local now = hs.timer.secondsSinceEpoch()
  if aiNotificationLastClearAt[app] and now - aiNotificationLastClearAt[app] < 2 then
    return
  end

  if hs.fs.attributes(sketchybarNotifications, "mode") ~= "file" then
    return
  end

  aiNotificationLastClearAt[app] = now
  hs.task.new(sketchybarNotifications, function(exitCode, stdout, stderr)
    if exitCode ~= 0 then
      log("notification-clear-failed", exitCode)
      return
    end

    triggerAINotificationSync()
    hs.timer.doAfter(0.7, refreshAINotifications)
  end, { "request-clear", app }):start()
end

local function scheduleClearAINotificationForBundle(bundleID)
  local app = bundleID and aiAttentionAppByBundle[bundleID]
  if not app then
    return
  end

  if aiNotificationClearTimers[app] then
    aiNotificationClearTimers[app]:stop()
  end

  aiNotificationClearTimers[app] = hs.timer.doAfter(0.5, function()
    aiNotificationClearTimers[app] = nil
    requestClearAINotification(app)
  end)
end

local function scheduleClearAINotificationForFrontmostApp()
  local app = hs.application.frontmostApplication()
  scheduleClearAINotificationForBundle(app and app:bundleID())
end

local function scheduleWorkspaceSettle(delay)
  if workspaceSettleTimer then
    workspaceSettleTimer:stop()
  end

  workspaceSettleTimer = hs.timer.doAfter(delay or 0.08, function()
    workspaceSettleTimer = nil
    runAerospace({ "balance-sizes" }, function()
      refreshSketchyBar()
    end)
  end)
end

local function visibleWindowFrameByID()
  local frames = {}

  for _, win in ipairs(hs.window.allWindows()) do
    frames[tostring(win:id())] = win:frame()
  end

  return frames
end

local function sortWindowsByFrame(windows)
  local frames = visibleWindowFrameByID()

  table.sort(windows, function(left, right)
    local leftFrame = frames[left.id]
    local rightFrame = frames[right.id]
    if leftFrame and rightFrame then
      if math.abs(leftFrame.x - rightFrame.x) > 4 then
        return leftFrame.x < rightFrame.x
      end

      if math.abs(leftFrame.y - rightFrame.y) > 4 then
        return leftFrame.y < rightFrame.y
      end
    end

    return tonumber(left.id) < tonumber(right.id)
  end)
end

local function terminalTilingWindowsForWorkspace(windows, workspace)
  local tilingWindows = {}

  for _, item in ipairs(windows or {}) do
    if item.workspace == workspace and item.layout ~= "floating" then
      if not isTerminalMasterStackBundle(item.bundleID) then
        log("terminal-stack-skipped")
        return nil
      end
      tilingWindows[#tilingWindows + 1] = item
    end
  end

  return tilingWindows
end

local function sendNativeTerminalNewWindow()
  terminalNewWindowPassthroughUntil = hs.timer.secondsSinceEpoch() + 0.4
  hs.eventtap.keyStroke({ "cmd" }, "n", 0)
end

local function rightmostBottomWindow(windows)
  if not windows or #windows == 0 then
    return nil
  end

  local frames = visibleWindowFrameByID()
  local best = windows[1]
  local bestFrame = frames[best.id]

  for _, item in ipairs(windows) do
    local frame = frames[item.id]
    if frame then
      if not bestFrame or frame.x > bestFrame.x + 4 or (math.abs(frame.x - bestFrame.x) <= 4 and frame.y > bestFrame.y) then
        best = item
        bestFrame = frame
      end
    elseif not bestFrame and tonumber(item.id) > tonumber(best.id) then
      best = item
    end
  end

  return best
end

local function prepareTerminalSplitForNewWindow(callback)
  focusedAeroWindowAsync(function(focused)
    if not focused or not isTerminalMasterStackBundle(focused.bundleID) then
      callback()
      return
    end

    listAeroWindowsWithLayoutAsync(function(windows)
      local tilingWindows = terminalTilingWindowsForWorkspace(windows, focused.workspace)
      if not tilingWindows or #tilingWindows < 1 or #tilingWindows >= terminalMasterStackMaxWindows then
        callback()
        return
      end

      sortWindowsByFrame(tilingWindows)

      local target = tilingWindows[1]
      local splitDirection = "horizontal"
      if #tilingWindows >= 2 then
        target = rightmostBottomWindow(tilingWindows) or tilingWindows[#tilingWindows]
        splitDirection = "vertical"
      end

      log("terminal-window-split")
      runAerospaceSequence({
        { "focus", "--window-id", target.id },
        { "split", splitDirection },
      }, function()
        callback()
      end)
    end)
  end)
end

local function isPlainCommandN(event)
  if event:getKeyCode() ~= hs.keycodes.map.n then
    return false
  end

  local flags = event:getFlags()
  return flags.cmd and not flags.ctrl and not flags.alt and not flags.shift and not flags.fn
end

if _G.wowTerminalNewWindowEventTap then
  _G.wowTerminalNewWindowEventTap:stop()
  _G.wowTerminalNewWindowEventTap = nil
end

-- Opting out leaves native Command-N untouched, including key repeat.
if aiFirstWindowAutomationEnabled then
  _G.wowTerminalNewWindowEventTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    if hs.timer.secondsSinceEpoch() < terminalNewWindowPassthroughUntil then
      return false
    end

    if not isPlainCommandN(event) then
      return false
    end

    local app = hs.application.frontmostApplication()
    if not isTerminalMasterStackBundle(app and app:bundleID()) then
      return false
    end

    if event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 1 then
      return true
    end

    prepareTerminalSplitForNewWindow(sendNativeTerminalNewWindow)
    return true
  end)
  _G.wowTerminalNewWindowEventTap:start()
end

local function moveCreatedWindow(win, bundleID, title, workspaceCandidates, key)
  if not win or not win:isStandard() then
    return
  end

  if #workspaceCandidates == 0 and not isJetBrainsBundle(bundleID) then
    return
  end

  if movedWindows[key] or movingWindows[key] or queryingWindows[key] then
    return
  end

  queryingWindows[key] = true
  findAeroWindowAsync(win, bundleID, title, function(item, windows)
    queryingWindows[key] = nil
    if movedWindows[key] or movingWindows[key] or not item then
      return
    end

    local effectiveWorkspaceCandidates = mergeJetBrainsOpenWindowCandidates(bundleID, item, workspaceCandidates, windows)
    if #effectiveWorkspaceCandidates == 0 then
      return
    end

    local targetWorkspace = pendingTargetsByWindow[key]
    if not targetWorkspace then
      if isJetBrainsBundle(bundleID) then
        targetWorkspace = chooseJetBrainsTargetWorkspace(item, effectiveWorkspaceCandidates)
      else
        targetWorkspace = chooseTargetWorkspace(item, effectiveWorkspaceCandidates)
      end
      pendingTargetsByWindow[key] = targetWorkspace
      log("inherit-target")
    end

    if item.workspace == targetWorkspace then
      movedWindows[key] = true
      return
    end

    movingWindows[key] = true
    log("inherit-move")
    hs.task.new(aerospace, function(exitCode)
      movingWindows[key] = nil
      if exitCode == 0 then
        movedWindows[key] = true
        hs.timer.doAfter(0.15, refreshSketchyBar)
      else
        log("inherit-failed", exitCode)
      end
    end, {
      "move-node-to-workspace",
      "--focus-follows-window",
      "--window-id",
      item.id,
      targetWorkspace,
    }):start()
  end)
end

local function inheritWorkspaceForCreatedWindow(win)
  if not aiFirstWorkspaceInheritanceEnabled then
    return
  end
  local app = win and win:application()
  local bundleID = app and app:bundleID()
  local appName = app and app:name()
  if not bundleID or bundleID == "" then
    return
  end

  -- Context tools should stay on the workspace that created the window.
  -- Reusing their older focus history here would make them globally pinned.
  if workspaceLocalAppByBundle[bundleID] then
    return
  end

  -- Explicit follow/prefer/fixed routes are owned by AeroSpace. Inheritance is
  -- only the author pack's fallback for apps that have no route at all.
  if routePolicyByBundle[bundleID] or (appName and routePolicyByName[appName]) then
    return
  end

  if fixedWorkspaceAppByBundle[bundleID] then
    log("inherit-fixed-skipped")
    return
  end

  local workspaceCandidates = recentWorkspaceCandidates(bundleID)
  if #workspaceCandidates == 0 and not isJetBrainsBundle(bundleID) then
    return
  end

  local title = win:title() or ""
  local key = windowKey(win, bundleID, title)
  local retryDelays = defaultInheritRetryDelays

  if isJetBrainsBundle(bundleID) then
    retryDelays = jetbrainsInheritRetryDelays
  end

  log("window-created")
  for _, delay in ipairs(retryDelays) do
    hs.timer.doAfter(delay, function()
      moveCreatedWindow(win, bundleID, title, workspaceCandidates, key)
    end)
  end

  hs.timer.doAfter(inheritWindowSeconds + 2, function()
    pendingTargetsByWindow[key] = nil
    queryingWindows[key] = nil
    movingWindows[key] = nil
    movedWindows[key] = nil
  end)
end

local function repairJetBrainsSecondaryWindow(win)
  if not aiFirstWindowAutomationEnabled or not aiFirstAppRoutingEnabled then
    return
  end
  local app = win and win:application()
  local bundleID = app and app:bundleID()
  local title = win and (win:title() or "") or ""

  if isJetBrainsBundle(bundleID) and isLikelyJetBrainsSecondaryTitle(title) then
    inheritWorkspaceForCreatedWindow(win)
  end
end

local function repairExistingJetBrainsSecondaryWindows()
  if not aiFirstWindowAutomationEnabled or not aiFirstAppRoutingEnabled then
    return
  end
  listAeroWindowsAsync(function(windows)
    if not windows then
      return
    end

    for _, item in ipairs(windows) do
      if isJetBrainsBundle(item.bundleID) and isLikelyJetBrainsSecondaryTitle(item.title) then
        local candidates = mergeJetBrainsOpenWindowCandidates(item.bundleID, item, recentWorkspaceCandidates(item.bundleID), windows)
        local targetWorkspace = chooseJetBrainsTargetWorkspace(item, candidates)
        if targetWorkspace and item.workspace ~= targetWorkspace then
          log("dialog-repair")
          hs.task.new(aerospace, function(exitCode)
            if exitCode == 0 then
              hs.timer.doAfter(0.15, refreshSketchyBar)
            else
              log("dialog-repair-failed", exitCode)
            end
          end, {
            "move-node-to-workspace",
            "--focus-follows-window",
            "--window-id",
            item.id,
            targetWorkspace,
          }):start()
        end
      end
    end
  end)
end

local function scheduleExistingJetBrainsRepair(delay)
  if not aiFirstWindowAutomationEnabled then
    return
  end
  if _G.wowJetBrainsRepairTimer then
    _G.wowJetBrainsRepairTimer:stop()
  end

  _G.wowJetBrainsRepairTimer = hs.timer.doAfter(delay or 0.4, function()
    _G.wowJetBrainsRepairTimer = nil
    repairExistingJetBrainsSecondaryWindows()
  end)
end

hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function(win)
  repairJetBrainsSecondaryWindow(win)
  if aiFirstWindowAutomationEnabled then
    scheduleRememberFocusedWindow(0.05)
  end
  local app = win and win:application()
  if aiFirstNotificationsEnabled then
    scheduleClearAINotificationForBundle(app and app:bundleID())
  end
end)

hs.window.filter.default:subscribe(hs.window.filter.windowCreated, function(win)
  inheritWorkspaceForCreatedWindow(win)
end)

hs.window.filter.default:subscribe(hs.window.filter.windowTitleChanged, repairJetBrainsSecondaryWindow)

hs.window.filter.default:subscribe(hs.window.filter.windowDestroyed, function()
  if aiFirstWindowAutomationEnabled then
    scheduleWorkspaceSettle(0.08)
  end
end)

local aiHotkeys = os.getenv("HOME") .. "/.hammerspoon/ai_hotkeys.lua"
if aiFirstAIHotkeysEnabled and hs.fs.attributes(aiHotkeys, "mode") == "file" then
  dofile(aiHotkeys)
end

local appReveal = os.getenv("HOME") .. "/.hammerspoon/app_reveal.lua"
if aiFirstNotificationsEnabled and hs.fs.attributes(appReveal, "mode") == "file" then
  dofile(appReveal)
elseif _G.wowAppRevealWatcher then
  _G.wowAppRevealWatcher:stop()
  _G.wowAppRevealWatcher = nil
end

local airForceQuit = os.getenv("HOME") .. "/.hammerspoon/air_force_quit.lua"
if hs.fs.attributes(airForceQuit, "mode") == "file" then
  dofile(airForceQuit)
end

local screencastWindow = os.getenv("HOME") .. "/.hammerspoon/screencast.lua"
if aiFirstRecordingEnabled and hs.fs.attributes(screencastWindow, "mode") == "file" then
  dofile(screencastWindow)
end

if aiFirstWindowAutomationEnabled then
  scheduleRememberFocusedWindow(0.05)
end
scheduleExistingJetBrainsRepair(0.4)
if aiFirstNotificationsEnabled then
  if _G.wowAINotificationRefreshTimer then
    _G.wowAINotificationRefreshTimer:stop()
  end
  _G.wowAINotificationRefreshTimer = hs.timer.doEvery(5, function()
    scheduleClearAINotificationForFrontmostApp()
    refreshAINotifications()
  end)
  hs.timer.doAfter(1, function()
    scheduleClearAINotificationForFrontmostApp()
    refreshAINotifications()
  end)
  if _G.wowAIApplicationWatcher then
    _G.wowAIApplicationWatcher:stop()
  end
  _G.wowAIApplicationWatcher = hs.application.watcher.new(function(appName, eventType, app)
    if eventType == hs.application.watcher.activated then
      scheduleClearAINotificationForBundle(app and app:bundleID())
      if isJetBrainsBundle(app and app:bundleID()) then
        scheduleExistingJetBrainsRepair(0.2)
      end
    end
  end)
  _G.wowAIApplicationWatcher:start()
else
  if _G.wowAINotificationRefreshTimer then
    _G.wowAINotificationRefreshTimer:stop()
    _G.wowAINotificationRefreshTimer = nil
  end
  if _G.wowAIApplicationWatcher then
    _G.wowAIApplicationWatcher:stop()
    _G.wowAIApplicationWatcher = nil
  end
end
log("watcher-started")
return { isLikelyJetBrainsSecondaryTitle = isLikelyJetBrainsSecondaryTitle }
