--[[ Headless test for the enharmonic build. Same gfx mock as the other suite:
     menu items are clicked by label, and both the circle colours and the note
     names drawn inside them are read back out of the mocked drawing calls. ]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local SCRIPT = HERE .. "/../reascripts/kallums_ScaleView Enharmonic.lua"

local ext, drawn, texts, deferred = {}, {}, {}, nil
local clickLabel = nil

reaper = {
  SetExtState = function(sec, key, val) ext[sec .. ":" .. key] = val end,
  GetExtState = function(sec, key) return ext[sec .. ":" .. key] or "" end,
  defer = function(f) deferred = f end,
  atexit = function() end,
}

local function classify(field)
  local rest, isSubmenu = field, false
  while true do
    local c = rest:sub(1, 1)
    if c == "<" or c == "!" or c == "#" then rest = rest:sub(2)
    elseif c == ">" then isSubmenu = true rest = rest:sub(2)
    else break end
  end
  if field == "" then return "separator", "" end
  rest = rest:gsub("&(&?)", "%1")
  if isSubmenu then return "submenu", rest end
  return "item", rest
end

gfx = {
  w = 200, h = 100, x = 0, y = 0, mouse_x = 10, mouse_y = 10, mouse_cap = 0,
  init = function() end, quit = function() end, update = function() end,
  rect = function() end, setfont = function() end,
  measurestr = function(str) return #str * 6, 12 end,
  set = function(r, g, b) gfx._color = {r, g, b} end,
  circle = function(x, y, r) drawn[#drawn + 1] = {x = x, y = y, color = gfx._color} end,
  drawstr = function(str) texts[#texts + 1] = str end,
  dock = function(_, a) if a ~= nil then return 0, 100, 100, 200, 100 end return 0 end,
  getchar = function() return 0 end,
  showmenu = function(str)
    local n = 0
    for field in (str .. "|"):gmatch("([^|]*)|") do
      local kind, label = classify(field)
      if kind == "item" then
        n = n + 1
        if label == clickLabel then return n end
      end
    end
    if clickLabel then error("no menu item labelled '" .. clickLabel .. "'") end
    return 0
  end,
}

dofile(SCRIPT)

local function fail(msg) print("FAIL: " .. msg) os.exit(1) end

local function choose(label, button)
  clickLabel = label
  gfx.mouse_cap = button or 1
  deferred()
  drawn, texts = {}, {}
  gfx.mouse_cap = 0
  deferred()
  clickLabel = nil
end

-- Circles are drawn black row then white row; texts[i] is the name inside
-- drawn[i]. This is the pitch class each one stands for.
local DRAW_ORDER = {1, 3, 6, 8, 10, 0, 2, 4, 5, 7, 9, 11}
local UNLIT = {0.30, 0.31, 0.35}

local function readIcon()
  local lit, name = {}, {}
  for i, circle in ipairs(drawn) do
    local pc = DRAW_ORDER[i]
    name[pc] = texts[i]
    lit[pc] = not (circle.color[1] == UNLIT[1] and circle.color[2] == UNLIT[2]
                   and circle.color[3] == UNLIT[3])
  end
  return lit, name, texts[#texts]   -- last string drawn is the scale label
end

-- The scale as it reads from the root upwards.
local function spelledScale(rootPc)
  local lit, name = readIcon()
  local out = {}
  for step = 0, 11 do
    local pc = (rootPc + step) % 12
    if lit[pc] then out[#out + 1] = name[pc] end
  end
  return table.concat(out, " ")
end

local ROOT_PC = {
  C = 0, ["C#"] = 1, Db = 1, D = 2, ["D#"] = 3, Eb = 3, E = 4, F = 5,
  ["F#"] = 6, Gb = 6, G = 7, ["G#"] = 8, Ab = 8, A = 9, ["A#"] = 10,
  Bb = 10, B = 11, Cb = 11,
}

local function expect(root, scaleName, spelling)
  choose(root .. " " .. scaleName)
  local got = spelledScale(ROOT_PC[root])
  if got ~= spelling then
    fail(root .. " " .. scaleName .. " spelled '" .. got .. "', expected '" .. spelling .. "'")
  end
  local _, _, label = readIcon()
  if label ~= root .. " " .. scaleName then
    fail("label reads '" .. label .. "'")
  end
  print(string.format("  %-26s %s", root .. " " .. scaleName, got))
end

-- 1) The cases given in the request.
print("the requested spellings:")
expect("C#", "Major", "C# D# E# F# G# A# B#")
expect("F#", "Major", "F# G# A# B C# D# E#")
expect("Gb", "Major", "Gb Ab Bb Cb Db Eb F")
expect("Cb", "Major", "Cb Db Eb Fb Gb Ab Bb")
expect("Db", "Major", "Db Eb F Gb Ab Bb C")

-- 2) The sharp/flat pairs are the same notes spelled differently.
print("enharmonic pairs light the same circles:")
for _, pair in ipairs({{"C#", "Db"}, {"D#", "Eb"}, {"F#", "Gb"}, {"G#", "Ab"},
                       {"A#", "Bb"}, {"B", "Cb"}}) do
  choose(pair[1] .. " Major")
  local litA = readIcon()
  local spellingA = spelledScale(ROOT_PC[pair[1]])
  choose(pair[2] .. " Major")
  local litB = readIcon()
  local spellingB = spelledScale(ROOT_PC[pair[2]])
  for pc = 0, 11 do
    if litA[pc] ~= litB[pc] then
      fail(pair[1] .. " and " .. pair[2] .. " major light different notes")
    end
  end
  if spellingA == spellingB then
    fail(pair[1] .. " and " .. pair[2] .. " major are spelled identically")
  end
  print(string.format("  %-3s %-24s = %-3s %s", pair[1], spellingA, pair[2], spellingB))
end

-- 3) The shorter and longer scales follow their conventional spellings.
print("other scale types:")
expect("C",  "Major Pentatonic", "C D E G A")
expect("A",  "Minor Pentatonic", "A C D E G")
expect("C",  "Major Blues", "C D Eb E G A")
expect("C",  "Minor Blues", "C Eb F Gb G Bb")
expect("C",  "Whole Tone", "C D E F# G# A#")
expect("C",  "Diminished Whole-Half", "C D Eb F Gb Ab A B")
expect("C",  "Diminished Half-Whole", "C Db Eb E F# G A Bb")
expect("Eb", "Harmonic Minor", "Eb F Gb Ab Bb Cb D")
expect("F",  "Dorian", "F G Ab Bb C D Eb")
expect("B",  "Lydian", "B C# D# E# F# G# A#")

-- 4) Notes outside the scale lean the same way as the key.
choose("F Major")
local _, names = readIcon()
if names[1] ~= "Db" or names[6] ~= "Gb" then
  fail("a flat key should name its outside notes as flats, got " .. names[1] .. " " .. names[6])
end
choose("G Major")
_, names = readIcon()
if names[1] ~= "C#" or names[3] ~= "D#" then
  fail("a sharp key should name its outside notes as sharps, got " .. names[1] .. " " .. names[3])
end
print("notes outside the scale follow the key: flats in F major, sharps in G major")

-- 5) Across every root and scale: the lit notes are unchanged by spelling, the
--    seven-note scales use each letter exactly once, and nothing needs more
--    than a double accidental.
local SCALE_INTERVALS = {
  ["Major"] = {0,2,4,5,7,9,11}, ["Minor (Natural)"] = {0,2,3,5,7,8,10},
  ["Harmonic Minor"] = {0,2,3,5,7,8,11}, ["Ionian"] = {0,2,4,5,7,9,11},
  ["Dorian"] = {0,2,3,5,7,9,10}, ["Phrygian"] = {0,1,3,5,7,8,10},
  ["Lydian"] = {0,2,4,6,7,9,11}, ["Mixolydian"] = {0,2,4,5,7,9,10},
  ["Aeolian"] = {0,2,3,5,7,8,10}, ["Major Pentatonic"] = {0,2,4,7,9},
  ["Minor Pentatonic"] = {0,3,5,7,10}, ["Major Blues"] = {0,2,3,4,7,9},
  ["Minor Blues"] = {0,3,5,6,7,10}, ["Whole Tone"] = {0,2,4,6,8,10},
  ["Diminished Whole-Half"] = {0,2,3,5,6,8,9,11},
  ["Diminished Half-Whole"] = {0,1,3,4,6,7,9,10},
}
local ROOT_ORDER = {"C","C#","Db","D","D#","Eb","E","F","F#","Gb","G","G#",
                    "Ab","A","A#","Bb","B","Cb"}
