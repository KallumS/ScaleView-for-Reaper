--[[
 * ReaScript Name: ScaleView
 * Description:    A small (200x100) clickable icon for the REAPER UI showing the
 *                 twelve pitch classes as circles - 5 on the top row (the black
 *                 keys of an octave) and 7 on the bottom row (the white keys).
 *                 Left-click the icon to pick a key signature / scale; the notes
 *                 belonging to that scale light up. Selecting a scale does
 *                 nothing else - it is purely a visual reference.
 * Instructions:   Run the script. Left-click the icon for the scale list,
 *                 right-click for display options (note names, sharps or
 *                 flats, highlight colour, docking).
 *                 Press D to dock/undock, Esc or the window close box to exit.
 * Author:         kallums
 * Version:        1.3
 * Provides:       [main] .
--]]

------------------------------------------------------------------------------
-- Configuration
------------------------------------------------------------------------------

local SCRIPT_NAME  = "ScaleView"
local EXT_SECTION  = "kallums_ScaleView"
local EXT_LEGACY   = "kallums_ScaleSelector"  -- section used before the rename

local DEFAULT_W    = 200
local DEFAULT_H    = 100

-- Colours are 0..1 RGB triplets, tweak to taste.
local COLOR_BG        = {0.10, 0.10, 0.12}  -- icon background
local COLOR_OFF       = {0.30, 0.31, 0.35}  -- note not in the selected scale
local COLOR_LABEL     = {0.72, 0.74, 0.80}  -- scale name text
local COLOR_TEXT_OFF  = {0.62, 0.64, 0.70}  -- note name on an unlit circle
local COLOR_TEXT_ON   = {0.06, 0.12, 0.11}  -- note name on a highlighted circle

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

-- Pitch classes: 0 = C ... 11 = B
local SHARP_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local FLAT_NAMES  = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"}

-- Nicer spellings for the root menu
local ROOT_MENU_NAMES = {
  "C", "C# / Db", "D", "D# / Eb", "E", "F",
  "F# / Gb", "G", "G# / Ab", "A", "A# / Bb", "B",
}

-- Bottom row: the seven white keys of an octave
local WHITE_PCS = {0, 2, 4, 5, 7, 9, 11}

-- Top row: the five black keys of an octave
local BLACK_PCS = {1, 3, 6, 8, 10}

-- Which white-key gap each black key sits above (1 = between white 1 and 2).
-- C#=1, D#=2, (no black key between E and F), F#=4, G#=5, A#=6
local BLACK_SLOTS = {1, 2, 4, 5, 6}

-- Scale definitions as semitone offsets from the root.
local SCALES = {
  {name = "Major",            intervals = {0, 2, 4, 5, 7, 9, 11}},
  {name = "Minor (Natural)",  intervals = {0, 2, 3, 5, 7, 8, 10}},
  {name = "Harmonic Minor",   intervals = {0, 2, 3, 5, 7, 8, 11}},
  {name = "Ionian",           intervals = {0, 2, 4, 5, 7, 9, 11}},
  {name = "Dorian",           intervals = {0, 2, 3, 5, 7, 9, 10}},
  {name = "Phrygian",         intervals = {0, 1, 3, 5, 7, 8, 10}},
  {name = "Lydian",           intervals = {0, 2, 4, 6, 7, 9, 11}},
  {name = "Mixolydian",       intervals = {0, 2, 4, 5, 7, 9, 10}},
  {name = "Aeolian",          intervals = {0, 2, 3, 5, 7, 8, 10}},
  {name = "Major Pentatonic", intervals = {0, 2, 4, 7, 9}},
  {name = "Minor Pentatonic", intervals = {0, 3, 5, 7, 10}},
  {name = "Major Blues",      intervals = {0, 2, 3, 4, 7, 9}},
  {name = "Minor Blues",      intervals = {0, 3, 5, 6, 7, 10}},
  {name = "Whole Tone",       intervals = {0, 2, 4, 6, 8, 10}},
  {name = "Diminished Whole-Half", intervals = {0, 2, 3, 5, 6, 8, 9, 11}},
  {name = "Diminished Half-Whole", intervals = {0, 1, 3, 4, 6, 7, 9, 10}},
}

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

local state = {
  root      = nil,   -- 0..11, or nil when no scale is selected
  scale     = nil,   -- index into SCALES, or nil
  showNames = true,  -- draw note names inside the circles
  useFlats  = false, -- name the five black keys Db Eb Gb Ab Bb instead of sharps
  highlight = 1,     -- index into HIGHLIGHTS
}

local active = {}    -- active[pitchClass] = true when that note is in the scale

local prevMouseCap = 0
local needRedraw   = true
local lastW, lastH, lastDock

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

