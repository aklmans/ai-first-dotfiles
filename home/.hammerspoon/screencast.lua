local aerospace = "/opt/homebrew/bin/aerospace"

local module = {}
local pendingWindow = nil
local preparing = false
local home = os.getenv("HOME") or ""
local sketchybarSpaceScript = home .. "/.config/aerospace/toggle-sketchybar-space.sh"
local recordingTargetScript = home .. "/.config/aerospace/recording-target.sh"

-- Resolve on invocation so a profile edit takes effect without a Lua reload.
-- This helper is read-only and shares AeroSpace's data parser and overlays.
local function recordingWorkspace()
  local quoted = "'" .. recordingTargetScript:gsub("'", "'\\''") .. "'"
  local output, ok = hs.execute("/bin/bash " .. quoted .. " 2>/dev/null", false)
  local workspace = ok and output and output:match("^([%w_-]+)%s*$")
  return workspace or nil
end
local recordingTopInset = 20
local recorderBundleIDs = {
  "com.techsmith.camtasia",
  "com.TechSmith.Snagit",
}

local presets = {
  ["720p"] = {
    label = "Screencast 720p",
    canvasWidth = 1280,
    canvasHeight = 720,
    gutter = 20,
    bottomGutter = 45,
  },
  ["1080p"] = {
    label = "Screencast 1080p",
    canvasWidth = 1920,
    canvasHeight = 1080,
    gutter = 28,
    bottomGutter = 56,
  },
  ["16x9"] = {
    label = "Screencast 16:9",
    aspect = 16 / 9,
    gutter = 24,
    bottomGutter = 48,
  },
}

local function runShell(command, args, callback)
  local finished, timer, task = false, nil, nil
  local function done(ok)
    if finished then return end
    finished = true
    if timer then timer:stop() end
    if callback then callback(ok) end
  end
  task = hs.task.new(command, function(exitCode) done(exitCode == 0) end, args)
  if not task or not task:start() then done(false); return end
  if not finished then
    timer = hs.timer.doAfter(15, function()
      if finished then return end
      if task:isRunning() then task:terminate() end
      done(false)
    end)
  end
end

local function runAerospace(args, callback)
  if hs.fs.attributes(aerospace, "mode") ~= "file" then
    if callback then callback(false) end
    return
  end
  runShell(aerospace, args, callback)
end

local function setSketchybarSpaceMode(mode, callback)
  if hs.fs.attributes(sketchybarSpaceScript, "mode") ~= "file" then
    if callback then
      callback(false)
    end
    return
  end

  runShell("/bin/bash", { sketchybarSpaceScript, mode }, callback)
end

local function openRecorder()
  for _, bundleID in ipairs(recorderBundleIDs) do
    if hs.application.launchOrFocusByBundleID(bundleID) then
      return true
    end
  end

  return false
end

local function standardVisibleWindow(win)
  if not win then return false end
  local ok, visible = pcall(function()
    return win:id() ~= nil and win:isStandard() and win:isVisible() and not win:isMinimized()
  end)
  return ok and visible
end

local function frontmostAppWindow()
  local app = hs.application.frontmostApplication()
  if not app then
    return nil
  end

  local candidates = {
    app:focusedWindow(),
    app:mainWindow(),
  }

  for _, win in ipairs(candidates) do
    if standardVisibleWindow(win) then
      return win
    end
  end

  for _, win in ipairs(app:allWindows()) do
    if standardVisibleWindow(win) then
      return win
    end
  end

  return nil
end

local function targetWindow(winOverride)
  if winOverride then
    -- An explicitly selected window disappearing is not permission to resize
    -- whatever unrelated window happened to gain focus in the meantime.
    return standardVisibleWindow(winOverride) and winOverride or nil
  end

  local focused = hs.window.focusedWindow()
  if standardVisibleWindow(focused) then
    return focused
  end

  return frontmostAppWindow()
end

local function layoutArgsForWindow(win, layout)
  local windowID = win and win:id()
  if windowID then
    return { "layout", "--window-id", tostring(windowID), layout }
  end

  return { "layout", layout }
end

