# Scale Selector

A small ReaScript (Lua) icon for REAPER that shows the current key signature /
scale at a glance.

![Scale Selector](docs/preview.svg)

The icon is 200 x 100 pixels and draws the twelve pitch classes as circles,
laid out like one octave of a keyboard without the keyboard:

- **Top row** - 5 circles, the black keys (C#, D#, F#, G#, A#), positioned over
  the gaps between the white keys they sit between, including the missing black
  key between E and F.
- **Bottom row** - 7 circles, the white keys (C, D, E, F, G, A, B).

By default every circle is the same colour. Left-click the icon to pick a
scale; the notes belonging to that scale change colour. Picking a scale does
nothing else - it is purely a visual reference, it does not touch the project,
MIDI editor snap settings, or anything else.

## Installing

Copy `reascripts/kallums_Scale Selector.lua` anywhere, then in REAPER:

1. **Actions > Show action list... > New action > Load ReaScript...**
2. Select the file.
3. Run it from the action list (or bind it to a key / toolbar button).

## Using it

| Action | Result |
| --- | --- |
| Left-click the icon | Scale list - pick a root note under a scale type |
| Right-click the icon | Options: note names on/off, dock, close |
| `D` | Dock / undock the window |
| `Esc` or the close box | Quit |

To keep it in the REAPER UI rather than floating, dock it (right-click >
**Dock window**, or press `D`). The window position, dock state, size and the
selected scale are all remembered between sessions.

The drawing scales with the window, and keeps its 2:1 proportions centred in
whatever space it is given - so a dock that is much wider than it is tall shows
the icon at its natural shape in the middle rather than stretching the circles
across the full width.

## Scales included

Every one of these is available from all 12 root notes:

| Scale | Semitones from the root |
| --- | --- |
| Major | 0 2 4 5 7 9 11 |
| Minor (Natural) | 0 2 3 5 7 8 10 |
| Harmonic Minor | 0 2 3 5 7 8 11 |
| Ionian | 0 2 4 5 7 9 11 |
| Dorian | 0 2 3 5 7 9 10 |
| Phrygian | 0 1 3 5 7 8 10 |
| Lydian | 0 2 4 6 7 9 11 |
| Mixolydian | 0 2 4 5 7 9 10 |
| Aeolian | 0 2 3 5 7 8 10 |
| Major Pentatonic | 0 2 4 7 9 |
| Minor Pentatonic | 0 3 5 7 10 |
| Major Blues | 0 2 3 4 7 9 |
| Minor Blues | 0 3 5 6 7 10 |
| Whole Tone | 0 2 4 6 8 10 |

Ionian is the same set of notes as Major and Aeolian the same as Natural Minor;
both spellings are listed because both names are in common use. That is 168
selectable key signatures in total, plus **Clear scale** to go back to all
circles the same colour.

## Customising

The colours are 0..1 RGB triplets near the top of the script:

```lua
local COLOR_BG       = {0.10, 0.10, 0.12}  -- icon background
local COLOR_OFF      = {0.30, 0.31, 0.35}  -- note not in the selected scale
local COLOR_ON       = {0.20, 0.80, 0.62}  -- note in the selected scale
```

`DEFAULT_W` / `DEFAULT_H` set the icon size for a first run (200 x 100), and
the proportions it keeps when docked.

## Tests

`tests/test_scale_selector.lua` runs the script headlessly against a mock of
REAPER's `gfx` API, clicking menu entries by label and reading back which
circles were drawn lit. It checks all 168 scale/root combinations against the
interval formulas, the menu index mapping, the clear/options menus, the docked
layout and that the selection survives a restart:

```
lua5.4 tests/test_scale_selector.lua
```

The mock reproduces REAPER's real `gfx.showmenu` contract: the returned index
counts **only selectable items**, so separators and submenu headers must not be
counted when mapping the result back to an action.
