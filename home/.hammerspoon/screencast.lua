local aerospace = "/opt/homebrew/bin/aerospace"

local module = {}
local pendingWindow = nil

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

local function activeScreenFrame(win)
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
  local sketchybarTopInset = 95
  local usable = {
    x = fullFrame.x + 20,
    y = fullFrame.y + math.max(topInset, sketchybarTopInset),
    w = fullFrame.w - 40,
    h = fullFrame.h - math.max(topInset, sketchybarTopInset) - bottomInset - 20,
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

local function applyFrameAfterFloating(win, rect, label)
  if not win then
    hs.alert.show("No focused window")
    return
  end

  runAerospace({ "layout", "floating" }, function()
    hs.timer.doAfter(0.08, function()
      if not win:isStandard() then
        hs.alert.show("Focused window cannot be resized")
        return
      end

      win:setFrame(rect, 0)
      win:focus()
      hs.alert.show(string.format("%s: %dx%d", label, rect.w, rect.h), 0.8)
    end)
  end)
end

function module.apply(name, winOverride)
  local preset = presets[name] or presets["720p"]
  local win = winOverride or hs.window.focusedWindow()
  if not win then
    hs.alert.show("No focused window")
    return
  end

  local frame = activeScreenFrame(win)
  if not frame then
    hs.alert.show("No active screen")
    return
  end

  applyFrameAfterFloating(win, fitRect(frame, preset), preset.label)
end

function module.restoreTiling()
  runAerospace({ "layout", "tiling" }, function(ok)
    if ok then
      hs.alert.show("Window restored to tiling", 0.8)
    end
  end)
end

function module.showChooser()
  pendingWindow = hs.window.focusedWindow()

  local choices = {
    { text = "720p recording window", subText = "1280x720 canvas with safe gutters", value = "720p" },
    { text = "1080p recording window", subText = "1920x1080 canvas, scaled down if needed", value = "1080p" },
    { text = "16:9 centered recording window", subText = "Max usable 16:9 region on current display", value = "16x9" },
  }

  local chooser = hs.chooser.new(function(choice)
    if choice then
      module.apply(choice.value, pendingWindow)
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

_G.ScreencastWindow = module

return module