local function moveWindowToWorkspace(win, workspace, callback)
  local args = { "move-node-to-workspace", "--focus-follows-window" }
  local windowID = win and win:id()

  if not windowID then callback(false); return end

  if windowID then
    table.insert(args, "--window-id")
    table.insert(args, tostring(windowID))
  end

  table.insert(args, workspace)
  runAerospace(args, callback)
end

local function activeScreenFrame(win, sketchybarTopInset)
  local screen = win and win:screen() or hs.screen.mainScreen()
  if not screen then
    return nil
  end

  local fullFrame = screen.fullFrame and screen:fullFrame() or screen:frame()
  local visibleFrame = screen:frame()
  local topInset = math.max(visibleFrame.y - fullFrame.y, 0)
  local bottomInset = math.max((fullFrame.y + fullFrame.h) - (visibleFrame.y + visibleFrame.h), 0)

  -- SketchyBar is not part of macOS visibleFrame, so reserve the same top
  -- space used by the AeroSpace outer gap.
  local topInsetReserve = sketchybarTopInset or 95
  local usable = {
    x = fullFrame.x + 20,
    y = fullFrame.y + math.max(topInset, topInsetReserve),
    w = fullFrame.w - 40,
    h = fullFrame.h - math.max(topInset, topInsetReserve) - bottomInset - 20,
  }

  return usable
end

local function fitRect(frame, preset)
  local gutter = preset.gutter or 20
  local bottomGutter = preset.bottomGutter or gutter
  local maxWidth = math.max(frame.w - gutter * 2, 320)
  local maxHeight = math.max(frame.h - gutter - bottomGutter, 240)
  local targetWidth = maxWidth
  local targetHeight = maxHeight

  if preset.canvasWidth and preset.canvasHeight then
    targetWidth = preset.canvasWidth - gutter * 2
    targetHeight = preset.canvasHeight - gutter - bottomGutter

    local scale = math.min(1, maxWidth / targetWidth, maxHeight / targetHeight)
    targetWidth = math.floor(targetWidth * scale)
    targetHeight = math.floor(targetHeight * scale)
  elseif preset.aspect then
    targetWidth = maxWidth
    targetHeight = math.floor(targetWidth / preset.aspect)
    if targetHeight > maxHeight then
      targetHeight = maxHeight
      targetWidth = math.floor(targetHeight * preset.aspect)
    end
  end

  return {
    x = math.floor(frame.x + (frame.w - targetWidth) / 2),
    y = math.floor(frame.y + gutter),
    w = targetWidth,
    h = targetHeight,
  }
end

local function applyFrameAfterFloating(win, rect, label, callback)
  if not win then
    hs.alert.show("No focused window")
    if callback then
      callback(false)
    end
    return
  end

  if not pcall(function() win:focus() end) then
    hs.alert.show("Recording window is no longer available")
    if callback then callback(false) end
    return
  end
  runAerospace(layoutArgsForWindow(win, "floating"), function(ok)
    if not ok then
      hs.alert.show("Could not float recording window; preparation stopped")
      if callback then callback(false) end
      return
    end
    hs.timer.doAfter(0.08, function()
      if not standardVisibleWindow(win) then
        hs.alert.show("Focused window cannot be resized")
        if callback then
          callback(false)
        end
        return
      end

      local resized = pcall(function() win:setFrame(rect, 0) end)
      hs.timer.doAfter(0.15, function()
        local readOK, actual = pcall(function() return win:frame() end)
        local matches = resized and readOK and actual ~= nil
        for _, key in ipairs({ "x", "y", "w", "h" }) do
          matches = matches and type(actual[key]) == "number" and math.abs(actual[key] - rect[key]) <= 3
        end
        if not matches then
          hs.alert.show("Recording window refused the requested size; preparation stopped")
          if callback then callback(false) end
          return
        end
        win:focus()
        hs.alert.show(string.format("%s: %dx%d points", label, rect.w, rect.h), 0.8)
        if callback then callback(true) end
      end)
    end)
  end)
end

