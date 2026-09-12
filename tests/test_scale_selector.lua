--[[ Headless test: mocks the REAPER gfx API and drives the script by clicking
     menu entries *by label*. The mock reproduces REAPER's real gfx.showmenu
     contract - the returned index counts only selectable items, skipping
     separators and submenu headers - so the off-by-two reported from REAPER
     is reproducible here. ]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local SCRIPT = HERE .. "/../reascripts/kallums_Scale Selector.lua"

local ext, drawn, deferred = {}, {}, nil
local clickLabel, lastMenuStr = nil, nil

reaper = {
  SetExtState = function(sec, key, val) ext[sec .. ":" .. key] = val end,
  GetExtState = function(sec, key) return ext[sec .. ":" .. key] or "" end,
  defer = function(f) deferred = f end,
  atexit = function() end,
}

-- Strips the prefix characters REAPER understands and reports what the field is.
local function classify(field)
  local rest = field
  local isSubmenu = false
  while true do
    local c = rest:sub(1, 1)
    if c == "<" or c == "!" or c == "#" then
      rest = rest:sub(2)
    elseif c == ">" then
      isSubmenu = true
      rest = rest:sub(2)
    else
      break
    end
  end
  if field == "" then return "separator", "" end
  if isSubmenu then return "submenu", rest end
  return "item", rest
end

gfx = {
  w = 200, h = 100, x = 0, y = 0, mouse_x = 10, mouse_y = 10, mouse_cap = 0,
  init = function() end, quit = function() end, update = function() end,
  rect = function() end, setfont = function() end, drawstr = function() end,
  measurestr = function(str) return #str * 6, 12 end,
  set = function(r, g, b) gfx._color = {r, g, b} end,
  circle = function(x, y, r) drawn[#drawn + 1] = {x = x, y = y, r = r, color = gfx._color} end,
  dock = function(_, a) if a ~= nil then return 0, 100, 100, 200, 100 end return 0 end,
  getchar = function() return 0 end,
  showmenu = function(str)
    lastMenuStr = str
    local selectable = 0
    for field in (str .. "|"):gmatch("([^|]*)|") do
      local kind, label = classify(field)
      if kind == "item" then
        selectable = selectable + 1
        if label == clickLabel then return selectable end
      end
    end
    if clickLabel then error("menu has no item labelled '" .. clickLabel .. "'") end
    return 0
  end,
}

dofile(SCRIPT)

local function fail(msg) print("FAIL: " .. msg) os.exit(1) end

-- Click the icon and choose the menu entry with the given label.
local function choose(label, button)
  clickLabel = label
  gfx.mouse_cap = button or 1
  deferred()                  -- press
  drawn = {}                  -- keep only the frame drawn after the menu closes
  gfx.mouse_cap = 0
  deferred()                  -- release -> menu -> action -> redraw
  clickLabel = nil
end

-- Read back which pitch classes are lit, straight from the drawing calls.
local function lit()
  local top, bot = {}, {}
  for _, c in ipairs(drawn) do
    if c.y < gfx.h / 2 then top[#top + 1] = c else bot[#bot + 1] = c end
  end
  table.sort(top, function(a, b) return a.x < b.x end)
  table.sort(bot, function(a, b) return a.x < b.x end)
  local out = {}
  local function scan(row, pcs)
    for i, c in ipairs(row) do
      if c.color[1] < 0.25 and c.color[2] > 0.7 then out[#out + 1] = pcs[i] end
    end
  end
  scan(top, {1, 3, 6, 8, 10})
  scan(bot, {0, 2, 4, 5, 7, 9, 11})
  table.sort(out)
  return table.concat(out, ",")
end

local function expect(label, notes, why)
  choose(label)
  if lit() ~= notes then fail(label .. " lit " .. lit() .. ", expected " .. notes) end
  print(string.format("  %-28s -> %-22s %s", label, lit(), why or ""))
end

-- 1) The exact cases reported as broken from REAPER.
print("regressions reported from REAPER:")
expect("C Major",            "0,2,4,5,7,9,11", "was: nothing happened")
expect("C# / Db Major",      "0,1,3,5,6,8,10", "was: nothing happened")
expect("D Major",            "1,2,4,6,7,9,11", "was: gave C Major")
expect("D# / Eb Major",      "0,2,3,5,7,8,10", "was: gave C# Major")
expect("C Minor (Natural)",  "0,2,3,5,7,8,10", "was: gave A# Major")
expect("C# / Db Harmonic Minor", "0,1,3,4,6,8,9", "was: gave B Minor")

-- 2) Known scales, checked against theory.
print("theory checks:")
expect("A Minor (Natural)",  "0,2,4,5,7,9,11", "same notes as C major")
expect("G Major",            "0,2,4,6,7,9,11", "one sharp: F#")
expect("F Major",            "0,2,4,5,7,9,10", "one flat: Bb")
expect("D Dorian",           "0,2,4,5,7,9,11", "white keys from D")
expect("E Phrygian",         "0,2,4,5,7,9,11", "white keys from E")
expect("F Lydian",           "0,2,4,5,7,9,11", "white keys from F")
expect("G Mixolydian",       "0,2,4,5,7,9,11", "white keys from G")
expect("A Aeolian",          "0,2,4,5,7,9,11", "white keys from A")
expect("C Whole Tone",       "0,2,4,6,8,10",   "alternating semitones")
expect("C Major Pentatonic", "0,2,4,7,9",      nil)
expect("A Minor Pentatonic", "0,2,4,7,9",      "same notes as C major pentatonic")
expect("C Minor Blues",      "0,3,5,6,7,10",   nil)
expect("C Major Blues",      "0,2,3,4,7,9",    nil)
expect("A Harmonic Minor",   "0,2,4,5,8,9,11", "A natural minor with a G#")

-- 3) Every scale from every root: right note count, correct transposition.
local NAMES = {"C","C# / Db","D","D# / Eb","E","F","F# / Gb","G","G# / Ab","A","A# / Bb","B"}
local TYPES = {
  {"Major", {0,2,4,5,7,9,11}}, {"Minor (Natural)", {0,2,3,5,7,8,10}},
  {"Harmonic Minor", {0,2,3,5,7,8,11}}, {"Ionian", {0,2,4,5,7,9,11}},
  {"Dorian", {0,2,3,5,7,9,10}}, {"Phrygian", {0,1,3,5,7,8,10}},
  {"Lydian", {0,2,4,6,7,9,11}}, {"Mixolydian", {0,2,4,5,7,9,10}},
  {"Aeolian", {0,2,3,5,7,8,10}}, {"Major Pentatonic", {0,2,4,7,9}},
  {"Minor Pentatonic", {0,3,5,7,10}}, {"Major Blues", {0,2,3,4,7,9}},
  {"Minor Blues", {0,3,5,6,7,10}}, {"Whole Tone", {0,2,4,6,8,10}},
}
local checked = 0
for _, t in ipairs(TYPES) do
  for root = 0, 11 do
    local want = {}
    for _, iv in ipairs(t[2]) do want[#want + 1] = (root + iv) % 12 end
    table.sort(want)
    choose(NAMES[root + 1] .. " " .. t[1])
    if lit() ~= table.concat(want, ",") then
      fail(NAMES[root + 1] .. " " .. t[1] .. " lit " .. lit() ..
           ", expected " .. table.concat(want, ","))
    end
    checked = checked + 1
  end
end
print(string.format("all %d scale/root combinations light exactly the right notes", checked))

-- 4) Clear scale, and the options menu.
choose("Clear scale")
if lit() ~= "" then fail("clear left notes lit") end
local first = drawn[1].color
for _, c in ipairs(drawn) do
  if c.color[1] ~= first[1] then fail("cleared circles are not all one colour") end
end
print("clear scale -> all twelve circles one colour")

choose("C Major")
choose("Show note names", 2)          -- right-click
if lastMenuStr:find("Choose scale") then fail("dead 'Choose scale...' item still present") end
if lit() ~= "0,2,4,5,7,9,11" then fail("toggling note names disturbed the scale") end
print("options menu: note-name toggle works, no dead items")

-- 5) Docked wide: the icon keeps its proportions instead of stretching.
gfx.w, gfx.h = 900, 100
drawn = {}
deferred()
if #drawn ~= 12 then fail("expected 12 circles when docked wide") end
local minX, maxX = math.huge, -math.huge
for _, c in ipairs(drawn) do
  minX = math.min(minX, c.x - c.r)
  maxX = math.max(maxX, c.x + c.r)
end
local span = maxX - minX
if span > 205 then fail(string.format("icon stretched to %.0f px in a 900 px dock", span)) end
if math.abs((minX + maxX) / 2 - gfx.w / 2) > 1 then fail("icon not centred in a wide dock") end
print(string.format("docked at 900x100: icon stays %.0f px wide and centred", span))

-- 6) Selection survives a restart.
gfx.w, gfx.h = 200, 100
choose("F# / Gb Harmonic Minor")
local saved = lit()
-- Reload the script from scratch; init() draws one frame as it starts up.
drawn = {}
dofile(SCRIPT)
if lit() ~= saved then fail("scale not restored after restart: " .. lit() .. " vs " .. saved) end
print("selection restored after restart: " .. saved)

print("PASS")
