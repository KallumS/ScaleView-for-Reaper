--[[ Headless test for ScaleView Simple. The gfx mock is the same as the
     other suites; on top of it, reaper.MIDI_GetRecentInputEvent is mocked
     with a history that behaves like REAPER's: newest event at index 0, each
     with a sequence number, zero when there are no more. ]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local SCRIPT = HERE .. "/../reascripts/ScaleView Simple.lua"

local ext, drawn, texts, deferred = {}, {}, {}, nil
local now = 1000.0                     -- the clock the script sees
local projectsOn, activeProject = false, "projectA"
local projectStore, actionOptions = {}, {}
local atexitHandler = function() end
local clickLabel, menuOpened, lastMenuStr = nil, nil, nil

-- MIDI input history, newest first.
local history, sequence = {}, 0

local function pushEvent (message)
  sequence = sequence + 1
  table.insert (history, 1, { seq = sequence, msg = message })
end

local function noteOn  (note, velocity) pushEvent (string.char (0x90, note, velocity or 100)) end
local function noteOff (note)           pushEvent (string.char (0x80, note, 0)) end
local function allNotesOff()            pushEvent (string.char (0xB0, 123, 0)) end

reaper = {
  SetExtState = function(s, k, v) ext[s .. ":" .. k] = v end,
  GetExtState = function(s, k) return ext[s .. ":" .. k] or "" end,
  defer = function(f) deferred = f end,
  atexit = function(handler) atexitHandler = handler end,
  time_precise = function() return now end,

  -- Projects. EnumProjects returns nil until a test switches this on, so the
  -- rest of the suite runs as it would on a REAPER without these functions.
  EnumProjects = function() return projectsOn and activeProject or nil end,
  SetProjExtState = function(project, ext, key, value)
    projectStore[project] = projectStore[project] or {}
    projectStore[project][ext .. ":" .. key] = value
    return 1
  end,
  GetProjExtState = function(project, ext, key)
    local value = projectStore[project] and projectStore[project][ext .. ":" .. key]
    if value == nil or value == "" then return 0, "" end
    return 1, value
  end,

  set_action_options = function(flag) actionOptions[#actionOptions + 1] = flag end,
  midiCalls = 0,
  MIDI_GetRecentInputEvent = function(index)
    reaper.midiCalls = reaper.midiCalls + 1
    local event = history[index + 1]
    if not event then return 0, "", 0, 0, -1, 0 end
    return event.seq, event.msg, -100, 0, -1, 0
  end,
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
  circle = function(x, y, r, fill) drawn[#drawn + 1] = {x = x, y = y, r = r, fill = fill, color = gfx._color} end,
  drawstr = function(str) texts[#texts + 1] = str end,
  dock = function(_, a) if a ~= nil then return 0, 100, 100, 200, 100 end return 0 end,
  getchar = function() return 0 end,
  showmenu = function(str)
    lastMenuStr = str
    menuOpened = str:find("Clear scale", 1, true) and "scale"
              or str:find("Random Scale", 1, true) and "options" or "?"
    local n = 0
    for field in (str .. "|"):gmatch("([^|]*)|") do
      local kind, label = classify(field)
      if kind == "item" then
        n = n + 1
        if label == clickLabel then return n end
      end
    end
    return 0
  end,
}

dofile(SCRIPT)

local failures = 0
local function fail(message) print("FAIL: " .. message) failures = failures + 1 end

-- One pass of the script's defer loop, with time moving on as it would.
local function step()
  now = now + 1 / 30
  deferred()
end

local function frame()
  drawn, texts = {}, {}
  step()
end

-- The label under the circles is the last string drawn.
local function label()
  -- force a redraw even when nothing changed, so the label can always be read
  gfx.w = gfx.w == 200 and 201 or 200
  frame()
  return texts[#texts]
end

--[[  In a 200x100 icon the first white circle sits at about (14, 61), and
    (100, 8) is clear of every circle. Which menu opens depends on which of
    those a click starts on - not on the button.  ]]
local CIRCLE_X, CIRCLE_Y = 14, 61
local EMPTY_X,  EMPTY_Y  = 100, 8

-- Long enough for the settle window after a menu to pass.
local function settleMouse()
  gfx.mouse_cap = 0
  for _ = 1, 12 do step() end
end

local function clickAt(x, y, item, button)
  settleMouse()
  gfx.mouse_x, gfx.mouse_y = x, y
  clickLabel = item
  menuOpened = nil
  gfx.mouse_cap = button or 1
  step()                       -- press
  drawn, texts = {}, {}
  gfx.mouse_cap = 0
  step()                       -- release, which is when the menu opens
  clickLabel = nil
  return menuOpened
end

local function chooseScale(item, button)  return clickAt(CIRCLE_X, CIRCLE_Y, item, button) end
local function chooseOption(item, button) return clickAt(EMPTY_X, EMPTY_Y, item, button) end

-- Play a set of MIDI notes and read back the chord name.
local function play(notes)
  allNotesOff()
  frame()
  for _, note in ipairs(notes) do noteOn(note) end
  frame()
  return label()
end

local C3, C4 = 48, 60
local function expect(notes, want, why)
  local got = play(notes)
  if got ~= want then
    fail(string.format("%s -> '%s', expected '%s'", table.concat(notes, " "), tostring(got), want))
  else
    print(string.format("  %-28s %-14s %s", table.concat(notes, ","), got, why or ""))
  end
end

-- 6c) "Simplify Note Names" switches to piano-key naming: sharps for the black
--     keys, and never a double accidental. The key-aware spelling is the
--     default; this is the naming ScaleView Simple used.
local SHARP_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local DRAW_ORDER  = {1, 3, 6, 8, 10, 0, 2, 4, 5, 7, 9, 11}

local function circleNames()
  label()                      -- force a frame so texts[] is current
  local byPc = {}
  for i, pc in ipairs(DRAW_ORDER) do byPc[pc] = texts[i] end
  return byPc
end

local function namesAcross()
  local byPc, out = circleNames(), {}
  for pc = 0, 11 do out[#out + 1] = byPc[pc] end
  return table.concat(out, " ")
end

local function simplified() return table.concat(SHARP_NAMES, " ") end

local function simplify() chooseOption("Simplify Note Names") end

print("simplify note names:")

chooseScale("Gb Major")
local spelledForKey = namesAcross()
if spelledForKey ~= "C Db D Eb E F Gb G Ab A Bb Cb" then
  fail("Gb major should be spelled for the key by default, got " .. spelledForKey)
end
print("  default        Gb Major  " .. spelledForKey)

simplify()
if namesAcross() ~= simplified() then
  fail("simplified naming should be plain sharps, got " .. namesAcross())
end
print("  simplified     Gb Major  " .. namesAcross())

-- Double accidentals are the point of the option: they become piano keys.
chooseScale("Cb Major")
if namesAcross() ~= simplified() then
  fail("Cb major simplified should be plain sharps, got " .. namesAcross())
end
chooseScale("A# Harmonic Minor")
if circleNames()[9] ~= "A" then
  fail("Gx should simplify to A, got " .. tostring(circleNames()[9]))
end
print("  simplified     Cb Major and A# Harmonic Minor lose Cb, Fb and Gx")

-- Turning it off returns to the key's spelling.
simplify()
chooseScale("Cb Major")
if namesAcross() ~= "C Db D Eb Fb F Gb G Ab A Bb Cb" then
  fail("turning it off should restore the key spelling, got " .. namesAcross())
end
print("  back on        Cb Major  " .. namesAcross())

-- Chord detection is untouched; only the names it reports follow the scheme.
chooseScale("Gb Major")
simplify()
chooseScale("A# Harmonic Minor")
simplify()
chooseScale("A# Harmonic Minor")
chooseScale("Clear scale")

-- The setting survives a restart.
simplify()
drawn, texts = {}, {}
dofile(SCRIPT)
if namesAcross() ~= simplified() then
  fail("the simplify setting should survive a restart, got " .. namesAcross())
end
simplify()
print("  the setting survives a restart")

-- 9b) The settings key is deliberately not the display name, so that renaming
--     the script does not reset anyone. Settings saved under any name this
--     script has been published under are still picked up.
for _, section in ipairs({"kallums_ScaleViewSimple"}) do
  ext = {}
  ext[section .. ":root"]  = "Gb"
  ext[section .. ":scale"] = "Major"
  history, sequence = {}, 0

  dofile(SCRIPT)
  local shown = label()

  if shown ~= "Gb Major" then
    fail("settings from " .. section .. " were not carried over, label reads '"
         .. tostring(shown) .. "'")
  end
end
print("settings saved under the previous key still carry over")

-- When several old sections exist, the most recent name wins rather than a
-- stale one: this is the case for anyone who ran Detector after Pro.
ext = {}
ext["kallums_ScaleViewSimple:root"]  = "C"   -- stale, from before the rename
ext["kallums_ScaleViewSimple:scale"] = "Major"
ext["ScaleViewSimple:root"]  = "Gb"          -- what was chosen since
ext["ScaleViewSimple:scale"] = "Major"
dofile(SCRIPT)
if label() ~= "Gb Major" then
  fail("the current key should win over the legacy one, label reads '"
       .. tostring(label()) .. "'")
end
print("the current key wins over the one it replaced")

-- 11) Which menu opens depends on WHERE the click is, not which button.
--
--     The earlier build had a left-click menu and a right-click menu, and a
--     right click could open the left one, because the click that chooses an
--     item from a modal menu reaches the window afterwards and reads as a
--     fresh left click. Keying on position removes the idea of a wrong menu,
--     and the settle window below removes the stray click itself.
print("clicking:")

for _, button in ipairs({1, 2}) do
  local which = button == 1 and "left" or "right"

  if chooseScale(nil, button) ~= "scale" then
    fail(which .. " click on a circle should open the scale list")
  end
  if chooseOption(nil, button) ~= "options" then
    fail(which .. " click on empty space should open the options")
  end
  print("  " .. which .. " click: circle -> scale list, empty space -> options")
end

-- The stray click a menu leaves behind must open nothing, whether it arrives
-- immediately or a frame or two later. The second case is what still bit in
-- REAPER after the first fix.
for _, delayFrames in ipairs({0, 1, 3}) do
  chooseOption("Random Scale")          -- use a menu, which leaves the stray click

  for _ = 1, delayFrames do
    menuOpened = nil
    gfx.mouse_cap = 0
    step()
    if menuOpened then fail("an idle frame after a menu opened " .. menuOpened) end
  end

  menuOpened = nil
  gfx.mouse_cap = 1 step()              -- the menu's own click, arriving late
  gfx.mouse_cap = 0 step()

  if menuOpened then
    fail(string.format("the menu's own click %d frame(s) later opened the %s menu",
                       delayFrames, menuOpened))
  else
    print(string.format("  a stray click %d frame(s) after a menu opens nothing", delayFrames))
  end
end

-- And once the settle window has passed, clicking works again.
if chooseScale(nil, 1) ~= "scale" then fail("clicks stopped working after the settle") end
print("  clicks work again once the settle window passes")

-- A click belongs where it began: press on a circle, drift off, still the
-- scale list.
settleMouse()
gfx.mouse_x, gfx.mouse_y = CIRCLE_X, CIRCLE_Y
menuOpened = nil
gfx.mouse_cap = 1 step()                -- press on a circle
gfx.mouse_x, gfx.mouse_y = EMPTY_X, EMPTY_Y
gfx.mouse_cap = 0 step()                -- release over empty space
if menuOpened ~= "scale" then
  fail("a click that began on a circle should open the scale list, opened " .. tostring(menuOpened))
end
print("  a click belongs where it began, not where it ended")

-- 12) The scale belongs to the project. Everything else stays global, because
--     colour and note names are preferences rather than anything musical.
print("per-project scale:")

-- Section 10 left the input API broken on purpose, so start from a clean
-- script with working MIDI and nothing saved.
reaper.MIDI_GetRecentInputEvent = function(index)
  local event = history[index + 1]
  if not event then return 0, "", 0, 0, -1, 0 end
  return event.seq, event.msg, -100, 0, -1, 0
end
history, sequence = {}, 0

projectsOn, activeProject = true, "projectA"
projectStore, actionOptions = {}, {}
ext = {}
drawn, texts = {}, {}
dofile(SCRIPT)

chooseScale("Gb Major")
local storedA = projectStore["projectA"] or {}
if storedA["ScaleView:root"] ~= "Gb" or storedA["ScaleView:scale"] ~= "Major" then
  fail("picking a scale should write it into the project")
else
  print("  picking Gb Major writes root=Gb scale=Major into the project")
end

-- Only the scale: preferences are not project data.
chooseOption("Light Blue")
chooseOption("Simplify Note Names")
local keys = {}
for key in pairs(projectStore["projectA"]) do keys[#keys + 1] = key end
table.sort(keys)
if table.concat(keys, " ") ~= "ScaleView:root ScaleView:scale" then
  fail("only the scale belongs in the project, found " .. table.concat(keys, " "))
else
  print("  colour and note-name settings stay out of the project")
end
chooseOption("Simplify Note Names")   -- back to key spelling

-- Another project, with its own scale, and the icon follows when it becomes
-- the active one.
projectStore["projectB"] = {
  ["ScaleView:root"]  = "D",
  ["ScaleView:scale"] = "Dorian",
}
activeProject = "projectB"
frame()
if label() ~= "D Dorian" then
  fail("switching project should bring its scale, label reads " .. tostring(label()))
else
  print("  switching to another project brings its scale: " .. label())
end

activeProject = "projectA"
frame()
if label() ~= "Gb Major" then
  fail("switching back should restore that project's scale, got " .. tostring(label()))
else
  print("  and switching back restores the first: " .. label())
end

--[[  Switching project while notes are held used to throw. The project watcher
    renames the chord as the key changes, but it sits above the chord reader in
    the file and nothing was declared ahead of it, so the call found nil. The
    older tests never caught it because they switched project with nothing
    held. ]]
noteOn(C4); noteOn(C4 + 4); noteOn(C4 + 7)
frame()
activeProject = "projectB"
local switched, err = pcall(frame)
if not switched then
  fail("switching project while holding notes threw: " .. tostring(err))
else
  print("  switching project with notes held does not throw: " .. tostring(label()))
end
allNotesOff()
frame()
activeProject = "projectA"
frame()

-- A project that has never had a scale leaves what is showing alone.
activeProject = "projectC"
frame()
if label() ~= "Gb Major" then
  fail("a project with no saved scale should leave the icon alone, got " .. tostring(label()))
else
  print("  a project with no scale of its own changes nothing")
end

-- Reopening a project puts its own scale back, over whatever was used last.
activeProject = "projectB"
ext = {}
ext["ScaleViewSimple:root"]  = "C"       -- the last scale used anywhere
ext["ScaleViewSimple:scale"] = "Major"
drawn, texts = {}, {}
dofile(SCRIPT)
if label() ~= "D Dorian" then
  fail("the project's scale should beat the last one used, got " .. tostring(label()))
else
  print("  on load the project's scale beats the last one used globally")
end

-- Clearing removes it from the project rather than leaving a stale key.
chooseScale("Clear scale")
local cleared = projectStore["projectB"]
if cleared["ScaleView:root"] ~= "" or cleared["ScaleView:scale"] ~= "" then
  fail("clearing the scale should clear it in the project too")
else
  print("  clearing the scale clears it in the project")
end

-- 13) Toggle state, so a toolbar button lights up while the script runs.
do
  local sawOn = false
  for _, flag in ipairs(actionOptions) do
    if flag & 4 == 4 then sawOn = true end
    if flag & 1 ~= 1 then
      fail("re-running the action should terminate this instance, flag " .. flag)
    end
  end
  if not sawOn then fail("the script should set its toggle state on at startup") end

  actionOptions = {}
  atexitHandler()
  if #actionOptions ~= 1 or actionOptions[1] & 8 ~= 8 then
    fail("the script should set its toggle state off when it exits")
  else
    print("toolbar toggle: on at startup with re-run set to terminate, off at exit")
  end
end

projectsOn = false

-- 14) The highlight colours. There is no white one: the ring around a note
--     being played is white, so a white highlight would swallow it.
do
  local PALETTE = {
    {"Teal", {0.20, 0.80, 0.62}}, {"Orange", {0.98, 0.55, 0.15}},
    {"Light Green", {0.55, 0.87, 0.40}}, {"Light Blue", {0.40, 0.72, 0.98}},
    {"Light Pink", {0.98, 0.62, 0.78}}, {"Gold", {0.95, 0.78, 0.22}},
  }

  chooseScale("C Major")

  for _, entry in ipairs(PALETTE) do
    local name, rgb = entry[1], entry[2]
    chooseOption(name)
    label()

    local lit, white = 0, 0
    for _, circle in ipairs(drawn) do
      if circle.color[1] == rgb[1] and circle.color[2] == rgb[2] then lit = lit + 1 end
      if circle.color[1] == 1 and circle.color[2] == 1 and circle.color[3] == 1 then
        white = white + 1
      end
    end

    if lit ~= 7 then fail(name .. " lit " .. lit .. " circles, expected 7") end
    if white > 0 then fail(name .. " is white, which the played-note ring uses") end
  end
  print(string.format("highlights: %d colours, none of them white", #PALETTE))

  -- The option is gone from the menu entirely.
  chooseOption(nil)
  if lastMenuStr and lastMenuStr:find("White", 1, true) then
    fail("White is still offered in the menu")
  end

  -- Someone whose saved colour was White falls back to the default rather
  -- than breaking, the same as when Purple and Red were dropped.
  ext = {}
  ext["ScaleViewSimple:highlight"] = "White"
  ext["ScaleViewSimple:root"]  = "C"
  ext["ScaleViewSimple:scale"] = "Major"
  projectsOn = false
  drawn, texts = {}, {}
  dofile(SCRIPT)
  label()
  local teal = 0
  for _, circle in ipairs(drawn) do
    if circle.color[1] == 0.20 and circle.color[2] == 0.80 then teal = teal + 1 end
  end
  if teal ~= 7 then
    fail("a saved White should fall back to the default, lit " .. teal .. " teal circles")
  else
    print("  a saved White falls back to the default")
  end
end

-- Docking uses the documented bitfield: bit 0 is "docked", the second byte is
-- the docker index, which REAPER keeps even while the window is undocked. A
-- window that remembers docker 2 while undocked reads as 0x200 - non-zero, but
-- not docked - so the toggle has to test the bit, not the whole value.
do
  local dockState = 0x200        -- undocked, but remembering docker 2
  gfx.dock = function(v, a)
    if v and v >= 0 then dockState = v end
    if a ~= nil then return dockState, 100, 100, 200, 100 end
    return dockState
  end

  chooseOption("Dock Window")

  if dockState & 1 ~= 1 then
    fail(string.format("toggling an undocked window that remembers a docker should dock it (state 0x%X)", dockState))
  elseif dockState >> 8 ~= 2 then
    fail(string.format("docking lost the docker index (state 0x%X)", dockState))
  else
    print(string.format("dock toggle: 0x200 -> 0x%X, docked in docker 2", dockState))
  end

  chooseOption("Dock Window")

  if dockState & 1 ~= 0 then
    fail(string.format("toggling again should undock (state 0x%X)", dockState))
  elseif dockState >> 8 ~= 2 then
    fail(string.format("undocking lost the remembered docker index (state 0x%X)", dockState))
  else
    print(string.format("dock toggle: back to 0x%X, docker index kept", dockState))
  end
end

--[[  Simple is Pro without the chord detection, and "without" has to mean it
    never looks. The mock counts every call into REAPER's MIDI input API; the
    script may not make one, however much is waiting to be read. ]]
print("no chord detection:")
do
  local before = reaper.midiCalls
  for _, n in ipairs({60, 64, 67, 70}) do
    pushEvent(string.char(0x90, n, 100))
  end
  chooseScale("C Major")
  for _ = 1, 5 do frame() end

  if reaper.midiCalls ~= before then
    fail(string.format("Simple read the MIDI input %d time(s)",
                       reaper.midiCalls - before))
  else
    print("  four notes waiting in the input history, and it never asked")
  end
  if label() ~= "C Major" then
    fail("the label should stay the scale name, got " .. tostring(label()))
  else
    print("  the label stays the scale name: " .. label())
  end
end

--[[  Every scale from every root lights exactly the right notes. This sweep is
    the one piece of coverage that has always lived in this suite rather than
    Pro's, so it stays here. ]]
do
  local DRAW_ORDER = {1, 3, 6, 8, 10, 0, 2, 4, 5, 7, 9, 11}
  local TEAL = {0.20, 0.80, 0.62}
  local function lit()
    gfx.w = gfx.w == 200 and 201 or 200   -- force a repaint, as label() does
    frame()
    local on = {}
    local i = 0
    for _, circle in ipairs(drawn) do
      if circle.r then
        i = i + 1
        if circle.color[1] == TEAL[1] and circle.color[2] == TEAL[2] then
          on[#on + 1] = DRAW_ORDER[i]
        end
      end
    end
    table.sort(on)
    return table.concat(on, ",")
  end

  -- All eighteen roots the menu offers, with the pitch class each starts on.
  local ROOTS = {
    {"C", 0}, {"C#", 1}, {"Db", 1}, {"D", 2}, {"D#", 3}, {"Eb", 3},
    {"E", 4}, {"F", 5}, {"F#", 6}, {"Gb", 6}, {"G", 7}, {"G#", 8},
    {"Ab", 8}, {"A", 9}, {"A#", 10}, {"Bb", 10}, {"B", 11}, {"Cb", 11},
  }
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

  local checked, wrong = 0, 0
  for _, t in ipairs(TYPES) do
    for _, r in ipairs(ROOTS) do
      local want = {}
      for _, iv in ipairs(t[2]) do want[#want + 1] = (r[2] + iv) % 12 end
      table.sort(want)
      local key = r[1] .. " " .. t[1]
      chooseScale(key)
      local got = lit()
      if got ~= table.concat(want, ",") then
        wrong = wrong + 1
        if wrong <= 3 then
          fail(key .. " lit " .. got .. ", expected " .. table.concat(want, ","))
        end
      end
      checked = checked + 1
    end
  end
  if wrong == 0 then
    print(string.format("all %d scale/root combinations light exactly the right notes",
                        checked))
  end
end

if failures > 0 then print(failures .. " FAILURE(S)") os.exit(1) end
print("PASS")
