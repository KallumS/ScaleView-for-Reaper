# ScaleView for REAPER

Three ReaScripts that draw a 200x100 icon: the twelve pitch classes as circles,
five black keys on the top row over seven white keys on the bottom, with the
notes of the selected scale lit.

| Script | |
| --- | --- |
| `reascripts/kallums_ScaleView Pro.lua` | The full one, and where work happens: names spelled for the key, and it names the chord being played |
| `reascripts/kallums_ScaleView Simple.lua` | Deliberately the lesser one, kept for people who want it: always sharps or always flats, with a menu toggle |

Pro has been renamed repeatedly - Enharmonic, Pro, Detector, Pro again - and an
older, separate Pro was removed once this one contained it. Because of that,
**the ExtState key is tied to the tier, not the display name**:
`kallums_ScaleViewFull` and `kallums_ScaleViewSimple`. `EXT_LEGACY` lists every
name this script has shipped under, most recent first, so the newest saved
state wins over a stale one. Renaming the script again needs no migration; do
not "tidy" the key to match a new name.

**The two are independent copies, not a shared library.** A fix in one usually
belongs in the other too - check both before considering a bug fixed. The
docking fix, for example, applied to all of them.

Simple is not a stripped Pro: it keeps the **Swap Sharps & Flats** toggle,
which the key-aware spelling replaced. That is the reason it still exists, so
do not "simplify" it by removing that option.

## Working in this repo

- **The tests are the specification.** Run all three before and after any
  change; they need only `lua5.4` and take under a second:

  ```sh
  lua5.4 tests/test_scaleview_simple.lua
  lua5.4 tests/test_scaleview_pro.lua
  ```

- They mock `gfx` and `reaper`, drive the script through its own defer loop,
  and read the chord names and circle colours back out of the drawing calls.
  REAPER is not needed and is not available in the sandbox.
- **When fixing a bug, confirm the new test fails on the old code** before
  accepting it. Every regression test here was checked that way; a test that
  passes against the bug is worthless.
- Musical claims get verified, not assumed: the Pro suite checks all 288
  root/scale combinations and asserts that every seven-note scale uses each of
  the seven letters exactly once, which is the property that makes the spelling
  correct.

## REAPER API facts, verified against the documentation

These cost real debugging time. Two of them contradict the documentation.

- **`gfx.showmenu` counts only selectable items.** Separators and submenu
  headers appear in the menu string but are NOT counted in the return value.
  The official docs say "1 if the first field is selected", which reads as
  field-index counting and is misleading - building to it produced an
  off-by-two where a right click opened the wrong menu. Build the action table
  with a counter that only advances for selectable items.
- **A modal menu's own click comes back afterwards.** `gfx.showmenu` is modal,
  and the click used to choose an item reaches the window once the menu closes.
  Read naively it looks like a fresh left click, so the next right click
  matched the left-release test and opened the wrong menu. The scripts set a
  `settlingMouse` flag when a menu closes and ignore the mouse until no button
  is held.
- **`gfx.dock` is a bitfield, not a flag.** Bit 0 is "docked"; the second byte
  is the docker index, which REAPER keeps even while undocked. An undocked
  window that remembers docker 2 reads as `0x200` - non-zero but not docked.
  Test `dock & 1`, and toggle by flipping that bit so the docker index
  survives.
- **A literal `&` in a menu item must be written `&&`.** A single `&` is the
  mnemonic marker and would underline the next character instead.
- **`gfx.getchar()` returns -1 when the window is closed** (0 when no key is
  waiting), which is how the scripts know to quit.
- **`MIDI_GetRecentInputEvent` is the only live MIDI input API.** Every other
  `MIDI_*` function works on recorded items. The Lua form is:

  ```
  integer retval, string buf, integer ts, integer devIdx, number projPos,
  integer projLoopCnt = reaper.MIDI_GetRecentInputEvent(integer idx)
  ```

  `idx=0` is the most recent event and must be asked for first, since it
  latches the list. `retval` is a non-zero sequence number, or zero when there
  are no more events - remember the newest one and walk back to it to get
  exactly the events not yet seen, then apply them in reverse so note-ons and
  note-offs stay in order. It reads the *global input history*: it sees a
  controller being played anywhere in REAPER, but NOT MIDI items playing back,
  and it is not per-track.
