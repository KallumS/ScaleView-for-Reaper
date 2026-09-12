--[[
 * ReaScript Name: ScaleView Detector
 * Description:    ScaleView Pro, plus live chord detection. The twelve pitch
 *                 classes are drawn as circles with the notes of the selected
 *                 scale lit; notes you are playing are ringed, and the label
 *                 underneath names the chord you are holding - Cmin7, Bsus2,
 *                 C/E and so on - instead of the scale name.
 *
 *                 Chord roots are spelled for the selected key, so in Gb major
 *                 a chord on Gb reads Gbmaj7 rather than F#maj7.
 *
 *                 Notes are read from REAPER's global MIDI input history, so
 *                 the script shows what you play on a controller anywhere in
 *                 REAPER, without being inserted on a track. It does not see
 *                 MIDI items playing back - that would need a JSFX feeding it.
 * Instructions:   Run the script and play. Left-click the icon for the scale
 *                 list, right-click for a random scale and display options.
 *                 Press D to dock/undock, Esc or the window close box to exit.
 * Author:         kallums
 * Version:        1.0
 * Provides:       [main] .
--]]

------------------------------------------------------------------------------
-- Configuration
------------------------------------------------------------------------------

local SCRIPT_NAME  = "ScaleView Detector"
local EXT_SECTION  = "kallums_ScaleViewDetector"

-- Sections used by earlier names of this script.
local EXT_LEGACY   = {}

local DEFAULT_W    = 200
local DEFAULT_H    = 100

-- Colours are 0..1 RGB triplets, tweak to taste.
local COLOR_BG        = {0.10, 0.10, 0.12}  -- icon background
local COLOR_OFF       = {0.30, 0.31, 0.35}  -- note not in the selected scale
local COLOR_LABEL     = {0.72, 0.74, 0.80}  -- scale name text
local COLOR_TEXT_OFF  = {0.62, 0.64, 0.70}  -- note name on an unlit circle
local COLOR_TEXT_ON   = {0.06, 0.12, 0.11}  -- note name on a highlighted circle
local COLOR_HELD      = {1.00, 1.00, 1.00}  -- ring around a note being played
local COLOR_CHORD     = {0.95, 0.96, 0.98}  -- the chord name, brighter than a scale name

-- Chord shapes, as semitones above the root. Order is priority: when two
-- readings fit the same notes and the bass does not decide between them, the
-- one nearer the top wins, so C E G A over a G reads Amin7/G rather than C6/G.
local CHORDS = {
  {name = "",         intervals = {0, 4, 7}},
  {name = "min",      intervals = {0, 3, 7}},
  {name = "7",        intervals = {0, 4, 7, 10}},
  {name = "min7",     intervals = {0, 3, 7, 10}},
  {name = "maj7",     intervals = {0, 4, 7, 11}},
  {name = "6",        intervals = {0, 4, 7, 9}},
  {name = "min6",     intervals = {0, 3, 7, 9}},
  {name = "dim",      intervals = {0, 3, 6}},
  {name = "aug",      intervals = {0, 4, 8}},
  {name = "sus4",     intervals = {0, 5, 7}},
  {name = "sus2",     intervals = {0, 2, 7}},
  {name = "min7b5",   intervals = {0, 3, 6, 10}},
  {name = "dim7",     intervals = {0, 3, 6, 9}},
  {name = "minMaj7",  intervals = {0, 3, 7, 11}},
  {name = "aug7",     intervals = {0, 4, 8, 10}},
  {name = "maj7#5",   intervals = {0, 4, 8, 11}},
  {name = "7sus4",    intervals = {0, 5, 7, 10}},
  {name = "7sus2",    intervals = {0, 2, 7, 10}},
  {name = "add9",     intervals = {0, 2, 4, 7}},
  {name = "minAdd9",  intervals = {0, 2, 3, 7}},
  {name = "9",        intervals = {0, 2, 4, 7, 10}},
  {name = "min9",     intervals = {0, 2, 3, 7, 10}},
  {name = "maj9",     intervals = {0, 2, 4, 7, 11}},
  {name = "6/9",      intervals = {0, 2, 4, 7, 9}},
  {name = "7b9",      intervals = {0, 1, 4, 7, 10}},
  {name = "7#9",      intervals = {0, 3, 4, 7, 10}},
  {name = "7#11",     intervals = {0, 4, 6, 7, 10}},
  {name = "7b5",      intervals = {0, 4, 6, 10}},
  {name = "11",       intervals = {0, 2, 5, 7, 10}},
  {name = "min11",    intervals = {0, 2, 3, 5, 7, 10}},
  {name = "13",       intervals = {0, 2, 4, 7, 9, 10}},
  {name = "min13",    intervals = {0, 2, 3, 7, 9, 10}},
  {name = "maj13",    intervals = {0, 2, 4, 7, 9, 11}},
  {name = "5",        intervals = {0, 7}},

  -- Shells with the fifth left out, which is how these are usually voiced.
  {name = "7",        intervals = {0, 4, 10}},
  {name = "min7",     intervals = {0, 3, 10}},
  {name = "maj7",     intervals = {0, 4, 11}},
  {name = "minMaj7",  intervals = {0, 3, 11}},
  {name = "9",        intervals = {0, 2, 4, 10}},
  {name = "min9",     intervals = {0, 2, 3, 10}},
}

