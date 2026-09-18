--[[
 * ReaScript Name: ScaleView Simple
 * Description:    The twelve pitch classes drawn as circles - five black keys
 *                 on the top row over seven white keys on the bottom - with
 *                 the notes of the selected scale lit.
 *
 *                 Note names are spelled for the key: each degree of a
 *                 seven-note scale takes the next letter of the alphabet and
 *                 whatever accidental that letter needs, so C# major reads
 *                 C# D# E# F# G# A# B# while Db major - the same seven notes -
 *                 reads Db Eb F Gb Ab Bb C.
 *
 *                 Simple is ScaleView Pro without the chord detection: it
 *                 does not listen to what you play and names no chords. The
 *                 icon, the scales, the spelling, the menus and the
 *                 per-project key all behave exactly as they do in Pro.
 *
 *                 "Simplify Note Names" in the options menu turns that off
 *                 and names every note the way a piano key is named: sharps for
 *                 the black keys, and no double accidentals, so Bbb reads A and
 *                 Cb reads B.
 * Instructions:   Run the script.
 *                 Click a circle for the scale list, click anywhere else for
 *                 a random scale and display options. Either mouse button
 *                 does the same thing.
 *                 Press D to dock/undock, Esc or the window close box to exit.
 * Author:         kallums
 * Version:        1.0
 * Provides:       [main] .
--]]

------------------------------------------------------------------------------
-- Configuration
------------------------------------------------------------------------------

local SCRIPT_NAME  = "ScaleView Simple"
local EXT_SECTION  = "ScaleViewSimple"

-- Read only when this script has no settings of its own, so the rename does
-- not lose anyone's scale, colour or window position.
local EXT_LEGACY   = {"kallums_ScaleViewSimple"}

local DEFAULT_W    = 200
local DEFAULT_H    = 100

-- Colours are 0..1 RGB triplets, tweak to taste.
local COLOR_BG        = {0.1375, 0.1532, 0.1806}  -- icon background, #23272e
local COLOR_OFF       = {0.30, 0.31, 0.35}  -- note not in the selected scale
local COLOR_LABEL     = {0.7492, 0.7727, 0.8080}  -- scale name text, #BFC5CE
local COLOR_TEXT_OFF  = {0.62, 0.64, 0.70}  -- note name on an unlit circle
local COLOR_TEXT_ON   = {0.0786, 0.0904, 0.1100}  -- note name on a lit circle, #14171c

-- Highlight colours offered in the menu. The first is the default.
-- Keep these pale: the note names drawn on top of them are dark. There is
-- deliberately nothing here that the ring around a played note could hide in.
-- That ring is #FFF200, so the colour to keep out is a yellow. White is the
-- nearest the palette comes, and reads 1.2:1 against it where the two touch -
-- which is only the antialiased edge: both strokes sit outside the circle.
local HIGHLIGHTS = {
  {name = "Teal",        rgb = {0.20, 0.80, 0.62}},
  {name = "Orange",      rgb = {0.98, 0.55, 0.15}},
  {name = "Light Green", rgb = {0.55, 0.87, 0.40}},
  {name = "Light Blue",  rgb = {0.40, 0.72, 0.98}},
  {name = "Light Pink",  rgb = {0.98, 0.62, 0.78}},
  {name = "White",       rgb = {1.00, 1.00, 1.00}},
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
  simpleNames = false, -- name notes as piano keys rather than for the key
  highlight = 1,     -- index into HIGHLIGHTS
}

local active = {}    -- active[pitchClass] = true when that note is in the scale
local names  = {}    -- names[pitchClass] = how to spell it in the current key

local keyUsesFlats = false -- whether the selected key spells its notes as flats



