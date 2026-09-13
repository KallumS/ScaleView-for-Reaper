--[[ Headless test for ScaleView, the merged script. The gfx mock is the same as the
     other suites; on top of it, reaper.MIDI_GetRecentInputEvent is mocked
     with a history that behaves like REAPER's: newest event at index 0, each
     with a sequence number, zero when there are no more. ]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local SCRIPT = HERE .. "/../reascripts/kallums_ScaleView.lua"

local ext, drawn, texts, deferred = {}, {}, {}, nil
local clickLabel = nil

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
  atexit = function() end,
  time_precise = function() return 1234.5 end,
  MIDI_GetRecentInputEvent = function(index)
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

local function frame()
  drawn, texts = {}, {}
  deferred()
end

-- The label under the circles is the last string drawn.
local function label()
  -- force a redraw even when nothing changed, so the label can always be read
  gfx.w = gfx.w == 200 and 201 or 200
  frame()
  return texts[#texts]
end

local function chooseMenu(item, button)
  gfx.mouse_cap = 0 deferred()
  clickLabel = item
  gfx.mouse_cap = button or 1 deferred()
  gfx.mouse_cap = 0 deferred()
  clickLabel = nil
end

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

-- 1) The two examples from the request.
print("the requested examples:")
expect({C4, C4 + 3, C4 + 7, C4 + 15}, "Cmin", "C Eb G with Eb doubled an octave up")
expect({C4, C4 + 3, C4 + 7, C4 + 10}, "Cmin7", "C Eb G Bb")
expect({59, 61, 66}, "Bsus2", "B C# F#")

-- 2) Triads and sevenths from C.
print("triads and sevenths:")
expect({C4, C4 + 4, C4 + 7}, "C")
expect({C4, C4 + 3, C4 + 7}, "Cmin")
expect({C4, C4 + 3, C4 + 6}, "Cdim")
expect({C4, C4 + 4, C4 + 8}, "Caug")
expect({C4, C4 + 5, C4 + 7}, "Csus4")
expect({C4, C4 + 2, C4 + 7}, "Csus2")
expect({C4, C4 + 4, C4 + 7, C4 + 11}, "Cmaj7")
expect({C4, C4 + 4, C4 + 7, C4 + 10}, "C7")
expect({C4, C4 + 3, C4 + 6, C4 + 10}, "Cmin7b5")
expect({C4, C4 + 3, C4 + 6, C4 + 9}, "Cdim7")
expect({C4, C4 + 4, C4 + 7, C4 + 9}, "C6")
expect({C4, C4 + 2, C4 + 4, C4 + 7}, "Cadd9")
expect({C4, C4 + 2, C4 + 4, C4 + 7, C4 + 10}, "C9")

-- 3) Inversions name the bass after a slash.
print("inversions:")
expect({52, C4, 67}, "C/E", "E in the bass")
expect({43, C4, 64}, "C/G", "G in the bass")
expect({C3, C3 + 4, C3 + 7, C3 + 11}, "Cmaj7", "root position stays plain")

-- 4) The classic ambiguity: the same four notes, named by what is underneath.
print("C6 against Amin7 - the bass decides:")
expect({45, C4, 64, 67}, "Amin7", "A in the bass")
expect({C3, 64, 67, 69}, "C6", "C in the bass")
expect({43, C4, 64, 69}, "Amin7/G", "neither: the commoner chord, with a slash")

-- 5) One and two notes.
print("one and two notes:")
expect({C4}, "C")
expect({C4, C4 + 7}, "C5", "a bare fifth")
expect({C4, C4 + 4}, "C E", "not a chord we know: name the notes")

-- 6) Chord roots are spelled for the selected key.
print("spelling follows the key:")
chooseMenu("Gb Major")
expect({54, 58, 61}, "Gb", "Gb Bb Db in Gb major")
expect({54, 58, 61, 65}, "Gbmaj7", nil)
chooseMenu("F# Major")
expect({54, 58, 61}, "F#", "the same three notes in F# major")
chooseMenu("Clear scale")

-- 6b) Chord symbols never use double accidentals, even where the key spells
--     the notes that way. Both cases below were reported from REAPER.
print("keys whose notes need double accidentals:")