- Settings are stored with `SetExtState`/`GetExtState` **by name, never by
  index**, so reordering a table cannot repoint a saved choice. Each script
  reads through a list of the sections it used under earlier names, and of any
  script it supersedes, so a rename or a replacement does not reset an existing
  install. `EXT_LEGACY` holds that list.

## How the spelling engine works

Each scale carries `intervals` (semitones from the root) alongside `letters`
(how many letter names each degree sits above the root letter). A seven-note
scale walks the letters in order, so each degree takes the next letter and
whatever accidental that letter then needs - which is why C# major reads
C# D# E# F# G# A# B# while Db major, the same seven notes, reads
Db Eb F Gb Ab Bb C. Scales that cannot take one letter per degree keep their
conventional spelling instead: major blues repeats a letter for its b3 and 3,
and the diminished scales repeat one across their eight notes.

Roots are offered in both spellings (C# and Db, F# and Gb) plus Cb, so 18
roots x 16 scales = 288 keys. Anything needing more than a double accidental
falls back to a plain sharp or flat name.

In Pro, the same engine spells chord roots, so a chord on Gb reads `Gbmaj7` in
Gb major and `F#maj7` in F# major - but chord symbols stop at one accidental.
A key like Gb minor blues spells notes Bbb and Dbb, which is right on the
circles and absurd in a chord symbol, so `chordNoteName` falls back to the
plain name when the key's spelling is doubled. Keep that split: circles follow
the key, chord symbols follow what a musician would write.

## JSFX, if Pro ever needs to follow playback

Not built. Pro cannot see MIDI items playing back; a small JSFX on the
track feeding it through shared memory would fix that, changing only where the
notes come from. Verified from the JSFX reference:

- `midirecv(offset,msg1,msg2,msg3)` in `@block`. **Calling it consumes the
  event** - anything not handled must be passed on with `midisend()`, or the
  plugin silently swallows the track's MIDI.
- Shared memory: the JSFX declares `options:gmem=someUniquelyNamedSpace` and
  writes to `gmem[]`; the script calls `reaper.gmem_attach(name)` then
  `gmem_read(index)`. A named space is private to plugins using that name and
  holds 8M slots.
- EEL2 traps: `==` compares with a 0.00001 tolerance (`===` is exact); `~` is
  XOR, not NOT; `|`, `&` and `~` have equal precedence evaluated left to right,
  unlike C; memory indices round as `value + 0.00001` truncated, so use
  `x[y|0]`; loops are capped at about 1,000,000 iterations.
- EEL2 does have usable strings - 1024 fixed slots intended for string tables,
  named persistent strings, `sprintf` and `match`. What it lacks is
  associative containers. A full JSFX port is possible; the reason to stay in
  Lua is that this code is already written and tested, not that EEL2 could not
  express it.

## Environment

- **`reaper.fm` is blocked by the sandbox's egress proxy**, so REAPER's own
  documentation cannot be fetched. Ask the user to upload
  `reascripthelp.html` (REAPER: Help > ReaScript documentation) and the JSFX
  reference pages when an API needs checking. Uploads do not survive the
  session - that is why the verified facts above live in this file.
- `raw.githubusercontent.com` **is** reachable, so JUCE, CLAP, the VST3 SDK,
  REAPER's extension SDK headers and Apple's developer docs can be fetched
  directly without asking.
- REAPER 7.79 as of this writing.

## Related

`KallumS/ScaleView` is the same icon as a VST3 / AU / CLAP plugin (JUCE, C++).
Its musical core is a port of the spelling engine here and was verified by
diffing all 288 keys against this repo's output - if the spelling changes here, change it there
too.
