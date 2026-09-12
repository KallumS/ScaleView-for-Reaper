--[[ Headless test: mocks the REAPER gfx API and drives the script by clicking
     menu entries *by label*. The mock reproduces REAPER's real gfx.showmenu
     contract - the returned index counts only selectable items, skipping
     separators and submenu headers - so the off-by-two reported from REAPER
     is reproducible here. ]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local SCRIPT = HERE .. "/../reascripts/kallums_ScaleView.lua"

local ext, drawn, texts, deferred = {}, {}, {}, nil
local clickLabel, lastMenuStr = nil, nil

reaper = {
  SetExtState = function(sec, key, val) ext[sec .. ":" .. key] = val end,
  GetExtState = function(sec, key) return ext[sec .. ":" .. key] or "" end,
  defer = function(f) deferred = f end,
  time_precise = function() return 1234.5678 end,
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
  rest = rest:gsub("&(&?)", "%1")   -- as Win32/SWELL render it
  if isSubmenu then return "submenu", rest end
  return "item", rest
end

gfx = {
  w = 200, h = 100, x = 0, y = 0, mouse_x = 10, mouse_y = 10, mouse_cap = 0,
  init = function() end, quit = function() end, update = function() end,
  rect = function() end, setfont = function() end,
  drawstr = function(str) texts[#texts + 1] = {text = str, color = gfx._color} end,
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
  drawn, texts = {}, {}                  -- keep only the frame drawn after the menu closes
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
  local function isLit(c)   -- anything that is not the unlit grey
    return not (c.color[1] == 0.30 and c.color[2] == 0.31 and c.color[3] == 0.35)
  end
  local function scan(row, pcs)
    for i, c in ipairs(row) do
      if isLit(c) then out[#out + 1] = pcs[i] end
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
expect("C Diminished Whole-Half", "0,2,3,5,6,8,9,11", "8 notes, W H W H W H W H")
expect("C Diminished Half-Whole", "0,1,3,4,6,7,9,10", "8 notes, H W H W H W H W")
expect("D# / Eb Diminished Whole-Half", "0,2,3,5,6,8,9,11", "same set as C, a minor 3rd up")

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
  {"Diminished Whole-Half", {0,2,3,5,6,8,9,11}},
  {"Diminished Half-Whole", {0,1,3,4,6,7,9,10}},
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
drawn, texts = {}, {}
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
drawn, texts = {}, {}
dofile(SCRIPT)
if lit() ~= saved then fail("scale not restored after restart: " .. lit() .. " vs " .. saved) end
print("selection restored after restart: " .. saved)

-- 7) Settings written by the pre-rename version are still picked up.
ext = {}
ext["kallums_ScaleSelector:root"]  = "7"   -- G
ext["kallums_ScaleSelector:scale"] = "1"   -- Major
drawn, texts = {}, {}
dofile(SCRIPT)
if lit() ~= "0,2,4,6,7,9,11" then
  fail("settings from the old script name were not carried over: " .. lit())
end
print("settings from the pre-rename script name carry over")

-- 8) Sharps <-> flats is purely cosmetic and renames the five black keys.
local function circleNames()
  local out = {}
  for i = 1, #texts - 1 do out[#out + 1] = texts[i].text end   -- last is the scale label
  return table.concat(out, " ")
end
local function scaleLabel() return texts[#texts].text end

choose("C# / Db Major")
local sharpNotes, sharpLit = circleNames(), lit()
if not sharpNotes:find("C#") or scaleLabel() ~= "C# Major" then
  fail("sharp names wrong: " .. sharpNotes .. " / " .. scaleLabel())
end

choose("Swap Sharps & Flats", 2)
local flatNotes = circleNames()
for _, sharp in ipairs({"C#", "D#", "F#", "G#", "A#"}) do
  if flatNotes:find(sharp, 1, true) then fail("still showing " .. sharp .. " in flats mode") end
end
for _, flat in ipairs({"Db", "Eb", "Gb", "Ab", "Bb"}) do
  if not flatNotes:find(flat, 1, true) then fail("missing " .. flat .. " in flats mode") end
end
for _, white in ipairs({"C", "D", "E", "F", "G", "A", "B"}) do
  if not flatNotes:find(white) then fail("white key " .. white .. " disappeared") end
end
if scaleLabel() ~= "Db Major" then fail("scale label not respelled: " .. scaleLabel()) end
if lit() ~= sharpLit then fail("swapping sharps/flats changed which notes are lit") end
print("swap sharps & flats: " .. flatNotes .. "  (" .. scaleLabel() .. ")")

choose("Swap Sharps & Flats", 2)
if circleNames() ~= sharpNotes then fail("toggling back did not restore sharps") end
print("toggling back restores sharps")

-- 9) Every highlight colour applies, and note names keep enough contrast.
local PALETTE = {
  {"Teal", {0.20, 0.80, 0.62}}, {"Orange", {0.98, 0.55, 0.15}},
  {"Light Green", {0.55, 0.87, 0.40}}, {"White", {0.95, 0.96, 0.98}},
  {"Light Blue", {0.40, 0.72, 0.98}}, {"Light Pink", {0.98, 0.62, 0.78}},
  {"Gold", {0.95, 0.78, 0.22}},
}
choose("C Major")
local baseline = lit()
for _, entry in ipairs(PALETTE) do
  local name, rgb = entry[1], entry[2]
  choose(name, 2)
  if lit() ~= baseline then fail(name .. " changed which notes are lit") end
  local litCount, offCount = 0, 0
  for _, c in ipairs(drawn) do
    if c.color[1] == 0.30 and c.color[2] == 0.31 then
      offCount = offCount + 1
    elseif c.color[1] == rgb[1] and c.color[2] == rgb[2] and c.color[3] == rgb[3] then
      litCount = litCount + 1
    else
      fail(name .. ": unexpected circle colour")
    end
  end
  if litCount ~= 7 or offCount ~= 5 then
    fail(string.format("%s: %d lit / %d unlit", name, litCount, offCount))
  end
  -- Note names on lit circles are always dark, so every highlight in the
  -- palette has to stay pale enough to read them against.
  local lum = 0.2126 * rgb[1] + 0.7152 * rgb[2] + 0.0722 * rgb[3]
  if lum <= 0.55 then
    fail(string.format("%s is too dark (luminance %.2f) for dark note names", name, lum))
  end
  -- texts[i] is the name drawn inside drawn[i], in the same order.
  for i, circle in ipairs(drawn) do
    local isLitCircle = circle.color[1] == rgb[1] and circle.color[2] == rgb[2]
    if isLitCircle and texts[i].color[1] ~= 0.06 then
      fail(name .. ": note name on a lit circle is not the dark text colour")
    end
  end
  print(string.format("  %-12s rgb(%.2f, %.2f, %.2f), luminance %.2f, dark note names",
    name, rgb[1], rgb[2], rgb[3], lum))
end

-- 10) Both new settings survive a restart.
choose("Gold", 2)
choose("Swap Sharps & Flats", 2)
local wantNames, wantColor = circleNames(), drawn[1].color
drawn, texts = {}, {}
dofile(SCRIPT)
if circleNames() ~= wantNames then fail("flats setting lost on restart") end
local restored = false
for _, c in ipairs(drawn) do
  if c.color[1] == 0.95 and c.color[2] == 0.78 then restored = true end
end
if not restored then fail("highlight colour lost on restart") end
print("flats and highlight colour both restored after restart")

-- 11) Random Scale always lands on a real scale, and never on the one showing.
local ROOT_PC = {
  C = 0, ["C#"] = 1, Db = 1, D = 2, ["D#"] = 3, Eb = 3, E = 4, F = 5,
  ["F#"] = 6, Gb = 6, G = 7, ["G#"] = 8, Ab = 8, A = 9, ["A#"] = 10, Bb = 10, B = 11,
}
local INTERVALS = {}
for _, t in ipairs(TYPES) do INTERVALS[t[1]] = t[2] end

local seen, seenRoots, seenScales, previous = {}, {}, {}, nil
for attempt = 1, 60 do
  choose("Random Scale", 2)
  local label = texts[#texts].text

  local root, scaleName
  for name in pairs(INTERVALS) do
    local prefix = label:match("^(.-) " .. name:gsub("[%(%)%-]", "%%%0") .. "$")
    if prefix then root, scaleName = prefix, name end
  end
  if not scaleName or not ROOT_PC[root] then
    fail("random pick " .. attempt .. " produced an unknown scale: " .. label)
  end

  local want = {}
  for _, iv in ipairs(INTERVALS[scaleName]) do
    want[#want + 1] = (ROOT_PC[root] + iv) % 12
  end
  table.sort(want)
  if lit() ~= table.concat(want, ",") then
    fail("random pick '" .. label .. "' lit " .. lit() .. ", expected " .. table.concat(want, ","))
  end
  if label == previous then fail("random pick repeated the current scale: " .. label) end

  previous = label
  seen[label] = true
  seenRoots[root] = true
  seenScales[scaleName] = true
end
local distinct = 0
for _ in pairs(seen) do distinct = distinct + 1 end
local roots, scales = 0, 0
for _ in pairs(seenRoots) do roots = roots + 1 end
for _ in pairs(seenScales) do scales = scales + 1 end
if distinct < 20 or roots < 5 or scales < 5 then
  fail(string.format("random picks look stuck: %d distinct, %d roots, %d scales",
    distinct, roots, scales))
end
print(string.format("random scale: 60 picks, %d distinct, %d roots, %d scale types, no repeats",
  distinct, roots, scales))

print("PASS")