-- Looked up by the sorted interval list, e.g. "0,4,7". Built once at startup.
local CHORD_BY_SHAPE = {}

for priority, chord in ipairs(CHORDS) do
  local shape = table.concat(chord.intervals, ",")
  if not CHORD_BY_SHAPE[shape] then
    CHORD_BY_SHAPE[shape] = {name = chord.name, priority = priority}
  end
end

-- Highlight colours offered in the right-click menu. The first is the default.
-- Keep these pale: the note names drawn on top of them are dark.
local HIGHLIGHTS = {
  {name = "Teal",        rgb = {0.20, 0.80, 0.62}},
  {name = "Orange",      rgb = {0.98, 0.55, 0.15}},
  {name = "Light Green", rgb = {0.55, 0.87, 0.40}},
  {name = "White",       rgb = {0.95, 0.96, 0.98}},
  {name = "Light Blue",  rgb = {0.40, 0.72, 0.98}},
  {name = "Light Pink",  rgb = {0.98, 0.62, 0.78}},
  {name = "Gold",        rgb = {0.95, 0.78, 0.22}},
}

------------------------------------------------------------------------------
-- Musical data
------------------------------------------------------------------------------

-- Pitch classes: 0 = C ... 11 = B. These plain names are used for the notes
-- that are *outside* the selected scale, where the key implies no spelling.
local SHARP_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local FLAT_NAMES  = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"}

-- The seven letters and the pitch class each one names on its own.
local LETTERS    = {"C", "D", "E", "F", "G", "A", "B"}
local LETTER_PCS = {  0,   2,   4,   5,   7,   9,  11}

local ACCIDENTALS = {[-2] = "bb", [-1] = "b", [0] = "", [1] = "#", [2] = "x"}

-- Roots offered in the scale list: both spellings of every pitch class, plus
-- Cb. C# major and Db major are the same seven notes spelled differently, so
-- each needs its own entry. letter is an index into LETTERS.
local ROOTS = {
  {name = "C",  letter = 1, acc =  0},
  {name = "C#", letter = 1, acc =  1},
  {name = "Db", letter = 2, acc = -1},
  {name = "D",  letter = 2, acc =  0},
  {name = "D#", letter = 2, acc =  1},
  {name = "Eb", letter = 3, acc = -1},
  {name = "E",  letter = 3, acc =  0},
  {name = "F",  letter = 4, acc =  0},
  {name = "F#", letter = 4, acc =  1},
  {name = "Gb", letter = 5, acc = -1},
  {name = "G",  letter = 5, acc =  0},
  {name = "G#", letter = 5, acc =  1},
  {name = "Ab", letter = 6, acc = -1},
  {name = "A",  letter = 6, acc =  0},
  {name = "A#", letter = 6, acc =  1},
  {name = "Bb", letter = 7, acc = -1},
  {name = "B",  letter = 7, acc =  0},
  {name = "Cb", letter = 1, acc = -1},
}

-- Bottom row: the seven white keys of an octave
local WHITE_PCS = {0, 2, 4, 5, 7, 9, 11}

-- Top row: the five black keys of an octave
local BLACK_PCS = {1, 3, 6, 8, 10}

-- Which white-key gap each black key sits above (1 = between white 1 and 2).
-- C#=1, D#=2, (no black key between E and F), F#=4, G#=5, A#=6
local BLACK_SLOTS = {1, 2, 4, 5, 6}

