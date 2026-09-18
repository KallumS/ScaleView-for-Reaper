# ScaleView for REAPER

Two ReaScripts that draw a 200x100 icon: the twelve pitch classes as circles,
five black keys on the top row over seven white keys on the bottom, with the
notes of the selected scale lit.

| Script | |
| --- | --- |
| `reascripts/ScaleView Pro.lua` | The whole thing: names spelled for the key, a **Simplify Note Names** option that switches to piano-key naming, and the chord you play **read** rather than looked up. ExtState key `ScaleViewPro`. |
| `reascripts/ScaleView Simple.lua` | **Pro with the chord detection taken out, and nothing else changed.** Same icon, scales, spelling, menus, palette, click model and per-project key. ExtState key `ScaleViewSimple`. |

There used to be five. `kallums_ScaleView.lua` (Pro and Simple merged), an
older table-based `Pro`, `Alt` and `Alt 2` were all folded into the script
above, which is `Alt 2` under its final name. Nothing was lost in the merge -
the one test unique to `Alt` was carried over first, and the scale/root sweep
that the note below used to credit to the Pro suite actually lives in the
Simple suite, which is still here.

Pro has been renamed repeatedly - Enharmonic, Pro, Detector, Pro again, then
Alt, Alt 2 and Pro once more - and it has absorbed three other scripts along
the way. Through all of that the ExtState key was deliberately frozen, and this
file said in bold never to tidy it to match the name, because every rename
would otherwise have reset somebody's settings.

**That is over.** When the `kallums_` prefix came off the filenames the user
pointed out that nobody but them had ever installed the scripts, so the one
moment it was free had arrived. The keys are now `ScaleViewPro` and
`ScaleViewSimple`, matching the files, and the six-deep list of historical
sections went with them - those sections could only have existed on one
machine, and had already been migrated forward.

`EXT_LEGACY` keeps exactly one entry each, the key immediately before the
rename, so even that one machine loses nothing. The project section in the
.RPP moved the same way, `kallums_ScaleView` to `ScaleView`, with
`PROJECT_LEGACY` read when a project has nothing under the new name.

The **reason** for the old rule still stands, though, and applies from here on:
a key is tied to what a script is, not to what it is called. Renaming again
once other people have these installed would cost them their settings, and
there would be no second free moment.

Pro carries Simple's naming as an option: with `state.simpleNames` set,
`noteName` returns the plain sharp table instead of the key's spelling. Chord
*detection* is untouched by it - only the names it reports change, since they
come from `noteName`. The scale label keeps the key as chosen from the menu, so
picking Gb Major still says Gb Major when simplified.

**The two scripts are independent copies, not a shared library.** A fix in one
usually belongs in the other - check both before considering a bug fixed. The
docking fix applied to every script there was.

**The ring round a played note is always one colour - `#FFF200` - and it must
not be made to depend on the circle underneath.** The hue is the user's to
choose and has changed once (it was white); what must not change is that it is
unconditional. That was tried, on the strength of a contrast calculation, and
it looked broken in REAPER. Keep the calculation in mind only as the shape of
the mistake: the ring reads at just 1.4:1 to 2.0:1 against a highlight colour,
which is true, but **both strokes are drawn at `r + 1.5` and `r + 2.5`, outside
the filled circle, on the background**. That is the surface a ring has to
contrast with, and `#FFF200` reads 12.8:1 against it (white read 17.4:1 on the
old background and 15.0:1 on `#23272e`). Recompute when either colour moves;
no plausible icon background brings the figure near a fill's 2.0:1. The
arithmetic was right about the wrong surface, and a test pins the ring to one
colour so it cannot be made conditional again.

**No highlight may be the ring's own colour**, for the part of the ring that
does touch a circle. With a yellow ring the colour to keep out is a yellow, and
Gold is the nearest the palette comes - 1.4:1 against the ring, where white
against Gold was 1.6:1. Simple has no rings and so no clash, but it carries the
same six colours because it is meant to match, and both suites assert it.

## The house colour scheme

ScaleView's colours are not arbitrary any more: the user is standardising one
scheme across their projects, and this is it, written down because the message
carrying it does not survive the session.

**The three that carry it, plus the ink.**

| | | |
| --- | --- | --- |
| Accent | `#FFF200` | chosen buttons, checkmarks, active slider grab, every MIDI note |
| Controls | `#A9AFBA` | unchosen buttons, slider grabs |
| Ground | `#23272E` | window chrome |
| Ink | `#14171C` | text on any button - grey and yellow alike |

**The cool grey ramp**, darkest to lightest. **Every entry satisfies R < G < B,
and that is the load-bearing property** - a neutral grey of the same lightness
reads flat beside the yellow.

| | | | | | |
| --- | --- | --- | --- | --- | --- |
| `#111419` piano-roll ground | `#14171C` borders, button ink | `#1A1D23` sunken frames, scrollbar track | `#1B1F25` popups, title bar | `#1E2228` roll beat lines | `#22262D` frame hover |
| `#23272E` window chrome, active title | `#2A2F37` frame active | `#3A404A` separators, roll bar lines | `#585F6B` scrollbar grab | `#6D7581` scrollbar hover | `#8A919C` disabled/dim text |
| `#8F96A2` button held | `#A9AFBA` buttons | `#BFC5CE` step numbers | `#C0C6CF` button hover | `#DDE1E7` body text | `#F2F4F7` playhead |

One off-ramp colour: **`#D2483F` for warnings** - red rather than a shade of the
accent, so a warning cannot be mistaken for a selection.

**Two rules travel with the hexes, and they are the part worth keeping:**

- **Light controls force dark text.** `#A9AFBA` and `#FFF200` are both far
  lighter than the ground, so body text at `#DDE1E7` vanishes on them. Every
  button needs `#14171C`, *including the unselected ones* - that is the trap,
  because the selected button looks fine while the rest go unreadable.
- **Hover and held are derived, not picked.** `#C0C6CF` and `#8F96A2` are
  `#A9AFBA` shifted +/-18% toward white and black, and the yellow's states are
  computed the same way at runtime rather than stored - so re-tinting means
  changing one value, not three.

### Where ScaleView sits against it

Exact: `COLOR_BG` is Ground, `COLOR_TEXT_ON` is Ink, `COLOR_HELD` is Accent.
`COLOR_LABEL` and `COLOR_CHORD` were near-misses - `#B8BDCC` and `#F2F5FA`,
10.8 and 3.2 away from `#BFC5CE` and `#F2F4F7` - and have been snapped to the
ramp. All four of ScaleView's greys already satisfied R < G < B, which is why
the scheme sat on it so easily.

**Two things are deliberately still off it, and both need a decision rather
than a tidy-up:**

- **The unlit circle is dark with light text** (`COLOR_OFF` `#4C4F59`,
  `COLOR_TEXT_OFF` `#9EA3B2`), where the scheme's unchosen button is `#A9AFBA`
  with `#14171C` ink. Inverting it would follow the scheme exactly, and it
  would also make the notes *outside* the key the brightest thing in the icon -
  which is the opposite of what the icon is for. These two constants move
  together or not at all: a light fill demands the dark ink, and a dark fill
  demands light text.
- **Lit circles are one of six user-chosen highlights, not the Accent.** In a
  piano roll every MIDI note is `#FFF200`; here the accent already means
  *being played* (the ring), and the highlight means *in the key*. Those are
  two different states in one icon and they cannot share a colour - the ring
  would vanish into the circle, which is the rule two paragraphs up. So
  standardising the lit circle onto `#FFF200` requires moving the ring
  somewhere else first, and the six-colour menu becomes vestigial.

**What decides a redraw is the held set, not the chord name** (`heldVersion`).
Those are not the same thing: adding B to D E Ab leaves the name `E7/D`,
because B is the fifth and a missing fifth is silent, so a poll that redrew
only on a name change left that B unringed until something else forced a
frame. It reached REAPER as "B never lights up, then lights up when I resize
the window and stays lit for seconds" - which is what redrawing on the name
looks like from outside, since a resize is the other thing that forces one.
The JUCE plugin never had this: its editor repaints on the held-note mask.
Anything else that gets drawn from the notes has to go through `heldVersion`
too.