local function applyPreset(name, winOverride, options, callback)
  local preset = presets[name] or presets["720p"]
  local win = targetWindow(winOverride)
  if not win then
    hs.alert.show("No focused window")
    if callback then
      callback(false)
    end
    return
  end

  local frame = activeScreenFrame(win, options and options.topInset)
  if not frame then
    hs.alert.show("No active screen")
    if callback then
      callback(false)
    end
    return
  end

  applyFrameAfterFloating(win, fitRect(frame, preset), (options and options.label) or preset.label, callback)
end

function module.apply(name, winOverride)
  applyPreset(name, winOverride)
end

function module.restoreTiling()
  local win = targetWindow()
  if not win then
    hs.alert.show("No focused window")
    return
  end

  runAerospace(layoutArgsForWindow(win, "tiling"), function(ok)
    if ok then
      hs.alert.show("Window restored to tiling", 0.8)
    end
  end)
end

function module.enterRecordingMode(name, winOverride)
  if preparing then hs.alert.show("Recording preparation is already running"); return end
  local workspace = recordingWorkspace()
  if not workspace then
    hs.alert.show("Recording workspace is invalid; run AeroSpace plan.sh --check")
    return
  end
  local win = targetWindow(winOverride)
  if not win then
    hs.alert.show("No focused window")
    return
  end

  local presetName = name or "16x9"
  preparing = true
  local function stop(message)
    preparing = false
    if message then hs.alert.show(message .. "; earlier steps may remain applied") end
  end

  moveWindowToWorkspace(win, workspace, function(ok)
    if not ok then
      stop("Could not move window to recording workspace")
      return
    end

    hs.timer.doAfter(0.25, function()
      if not standardVisibleWindow(win) then stop("Recording window disappeared"); return end
      setSketchybarSpaceMode("hide", function(hidden)
        if not hidden then stop("Could not hide the bar / compact gaps"); return end
        hs.timer.doAfter(0.25, function()
          applyPreset(presetName, win, {
            topInset = recordingTopInset,
            label = "Recording Mode",
          }, function(ok)
            stop()
            if ok and not openRecorder() then
              hs.alert.show("Window prepared; no supported recorder could be opened")
            end
          end)
        end)
      end)
    end)
  end)
end

function module.exitRecordingMode()
  if preparing then hs.alert.show("Wait for recording preparation to finish"); return end
  setSketchybarSpaceMode("show", function(ok)
    hs.alert.show(ok and "Bar / gaps restored (window remains floating)" or "Could not restore bar / gaps", 1.5)
  end)
end

function module.showChooser()
  pendingWindow = targetWindow()

  local choices = {
    {
      text = "Enter Recording Mode",
      subText = string.format(
        "Move focused window to workspace %s, hide bar, fit 16:9, open recorder",
        recordingWorkspace() or "(not configured)"
      ),
      value = "recording",
    },
    { text = "720p recording window", subText = "1280x720 canvas with safe gutters", value = "720p" },
    { text = "1080p recording window", subText = "1920x1080 canvas, scaled down if needed", value = "1080p" },
    { text = "16:9 centered recording window", subText = "Max usable 16:9 region on current display", value = "16x9" },
    { text = "Exit Recording Mode", subText = "Restore SketchyBar and normal AeroSpace top gap", value = "recording-off" },
  }

  local chooser = hs.chooser.new(function(choice)
    if choice then
      if choice.value == "recording" then
        module.enterRecordingMode("16x9", pendingWindow)
      elseif choice.value == "recording-off" then
        module.exitRecordingMode()
      else
        module.apply(choice.value, pendingWindow)
      end
    end
    pendingWindow = nil
  end)

  chooser:choices(choices)
  chooser:placeholderText("Screencast Window Preset")
  chooser:show()
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "R", function()
  module.apply("720p")
end)

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "F", function()
  module.apply("16x9")
end)

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "0", module.showChooser)
hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "T", module.restoreTiling)
hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "M", function()
  module.enterRecordingMode("16x9")
end)
hs.hotkey.bind({ "ctrl", "alt", "cmd", "shift" }, "M", module.exitRecordingMode)

_G.ScreencastWindow = module

return module
