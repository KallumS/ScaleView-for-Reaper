--[[ Drives a real ScaleView script over a corpus of chords. Reads lines of
     space-separated MIDI note numbers on stdin, writes "notes<TAB>name". The
     mocks are the test suite's, so this names chords exactly as the script
     does in REAPER. ]]
local SCRIPT = arg[1]
local SCALE  = arg[2]          -- optional scale to select first

local ext, drawn, texts, deferred = {}, {}, {}, nil
local now = 1000.0
local history, sequence = {}, 0
local clickLabel = nil

--  REAPER's input history is a bounded ring, and the script only ever walks
--  back as far as the sequence number it finished on last time, so anything
--  older than one poll is dead weight. Keeping it was quadratic - inserting at
--  position 1 shifts the whole table - and over a large corpus that was the
--  difference between minutes and an hour. HISTORY_KEEP is far above the
--  script's own MAX_EVENTS_PER_POLL of 64, so nothing it could ask for is
--  ever discarded.
local HISTORY_KEEP = 256

local function pushEvent(message)
  sequence = sequence + 1
  table.insert(history, 1, {seq = sequence, msg = message})
  if #history > HISTORY_KEEP then
    for i = #history, HISTORY_KEEP + 1, -1 do history[i] = nil end
  end
end
local function noteOn(n)  pushEvent(string.char(0x90, n, 100)) end
local function allOff()   pushEvent(string.char(0xB0, 123, 0)) end

reaper = {
  SetExtState = function(s, k, v) ext[s .. ":" .. k] = v end,
  GetExtState = function(s, k) return ext[s .. ":" .. k] or "" end,
  defer = function(f) deferred = f end,
  atexit = function() end,
  time_precise = function() return now end,
  EnumProjects = function() return nil end,
  SetProjExtState = function() return 1 end,
  GetProjExtState = function() return 0, "" end,
  set_action_options = function() end,
  MIDI_GetRecentInputEvent = function(index)
    local e = history[index + 1]
    if not e then return 0, "", 0, 0, -1, 0 end
    return e.seq, e.msg, -100, 0, -1, 0
  end,
}

local function classify(field)
  local rest, isSub = field, false
  while true do
    local c = rest:sub(1, 1)
    if c == "<" or c == "!" or c == "#" then rest = rest:sub(2)
    elseif c == ">" then isSub = true rest = rest:sub(2)
    else break end
  end
  if field == "" then return "separator", "" end
  rest = rest:gsub("&(&?)", "%1")
  if isSub then return "submenu", rest end
  return "item", rest
end

gfx = {
  w = 200, h = 100, x = 0, y = 0, mouse_x = 10, mouse_y = 10, mouse_cap = 0,
  init = function() end, quit = function() end, update = function() end,
  rect = function() end, setfont = function() end,
  measurestr = function(s) return #s * 6, 12 end,
  set = function(r, g, b) gfx._color = {r, g, b} end,
  circle = function(x, y, r, fill) drawn[#drawn + 1] = {r = r, fill = fill} end,
  drawstr = function(s) texts[#texts + 1] = s end,
  dock = function(_, a) if a ~= nil then return 0, 100, 100, 200, 100 end return 0 end,
  getchar = function() return 0 end,
  showmenu = function(str)
    local n = 0
    for field in (str .. "|"):gmatch("([^|]*)|") do
      local kind, lbl = classify(field)
      if kind == "item" then
        n = n + 1
        if lbl == clickLabel then return n end
      end
    end
    return 0
  end,
}

dofile(SCRIPT)

local function step() now = now + 1 / 30 deferred() end
local function frame() drawn, texts = {}, {} step() end
local function label()
  gfx.w = gfx.w == 200 and 201 or 200
  frame()
  return texts[#texts]
end

if SCALE then
  gfx.mouse_cap = 0
  for _ = 1, 12 do step() end
  gfx.mouse_x, gfx.mouse_y = 14, 61      -- a circle: opens the scale list
  clickLabel = SCALE
  gfx.mouse_cap = 1 step()
  gfx.mouse_cap = 0 step()
  clickLabel = nil
  for _ = 1, 12 do step() end
end

for line in io.lines() do
  local notes = {}
  for n in line:gmatch("%-?%d+") do notes[#notes + 1] = tonumber(n) end
  if #notes > 0 then
    allOff() frame()
    for _, n in ipairs(notes) do noteOn(n) end
    frame()
    io.write(line, "\t", tostring(label()), "\n")
  end
end
