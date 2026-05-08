local aerospace = "/opt/homebrew/bin/aerospace"
local sketchybar = "/opt/homebrew/bin/sketchybar"
local sketchybarNotifications = os.getenv("HOME") .. "/.config/sketchybar/plugins/ai_app_notifications.sh"
local logPath = "/tmp/hammerspoon-app-reveal.log"
local revealDelaySeconds = 0.12
local revealCooldownSeconds = 0.8
local clearAttentionCooldownSeconds = 1.5
local lastRevealAtByBundle = {}
local lastClearAttentionAtByBundle = {}

local revealAppByBundle = {
  ["dev.warp.Warp-Stable"] = "warp",
  ["com.openai.codex"] = "codex",
  ["com.jetbrains.intellij"] = "idea",
  ["com.jetbrains.goland"] = "goland",
}

local function log(message)
  local file = io.open(logPath, "a")
  if file then
    file:write(os.date("%Y-%m-%d %H:%M:%S "), message, "\n")
    file:close()
  end
end

local function runAerospace(args, callback)
  if hs.fs.attributes(aerospace, "mode") ~= "file" then
    log("missing aerospace binary: " .. aerospace)
    return
  end

  hs.task.new(aerospace, function(exitCode, stdout, stderr)
    if exitCode ~= 0 then
      log("aerospace failed exit=" .. tostring(exitCode) .. " args=" .. table.concat(args, " ") .. " stderr=" .. (stderr or ""))
      if callback then
        callback(nil, exitCode, stderr)
      end
      return
    end

    if callback then
      callback(stdout or "", exitCode, stderr)
    end
  end, args):start()
end

local function parseWindowList(output)
  local windows = {}

  for line in (output or ""):gmatch("[^\r\n]+") do
    local id, workspace, title = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
    if id and id ~= "" and workspace and workspace ~= "" then
      windows[#windows + 1] = {
        id = id,
        workspace = workspace,
        title = title or "",
      }
    end
  end

  return windows
end

local function chooseWindow(windows)
  local fallback = nil

  for _, item in ipairs(windows or {}) do
    fallback = fallback or item
    if item.title and item.title ~= "" then
      return item
    end
  end

  return fallback
end

local function revealBundle(bundleID)
  local attentionApp = revealAppByBundle[bundleID]
  if not attentionApp then
    return
  end

  local now = hs.timer.secondsSinceEpoch()
  if lastRevealAtByBundle[bundleID] and now - lastRevealAtByBundle[bundleID] < revealCooldownSeconds then
    return
  end
  lastRevealAtByBundle[bundleID] = now

  runAerospace({
    "list-windows",
    "--monitor",
    "all",
    "--app-bundle-id",
    bundleID,
    "--format",
    "%{window-id}%{tab}%{workspace}%{tab}%{window-title}",
  }, function(output)
    local target = chooseWindow(parseWindowList(output))
    if not target then
      log("no window for " .. bundleID)
      return
    end

    log("reveal " .. bundleID .. " window=" .. target.id .. " workspace=" .. target.workspace .. " title=" .. target.title)
    runAerospace({ "workspace", target.workspace }, function()
      runAerospace({ "focus", "--window-id", target.id }, function()
        if hs.fs.attributes(sketchybarNotifications, "mode") == "file" then
          hs.task.new(sketchybarNotifications, function()
            if hs.fs.attributes(sketchybar, "mode") == "file" then
              hs.task.new(sketchybar, nil, { "--trigger", "ai_notification_sync" }):start()
            end
          end, { "request-clear", attentionApp }):start()
        end
      end)
    end)
  end)
end

local function clearAttention(bundleID)
  local attentionApp = revealAppByBundle[bundleID]
  if not attentionApp then
    return
  end

  local now = hs.timer.secondsSinceEpoch()
  if lastClearAttentionAtByBundle[bundleID] and now - lastClearAttentionAtByBundle[bundleID] < clearAttentionCooldownSeconds then
    return
  end
  lastClearAttentionAtByBundle[bundleID] = now

  if hs.fs.attributes(sketchybarNotifications, "mode") ~= "file" then
    return
  end

  log("clear attention " .. bundleID)
  hs.task.new(sketchybarNotifications, function()
    if hs.fs.attributes(sketchybar, "mode") == "file" then
      hs.task.new(sketchybar, nil, { "--trigger", "ai_notification_sync" }):start()
    end
  end, { "request-clear", attentionApp }):start()
end

if _G.wowAppRevealWatcher then
  _G.wowAppRevealWatcher:stop()
end

_G.wowAppRevealWatcher = hs.application.watcher.new(function(appName, eventType, app)
  if eventType ~= hs.application.watcher.activated then
    return
  end

  local bundleID = app and app:bundleID()
  if not bundleID or not revealAppByBundle[bundleID] then
    return
  end

  hs.timer.doAfter(revealDelaySeconds, function()
    clearAttention(bundleID)
  end)
end)

_G.wowAppRevealWatcher:start()
log("app attention clear watcher started")