-- Scale definitions as semitone offsets from the root.
-- Scale definitions. intervals are semitones from the root; letters are how
-- many letter-names each degree sits above the root letter, which is what
-- makes the spelling come out right. A seven-note scale simply walks the
-- letters in order (0..6); the others follow the conventional spelling, so
-- major blues repeats a letter for its b3 and 3 (C D Eb E G A) and the
-- diminished scales repeat one letter across their eight notes.
local SCALES = {
  {name = "Major",            intervals = {0, 2, 4, 5, 7, 9, 11},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Minor (Natural)",  intervals = {0, 2, 3, 5, 7, 8, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Harmonic Minor",   intervals = {0, 2, 3, 5, 7, 8, 11},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Ionian",           intervals = {0, 2, 4, 5, 7, 9, 11},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Dorian",           intervals = {0, 2, 3, 5, 7, 9, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Phrygian",         intervals = {0, 1, 3, 5, 7, 8, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Lydian",           intervals = {0, 2, 4, 6, 7, 9, 11},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Mixolydian",       intervals = {0, 2, 4, 5, 7, 9, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Aeolian",          intervals = {0, 2, 3, 5, 7, 8, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Major Pentatonic", intervals = {0, 2, 4, 7, 9},
                              letters   = {0, 1, 2, 4, 5}},
  {name = "Minor Pentatonic", intervals = {0, 3, 5, 7, 10},
                              letters   = {0, 2, 3, 4,  6}},
  {name = "Major Blues",      intervals = {0, 2, 3, 4, 7, 9},
                              letters   = {0, 1, 2, 2, 4, 5}},
  {name = "Minor Blues",      intervals = {0, 3, 5, 6, 7, 10},
                              letters   = {0, 2, 3, 4, 4,  6}},
  {name = "Whole Tone",       intervals = {0, 2, 4, 6, 8, 10},
                              letters   = {0, 1, 2, 3, 4,  5}},
  {name = "Diminished Whole-Half", intervals = {0, 2, 3, 5, 6, 8, 9, 11},
                                   letters   = {0, 1, 2, 3, 4, 5, 5,  6}},
  {name = "Diminished Half-Whole", intervals = {0, 1, 3, 4, 6, 7, 9, 10},
                                   letters   = {0, 1, 2, 2, 3, 4, 5,  6}},
}


------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

local state = {
  root      = nil,   -- index into ROOTS, or nil when no scale is selected
  scale     = nil,   -- index into SCALES, or nil
  showNames = true,  -- draw note names inside the circles
  highlight = 1,     -- index into HIGHLIGHTS
}

local active = {}    -- active[pitchClass] = true when that note is in the scale
local names  = {}    -- names[pitchClass] = how to spell it in the current key

local held      = {} -- held[midiNote] = true while the note is being played
local heldCount = 0
local chordName = nil   -- what the held notes spell, or nil when nothing is held
local lastEventSeq = nil -- newest input event already applied
local midiFailed = false -- set if the input history cannot be read at all

local MOUSE_BUTTONS = 1 | 2 | 64   -- left, right, middle; the rest are modifiers

local prevMouseCap  = 0
local settlingMouse = false   -- true from a menu closing until the mouse is idle
local needRedraw   = true
local lastW, lastH, lastDock

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

-- Reads a saved setting, falling back to the section used under the earlier
-- name so a rename doesn't reset an existing install's scale, window position
-- or dock state.
local function getSetting(key)
  local value = reaper.GetExtState(EXT_SECTION, key)
  local i = 1
  while value == "" and EXT_LEGACY[i] do
    value = reaper.GetExtState(EXT_LEGACY[i], key)
    i = i + 1
  end
  return value
end

local function setColor(c)
  gfx.set(c[1], c[2], c[3], 1)
end

local function rootPitch(root)
  return (LETTER_PCS[root.letter] + root.acc) % 12
end

-- Spell pitch class pc using the given letter, e.g. letter G and pc 6 gives
-- "Gb". Returns nil when that would need more than a double accidental, which
-- only happens in spellings nobody writes.
local function spellAs(letter, pc)
  letter = (letter - 1) % 7 + 1
  local offset = ((pc - LETTER_PCS[letter] + 6) % 12) - 6   -- -6..+5, 0 = natural
  local accidental = ACCIDENTALS[offset]
  if not accidental then return nil end
  return LETTERS[letter] .. accidental
end

local function noteName(pc)
  return names[pc] or SHARP_NAMES[pc + 1]
end

local function highlightColor()
  return HIGHLIGHTS[state.highlight].rgb
end

-- Recalculate which pitch classes are lit for the current selection.
local function refreshActive()
  active, names = {}, {}
  if not (state.root and state.scale) then return end

  local root  = ROOTS[state.root]
  local rootPc = rootPitch(root)
  local scale = SCALES[state.scale]
  local sharps, flats = 0, 0

  for degree, interval in ipairs(scale.intervals) do
    local pc = (rootPc + interval) % 12
    local name = spellAs(root.letter + scale.letters[degree], pc)
    active[pc] = true
    names[pc]  = name
    if name then
      if name:find("#") or name:find("x") then sharps = sharps + 1 end
      if name:find("b", 2) then flats = flats + 1 end   -- skip the note letter B
    end
  end

  -- The notes outside the scale have no spelling of their own, so name them
  -- in whichever direction the key leans.
  local outside = flats > sharps and FLAT_NAMES or SHARP_NAMES
  for pc = 0, 11 do
    if not names[pc] then names[pc] = outside[pc + 1] end
  end
end

local function displayLabel()
  if chordName then return chordName, true end
  if midiFailed then return "MIDI input unavailable", false end
  if state.root and state.scale then
    return ROOTS[state.root].name .. " " .. SCALES[state.scale].name, false
  end
  return "No scale selected", false
end

local function saveState()
  -- Stored by name throughout, so reordering a table cannot repoint a saved
  -- choice at a different entry.
  reaper.SetExtState(EXT_SECTION, "root",  state.root  and ROOTS[state.root].name   or "", true)
  reaper.SetExtState(EXT_SECTION, "scale", state.scale and SCALES[state.scale].name or "", true)
  reaper.SetExtState(EXT_SECTION, "shownames", state.showNames and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "highlight", HIGHLIGHTS[state.highlight].name, true)
end

local function loadState()
  local function lookup(list, saved)
    for i, entry in ipairs(list) do
      if entry.name == saved then return i end
    end
  end

  state.root  = lookup(ROOTS,  getSetting("root"))
  state.scale = lookup(SCALES, getSetting("scale"))
  state.highlight = lookup(HIGHLIGHTS, getSetting("highlight")) or 1
  if getSetting("shownames") == "0" then state.showNames = false end

  -- A root without a scale, or the other way round, would light nothing.
  if not (state.root and state.scale) then state.root, state.scale = nil, nil end
  refreshActive()
end

local function saveWindowState()
  local dock, x, y, w, h = gfx.dock(-1, 0, 0, 0, 0)
  reaper.SetExtState(EXT_SECTION, "wnd", table.concat({dock, x, y, w, h}, " "), true)
end

local function loadWindowState()
  local dock, x, y, w, h = getSetting("wnd"):match(
    "(-?%d+) (-?%d+) (-?%d+) (-?%d+) (-?%d+)")
  if not dock then return 0, nil, nil, DEFAULT_W, DEFAULT_H end
  w, h = tonumber(w), tonumber(h)
  if w < 60 then w = DEFAULT_W end
  if h < 40 then h = DEFAULT_H end
  return tonumber(dock), tonumber(x), tonumber(y), w, h
end

------------------------------------------------------------------------------
-- Layout - everything is derived from the current window size so the icon
-- stays correct if it is resized or docked.
------------------------------------------------------------------------------

local function layout()
  local aspect = DEFAULT_W / DEFAULT_H

  -- The icon keeps its 2:1 proportions inside whatever window it is given and
  -- is centred in it, so a wide docker doesn't smear the circles across the
  -- full width of the dock.
  local boxW = math.min(gfx.w, gfx.h * aspect)
  local boxH = math.min(gfx.h, gfx.w / aspect)
  local originX = (gfx.w - boxW) / 2
  local originY = (gfx.h - boxH) / 2

  local step   = boxW / 7                              -- one white-key slot
  local labelH = boxH * 0.20
  local radius = math.min(step * 0.40, (boxH - labelH) * 0.20)

  return {
    originX = originX,
    boxW    = boxW,
    step    = step,
    radius  = radius,
    topY    = originY + (boxH - labelH) * 0.33,
    botY    = originY + (boxH - labelH) * 0.76,
    labelY  = originY + boxH - labelH,
    labelH  = labelH,
  }
end

------------------------------------------------------------------------------
-- Chord detection
--
-- The held notes give a set of pitch classes and a bass - the lowest note
-- actually sounding. Every pitch class is tried as a root: the other notes
-- become intervals above it, and if that shape is a chord we know, it is a
-- candidate. The bass decides between readings that fit equally well, which
-- is what separates Bsus2 from F#sus4, and names the slash when the bass is
-- not the root.
------------------------------------------------------------------------------

local function heldPitchClasses()
  local classes, bass = {}, nil

  for note in pairs(held) do
    classes[note % 12] = true
    if not bass or note < bass then bass = note end
  end

  return classes, bass and bass % 12 or nil
end

-- The shape of `classes` seen from `root`, e.g. "0,4,7", or nil if the root
-- itself is not one of the notes.
local function shapeFrom(root, classes)
  if not classes[root] then return nil end

  local intervals = {}
  for pc = 0, 11 do
    if classes[pc] then intervals[#intervals + 1] = (pc - root) % 12 end
  end
  table.sort(intervals)

  return table.concat(intervals, ",")
end

local function detectChord()
  local classes, bass = heldPitchClasses()
  if not bass then return nil end

  local count = 0
  for _ in pairs(classes) do count = count + 1 end
  if count == 1 then return noteName(bass) end

  local best
  for root = 0, 11 do
    local shape = shapeFrom(root, classes)
    local chord = shape and CHORD_BY_SHAPE[shape]

    if chord then
      -- A reading whose root is in the bass wins outright; otherwise the
      -- more common chord, which is the one earlier in the table.
      local rooted = root == bass
      if not best
         or (rooted and not best.rooted)
         or (rooted == best.rooted and chord.priority < best.priority) then
        best = {root = root, name = chord.name, priority = chord.priority, rooted = rooted}
      end
    end
  end

  if not best then
    -- Nothing we recognise: name the notes instead of guessing.
    local spelled = {}
    for pc = 0, 11 do
      if classes[pc] then spelled[#spelled + 1] = noteName(pc) end
    end
    return table.concat(spelled, " ")
  end

  local name = noteName(best.root) .. best.name
  if not best.rooted then name = name .. "/" .. noteName(bass) end
  return name
end

------------------------------------------------------------------------------
-- Live MIDI input
--
-- MIDI_GetRecentInputEvent reads REAPER's global input history: idx 0 is the
-- most recent event and must be asked for first, since it latches the list.
-- Each event carries a sequence number, so walking back until we meet the one
-- we finished on last time gives exactly the events we have not seen yet.
------------------------------------------------------------------------------

local MAX_EVENTS_PER_POLL = 64   -- a generous ceiling at 30 polls a second

local function applyEvent(message)
  if #message < 3 then return end

  local status   = message:byte(1)
  local command  = status & 0xF0
  local note     = message:byte(2)
  local velocity = message:byte(3)

  if command == 0x90 and velocity > 0 then
    if not held[note] then
      held[note] = true
      heldCount = heldCount + 1
    end
  elseif command == 0x80 or (command == 0x90 and velocity == 0) then
    if held[note] then
      held[note] = nil
      heldCount = heldCount - 1
    end
  elseif command == 0xB0 and (note == 120 or note == 123) then
    held, heldCount = {}, 0       -- all sound off / all notes off
  end
end

local function pollMidiInput()
  if midiFailed then return false end

  local fresh, newestSeq = {}, nil

  for index = 0, MAX_EVENTS_PER_POLL - 1 do
    local ok, sequence, message = pcall(reaper.MIDI_GetRecentInputEvent, index)

    if not ok or type(sequence) ~= "number" or type(message) ~= "string" then
      -- Either the API is missing or it does not return what we expect. Say
      -- so once rather than throwing in the defer loop on every frame.
      midiFailed = true
      return false
    end

    if sequence == 0 or sequence == lastEventSeq then break end
    if index == 0 then newestSeq = sequence end

    fresh[#fresh + 1] = message
  end

  if #fresh == 0 then return false end

  -- The history runs newest first, so apply it backwards to keep note-ons and
  -- note-offs in the order they were played.
  for i = #fresh, 1, -1 do applyEvent(fresh[i]) end

  lastEventSeq = newestSeq or lastEventSeq

  local detected = heldCount > 0 and detectChord() or nil
  if detected ~= chordName then
    chordName = detected
    return true
  end
  return false
end

------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------

-- A note being played is ringed, whether or not it is in the scale.
local function drawHeldRing(x, y, r, pc)
  for _, note in ipairs({pc, pc + 12, pc + 24, pc + 36, pc + 48, pc + 60,
                         pc + 72, pc + 84, pc + 96, pc + 108, pc + 120}) do
    if held[note] then
      setColor(COLOR_HELD)
      gfx.circle(x, y, r + 1.5, false, true)
      gfx.circle(x, y, r + 2.5, false, true)
      return
    end
  end
end

local function drawCircle(x, y, r, pc)
  local on = active[pc] == true
  local fill = on and highlightColor() or COLOR_OFF
  setColor(fill)
  gfx.circle(x, y, r, true, true)

  if state.showNames and r >= 7 then
    local name = noteName(pc)
    -- "Bbb" needs to fit the same circle as "B".
    local fit = ({0.95, 0.80, 0.62})[#name] or 0.55
    gfx.setfont(2, "Arial", math.max(7, math.floor(r * fit)))
    local tw, th = gfx.measurestr(name)
    setColor(on and COLOR_TEXT_ON or COLOR_TEXT_OFF)
    gfx.x, gfx.y = x - tw / 2, y - th / 2
    gfx.drawstr(name)
  end

  drawHeldRing(x, y, r, pc)
end

local function draw()
  setColor(COLOR_BG)
  gfx.rect(0, 0, gfx.w, gfx.h, true)

  local L = layout()

  -- Top row: the five black keys, sitting over the gaps between white keys.
  for i, pc in ipairs(BLACK_PCS) do
    drawCircle(L.originX + BLACK_SLOTS[i] * L.step, L.topY, L.radius, pc)
  end

  -- Bottom row: the seven white keys.
  for i, pc in ipairs(WHITE_PCS) do
    drawCircle(L.originX + (i - 0.5) * L.step, L.botY, L.radius, pc)
  end

  -- Current scale name.
  if L.labelH > 6 then
    gfx.setfont(1, "Arial", math.max(9, math.floor(L.labelH * 0.62)))
    local text, isChord = displayLabel()
    local tw, th = gfx.measurestr(text)
    setColor(isChord and COLOR_CHORD or COLOR_LABEL)
    gfx.x = math.max(2, L.originX + (L.boxW - tw) / 2)
    gfx.y = L.labelY + (L.labelH - th) / 2
    gfx.drawstr(text)
  end
end

------------------------------------------------------------------------------
-- Menus
--
-- gfx.showmenu() returns the 1-based index of the chosen item counting only
-- *selectable* items: separators and submenu headers are in the menu string
-- but are not counted. The action table is therefore keyed by a separate
-- counter that only advances for selectable items, so the indices line up
-- whatever gets added to the menu later.
------------------------------------------------------------------------------

local function newMenu()
  return {fields = {}, actions = {}, selectableCount = 0}
end

local function addField(menu, field)
  menu.fields[#menu.fields + 1] = field
end

-- opts.checked draws a tick, opts.last closes the submenu the item is in.
local function addItem(menu, label, action, opts)
  opts = opts or {}
  local prefix = (opts.last and "<" or "") .. (opts.checked and "!" or "")
  addField(menu, prefix .. label)
  menu.selectableCount = menu.selectableCount + 1
  menu.actions[menu.selectableCount] = action
end

local function addSeparator(menu)
  addField(menu, "")
end

local function addSubmenu(menu, label)
  addField(menu, ">" .. label)
end

local function showMenu(menu)
  gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
  local choice = gfx.showmenu(table.concat(menu.fields, "|"))
  local action = menu.actions[choice]
  if action then action() end

  -- showmenu() is modal, and the click that picked an item is reported to the
  -- window once the menu closes. Left alone it looks like a fresh left click
  -- here, which is why a right click could open the left click's menu.
  settlingMouse = true
end

local function selectScale(root, scaleIdx)
  state.root, state.scale = root, scaleIdx
  refreshActive()
  -- The chord is spelled for the key, so it has to be renamed when the key
  -- changes: the same notes read Gb in one key and F# in another.
  if heldCount > 0 then chordName = detectChord() end
  saveState()
  needRedraw = true
end

local function clearScale()
  selectScale(nil, nil)
end

-- Picks a scale at random, never the one already showing.
local function randomScale()
  local root, scale
  repeat
    root  = math.random(#ROOTS)
    scale = math.random(#SCALES)
  until root ~= state.root or scale ~= state.scale
  selectScale(root, scale)
end

local function scaleMenu()
  local menu = newMenu()

  addItem(menu, "Clear scale", clearScale, {checked = state.scale == nil})
  addSeparator(menu)

  for scaleIdx, scale in ipairs(SCALES) do
    addSubmenu(menu, scale.name)
    for rootIdx, root in ipairs(ROOTS) do
      addItem(menu, root.name .. " " .. scale.name,
        function() selectScale(rootIdx, scaleIdx) end,
        {
          last    = rootIdx == #ROOTS,
          checked = state.root == rootIdx and state.scale == scaleIdx,
        })
    end
  end

  showMenu(menu)
end

-- The dock state is a bitfield: bit 0 says whether the window is docked, and
-- the second byte holds the docker index, which is kept even while undocked.
-- So flip the bit rather than setting 0 or 1 - otherwise an undocked window
-- that still remembers a docker reads as non-zero and never docks again.
local function isDocked()
  return gfx.dock(-1) & 1 == 1
end

local function toggleDock()
  local dock = gfx.dock(-1)
  gfx.dock(dock & 1 == 1 and dock & ~1 or dock | 1)
  saveWindowState()
  needRedraw = true
end

local function optionsMenu()
  local menu = newMenu()

  addItem(menu, "Random Scale", randomScale)
  addSeparator(menu)

  addItem(menu, "Show note names", function()
    state.showNames = not state.showNames
    saveState()
    needRedraw = true
  end, {checked = state.showNames})

  addSubmenu(menu, "Highlight Colour")
  for i, entry in ipairs(HIGHLIGHTS) do
    addItem(menu, entry.name, function()
      state.highlight = i
      saveState()
      needRedraw = true
    end, {last = i == #HIGHLIGHTS, checked = state.highlight == i})
  end

  addSeparator(menu)
  addItem(menu, "Dock window", toggleDock, {checked = isDocked()})
  addSeparator(menu)
  addItem(menu, "Close", function() gfx.quit() end)

  showMenu(menu)
end

------------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------------

local function handleMouse()
  local cap = gfx.mouse_cap

  -- After a menu closes, ignore the mouse until nothing is held. Whatever it
  -- did while the menu was up belongs to the menu, not to the icon.
  if settlingMouse then
    settlingMouse = cap & MOUSE_BUTTONS ~= 0
    prevMouseCap = cap
    return
  end

  -- Left click (on release, so a click-and-drag on the docker doesn't fire).
  if prevMouseCap & 1 == 1 and cap & 1 == 0 then
    scaleMenu()
  -- Right click
  elseif prevMouseCap & 2 == 2 and cap & 2 == 0 then
    optionsMenu()
  end

  prevMouseCap = cap
end

-- Returns false when the script should stop.
local function handleKeys()
  local char = gfx.getchar()
  if char < 0 or char == 27 then return false end        -- window closed / Esc
  if char == 100 or char == 68 then toggleDock() end     -- d / D
  return true
end

------------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------------

local function main()
  if pollMidiInput() then needRedraw = true end

  handleMouse()

  if not handleKeys() then
    saveWindowState()
    gfx.quit()
    return
  end

  local dock = gfx.dock(-1)
  if needRedraw or gfx.w ~= lastW or gfx.h ~= lastH or dock ~= lastDock then
    lastW, lastH, lastDock = gfx.w, gfx.h, dock
    needRedraw = false
    draw()
    gfx.update()
  end

  reaper.defer(main)
end

local function init()
  math.randomseed(os.time() + math.floor(reaper.time_precise() * 1000))
  loadState()
  local dock, x, y, w, h = loadWindowState()
  if x and y then
    gfx.init(SCRIPT_NAME, w, h, dock, x, y)
  else
    gfx.init(SCRIPT_NAME, w, h, dock)
  end
  gfx.setfont(1, "Arial", 12)
  main()
end

reaper.atexit(function()
  saveState()
  gfx.quit()
end)

init()