**Simple is now Pro minus the chord reader, and that is the only difference.**
It was once its own lesser thing, with a **Swap Sharps & Flats** toggle instead
of key-aware spelling; the user asked for the two to match in every way except
the detection, so that toggle is gone and Pro's spelling plus **Simplify Note
Names** replaces it. An earlier version of this file said never to remove that
toggle - superseded, deliberately. What stays true is the other half of the
rule: **a fix to either script belongs in both**, because they are independent
copies of the same code.

Simple must not read MIDI at all. Its suite counts every call into
`MIDI_GetRecentInputEvent` and fails if the script makes one, however many
notes are waiting - "no chord detection" means it never looks, not that it
looks and says nothing.

## A table cannot be made complete - the experiment that settled it

`ScaleView Pattern` was a second script, Pro with the chord reader replaced by
a port of Long Kelvin's pattern-matching algorithm, built so the two approaches
could be judged side by side against Scaler. **It has been deleted** - Pro won
the comparison outright and the user has tested both. The result is kept here
because it is the answer to "why not just match a table of chords", and that
question will come round again:

| over all 17,688 voicings of three to seven notes | Pro | Pattern |
| --- | --- | --- |
| symbol accounts for exactly the notes | **100%** | **23.5%** |
| symbol leaves a played note out, or names one not played | 0 | 12,584 |
| gives up and reads the notes out | 0 | 318 |

| on real music | sonorities | Pro | Pattern |
| --- | --- | --- | --- |
| music21 core corpus, by instance | 363,963 | **99.999%** | 93.276% |
| music21 core corpus, by distinct set | 37,106 | **99.992%** | 83.270% |
| the standards vocabulary, every inversion | 2,097 | **100%** | 99.05% |

Read those together: **a table is strong exactly where it was aimed and
collapses outside it.** 62 patterns covered the jazz vocabulary they were built
for, held 93.3% of real score sonorities by instance but only 83.3% by distinct
set - the chords that occur most often are the ones it had patterns for - and
managed one in four across the exhaustive sweep. Its failures were one failure
repeated: a pattern wins while leaving a note unexplained, so `G D F` reads
`G5`. Raising the penalty for an unexplained note helps to 23.5% and then the
engine drops below its own threshold and gives up instead. That is a ceiling,
not a tuning problem.

Two other findings from it are worth keeping:

- **Tying detection to the selected scale did nothing there either.** Scoring a
  candidate root for being a scale degree moved Pattern's objective score from
  22.07% to 22.08%. That reproduces, on a completely different architecture,
  the null recorded below for Pro - and two independent nulls settle it.
- The port was made from the C++ source rather than that project's own
  documentation, **which disagrees with its code** in at least three constants.
  Read the source.

## Working in this repo

- **The tests are the specification.** Run both before and after any change;
  they need only `lua5.4` and take under a second:

  ```sh
  lua5.4 tests/test_scaleview_pro.lua
  lua5.4 tests/test_scaleview_simple.lua
  ```

- They mock `gfx` and `reaper`, drive the script through its own defer loop,
  and read the chord names and circle colours back out of the drawing calls.
  REAPER is not needed and is not available in the sandbox.
- **When fixing a bug, confirm the new test fails on the old code** before
  accepting it. Every regression test here was checked that way; a test that
  passes against the bug is worthless.
- Musical claims get verified, not assumed: the **Simple** suite is the one
  that sweeps every root and scale type against the interval formulas - all
  288 of them now that Simple offers Pro's eighteen roots. An earlier version
  of this file credited that sweep to the Pro suite, which never had it - worth
  knowing before deleting anything on the strength of a claim written here.

### Lessons learned

Every one of these cost something. They are method rather than music, they
generalise beyond this repo, and the detail behind each sits in the section
named at the end of its line.

