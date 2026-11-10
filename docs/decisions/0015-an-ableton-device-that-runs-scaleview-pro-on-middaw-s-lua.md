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
