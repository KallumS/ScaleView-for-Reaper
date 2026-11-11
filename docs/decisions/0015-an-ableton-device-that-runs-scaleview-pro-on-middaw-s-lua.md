# 0015. An Ableton device that runs ScaleView Pro on Middaw's Lua

Taken 2026-11-10. Stands.

## Context

The user is moving from REAPER to Ableton Live and asked for every family REAPER project as Max for Live, each on its own branch. This script draws with REAPER's gfx rather than ReaImGui, and Middaw's Lua 5.4 runtime (JavaScript, held to the real Lua byte for byte) runs in Max 9's `[v8ui]`.

## Decision

`ableton/` holds a Max for Live device that runs the script itself, unchanged, on Middaw's Lua runtime. `ableton/kit/lua_device.js` supplies the `gfx` table, drawn by `ableton/kit/gfx.js` (REAPER's gfx on Max's mgraphics), and the part of the `reaper` table the script uses: defer, ExtState and ProjExtState (kept with the Live set), time_precise, MIDI_GetRecentInputEvent (what came into the device). Each repaint runs the deferred callback once; the last frame that drew is shown until another draws, as REAPER's window keeps it.

gfx.showmenu is modal in REAPER and Middaw's Lua has no coroutines, so the frame that asks is stopped there and the menu drawn; when an item is chosen the click that opened it is played again at the same place - released, pressed, released - or the same keys typed, and the menu call it reaches returns the item. 

## Consequences

- The script is bundled from `reascripts/` at build time: a fix to it reaches the device by rebuilding.
- A `reaper.` function the script starts using that `lua_device.js` does not supply is nil, and the script stops with an error the device shows.
- Nothing here has been opened in Live. The tests run the device in Node on a stand-in for Max and Live.

## 11 November 2026: Live's colours

The user asked for the Ableton versions to look like Ableton, and pointed to the Ableton-inspired scheme the family had tried: Starting Blocks' window themed after Live 8 on 18 September 2026 (commit 2765b0a3), neutral greys with a warm amber accent, replaced the same day by the yellow house scheme. The devices now draw in that scheme (`ableton/kit/palette.js`), with two changes so the family's rules hold: the chrome is #3E3E3E rather than #4A4A4A, because on the lighter grey a secondary word cannot reach 7:1 and still look secondary; and the buttons are light grey with dark ink, because light words on its #5E5E5E buttons reach only 5:1. The greys are neutral, as Live's are, not blue-shifted as the house scheme's.

The window is the script's own and is not edited for Live. `Palette.tone` translates as it draws: the house scheme's colours one for one (each chosen so the pairs the script was checked for stay 7:1 and 3:1), its yellow and the shades made of it to the amber, any other grey made neutral at the same brightness (so a palette of its own keeps every contrast), and every other colour left as it is. The REAPER version keeps the house scheme. `kit/test/palette_suite.js` holds all of it, and was checked by breaking each rule.