local SCALE_ORDER = {"Major","Minor (Natural)","Harmonic Minor","Ionian","Dorian",
                     "Phrygian","Lydian","Mixolydian","Aeolian","Major Pentatonic",
                     "Minor Pentatonic","Major Blues","Minor Blues","Whole Tone",
                     "Diminished Whole-Half","Diminished Half-Whole"}
local combinations = 0
for _, scaleName in ipairs(SCALE_ORDER) do
  local intervals = SCALE_INTERVALS[scaleName]
  for _, root in ipairs(ROOT_ORDER) do
    choose(root .. " " .. scaleName)
    local lit, name = readIcon()

    local want = {}
    for _, iv in ipairs(intervals) do want[(ROOT_PC[root] + iv) % 12] = true end
    for pc = 0, 11 do
      if lit[pc] ~= (want[pc] or false) then
        fail(root .. " " .. scaleName .. ": wrong notes lit")
      end
    end

    local letters = {}
    for pc = 0, 11 do
      if lit[pc] then
        local letter, accidental = name[pc]:match("^([A-G])(.*)$")
        if not letter then fail("unspellable name: " .. tostring(name[pc])) end
        if accidental ~= "" and accidental ~= "#" and accidental ~= "b"
           and accidental ~= "x" and accidental ~= "bb" then
          fail(root .. " " .. scaleName .. ": odd accidental in " .. name[pc])
        end
        letters[letter] = (letters[letter] or 0) + 1
      end
    end
    if #intervals == 7 then
      local distinct = 0
      for _, count in pairs(letters) do
        if count ~= 1 then
          fail(root .. " " .. scaleName .. ": a letter is used twice")
        end
        distinct = distinct + 1
      end
      if distinct ~= 7 then fail(root .. " " .. scaleName .. ": not all seven letters used") end
    end
    combinations = combinations + 1
  end
end
print(string.format("all %d root/scale combinations: right notes lit, and every", combinations))
print("seven-note scale uses each of the seven letters exactly once")

-- 6) The 15 real major keys need no double accidentals.
print("the fifteen standard major keys:")
for _, root in ipairs({"C","G","D","A","E","B","F#","C#","F","Bb","Eb","Ab","Db","Gb","Cb"}) do
  choose(root .. " Major")
  local spelling = spelledScale(ROOT_PC[root])
  if spelling:find("x") or spelling:find("bb") then
    fail(root .. " major should not need a double accidental: " .. spelling)
  end
  print(string.format("  %-3s %s", root, spelling))
end

-- 7) The selection survives a restart, spelling and all.
choose("Cb Major")
local before = spelledScale(ROOT_PC["Cb"])
drawn, texts = {}, {}
dofile(SCRIPT)
if spelledScale(ROOT_PC["Cb"]) ~= before then
  fail("spelling not restored after restart: " .. spelledScale(ROOT_PC["Cb"]))
end
print("restored after restart: " .. before)

print("PASS")