chooseMenu("Gb Minor Blues")
-- Gb minor blues spells these notes Dbb, Fb and Bbb; the chord is still Amin/C.
expect({C4, C4 + 4, C4 + 9}, "Amin/C", "was: Bbbmin/Dbb")

chooseMenu("A# Harmonic Minor")
-- A# harmonic minor spells the root Gx; B# is a single sharp and is kept.
expect({C4, C4 + 3, C4 + 9}, "Adim/B#", "was: Gxdim/B#")

-- The circles keep the key's spelling: only the chord symbol simplifies.
do
  -- Circles are drawn black row then white row, so texts[] runs in this order.
  local DRAW_ORDER = {1, 3, 6, 8, 10, 0, 2, 4, 5, 7, 9, 11}
  local circleName = {}
  for i, pc in ipairs(DRAW_ORDER) do circleName[pc] = texts[i] end

  if circleName[9] ~= "Gx" then
    fail("the circles should still show Gx in A# harmonic minor, showed "
         .. tostring(circleName[9]))
  else
    print("  circles still read Gx; only the chord symbol simplifies")
  end
end

-- A single accidental is still kept, so a chord in Gb major reads Gb not F#.
chooseMenu("Gb Major")
expect({54, 58, 61}, "Gb", "single accidentals are untouched")
chooseMenu("Cb Major")
expect({59, 63, 66}, "Cb", "and Cb major still reads Cb")
chooseMenu("Clear scale")

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

local function simplify() chooseMenu("Simplify Note Names", 2) end

print("simplify note names:")

chooseMenu("Gb Major")
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
chooseMenu("Cb Major")
if namesAcross() ~= simplified() then
  fail("Cb major simplified should be plain sharps, got " .. namesAcross())
end
chooseMenu("A# Harmonic Minor")
if circleNames()[9] ~= "A" then
  fail("Gx should simplify to A, got " .. tostring(circleNames()[9]))
end
print("  simplified     Cb Major and A# Harmonic Minor lose Cb, Fb and Gx")

-- Turning it off returns to the key's spelling.
simplify()
chooseMenu("Cb Major")
if namesAcross() ~= "C Db D Eb Fb F Gb G Ab A Bb Cb" then
  fail("turning it off should restore the key spelling, got " .. namesAcross())
end
print("  back on        Cb Major  " .. namesAcross())

-- Chord detection is untouched; only the names it reports follow the scheme.
chooseMenu("Gb Major")
expect({54, 58, 61}, "Gb", "chord root spelled for the key")
simplify()
expect({54, 58, 61}, "F#", "the same chord, simplified")
expect({54, 58, 61, 65}, "F#maj7", "same quality, simplified root")
chooseMenu("A# Harmonic Minor")
expect({C4, C4 + 3, C4 + 9}, "Adim/C", "was Adim/B# with key spelling")
simplify()
chooseMenu("A# Harmonic Minor")
expect({C4, C4 + 3, C4 + 9}, "Adim/B#", "and back to key spelling")
chooseMenu("Clear scale")

-- The setting survives a restart.
simplify()
drawn, texts = {}, {}
dofile(SCRIPT)
if namesAcross() ~= simplified() then
  fail("the simplify setting should survive a restart, got " .. namesAcross())
end
simplify()
print("  the setting survives a restart")

-- 7) Releasing a note renames the chord; all-notes-off clears it.
print("note-offs:")
play({C4, C4 + 4, C4 + 7})
noteOff(C4 + 4)
frame()
if label() ~= "C5" then fail("releasing the third should leave C5, got " .. tostring(label())) end
noteOff(C4)
noteOff(C4 + 7)
frame()
if label() ~= "No scale selected" then
  fail("releasing everything should fall back to the scale label, got " .. tostring(label()))
end
print("  releasing the third of C leaves C5; releasing all falls back to the scale name")

play({C4, C4 + 4, C4 + 7})
allNotesOff()
frame()
if label() ~= "No scale selected" then fail("all-notes-off did not clear the chord") end
print("  an all-notes-off controller message clears the chord")