- **A surprising accuracy number is a bug in the measurement.** Six times now
  the fault was in the rig and not the engine: a truth table with no sixth
  chords, an inversion set built by mechanically slashing symbols, a checker
  demanding a fifth the engine deliberately never prints, a "390 misnamed
  suspensions" that was a table with no `7sus4` in it, a sweep generator that
  silently produced voicings with duplicate pitch classes, and a 68% against
  human analyses that was three separate faults in how labels were joined to
  slices. Validate the checker against data already known to be right *before*
  believing any figure it produces. (*What it scores on real music*, *Generate
  that sweep carefully*, *Against a human's name for the same notes*.)
- **Validate the input distribution too, not just the checker.** The DCML
  corpora scored a flat 100%, which is exactly the shape of a scanner that is
  quietly dropping notes. It was real: their sonorities stop at seven pitch
  classes, so the cluster guard never fires. The histogram is what turned a
  suspicious number into an explained one. A perfect score is a question, not
  an answer.
- **Say what did not parse.** 12 of 196 quartet movements and 68 of 764 When in
  Rome scores never reached the engine, because music21's MusicXML importer
  rejected them. Scoring the remainder and quoting the whole corpus size would
  have been wrong in a way nobody could have caught from the outside. Report
  the denominator you actually measured.
- **Profile the harness, not only the thing under test.** `tools/runner.lua`
  kept every event it had ever been handed and inserted each at position 1, so
  the *measuring rig* was quadratic. The 17,688-voicing sweep went from minutes
  to 3.4 seconds with a bound on the history and byte-identical output. When a
  sweep is slow, suspect the scaffolding first - it is the part nobody tests.
- **Change the engine, the tests and the checker together.** `sus#4` went into
  the script and its tests but not into `check_symbol.py`, which then reported
  84 failures that were the checker disagreeing with itself. The independent
  checker is only independent if it is kept current.
- **A published reference outranks a document somebody hands you.** `sus#4` was
  added on the strength of a reader's chord-theory write-up and was wrong;
  Hutchinson 31.2, already cited in this file, already said a raised fourth
  over a natural fifth is a #11. Check a new claim against what is already
  established here before building on it. (*There are two suspensions, not
  three*.)
- **Diff the output; do not check examples by eye.** Parity with the plugin,
  the effect of every weight change, the claim that two `handleMouse` functions
  were identical - all settled by dumping one line per case and diffing. It is
  the single habit that has caught the most.
- **Make the regression test fail on the old code first.** Stated above as a
  rule; repeated here because it has caught a test of ours that passed against
  the bug it was written for.
- **A test that forces the frame it then reads cannot see a redraw bug.** The
  suite's `label()` helper toggles `gfx.w` so the label can always be read,
  and `play()` calls it - so every chord assertion in the file was reading a
  frame the test itself had demanded. A note that failed to trigger a redraw
  was therefore invisible to all of them, and shipped. The test for it calls
  `frame()` alone, with no resize and no `label()`. **Ask what your harness
  supplies that the real thing does not**: the mock was not wrong, it was
  helpful, which is worse.
- **This file is not evidence about the code.** Several confident claims in it
  turned out to describe a version that no longer existed - Simple's menus,
  Simple's project state, Simple's toggle state, the scale sweep's location.
  Each was corrected only after reading the code. Treat any claim here as a
  lead to verify, not a fact to act on.
- **Two independent nulls beat one, and three end the argument.** Tying chord
  detection to the selected scale moved Pro's accuracy not at all, and moved a
  pattern-matching engine's - a completely different architecture - by one
  hundredth of a point. Then Scaler itself, which this repo treats as the
  reference, turned out to name the same four notes on the same root in two
  different keys and change only the spelling. One null invites a retry with
  different weights; three, from unrelated engines, close the question.
  **Note what the third one cost**: a rule was written into this file as
  probable, with the experiment that would settle it written beside it. That
  is the cheapest form a wrong guess can take - the experiment took one chord
  in one key, and the note said in advance what each answer would mean.
- **Prefer a number to an argument.** "A table cannot be made complete" was an
  opinion until the table-based engine was built alongside and measured at
  23.5% against Pro's 100% on the same 17,688 voicings, with the ceiling on its
  tuning located as well. Building the thing you are arguing against is often
  cheaper than the argument. (*A table cannot be made complete*.)
- **Measure without redistributing.** Two of the five corpora are CC BY-NC-SA.
  They were cloned, scanned, scored and discarded; nothing from any corpus is
  in this repository, and the table records each licence so the next person
  does not have to work it out again.

## REAPER API facts, verified against the documentation

These cost real debugging time. Two of them contradict the documentation.

- **`gfx.showmenu` counts only selectable items.** Separators and submenu
  headers appear in the menu string but are NOT counted in the return value.
  The official docs say "1 if the first field is selected", which reads as
  field-index counting and is misleading - building to it produced an
  off-by-two where a right click opened the wrong menu. Build the action table
  with a counter that only advances for selectable items.
- **A modal menu's own click comes back afterwards, and not always in the next
  frame.** `gfx.showmenu` is modal, and the click used to choose an item
  reaches the window once the menu closes. Read naively it looks like a fresh
  click. Ignoring the mouse until no button is held is **not enough** - that
  was tried, and a stray click arriving a frame or two later still opened a
  menu, which is what kept happening in REAPER. **Both scripts** also wait
  `MENU_SETTLE_SECONDS` (0.25) from when the menu closed, and both suites
  prove it by firing the stray click 0, 1 and 3 frames late; the buttons-only
  version fails the last two.
- **Neither script has left/right menus.** Which menu opens depends on
  where the click started - a circle opens the scale list, empty space opens
  the options - so there is no wrong menu to open, and either mouse button
  does the same thing. `isOverCircle` uses the same `layout()` the drawing
  does, so the hit areas cannot drift from the circles.

  An earlier version of this file said Simple "still uses the two-button
  arrangement and the weaker settle". That was true of the old Simple and was
  left behind when Simple was rebuilt as Pro minus the chord reader; the two
  `handleMouse` functions are now byte-identical, settle and all. Checked
  rather than assumed, which is the point of the note: this file is not
  evidence about the code, the code is.
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

## Script lifetime and persistence

From REAPER's ReaScript page, which is the authority on this:

- **A deferred script runs "until terminated by the user."** That is the whole
  of its life. REAPER does not record that a script was running, a project file
  stores tracks and FX rather than running actions, and there is no API for a
  script to ask to be started - `set_action_options` only covers relaunch
  behaviour and toggle state within a session. So a script not reopening when
  REAPER or a project is reopened is REAPER's design, not a bug to fix. Users
  asking for it want a startup action, not a change here.
- Two persistence mechanisms exist, and only two:
  - `SetExtState`/`GetExtState` - "persist between REAPER instances". This is
    what every script here uses, and it is **global**: the scale follows the
    user between projects rather than belonging to one.
  - `SetProjExtState`/`GetProjExtState` - "save data within the project RPP
    file". **Both scripts** use this for the scale, so each project reopens in
    its own key. (This file used to say Simple did not; it does, and its suite
    covers the round trip and the project switch. Another one left behind when
    Simple was rebuilt as Pro minus the chord reader.) Only the scale goes in
    the project - colour, note names and window are preferences and stay
    global.
    Writing project ext state marks the project edited, which is expected.
    The script polls `EnumProjects(-1)` each frame to notice a switch between
    open projects; a project with no scale of its own is left showing whatever
    is up rather than blanked.
- **`__startup.lua` is not in REAPER's ReaScript documentation.** It is widely
  used and described by community sources, and probably works, but do not
  present it to the user as an official REAPER feature - that was done once on
  the strength of a blog post and a forum thread. The SWS extension's global
  and project startup actions are the route that can be stated without
  qualification.
- REAPER 7+ scripts can set their own on/off toggle state through
  `set_action_options`. Pro calls it with `1|4` at startup -
  toggle on, and re-running the action terminates this instance rather than
  starting a second - and with `8` from its `atexit`. That is what makes a
  toolbar button light up while it runs and toggle it off when clicked again.
  Both calls are guarded on the function existing, so older REAPERs are fine.
  **Simple does this too** - the line here saying it did not was a third
  leftover from before Simple was rebuilt, and both suites assert it.

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

**The sixteen scales are canonically specified**, checked against Ian Ring's
*A Study of Scales* (ianring.com - blocked by the egress proxy, so the user
uploaded it). Ring numbers a scale as a 12-bit set with the root as bit 0, so
Major is 2741. All sixteen match:

| | | | |
| --- | --- | --- | --- |
| Major / Ionian | 2741 | Minor (Natural) / Aeolian | 1453 |
| Harmonic Minor | 2477 | Dorian | 1709 |
| Phrygian | 1451 | Lydian | 2773 |
| Mixolydian | 1717 | Major Pentatonic | 661 |
| Minor Pentatonic | 1193 | Major Blues | 669 |
| Minor Blues | 1257 | Whole Tone | 1365 |
| Diminished Whole-Half | 2925 | Diminished Half-Whole | 1755 |

Two naming notes, so nobody "corrects" these later:

- **Major Blues (669) has no traditional name in Ring's list** - he calls it
  *Gycrimic*, one of his coined names for scales without one. Minor Blues
  (1257) is his *Blues Scale*. Ours are the names players use; keep them.
- Our two octatonics are Ring's *Diminished* (2925) and *Octatonic* (1755).
  They are modes of each other, one Forte class (8-28), and his pair of names
  does not carry the whole-half / half-whole distinction that ours does. Do
  not rename ours to his.

The same engine spells chord roots, so a chord on Gb reads `Gbmaj7` in Gb
major and `F#maj7` in F# major. Keep the split it rests on: **circles follow
the key, chord symbols follow what a musician would write.**

In Pro, `chordNoteName` draws chord roots and basses from
the same eighteen spellings `ROOTS` offers - the roots real keys are built on.
Anything else falls back to a plain name leaning the way the key does: the
double accidentals of a key like Gb minor blues (`Amin/C`, never `Bbbmin/Dbb`)
and the theoretical spellings B#, E# and Fb, so B# D# E# in C# major reads
`CminAdd11` rather than `B#minAdd11`.

Two rules were learned by breaking them back when chords were matched against
a table. **That table is gone** - the section below is how a chord is named now
- but both rules are still live, and are still the fastest way to tell whether
a change to the weights has broken something:

- **A missing fifth is silent, a missing third is not.** The fifth is optional
  in an added-tone chord, so `{0,3,5}` is `minAdd11`; a missing third changes
  the quality, so `{0,7,10}` is `7(no3)`.
- **An incomplete chord must not beat a complete one.** `{0,4,9}` reads
  `Amin/C`, not `C6` - a rooted reading with a hole in it should not steal a
  complete triad's inversion. In the table this meant leaving `{0,4,9}` and
  `{0,3,9}` out of it; now it falls out of `COST_INVERSION` against
  `RANK_NO_FIFTH`, which is why those two weights are not free to retune.

## How Pro names a chord

The chord is **read, not looked up**, and that is what the old table-based
engines could not do. A table is matched exactly, so a voicing it does not hold
reads out as a list of notes, and lengthening it never ends - a chord is a
quality with any number of tones stacked on top. Measured over every three-,
four- and five-note voicing in every bass position (6,600), the old table named
28% of them and this engine names all of them.

It splits the symbol. The **third, fifth and seventh** are a closed vocabulary -
about thirty combinations, each with an agreed name - so that half is still a
table, `CORE_RANK`, ordered by how common the quality is. Everything above it
is **described**: whatever the core did not consume is read off as a sixth,
ninth, eleventh or thirteenth, altered or not.

Each candidate root is costed and the cheapest wins. Cost is the core's rank
plus what its extensions cost plus `COST_INVERSION` when the root is not in the
bass, so the weights are the whole of the musical judgement. Things learned
tuning them, each of which broke a test first:

- **A missing fifth is not one thing.** A seventh chord is routinely voiced
  without one - that is the standard shell - while a triad without its fifth is
  two notes and a guess. Hence `RANK_NO_FIFTH` (20) against `RANK_NO_FIFTH7`
  (4). Charging both alike made F G A A# read `Fadd9Add11` instead of
  `Gmin9/F`.
- **An alteration must belong to the chord under it.** b9, #9 and b13 are the
  dominant's; over a min7 or a plain triad they mean the root is wrong. Without
  that rule C D E G B over E came out `Emin7b13` rather than `Cmaj9/E`. A #11 is
  the exception - at home on anything with a perfect fifth - and any alteration
  over an already-altered fifth is suspect (`COST_CLASHING`).
- **There are two suspensions, not three. `sus#4` was tried and reverted.**
  A reader's chord-theory document lists `Csus#4` (C F# G), and it was added
  here on the strength of that. It was wrong, and the user caught it. Three
  things say so:

  - **Hutchinson 31.2, already cited below and already holding**: with a
    natural fifth present, a raised fourth is a **#11**. That is exactly the
    condition `sus#4` fired on (`has[6] and has[7]`), so adding it overrode
    the repo's own reference.
  - **A suspension replaces the third and resolves to it by step.** A #4 sits
    a semitone under a fifth that is already sounding; it is not standing in
    for a third, and it has nothing to resolve to.
  - **The document itself excludes it**: "these are all of the main triads
    that are written down in music (minus sus#4 or susb2 chords)", and
    "generally when people talk about suspended chords, this chord is not
    included". It is one musician's classification, not nomenclature.

  The names it displaced were already standard and correct: C F# G is
  `Gmaj7sus4/C`, C Db F# G is `Caddb9#11(no3)` - which was applying the #11
  rule properly all along. Do not add it back without a published source that
  outranks Hutchinson.

- **A suspension replaces the third; it does not take added tones.**
  "sus4 add6 add9" is not a chord anybody writes, so a sus core pays
  `COST_SUS_EXTRA` for every tone it carries. The one exception is a sus4 with a
  seventh and a ninth, which is how an eleventh chord is voiced and is named
  `11` - and only over an unaltered fifth, or the name would swallow the very
  note that makes the chord odd.
- **The highest natural extension names the chord, but only when the ninth is
  actually played.** A stacked number claims every degree beneath it.
  Hutchinson's chord list (31.4) prints `Cm11` and `Cm7(11)` side by side, six
  noteheads against five - the first has the ninth in it, the second does not -
  so a ninth that is not there is bracketed after the seventh instead:
  `Cmin7(11)`, `C7(13)`. An **altered** ninth still fills the place, since the
  same list prints `C13sus(b9)` with six noteheads, which is why `C13b9` keeps
  its number. A natural eleventh over a major third clashes, so it is bracketed
  whatever else is present.
- `(no3)` goes at the end of the whole symbol, so it reads as a chord with a
  note taken out: `maj7b5(no3)`, not `maj7(no3)b5`.
- **A sixth is a 6 without a seventh under it and a 13 with one, and the
  flattened sixth follows the same rule** - `C(add b6)`, then `C7b13`. Only the
  printed name changes: the cost still reads a flat sixth as a b13 wherever it
  sits, which is what keeps E G B C reading `Cmaj7/E`.
- **The root-to-third interval decides most.** A quality `CORE_RANK` does not
  name is ranked by `RANK_UNNAMED[third]`: a real third, major or minor, keeps
  a chord readable however odd the rest is (25), a suspension is a stand-in for
  one (70), and a shape with neither is the last resort (90). Before this every
  unnamed quality cost the same 100, so F A B lost to `B7b5(no3)/A` - a reading
  with no third at all - instead of `F(b5)`.
  A third excuses **one** oddity, not two: every altered fifth carrying a
  seventh that anyone actually plays is already in `CORE_RANK`, so one that is
  not gets `RANK_TWICE_ODD` on top, or C D Eb Gb Cb reads `CminMaj9b5`.
- A bare altered fifth is bracketed - `C(b5)`, never `Cb5`, which reads as a
  chord on C flat.
- **A third beats a shape with none, even from an inversion**, and two entries
  make that true rather than merely stated. `maj7b5` was missing from
  `CORE_RANK` although players write it constantly as the Lydian tonic, so it
  paid `RANK_UNNAMED` plus `RANK_TWICE_ODD` - 37 before any slash - and lost to
  readings with no third at all: D D# G A read `Dsus4b9` rather than
  `D#maj7b5/D`. And the two third-less qualities whose fifth is *also* altered
  sit at 41 and 42 rather than 32 and 33, past `COST_INVERSION` from an unnamed
  quality with a third (25), so D E A# reads `Bb(b5)/E` the same way F A B
  reads `F(b5)`. **The perfect-fifth pair stay at 30 and 31**: a seventh over a
  bare fifth is a real voicing, and moving them makes C G Bb read
  `GminAdd11/C` instead of `C7(no3)`.
- **A minor sixth is charged one more than any other sixth** (`COST_MIN_SIXTH`
  against `COST_SIXTH`) because it is the one sixth that is also something
  else: A C E F# is `Amin6` and equally `F#min7b5`, the half-diminished on its
  third. The two tie exactly, and the half-diminished is what Scaler prints,
  what jazznet's labels carry, and what analysts write - flipping it raised
  agreement with When in Rome's analysts from 91.99% to 92.58% and with
  jazznet from 63.1% to 66.7%.
- **A diminished seventh carrying a ninth is a `dim9`**, not a `dim7` with a
  note stuck on the end. Only the spelling changes: it still costs what an
  added tone costs, so which reading wins is untouched.
- **Which note is the fifth is costed, not guessed.** With both a flattened and
  a raised fifth sounding and no perfect one between them, `core()` used to take
  the flattened one greedily, so C E F# G# B read `Cmaj7b5b13` - a b13 over a
  chord that is not at home with one - where `Cmaj7#5#11` costs 14 less. Both
  readings are built and the cheaper wins; everywhere else the second is not
  built at all. It moves 24 names in the sweep, `maj7b5b13` to `maj7#5#11` and
  `9b5b13` to `aug9#11`. Found by running Wikipedia's *List of chords* through
  the engine, which is `tools/wikipedia_chords.py`.
- **Two notes are an interval, except a fifth or a third.** B D is `Bmin(no5)`
  and C E is `Cmaj(no5)` - the missing fifth is said out loud because with two
  notes it cannot be silent, and printing `C` for C E would claim a G nobody is
  playing. A third has only one reading, since four semitones are a major third
  one way and a minor sixth the other. A second, a fourth, a tritone, a sixth
  or a seventh is still read out as notes.

### The complete triad wins

Where two readings fit, the one holding a complete triad - a real third with a
perfect fifth - wins, and the odd notes hang off it. That is how Scaler 3 reads
a chord. It is expressed as what counts as a home for an alteration:

```lua
local dominant = third == "maj" and seventh == "b7"
local triad    = (third == "maj" or third == "min") and fifth == "P"
athome = ... and (token == "#11" or dominant or (triad and token ~= "b13"))
```

Without the `triad` clause, only a dominant is at home with a b9, #9 or b13,
and C D Eb Gb Cb reads `D13b9/C` rather than Scaler's `Cbaddb9#9/C`.

`triad` is the right lever, **not `COST_CLASHING`**. Cheapening the alteration
cost reaches the same answer for that chord but takes `C9/E` down with it
(`Emin7b5b13`), because that reading's fifth is flattened - it holds no
complete triad, so `triad` leaves it alone.

A **b13 is excluded**, and that was measured rather than guessed. It is the one
alteration whose note is nearly always a chord tone of something plainer: E G B
with a C in it is Cmaj7 in first inversion, not Emin wearing a b13. Letting a
complete triad take one cost 207 misnamed sonorities across 382 Bach chorales
and 7 points on inverted jazz voicings, and bought nothing - the chord the rule
exists for carries a b9 and a #9.

### How the bass is decided

The bass is the lowest note sounding. It is found separately from the root and
a slash names it, which is what makes C E A read `Amin/C` and what separates
`Bsus2` from `F#sus4`.

**One convention sits on top of that, and it is Scaler's.** A root sounding in
more than one octave that is a first, third or fifth degree of the key reads as
root position, and the slash comes off: E G C C is `C`, not `C/E`. Doubling the
root is how a chord is voiced around its root rather than inverted. This was
the last place Pro and Scaler parted company on the same notes - the reading
was right and the bass was not - and `readAsRootPosition` is the whole of it.

Three things keep it honest:

- **It can only remove a slash, never invent one.** What follows a slash is
  still always the lowest note sounding, so no symbol can name a bass that is
  not there, and no note goes unaccounted for: the notes a symbol claims are
  unchanged by it.
- **The key decides which notes qualify**, and the degrees come off the
  selected scale rather than being assumed to be a major triad, so F A D D is
  `Dmin/F` in C major and `Dmin` in D minor. With no scale selected the assumed
  key supplies them - C, E and G, in `ASSUMED_TONIC`, which has to move if
  `ASSUMED_KEY` ever does.
- **The cost model is untouched.** The reading is still chosen with the lowest
  note as the bass, which is what every figure below measured; the rule decides
  only how the winner is written down. The 17,688-voicing sweep is byte
  identical either way, because nothing in it is doubled - the rule needs a
  real voicing to fire at all.

Measured over the five corpora and the music21 core corpus, it renames 1.2% to
3.3% of distinct sonorities (1.0% to 2.8% by instance). Every rename is an
inversion losing its slash - `E C G C` to `C`, `B G D G` to `G`, `D# C G C` to
`Cmin` - so what it costs is the classical reading of those voicings, which is
the trade that was asked for. Nothing else moved.

### What it scores on real music

| Corpus | sonorities | Pro |
| --- | --- | --- |
| **The whole music21 core corpus** - 3,194 files, 33 collections | **363,963** | **99.999%** |
| Bach, 382 chorales (`czhuang/JSB-Chorales-dataset`) | 89,108 | **100%** |
| Chopin, 49 mazurkas (`craigsapp/chopin-mazurkas`) | 13,053 | **100%** |
| The standards vocabulary, every inversion | 1,679 | **100%** |

Every collection in the corpus comes out at 100% except two, and both misses
are the same thing. Four sonorities out of 363,963 - two in Monteverdi, two in
Schoenberg - carry **eight** pitch classes, so they hit the deliberate guard in
`detectChord` ("past a certain thickness there is no chord left to find, only a
cluster") and are read out as notes. That is the design working, not a defect;
the largest collection, 1,318 Palestrina works and 231,859 sonorities, is
exactly 100%.

**Five more corpora, none of them music21's own.** Asked for by licence, so
each row says which: two are CC BY-NC-SA, which is why nothing from any of them
is in this repository - these are measurements, not redistribution. Cloned,
scanned, scored, discarded.

| corpus | sonorities | distinct | by instance | by distinct set |
| --- | --- | --- | --- | --- |
| Sapp's Bach 370 chorales (`**kern`, CC BY-NC-SA) | 29,300 | 4,658 | **100%** | **100%** |
| DCML annotated corpora (13 repos, CC BY-NC-SA) | 202,692 | 54,711 | **100%** | **100%** |
| OpenScore String Quartets (CC0) | 517,862 | 112,811 | **99.999%** | **99.997%** |
| OpenScore Lieder (CC0) | 348,324 | 95,331 | **99.995%** | **99.983%** |
| When in Rome (CC BY-SA) | 118,099 | 35,239 | **99.999%** | **99.997%** |

Same story as the core corpus: **every single miss is an eight-or-more
pitch-class cluster** hitting the same guard in `detectChord` - `C D D# E G G# A
B`, `C C# D E F F# G B`, `C C# D D# E F G A A#`. Twelve missed sonorities out
of 1,216,277, eight distinct pitch-class sets between them, and not one is a
chord that was misnamed - each is the guard refusing to name a cluster.

Two cautions about those numbers, because the rule here is that a surprising
figure is a bug in the measurement until proved otherwise:

- **Some files did not parse, and that is music21, not the engine.** 12 of 196
  quartet movements and 68 of 764 When in Rome scores fail its MusicXML
  importer with `found unknown MusicXML type: None`. The rows above are 184 and
  696 files. Lieder and Bach 370 had no failures.
- **DCML was read from its note tables, not its scores** - `notes/*.tsv`,
  sonorities built from `quarterbeats`, `duration_qb` and `midi` - so it went
  through a scanner the other rows did not use. It reads 100%, which would be
  suspicious on its own; the pitch-class histogram says why. DCML's sonorities
  stop at seven pitch classes, so the cluster guard never fires. Bach 370 is
  three and four, as four-part chorales have to be. Both distributions were
  checked before the scores were believed.

For comparison the old table engine managed 96.6% on Bach and 87.1% on the
jazz set. Brahms and Tchaikovsky were asked for too and are **not** covered:
neither music21's corpus nor the Humdrum collections have them, and the MIDI
that is on GitHub for them comes from scrapes of unclear provenance. If they
matter, the way in is a MusicXML, kern or MIDI upload.

The old engine was never *wrong* where it answered - every shortfall was it
giving up and printing the notes, which is why it felt trustworthy while
missing things. The gap was coverage, not correctness.

Sources: music21's entire core corpus (Palestrina, Bach, Beethoven, Monteverdi,
Trecento, Mozart, Haydn, both Schumanns, Joplin, Schoenberg, folk collections
and the rest - 3,194 files, none of which failed to parse), the 382 JSB
chorales, the Chopin mazurkas, and the 26 chord qualities of the standards
repertoire in all twelve keys voiced close, as a shell, spread, drop-2 and in
every inversion. Scores are chordified with music21 - used only as a file
reader, never for naming - and driven through a real script by `runner.lua`,
rebuilt from the test suite's mocks: it reads MIDI note numbers on stdin and
writes the name the script shows. Scanning the whole corpus takes about twenty
minutes on four cores.

**The tools are in `tools/`** - `runner.lua`, `check_symbol.py` and
`corpus_scan.py`, with a README explaining each. They were in a scratchpad that
does not survive the session, and every measurement quoted above was made with
them, so they are committed rather than described.

The only thing the Romantic repertoire turned up was both sevenths sounding at
once, a passing note over a seventh chord: G B D F with an F# above it, 83
voicings across the two composers. The reading was right and the symbol was
not - `G7maj7` ran the two seventh names together - so it is bracketed now.

**What 100% means here.** The test is that the printed symbol describes exactly
the notes played and names the right bass - parsed back into pitch classes by
a checker written from music theory alone, which knows nothing about this code.
It is not a claim that the engine picks the name a particular musician would
have written.

Since the doubled-root rule above, "the right bass" is the engine's rule rather
than the strict one, and the tables above are scored that way (`names_bass` in
the checker, against `claimed` for the strict reading). The two differ by
design and by a knowable amount. Scored strictly - the bass is the lowest note,
no exceptions - the same runs read 98.382% on Bach 370, 97.993% on DCML,
97.608% on When in Rome, 97.152% on Lieder, 97.931% on the quartets and 99.008%
on the music21 corpus. **Every one of those "failures" is a slash deliberately
left off a doubled root, not a misnamed chord**: the proportion of sonorities
whose symbol accounts for exactly the notes played did not move at all. Where several names describe the same notes, which one is best is
a matter of taste and the bass rule settles it.

**Three times the ground truth was the bug, not the engine.** This is the thing
to remember before quoting any accuracy figure from this repo:

1. An early Bach run read 95.6% because the truth table had no sixth chords and
   no shell voicings in it.
2. An early inversion run read 47% because it was generated by mechanically
   inverting each chord symbol and demanding the name stay the same with a
   slash - so it wanted `C6/A` where A C E G with A in the bass is `Amin7`,
   which is what the engine says, what a musician writes, and what this repo's
   own tests have pinned since the beginning.
3. The checker that produced the figures above had to be fixed twice before it
   agreed with 537 voicings already known to be right: it demanded a perfect
   fifth that the engine deliberately never states, and it demanded the whole
   stack under a 13th chord.
4. "390 suspensions misnamed in Bach" was the same table again, this time with
   no entry for `7sus4` or `7sus2`. Every one of those symbols accounts for
   exactly the notes played. A piece of work was very nearly commissioned off
   the back of that number.

So validate the checker on known-good data first, and treat a surprising
accuracy number as a bug in the measurement until that passes.

**There is no known defect left to fix by measurement.** Both engines print a
symbol that describes exactly what is played, with the right bass, on every
voicing in both corpora. What remains is *preference* - which of several valid
names reads best - and that cannot be measured here, only judged by ear or
against a reference like Scaler. So the useful bug report now is a specific
chord, in a specific key, where the name reads wrong to a musician; a sweep
will not find one.

**The scale cannot improve this.** Running the jazz corpus through all twelve
keys moves the inversion figure by 2.6 points at most, because the ambiguity is
not about which roots are diatonic - in `C E G A` over E, both candidate roots
are in C major. Scale degrees are a display feature, not a detection input; do
not wire them into root choice expecting accuracy.

### Against a human's name for the same notes

Every figure above asks the same question: does the symbol account for exactly
the notes played. **This section asks a different one** - does it agree with the
name somebody else gave those notes - and the two must not be confused. Where
two notations disagree, usually neither is wrong.

**jazznet** (MIT, github.com/tosiron/jazznet) is 162,520 labelled piano
patterns. `tools/jazznet_check.py` generates its chord-shaped ones from its own
generator's inversion formulas - 6 triads and 6 tetrads over 85 bases in every
inversion, 3,570 voicings:

| | |
| --- | --- |
| symbol accounts for exactly the notes | **100%** |
| names the same bass as the voicing | **100%** |
| symbol identical to jazznet's label | **63.1%** (71.7% excluding symmetric sets) |

All 1,316 differences are in three classes and none is a defect: **symmetric
sets** (425 - `aug` and `dim7` inversions, where no root is derivable by
anyone), **the 6/min7 family** (551 - `C6/E` against `Amin7/E`, `Cmin7/Eb`
against `Eb6`, the preference this repo settled long ago and pinned in the
tests), and **sus inversions** (340 - sus2 and sus4 are inversionally
equivalent, so `Csus2/G` and `Gsus4` are both exact). Selecting the chord's own
key moves agreement from 63.1% to 65.7%, which is a third independent
reproduction of "the scale only breaks a draw".

Worth knowing what jazznet's label is: a record of how the file was generated,
a root plus an inversion, not a musician's judgement about the printed voicing.

**DCML and When in Rome carry human analyses** of the same scores whose notes
are scored above - 729 movements of DCML harmony tables, 266 When in Rome
scores with a Roman-numeral analysis beside them. `tools/collect_labels.py`
joins them to the sonorities and `tools/score_labels.py` scores the result:

| | slices | analyst's root | analyst's bass |
| --- | --- | --- | --- |
| DCML, 13 repos | 84,788 | **91.1%** (93.9% excl. symmetric) | **100%** |
| When in Rome | 26,935 | **92.0%** (95.6% excl. symmetric) | **100%** |

**The bass figure is the striking one: whenever the analyst's bass is the
lowest note sounding, Pro names it, on every one of 111,723 slices.** The
differences are 13,408 slices where the analyst's bass is not sounding lowest
at that instant - their figure describes a span, and an arpeggiating
accompaniment moves underneath it - and 2,027 from the doubled-root rule, which
is that rule's measured price against analysts who mark first inversions
explicitly: **1.8%**, in both corpora.

Where the roots differ, about half is not decidable from the notes at all:

| | DCML | When in Rome |
| --- | --- | --- |
| the set is symmetric, so no root is derivable | 33.6% | 47.1% |
| the analyst's root is not sounding | 15.3% | 4.8% |
| a real difference of preference | 51.1% | 48.1% |

and that last half is two things, the same two in both corpora:

- **Augmented sixths.** `F A D# C` is `Ger65` to an analyst and `F7` to a chord
  symbol. The notes are a dominant seventh; the label is about where it goes.
  ~570 in DCML, ~300 in When in Rome.
- **Half-diminished and minor-seventh inversions.** `D# A# C F#` is `iiø65`
  analytically and `D#min6` as a symbol - the same family jazznet found from
  completely different data.

**Three cautions, because this is the easiest measurement here to get wrong.**

- **It read 68% first, and the number was the measurement.** Three faults: a
  slice inside a labelled span often holds only part of the chord, so Pro was
  naming three notes correctly and being marked against a four-note label; the
  cadential six-four, where an analyst writes `V(64)` for a C major triad over
  G because of where it goes and a musician writes `C/G` because of what it is;
  and the analyst's span-level bass against an instantaneous slice. All three
  are counted apart now.
- **Validate the label arithmetic before the engine.** DCML writes chord tones,
  roots and basses as steps on the line of fifths relative to the *local* key,
  and the local key is itself a numeral relative to the global one. Both
  conversions were checked against labels whose answer is known from the
  numeral alone - F minor `i` is F Ab C, C major `V2` is G B D F over F.
- **Roman numerals answer a different question.** They name function; a chord
  symbol names notes. Agreement is interesting, disagreement is mostly the gap
  between the two notations, and neither is evidence of a defect.

**On jazz specifically, a labelled corpus does not exist in the useful form**,
and this was surveyed rather than guessed. The Weimar Jazz Database (ODbL, 456
solos) takes its chords from lead sheets and *clones them across every chorus*,
and its MIDI is the monophonic solo, so its notes are not the chord. JAAH is
audio. iReal Pro, the Jazz Harmony Treebank and Chordonomicon are symbols with
no notes. POP909's labels came from an MIR algorithm, and grading this engine
against another chord recogniser is how the "390 misnamed suspensions" scare
happened. What is left is jazznet, which is generated, and Hooktheory's lead
sheets, whose chord tracks are rendered from the symbol.

The reason is not a gap in the datasets. **In a real jazz performance the chart
symbol is frequently not in the notes**: a pianist voicing D F A C under a
bassist's Bb is `Bbmaj9` on the chart and `Dmin7` in isolation. The DCML
measurement puts a number on that - in 15.3% of its root disagreements the
analyst's root is not sounding at all. No engine reading one voicing can
recover it, and a corpus like that measures context we do not have.

### Where Pro and Scaler 3 disagree, and why

**Twenty-four chords were put through Scaler 3 and reported back** - one per
major key, then one per natural minor key. They are the only hard evidence
about Scaler in this repo, they are reproduced by `tools/scaler_cases.py`, and
every one of the 48 names - both engines, all 24 chords - accounts for exactly
the notes played. **The bass agrees everywhere it can be compared.** It was
never anything but a fight about which root to name, and Pro names the same
root as Scaler on 12 of the 24.

**One reading is confirmed and unexplained.** C minor's D F G# A# is `Ddim#5`
to Scaler with no slash, over a bass of F - which is what makes Pro read
`Bb7/F`. This was recorded here as possibly a voicing that had D lowest; it was
re-checked in Scaler and the reading stands, so it is the one case of the 24
where Scaler names a root that is not the bass and prints no slash. The other
ten all carry one, and nothing else here accounts for it: **nothing is
doubled**, so the doubled-root rule cannot be what is dropping the slash, and
the set is not symmetric, so the root is derivable. Note also what Scaler
passed up - D F G# A# is a plain dominant seventh on Bb - in favour of a
quality carrying a flattened *and* a raised fifth. Pro is not moving; `Bb7/F`
is what a musician writes. Keep the case in view rather than building on it:
it is the only evidence in this repo that Scaler's bass rule is something other
than "the lowest note, less a doubled root".

Four rules came out of them and are implemented; two are not, and are listed
below with what would settle them.

- **The bass, on a doubled root** - settled. Scaler reads a doubled root as
  root position where Pro printed a slash. See *How the bass is decided*.
- **A dim7 with a ninth is `dim9`**, a minor sixth loses to the
  half-diminished on its third, a third beats a shape with none, and two notes
  a third apart are a chord. All four are in *How Pro names a chord* above.
- **E G A** - Pro `EminAdd11/G`, Scaler `G6(sus2)`. Pro's reading has a minor
  third, Scaler's has none, so this is Scaler disagreeing with the third rule
  rather than Pro getting it wrong. Scaler evidently will write a suspension
  carrying a sixth, which `COST_SUS_EXTRA` deliberately suppresses. Change that
  only if asked, and expect the D E G A family to move with it.

**Not implemented, and why.**

- **Scaler does NOT use the key to choose the root. This was tested and the
  answer was no.** It looked from the twelve as though it might: in four of
  them Scaler's root is a degree of the selected scale and Pro's is not, and
  in two more it falls back to the bass. That reading was written into this
  file as a probable rule, with the experiment that would settle it - the same
  chord in two keys. The experiment was run. **C# F# G# A# is `C#6(sus4)` in C
  major and `Db6(sus4)` in F#/Gb major**: the same root, respelled for the
  flat key. Scaler uses the key exactly the way ScaleView does, for spelling,
  and Pro reads the same four notes as `F#add9/C#` and `Gbadd9/Db` in those
  two keys - also the same root, also respelled.

  So that is a **third independent null** for "the key decides the root",
  after Pro and the pattern-matching engine, and this time from the reference
  implementation itself. Four of the twelve merely *looked* diatonic because
  a root Scaler liked for other reasons happened to be in the key.

  **What actually drives Scaler's root choice is still unknown.** The
  closest fit to the twelve is that it prefers the bass as root when the
  resulting shape is one it has a name for - `6(sus4)`, `6(sus2 b5)`,
  `min(no5)` - and goes looking elsewhere when it is not, but C E F# A breaks
  it: `C6(b5)` would be such a shape and Scaler still prints `F#min7(b5)/C`.
  Twelve chords are not enough to separate "prefers the bass" from "prefers a
  quality". C minor's D F G# A# is the second case that bears on it and it
  points the other way: F as a root is no shape Scaler has a name for, and it
  went looking and found `Ddim#5` - quality-driven - but then printed no slash,
  which no bass rule here explains. **The probe that would separate them is one
  pitch-class set voiced four times, a different note lowest each time**: if
  Scaler's root follows the bass it is bass-driven, and if it stays put it is
  quality-driven. D F G# A# is the set worth using, since it is also the one
  that will say whether the missing slash follows the voicing or the quality.
- **A natural 11 over a major third may be forbidden outright.** Eb major
  Eb E Gb B is `Emaj7(sus2)/D#` to Scaler, where Pro's `Badd11/Eb` puts E
  against D#. Pro brackets such elevenths rather than refusing them. This one
  is still open.

#### The probe that would settle the root rule, written down in advance

Strong bass-driven is already dead: Scaler prints `C/E` for E G C, so it will
slash an ordinary inversion. The live question is narrower - **what makes it
abandon the obvious root** - and the twenty-four contain one unexploited lead.
They hold exactly two chords Pro reads as a **dominant seventh in inversion**,
and Scaler refused the dominant both times: `E7/D` came back `D6(sus2 b5)` and
`Bb7/F` came back `Ddim#5`. Two of two is a pattern worth one experiment.

The design is one pitch-class set voiced in every position, nothing doubled -
a doubling would fire Scaler's root-position rule and confound the answer -
and close position, so the voicing is one a player would use. Write down what
each answer means before running it:

| set, in the key given | Pro | if the root tracks the bass | if it stays put |
| --- | --- | --- | --- |
| **Bb7**, four positions, C minor | `Bb7`, `Bb7/D`, `Bb7/F`, `Bb7/Ab` | bass-driven, and the missing slash on `Ddim#5` goes with the voicing | quality-driven, and `Ddim#5` was about the shape |
| **C7**, four positions, C major | `C7`, `C7/E`, `C7/G`, `C7/A#` | as above | if it refuses the dominant in every inversion, that is the rule the two cases hinted at |
| **Cmaj7**, first inversion, C major | `Cmaj7/E` | - | the control: if this one keeps its slash, it is *dominant* sevenths Scaler will not invert, not sevenths |
| **C6 / Amin7**, C and E lowest, C major | `C6`, `Amin7/E` | `C6` then something on E | both readings are standard and complete, so this grades commonness against the bass with nothing exotic in the way |

The C7 row is the one that pays. If Scaler names all three inversions `C7/x`
then the two refusals were about those particular shapes and there is no rule
to find; if it names none of them, the rule is "a dominant seventh is named
from its root or not at all", which is a real difference from Pro and a
decidable one. Note `C7/A#`: C major has no flats, so Pro spells the seventh
A#. Same root, same notes.

**Tuning the weights cannot buy Scaler's remaining roots. This was measured.**
Twelve of the 24 roots differ, and two weights look responsible for most of
them: 7 of the 12 are Scaler printing a suspension that carries an added tone,
which `COST_SUS_EXTRA` suppresses, and Scaler's root is the bass on 13 of 24
against Pro's 9, which is `COST_INVERSION`. Both were swept:

| | agreement with Scaler | what it costs |
| --- | --- | --- |
| shipped (sus 12, inversion 14) | 11/24 | - |
| `COST_SUS_EXTRA` 12 -> 2 | 14/24 | 248 sweep names (1.4%) |
| `COST_INVERSION` 14 -> 22 | 12/24 | 2,196 sweep names (12.4%) |
| `COST_INVERSION` 14 -> 40 | 11/24 | 5,857 sweep names (33.1%) |
| **best of 36 combinations of the two** | **14/24** | - |

Raising `COST_INVERSION` does move Pro onto the bass - 8 of 24 becomes 21 -
**and agreement does not improve**, because it lands on the bass in the cases
where Scaler did not. The ceiling over the whole grid is three more chords than
shipped, each bought with collateral, and no setting is stable: sus 2 gains
three and sus 0 gives them back. **The remaining disagreements are not one
systematic bias. They are individually different readings**, both exact, and
weight-tuning is the wrong instrument for them. The objective score is 100% at
every setting tried, which is the other half of the point: none of this is
about correctness.

**Three of the 24 are notation, not reading** - same root, same notes:

- `Aaug6` against `Aaug add13`. Hutchinson 31.2 is explicit that a sixth is a
  13 only with a seventh under it, and there is no seventh here, so this one
  has a cited source behind it.
- `D#11` against `D#9(sus4)`. Both are standard and both are written; ours is
  the documented sus4-with-a-seventh-and-a-ninth rule.
- `FminMaj7` against `Fmin(no5)maj7`. Scaler says the missing fifth out loud;
  Hutchinson's 31.4 vocabulary never does, which is why ours is silent. Note
  the deliberate exception: a two-note chord *does* say it, because there it
  cannot be silent.

And one is a category we do not name: `E F` is `E min second` to Scaler, which
labels every two-note interval. ScaleView names a fifth and a third and reads
the rest out as notes.

**One difference is punctuation, not reading.** After the four changes Pro
picks Scaler's root and quality on five of the twelve but prints them
differently: `D#maj7b5` against `D#maj7(b5)`, `A#(b5)` against `Bbmaj(b5)`.
Scaler brackets every modifier and writes the triad quality out. Matching it
would rewrite every `b5`/`#5` symbol in the vocabulary, so it is a separate
decision and has not been taken. The A# against Bb is not a difference at all:
Scaler has its own sharps/flats display mode, and the two must be compared
like for like.

Diffing two builds of the engine against each other over all 6,600 voicings is
worth doing after any change to the weights: that is what turned up `Cmin6`
being printed for C Eb G# A, where the sixth branch assigned the name and
dropped the altered fifth.

**Generate that sweep carefully.** The voicing for a pitch-class set over a
bass is `60+bass` for the bass and `60+bass+((pc-bass)%12)+12` for every other
note. Writing the upper notes as `60+((pc-bass)%12)+12` - relative intervals
over an absolute bass - looks right and is not: it silently produces voicings
that repeat a pitch class, so a "3-note" set arrives as two notes. A blast
radius measured that way came out 114 when the real figure was 84, and the
error was invisible until the size buckets were counted. The cheap guard is to
assert that
every generated voicing has as many distinct pitch classes as notes, and the
cheap sanity check is that a known shape transposes to itself - a dominant
ninth should read C9, C#9, D9 and so on across the twelve.

**The selected scale only breaks a draw.** At equal cost a root that is a scale
degree wins, then a reading whose notes sit in the scale, then the commoner
quality. It is deliberately no stronger, and it is not a filter: a chord from
outside the key is named for what it is. **Scaler agrees**, which was checked
rather than assumed - see *Where Pro and Scaler 3 disagree*. Two of the three mismatches this work
started from had out-of-scale notes and Scaler named them anyway. Do not
promote it to a filter.

Measured, the key decides the name for 1.6% of voicings - the genuine draws.
Those are mostly semitone clusters but not only: symmetrical chords like
C D# F# A# tie between two equally good roots and something has to choose. An
earlier note here said "only semitone clusters", which was read off the first
few examples printed rather than all of them, and was wrong.

**Which chords those are is not a matter of opinion.** Ring's rotational
symmetry is the mechanism: a set that maps onto itself under transposition has
no root derivable from the notes, so every engine - Scaler included - is
choosing rather than deriving. Counted over every pitch-class set:

| notes | sets that map onto themselves | of |
| --- | --- | --- |
| 3 | 4 | 220 |
| 4 | 15 | 495 |
| **5** | **0** | 792 |
| 6 | 24 | 924 |
| **7** | **0** | 792 |

**No five- or seven-note set is symmetric**, and none can be - 5 and 7 do not
divide 12. So a disagreement about a five-note chord is never inherent
ambiguity in the notes; it is a weighting preference, and it has an answer.
Worth knowing before writing off a report about a thick voicing as unresolvable.

**With no scale selected, Pro assumes C major** (`ASSUMED_KEY`) rather than
going quiet. The assumption must stay invisible: no circle lights, no label
names a key, and choosing C Major explicitly must give identical names. The
test sweeps every three- and four-note voicing both ways to hold that. It works
because C major is also where the note names already fall back to - no
accidentals, so the twelve read C C# D D# E F F# G G# A A# B either way. If the
assumed key is ever changed to something with accidentals, the spelling and the
naming would part company and that property would break.

`tests/test_scaleview_pro.lua` carries a property test that is the real
specification: every three- and four-note voicing must come back as a chord,
never a list of notes. A chord symbol has no spaces in it, which is how it
checks.

### music21, and why it is not the answer here

`music21` (MIT, Python) was checked on the suggestion that it names chords from
theory rather than by set-matching. Half of that is right, and the half that is
right is the half this engine already does.

- **Root finding**: `chord.Chord._findRoot` scores each candidate by "the note
  with the most 3rds above it" - third-stacking, like `core()` here.
- **Symbol generation**: `harmony.chordSymbolFigureFromChord` is table-driven
  over a fixed list of chord types and returns the string
  `"Chord Symbol Cannot Be Identified"` when nothing matches. That is the old
  table engine's failure mode, which is what this repo moved away from.

Measured on the same two corpora, judged by music21's own round trip - generate
the figure, parse it back with `harmony.ChordSymbol`, compare pitch classes and
bass - so that nothing here is grading it:

| | music21 | Pro |
| --- | --- | --- |
| Bach chorales | 90.5% | **100%** |
| Standards vocabulary | 60.8% | **100%** |

Where it fails on the jazz set: 8.3% get no symbol at all (`C E B`, a maj7
shell; `C F G Bb`, a 7sus4), and 26.6% get a figure naming different notes,
because it writes added tones as pitch names its own parser then drops -
`Am7/CaddD` reads back as A C E G, the D gone. A further 4.3% will not parse
back at all (`Am7/CaddB-,D`, `F#susaddE,omitC#`).

It is also worth knowing that music21 always takes the third-stacked root, so
C E G A over C is `Am7/C` to it and `C6` here - a preference this repo settled
with the user long ago, and pinned in the tests. Nothing to port; the comparison
is recorded so it does not have to be run again.

### The reference the naming is checked against

Robert Hutchinson, *Music Theory for the 21st-Century Classroom* (September
2025 edition, 556 pages, GNU FDL, musictheory.pugetsound.edu). The user has
uploaded it twice; **it does not survive the session**, so the rules worth
having are written down here rather than re-derived.

Sections that settle chord naming, and what each one says:

- **6.3.1 Slash chords** - the root goes before the slash and the bass after,
  and the bass need not be a chord tone. Exactly what `detectChord` prints.
- **31.1** - "adding 9 to a chord symbol means the 7th is also present", so a
  ninth without a seventh is `add9`. `ø7` is the same as `m7(b5)`.
- **31.2** - three numbered rules: 6 versus 13 (a sixth is a 13 only with a
  seventh under it); 11 versus sus (a fourth is a suspension only with no third
  present, an 11 otherwise); b5 versus #11 (with a natural fifth it is a #11,
  without one either name will do). All three already held.
- **31.4** - the canonical vocabulary, "edited and condensed from The New Real
  Book". The figures print noteheads, and **counting them is what settles the
  stack rule** where the prose does not.
- **31.6** - the method: write out every chord member up to the 13th, then name
  the deviations. That is what this engine does.

Two cautions about reading it:

- `(no 3rd)` and `(no 5th)` appear in the analysis figures (`G7(no 3rd)`,
  `Ab7(no 5th)`), but **not once in the 31.4 vocabulary**, where `C7`, `C9` and
  `C13` stand unqualified. They are analytical emphasis, not part of the
  symbol, so "a missing fifth is silent" stays. A missing third is still said,
  which `(no3)` matches.
- The text is a PDF conversion: `<span class="_">` empty means a kerning break
  inside a word and one containing a space means a real word break, so join on
  the former and split on the latter or the whole thing reads as "Rob ert
  Hutc hinson". Noteheads survive as lines reading `w`.

## Publishing through ReaPack

`index.xml` at the repository root is a ReaPack index (format version 1). It
declares one package per script under the category `Scales`, each with a
version, an author, a changelog and a `<source>`.

**Every `<source>` is pinned to a commit hash, never to a branch.** An installed
version is then the exact file that was tested and cannot change underneath
anyone who has it. That is the whole point of the pin, so:

- To publish a new version, **add** a `<version>` block with a fresh hash. Do
  not edit an existing one, and do not repoint an old version at a new commit.
- The hash has to be of a commit that is already pushed, or the raw URL 404s.
  Push the scripts first, take `git rev-parse HEAD`, then write the index and
  commit that separately.
- Spaces in the filenames are `%20` in the URL.
- **Renaming a script is not an upgrade.** ReaPack keys an installed package
  by its name, so anyone holding the old package keeps the old file, never sees
  the new one, and ends up running both unless they uninstall the old by hand.
  This was learned when the `kallums_` prefix came off the filenames, before
  any of this was public. Rename sparingly - it is not free any more.
- **The published history starts at 1.0.3.** The versions before it were only
  ever on one machine, so when the first public release went out they were
  dropped from the index rather than shipped as history nobody had. Do not
  re-add them, and do not renumber 1.0.3 down to 1.0.0: ReaPack compares
  version names, so a lower number would read as a downgrade on the one
  install that has it.

The repository is **`KallumS/ScaleView-for-Reaper`** and its default branch is
**`master`**. `ubiquitous-eureka` is the old name and still redirects, but the
canonical one is what the index uses. Users import
`https://raw.githubusercontent.com/KallumS/ScaleView-for-Reaper/master/index.xml`,
which resolves once the index is merged to the default branch.

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
  documentation cannot be fetched. Ask the user to upload it when an API needs
  checking. What has been consulted so far: `reascripthelp.html` (REAPER:
  Help > ReaScript documentation) for the API list, the ReaScript overview page
  for script lifetime and persistence, and all ten JSFX reference pages.
  Uploads do not survive the session - that is why the verified facts above
  live in this file. Note what a page does and does not say: the ReaScript
  overview covers how scripts run, not how REAPER starts them, which is why it
  settles script lifetime but says nothing about `__startup.lua`.
- `raw.githubusercontent.com` **is** reachable, so JUCE, CLAP, the VST3 SDK,
  REAPER's extension SDK headers and Apple's developer docs can be fetched
  directly without asking.
- REAPER 7.79 as of this writing.

## Related

`KallumS/ScaleView` is the same icon as a VST3 / AU / CLAP plugin (JUCE, C++).
It matches Pro, and its musical core is a port of **both** engines here - the
spelling and the chord reader, `Simplify Note Names` and the assumed key
included. **If either changes here, change it there too.**

Parity is held by diffing output, never by eye: all 288 keys, then 36,283
voicings with no scale selected and 1,679 voicings in each of ten keys, about
53,000 names, byte-identical. The doubled-root bass rule was checked the same
way and needed a different corpus to mean anything - a sweep has no doublings
in it - so it went through 97,346 real voicings from the corpora, 51,248 of
them doubling a pitch class, in six keys: 584,076 names, byte-identical.
`tools/runner.lua` is one half of that rig - the other is a twenty-line C++
file calling `chordName`. The plugin sees MIDI items
playing back, which a script cannot, so it is also the answer to anyone asking
for that.