-- Reads a saved setting, falling back to the pre-rename section so an existing
-- install keeps its scale, window position and dock state.
local function getSetting(key)
  local value = reaper.GetExtState(EXT_SECTION, key)
  if value == "" then value = reaper.GetExtState(EXT_LEGACY, key) end
  return value
end

local function setColor(c)
  gfx.set(c[1], c[2], c[3], 1)
end

local function noteName(pc)
  return (state.useFlats and FLAT_NAMES or SHARP_NAMES)[pc + 1]
end

local function highlightColor()
  return HIGHLIGHTS[state.highlight].rgb
end

-- Recalculate which pitch classes are lit for the current selection.
local function refreshActive()
  active = {}
  if not (state.root and state.scale) then return end
  for _, interval in ipairs(SCALES[state.scale].intervals) do
    active[(state.root + interval) % 12] = true
  end
end

local function scaleLabel()
  if state.root and state.scale then
    return noteName(state.root) .. " " .. SCALES[state.scale].name
  end
  return "No scale selected"
end

local function saveState()
  local root  = state.root  and tostring(state.root)  or ""
  local scale = state.scale and tostring(state.scale) or ""
  reaper.SetExtState(EXT_SECTION, "root",      root, true)
  reaper.SetExtState(EXT_SECTION, "scale",     scale, true)
  reaper.SetExtState(EXT_SECTION, "shownames", state.showNames and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "flats",     state.useFlats and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "highlight", HIGHLIGHTS[state.highlight].name, true)
end

local function loadState()
  local root  = tonumber(getSetting("root"))
  local scale = tonumber(getSetting("scale"))
  if root and root >= 0 and root <= 11 then state.root = math.floor(root) end
  if scale and SCALES[math.floor(scale)] then state.scale = math.floor(scale) end
  if getSetting("shownames") == "0" then state.showNames = false end
  if getSetting("flats") == "1" then state.useFlats = true end

  -- Stored by name, so reordering the palette can't repoint an existing choice.
  local highlight = getSetting("highlight")
  for i, entry in ipairs(HIGHLIGHTS) do
    if entry.name == highlight then state.highlight = i end
  end
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
-- Drawing
------------------------------------------------------------------------------

local function drawCircle(x, y, r, pc)
  local on = active[pc] == true
  local fill = on and highlightColor() or COLOR_OFF
  setColor(fill)
  gfx.circle(x, y, r, true, true)

  if state.showNames and r >= 7 then
    local name = noteName(pc)
    gfx.setfont(2, "Arial", math.max(8, math.floor(r * 0.95)))
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
    local text = scaleLabel()
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
end

local function selectScale(root, scaleIdx)
  state.root, state.scale = root, scaleIdx
  refreshActive()
  saveState()
  needRedraw = true
end

local function clearScale()
  selectScale(nil, nil)
end

local function scaleMenu()
  local menu = newMenu()

  addItem(menu, "Clear scale", clearScale, {checked = state.scale == nil})
  addSeparator(menu)

  for scaleIdx, scale in ipairs(SCALES) do
    addSubmenu(menu, scale.name)
    for root = 0, 11 do
      addItem(menu, ROOT_MENU_NAMES[root + 1] .. " " .. scale.name,
        function() selectScale(root, scaleIdx) end,
        {
          last    = root == 11,
          checked = state.root == root and state.scale == scaleIdx,
        })
    end
  end

  showMenu(menu)
end

local function toggleDock()
  local dock = gfx.dock(-1)
  gfx.dock(dock == 0 and 1 or 0)
  saveWindowState()
  needRedraw = true
end

local function optionsMenu()
  local menu = newMenu()

  addItem(menu, "Show note names", function()
    state.showNames = not state.showNames
    saveState()
    needRedraw = true
  end, {checked = state.showNames})

  -- "&&" is an escaped ampersand: a single "&" is the mnemonic marker in a
  -- menu item and would underline the F instead of showing the symbol.
  addItem(menu, "Swap Sharps && Flats", function()
    state.useFlats = not state.useFlats
    saveState()
    needRedraw = true
  end, {checked = state.useFlats})

  addSubmenu(menu, "Highlight Colour")
  for i, entry in ipairs(HIGHLIGHTS) do
    addItem(menu, entry.name, function()
      state.highlight = i
      saveState()
      needRedraw = true
    end, {last = i == #HIGHLIGHTS, checked = state.highlight == i})
  end

  addSeparator(menu)
  addItem(menu, "Dock window", toggleDock, {checked = gfx.dock(-1) ~= 0})
  addSeparator(menu)
  addItem(menu, "Close", function() gfx.quit() end)

  showMenu(menu)
end

------------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------------

local function handleMouse()
  local cap = gfx.mouse_cap

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
