-- Execute the actual init under a quiet profile with effect-recording doubles.
-- No real Hammerspoon, IPC, window movement, timer or log file is used.
local repo = assert(arg[1])
local subscriptions = {}
local timers, tasks, eventTaps = 0, 0, 0
local realOpen = io.open
io.open = function(path, mode)
  if path == "/tmp/hammerspoon-workspace-inherit.log" then
    return { write = function() end, close = function() end }
  end
  return realOpen(path, mode)
end
hs = {
  fs = { attributes = function(path)
    -- A deployed app_reveal.lua must not register its notification watcher.
    if path:match("/app_reveal%.lua$") then return "file" end
    return nil
  end },
  window = { filter = {
    windowFocused = "focus", windowCreated = "create",
    windowTitleChanged = "title", windowDestroyed = "destroy",
    default = { subscribe = function(_, event, fn) subscriptions[event] = fn end },
  } },
  eventtap = { new = function() eventTaps = eventTaps + 1; error("unexpected key interception") end },
  timer = {
    doAfter = function() timers = timers + 1; error("unexpected background timer") end,
    doEvery = function() timers = timers + 1; error("unexpected polling") end,
  },
  task = { new = function() tasks = tasks + 1; error("unexpected external task") end },
  autoLaunch = function() end,
}
local stoppedOldWatcher = false
_G.wowAppRevealWatcher = { stop = function() stoppedOldWatcher = true end }
dofile(repo .. "/home/.hammerspoon/init.lua")
assert(stoppedOldWatcher and _G.wowAppRevealWatcher == nil, "notification opt-out must stop the activation watcher")
for _, event in ipairs({ "focus", "create", "title", "destroy" }) do
  assert(subscriptions[event], "missing event double")
  subscriptions[event](nil)
end
assert(timers == 0 and tasks == 0 and eventTaps == 0, "quiet mode must not interfere with windows")

-- Execute the real recording entry. Resolve its workspace using the real
-- read-only helper inside the test HOME, but never launch or move a real app.
local destination, alert
local win = {
  id = function() return 123 end, isStandard = function() return true end,
  isVisible = function() return true end, isMinimized = function() return false end,
}
hs.execute = function(command)
  local pipe = assert(io.popen(command))
  local output = pipe:read("*a")
  local ok = pipe:close()
  return output, ok == true
end
hs.fs.attributes = function() return "file" end
hs.hotkey = { bind = function() end }
hs.alert = { show = function(message) alert = message end }
hs.task.new = function(_, _, args)
  assert(args[1] == "move-node-to-workspace", "unexpected operation")
  destination = args[#args]
  return { start = function() end }
end
local recording = dofile(repo .. "/home/.hammerspoon/screencast.lua")
recording.enterRecordingMode("16x9", win)
assert(destination == "2", "recording must move to the primary-screen task role")

-- Reload-free profile/overlay changes are visible on the next invocation.
local overlay = assert(realOpen(os.getenv("HOME") .. "/.config/ai-first/modules/test-quiet/recording-test.conf", "w"))
overlay:write('AEROSPACE_WORKSPACE_ROLE_MAP="stage:6"\n')
overlay:close()
recording.enterRecordingMode("16x9", win)
assert(destination == "6", "recording must read module overlays on invocation")

overlay = assert(realOpen(os.getenv("HOME") .. "/.config/ai-first/modules/test-quiet/recording-test.conf", "w"))
overlay:write('AEROSPACE_WORKSPACE_ROLE_MAP="stage:99"\n')
overlay:close()
destination = nil
recording.enterRecordingMode("16x9", win)
assert(destination == nil and alert:match("invalid"), "invalid target must not move a window")
print("quiet_profile_runtime.lua: window opt-out and recording target passed")