-- 8) Events already seen are not applied twice.
print("input history:")
play({C4, C4 + 4, C4 + 7})
local before = label()
frame() frame() frame()
if label() ~= before then fail("re-polling the same events changed the chord") end
noteOn(C4 + 10)
frame()
if label() ~= "C7" then fail("a new event after idle polls was missed, got " .. tostring(label())) end
print("  polling again applies nothing twice, and still catches the next note")

-- 9) Notes being played are ringed, whichever octave they are in.
play({C4, C4 + 4, C4 + 7})
local rings = 0
for _, circle in ipairs(drawn) do if circle.fill == false then rings = rings + 1 end end
if rings ~= 6 then   -- two rings per held pitch class
  fail("expected 6 ring strokes for a three-note chord, got " .. rings)
end
play({24, 36, 108})   -- the same pitch class three octaves apart
rings = 0
for _, circle in ipairs(drawn) do if circle.fill == false then rings = rings + 1 end end
if rings ~= 2 then fail("one pitch class in three octaves should ring one circle, got " .. rings) end
print("  held notes are ringed, once per pitch class whatever the octave")

-- 9b) The settings key is deliberately not the display name, so that renaming
--     the script does not reset anyone. Settings saved under any name this
--     script has been published under are still picked up.
for _, section in ipairs({"kallums_ScaleViewFull", "kallums_ScaleViewDetector",
                          "kallums_ScaleViewPro", "kallums_ScaleViewEnharmonic"}) do
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
print("settings saved under every earlier name still carry over")

-- When several old sections exist, the most recent name wins rather than a
-- stale one: this is the case for anyone who ran Detector after Pro.
ext = {}
ext["kallums_ScaleViewPro:root"]   = "C"     -- stale, from an older name
ext["kallums_ScaleViewPro:scale"]  = "Major"
ext["kallums_ScaleViewFull:root"]  = "Gb"   -- what the user actually left in Pro
ext["kallums_ScaleViewFull:scale"] = "Major"
dofile(SCRIPT)
if label() ~= "Gb Major" then
  fail("the most recently used name should win, label reads '" .. tostring(label()) .. "'")
end
print("with both a stale and a recent section, the recent one wins")

-- 10) If the input API is missing or does not return what we expect, the
--     script must say so rather than throwing on every frame of the defer
--     loop. This is the path that matters if REAPER's Lua binding for
--     MIDI_GetRecentInputEvent differs from the documented C signature.
print("when MIDI input cannot be read:")

for _, broken in ipairs({
      { name = "the function is missing", fn = nil },
      { name = "it returns a boolean",    fn = function() return true end },
      { name = "it returns nothing",      fn = function() return end },
      { name = "it throws",               fn = function() error ("boom") end },
    }) do
  reaper.MIDI_GetRecentInputEvent = broken.fn
  history, sequence = {}, 0

  local loaded, err = pcall (dofile, SCRIPT)
  if not loaded then
    fail ("loading threw with " .. broken.name .. ": " .. tostring (err))
  else
    local ran = true
    for _ = 1, 5 do
      local ok, frameErr = pcall (frame)
      if not ok then ran = false fail (broken.name .. " threw in the defer loop: " .. tostring (frameErr)) break end
    end
    if ran then
      local shown = label()
      if shown ~= "MIDI input unavailable" then
        fail (broken.name .. " should report unavailable, showed '" .. tostring (shown) .. "'")
      else
        print ("  " .. broken.name .. " -> " .. shown)
      end
    end
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

  chooseMenu("Dock window", 2)

  if dockState & 1 ~= 1 then
    fail(string.format("toggling an undocked window that remembers a docker should dock it (state 0x%X)", dockState))
  elseif dockState >> 8 ~= 2 then
    fail(string.format("docking lost the docker index (state 0x%X)", dockState))
  else
    print(string.format("dock toggle: 0x200 -> 0x%X, docked in docker 2", dockState))
  end

  chooseMenu("Dock window", 2)

  if dockState & 1 ~= 0 then
    fail(string.format("toggling again should undock (state 0x%X)", dockState))
  elseif dockState >> 8 ~= 2 then
    fail(string.format("undocking lost the remembered docker index (state 0x%X)", dockState))
  else
    print(string.format("dock toggle: back to 0x%X, docker index kept", dockState))
  end
end

if failures > 0 then print(failures .. " FAILURE(S)") os.exit(1) end
print("PASS")