--[[  Naming a chord needs a key to settle the readings that are a genuine
    draw, and the script starts with no scale chosen. Rather than go quiet
    until one is picked, it reads those draws as if the key were C major.

    Nothing on the icon says so - with no scale selected no circle lights up,
    exactly as before - and choosing C major from the menu gives identical
    names, which is the property `tests/test_scaleview_pro.lua` checks over
    every three- and four-note voicing. C major is the right one to assume
    because it is also what the note names already fall back to: no
    accidentals, so the twelve read C C# D D# E F F# G G# A A# B either way. ]]
local ASSUMED_KEY = {[0] = true, [2] = true, [4] = true, [5] = true,
                     [7] = true, [9] = true, [11] = true}

local MOUSE_BUTTONS = 1 | 2 | 64   -- left, right, middle; the rest are modifiers

-- How long after a menu closes to keep ignoring the mouse. The click that
-- chose the item reaches the window afterwards, and not always in the very
-- next frame, so waiting for the buttons to come up is not enough on its own.
local MENU_SETTLE_SECONDS = 0.25

local prevMouseCap  = 0
local settlingMouse = false   -- true from a menu closing until the mouse is idle
local menuClosedAt  = -1      -- time_precise() when the last menu closed
local pressActive   = false   -- a press began on the icon and has not ended
local pressX, pressY = 0, 0   -- where it began, which decides the menu
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

-- Two naming schemes. By default a note is named for the key it is in, which
-- is what makes Gb major read Gb Ab Bb Cb Db Eb F. With "Simplify Note Names"
-- on, every note is named the way its piano key is: sharps for the black keys
-- and never a double accidental, so Bbb reads A, Gx reads A and Cb reads B.
local function noteName(pc)
  if state.simpleNames then return SHARP_NAMES[pc + 1] end
  return names[pc] or SHARP_NAMES[pc + 1]
end

local function highlightColor()
  return HIGHLIGHTS[state.highlight].rgb
end

-- Recalculate which pitch classes are lit for the current selection.
local function refreshActive()
  active, names = {}, {}
  keyUsesFlats = false
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
  keyUsesFlats = flats > sharps
  local outside = keyUsesFlats and FLAT_NAMES or SHARP_NAMES
  for pc = 0, 11 do
    if not names[pc] then names[pc] = outside[pc + 1] end
  end
end

local function displayLabel()
  if state.root and state.scale then
    return ROOTS[state.root].name .. " " .. SCALES[state.scale].name
  end
  return "No scale selected"
end

local function saveState()
  -- Stored by name throughout, so reordering a table cannot repoint a saved
  -- choice at a different entry.
  reaper.SetExtState(EXT_SECTION, "root",  state.root  and ROOTS[state.root].name   or "", true)
  reaper.SetExtState(EXT_SECTION, "scale", state.scale and SCALES[state.scale].name or "", true)
  reaper.SetExtState(EXT_SECTION, "shownames",   state.showNames and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "simplenames", state.simpleNames and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "highlight", HIGHLIGHTS[state.highlight].name, true)
end

-- The scale belongs to the project, not to the user: SetProjExtState stores it
-- inside the .RPP, so each project reopens in its own key. Everything else -
-- colour, note names, window - stays global, because those are preferences
-- rather than anything about the music.
local PROJECT_SECTION = "ScaleView"
-- What the section was called before the scripts lost their kallums_ prefix.
-- Read when a project has nothing under the name above, so a project saved
-- earlier still opens in its own key; the next change writes it across.
local PROJECT_LEGACY  = "kallums_ScaleView"

local currentProject = nil   -- the project the scale on screen came from

local function projectApiAvailable()
  return reaper.EnumProjects and reaper.GetProjExtState and reaper.SetProjExtState
end

local function activeProject()
  if not projectApiAvailable() then return nil end
  return reaper.EnumProjects(-1)
end

local function lookupNamed(list, saved)
  for i, entry in ipairs(list) do
    if entry.name == saved then return i end
  end
end

-- Writes the scale into the project. This marks the project as edited, which
-- is the cost of the project remembering it.
local function saveProjectScale()
  local project = activeProject()
  if not project then return end

  reaper.SetProjExtState(project, PROJECT_SECTION, "root",
    state.root and ROOTS[state.root].name or "")
  reaper.SetProjExtState(project, PROJECT_SECTION, "scale",
    state.scale and SCALES[state.scale].name or "")
end

-- The scale this project was left in, or nil when it has never had one.
local function projectScale(project)
  if not project then return nil end

  local _, rootName  = reaper.GetProjExtState(project, PROJECT_SECTION, "root")
  local _, scaleName = reaper.GetProjExtState(project, PROJECT_SECTION, "scale")

  if (rootName or "") == "" and (scaleName or "") == "" then
    _, rootName  = reaper.GetProjExtState(project, PROJECT_LEGACY, "root")
    _, scaleName = reaper.GetProjExtState(project, PROJECT_LEGACY, "scale")
  end

  local root  = lookupNamed(ROOTS,  rootName or "")
  local scale = lookupNamed(SCALES, scaleName or "")

  if root and scale then return root, scale end
  return nil
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
  if getSetting("simplenames") == "1" then state.simpleNames = true end

  -- A root without a scale, or the other way round, would light nothing.
  if not (state.root and state.scale) then state.root, state.scale = nil, nil end

  -- A scale saved in the project wins over the last one used anywhere, so
  -- reopening a project puts its own key back on screen.
  currentProject = activeProject()
  local root, scale = projectScale(currentProject)
  if root then state.root, state.scale = root, scale end

  refreshActive()
end

-- Following the project the user is looking at: switching tab, or opening
-- another project, brings that project's scale with it. A project that has
-- never had one is left showing whatever is already up rather than blanking.
local function followProjectChange()
  local project = activeProject()
  if not project or project == currentProject then return false end

  currentProject = project

  local root, scale = projectScale(project)
  if not root then return false end
  if root == state.root and scale == state.scale then return false end

  state.root, state.scale = root, scale
  refreshActive()
  return true
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
    local text = displayLabel()
    local tw, th = gfx.measurestr(text)
    setColor(COLOR_LABEL)
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
  -- window once the menu closes - sometimes a frame or two later. Left alone
  -- it reads as a fresh click and opens a menu nobody asked for.
  settlingMouse = true
  menuClosedAt  = reaper.time_precise()
end

local function selectScale(root, scaleIdx)
  state.root, state.scale = root, scaleIdx
  refreshActive()
  saveProjectScale()
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

  addItem(menu, "Clear Scale", clearScale, {checked = state.scale == nil})
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

  addItem(menu, "Show Note Names", function()
    state.showNames = not state.showNames
    saveState()
    needRedraw = true
  end, {checked = state.showNames})

  addItem(menu, "Simplify Note Names", function()
    state.simpleNames = not state.simpleNames
    saveState()
    needRedraw = true
  end, {checked = state.simpleNames})

  addSubmenu(menu, "Highlight Colour")
  for i, entry in ipairs(HIGHLIGHTS) do
    addItem(menu, entry.name, function()
      state.highlight = i
      saveState()
      needRedraw = true
    end, {last = i == #HIGHLIGHTS, checked = state.highlight == i})
  end

  addSeparator(menu)
  addItem(menu, "Dock Window", toggleDock, {checked = isDocked()})
  addSeparator(menu)
  addItem(menu, "Close", function() gfx.quit() end)

  showMenu(menu)
end

------------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------------

-- Which menu a click opens depends on where it is, not which button was used:
-- the circles are the scale list, everything else is the options. That means
-- there is no wrong menu to open by mistake.
local function isOverCircle(x, y)
  local L = layout()
  local reach = L.radius + 2      -- a little forgiveness around the edge

  for i, _ in ipairs(BLACK_PCS) do
    local cx = L.originX + BLACK_SLOTS[i] * L.step
    local dx, dy = x - cx, y - L.topY
    if dx * dx + dy * dy <= reach * reach then return true end
  end

  for i, _ in ipairs(WHITE_PCS) do
    local cx = L.originX + (i - 0.5) * L.step
    local dx, dy = x - cx, y - L.botY
    if dx * dx + dy * dy <= reach * reach then return true end
  end

  return false
end

local function handleMouse()
  local cap = gfx.mouse_cap
  local buttons = cap & MOUSE_BUTTONS

  -- After a menu closes, ignore the mouse until nothing is held AND a moment
  -- has passed. Whatever it did while the menu was up belongs to the menu.
  if settlingMouse then
    if buttons == 0 and reaper.time_precise() - menuClosedAt >= MENU_SETTLE_SECONDS then
      settlingMouse = false
    end
    prevMouseCap, pressActive = cap, false
    return
  end

  local wasDown = prevMouseCap & MOUSE_BUTTONS ~= 0

  if not wasDown and buttons ~= 0 then
    -- A press. Remember where it started: a click belongs where it began, so
    -- pressing on a circle and drifting off still opens the scale list.
    pressActive = true
    pressX, pressY = gfx.mouse_x, gfx.mouse_y
  elseif wasDown and buttons == 0 and pressActive then
    -- A release, so the click is finished. Firing here rather than on the
    -- press means dragging the window by its edge does not open a menu.
    pressActive = false
    if isOverCircle(pressX, pressY) then scaleMenu() else optionsMenu() end
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
  if followProjectChange() then needRedraw = true end

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
  --[[  Tell REAPER the script is on, so a toolbar button bound to it lights up,
      and that re-running the action should stop this instance rather than
      start a second one - which makes the same button toggle it off.
      REAPER 7+; harmless to skip on anything older.  ]]
  if reaper.set_action_options then reaper.set_action_options(1 | 4) end

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
  if reaper.set_action_options then reaper.set_action_options(8) end   -- toggle off
  gfx.quit()
end)

init()
