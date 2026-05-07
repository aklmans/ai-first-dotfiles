local aerospace = "/opt/homebrew/bin/aerospace"

local module = {}
local pendingWindow = nil
local home = os.getenv("HOME") or ""
local sketchybarSpaceScript = home .. "/.config/aerospace/toggle-sketchybar-space.sh"
local recordingWorkspace = "13"
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

local function runAerospace(args, callback)
  if hs.fs.attributes(aerospace, "mode") ~= "file" then
    if callback then
      callback(false)
    end
    return
  end

  hs.task.new(aerospace, function(exitCode)
    if callback then
      callback(exitCode == 0)
    end
  end, args):start()
end

local function runShell(command, args, callback)
  hs.task.new(command, function(exitCode)
    if callback then
      callback(exitCode == 0)
    end
  end, args):start()
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
  return win and win:isStandard() and win:isVisible() and not win:isMinimized()
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
  if standardVisibleWindow(winOverride) then
    return winOverride
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

  win:focus()
  runAerospace(layoutArgsForWindow(win, "floating"), function()
    hs.timer.doAfter(0.08, function()
      if not win:isStandard() then
        hs.alert.show("Focused window cannot be resized")
        if callback then
          callback(false)
        end
        return
      end

      win:setFrame(rect, 0)
      win:focus()
      hs.alert.show(string.format("%s: %dx%d", label, rect.w, rect.h), 0.8)
      if callback then
        callback(true)
      end
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
  local win = targetWindow(winOverride)
  if not win then
    hs.alert.show("No focused window")
    return
  end

  local presetName = name or "16x9"

  moveWindowToWorkspace(win, recordingWorkspace, function(ok)
    if not ok then
      hs.alert.show("Could not move window to recording workspace")
      return
    end

    hs.timer.doAfter(0.25, function()
      setSketchybarSpaceMode("hide", function()
        hs.timer.doAfter(0.25, function()
          applyPreset(presetName, win, {
            topInset = recordingTopInset,
            label = "Recording Mode",
          }, function(ok)
            if ok and not openRecorder() then
              hs.alert.show("Recording mode ready")
            end
          end)
        end)
      end)
    end)
  end)
end

function module.exitRecordingMode()
  setSketchybarSpaceMode("show", function()
    hs.alert.show("Recording Mode off", 0.8)
  end)
end

function module.showChooser()
  pendingWindow = targetWindow()

  local choices = {
    { text = "Enter Recording Mode", subText = "Move focused window to workspace 13, hide bar, fit 16:9, open recorder", value = "recording" },
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
