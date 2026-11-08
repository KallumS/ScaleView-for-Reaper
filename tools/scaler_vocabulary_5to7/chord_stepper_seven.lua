-- Chord stepper for the Scaler vocabulary probe. Run once from REAPER with
-- Actions > "ReaScript: Run ReaScript (EEL2, Lua, or python)...". It opens a
-- small window; each left click releases the current chord and holds the next
-- line of seven_list.txt (right click goes back one). Closing the window
-- releases every note. Lines look like "0 1 4 6 11: 48 49 52 54 59".
local SEQ = "/Users/kal/Documents/Claude/ScaleView-for-Reaper-main/tools/scaler_vocabulary_5to7/seven_list.txt"
local held, idx, label, cap0 = {}, 0, "click to start", 0
local function send(notes)
  for _, n in ipairs(held) do reaper.StuffMIDIMessage(0, 0x80, n, 0) end
  held = {}
  for _, n in ipairs(notes) do reaper.StuffMIDIMessage(0, 0x90, n, 100); held[#held+1] = n end
end
local function lines()
  local t = {}
  local f = io.open(SEQ, "r"); if not f then return t end
  for l in f:lines() do if l:match("%S") then t[#t+1] = l end end
  f:close(); return t
end
local function step(d)
  local t = lines(); idx = idx + d
  if idx < 1 or idx > #t then send({}); label = "done (" .. #t .. ")"; idx = (idx < 1) and 0 or #t + 1; return end
  local l = t[idx]; label = idx .. "  " .. l
  local notes = {}
  for n in (l:match(":(.*)") or l):gmatch("%d+") do notes[#notes+1] = tonumber(n) end
  send(notes)
end
gfx.init("Chord stepper", 420, 60, 0, 700, 690)
gfx.setfont(1, "Arial", 22)
local function loop()
  local c = gfx.getchar(); if c < 0 then send({}); return end
  local cap = gfx.mouse_cap
  if cap & 1 == 1 and cap0 & 1 == 0 then step(1) end
  if cap & 2 == 2 and cap0 & 2 == 0 then step(-1) end
  cap0 = cap
  gfx.set(0.1,0.1,0.1); gfx.rect(0,0,gfx.w,gfx.h)
  gfx.set(1,1,1); gfx.x, gfx.y = 10, 18; gfx.drawstr(label)
  gfx.update(); reaper.defer(loop)
end
reaper.atexit(function() send({}) end)
loop()
