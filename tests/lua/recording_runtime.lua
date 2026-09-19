-- Failure injection through the real recording module; no real IPC or windows.
local repo = assert(arg[1])
local cases = 0
local function scenario(failure)
  local operations, alerts, queue, rect, opens, terminated = {}, {}, {}, nil, 0, false
  local lateCallback
  local win = {
    id = function() return 123 end,
    isStandard = function() return failure ~= "disappeared" or #operations == 0 end,
    isVisible = function() return true end,
    isMinimized = function() return false end,
    focus = function() end,
    screen = function() return {
      fullFrame = function() return { x=0, y=0, w=2560, h=1440 } end,
      frame = function() return { x=0, y=25, w=2560, h=1415 } end,
    } end,
    setFrame = function(_, target)
      operations[#operations+1] = "resize"
      if failure ~= "resize" then rect = target end
    end,
    frame = function() return rect or {x=0,y=0,w=100,h=100} end,
  }
  hs = {
    execute = function() return "4\n", true end,
    fs = { attributes = function() return "file" end },
    hotkey = { bind = function() end },
    alert = { show = function(s) alerts[#alerts+1] = s end },
    timer = { doAfter = function(delay, callback)
      local timer = { active=true, delay=delay, callback=callback }
      function timer:stop() self.active=false end
      queue[#queue+1] = timer
      return timer
    end },
    application = { launchOrFocusByBundleID = function()
      opens=opens+1; return failure ~= "recorder"
    end },
    task = { new = function(command, callback, args)
      local stage = args[1] == "move-node-to-workspace" and "move"
        or (args[1] == "layout" and "float" or "bar")
      operations[#operations+1] = stage
      if failure == "create" then return nil end
      return {
        start = function(self)
          if failure == "start" then return false end
          if failure == "timeout" then lateCallback=callback; return self end
          callback(failure == stage and 1 or 0)
          return self
        end,
        isRunning = function() return true end,
        terminate = function() terminated=true end,
      }
    end },
  }
  local recording = dofile(repo .. "/home/.hammerspoon/screencast.lua")
  recording.enterRecordingMode("16x9", win)
  if failure == "timeout" then
    recording.enterRecordingMode("16x9", win)
    assert(#operations == 1, "parallel preparations must be refused")
  end
  -- Canceled timers remain in the queue; emulate their actual lifecycle.
  local count=0
  while #queue > 0 do
    local item = table.remove(queue, 1)
    if item.active then item.callback() end
    count=count+1; assert(count<30, "unexpected timer loop")
  end
  if lateCallback then lateCallback(0) end
  local expected = ({ move="move", start="move", create="move", timeout="move", disappeared="move",
    bar="move,bar", float="move,bar,float", resize="move,bar,float,resize" })[failure]
    or "move,bar,float,resize"
  assert(table.concat(operations, ",") == expected, failure .. ": continued after failure")
  if expected ~= "move,bar,float,resize" or failure == "resize" then
    assert(opens == 0, failure .. ": recorder launched after failure")
    assert(not table.concat(alerts):match("Recording Mode:"), "false success alert")
  end
  if failure == "timeout" then assert(terminated) end
  if failure == "ok" then assert(opens==1 and rect.w>0) end
  if failure == "recorder" then assert(table.concat(alerts):match("no supported recorder")) end
  cases=cases+1
end
for _, failure in ipairs({ "move", "bar", "float", "resize", "start", "create", "timeout", "disappeared", "recorder", "ok" }) do
  scenario(failure)
end
print("recording_runtime.lua: " .. cases .. " failure/success scenarios passed")
