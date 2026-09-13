# ScaleView for REAPER

Five ReaScripts that draw a 200x100 icon: the twelve pitch classes as circles,
five black keys on the top row over seven white keys on the bottom, with the
notes of the selected scale lit.

| Script | |
| --- | --- |
| `reascripts/kallums_ScaleView.lua` | Pro and Simple merged: Pro's behaviour with a **Simplify Note Names** option that switches to Simple's piano-key naming. ExtState key `kallums_ScaleViewUnified`. |
| `reascripts/kallums_ScaleView Alt.lua` | The merged script with the chord **read** rather than looked up. Same everything else. ExtState key `kallums_ScaleViewAlt`, falling back to the merged script's. |
| `reascripts/kallums_ScaleView Alt 2.lua` | Alt, but it prefers the reading with a complete triad in it, the way Scaler 3 does. **One rule differs, nothing else.** ExtState key `kallums_ScaleViewAlt2`, falling back to Alt's. |
| `reascripts/kallums_ScaleView Pro.lua` | The full one: names spelled for the key, and it names the chord being played |
| `reascripts/kallums_ScaleView Simple.lua` | Deliberately the lesser one, kept for people who want it: always sharps or always flats, with a menu toggle |

Pro has been renamed repeatedly - Enharmonic, Pro, Detector, Pro again - and an
older, separate Pro was removed once this one contained it. Because of that,
**the ExtState key is tied to the tier, not the display name**:
`kallums_ScaleViewFull` and `kallums_ScaleViewSimple`. `EXT_LEGACY` lists every
name this script has shipped under, most recent first, so the newest saved
state wins over a stale one. Renaming the script again needs no migration; do
not "tidy" the key to match a new name.

The merged script is a copy of Pro with one branch in `noteName`: with
`state.simpleNames` set it returns the plain sharp table instead of the key's
spelling. Chord *detection* is untouched by the option - only the names it
reports change, since they come from `noteName`. The scale label keeps the key
as chosen from the menu, so picking Gb Major still says Gb Major when
simplified; only note names change.

**The scripts are independent copies, not a shared library.** A fix in one usually
belongs in the other too - check both before considering a bug fixed. The
docking fix, for example, applied to all of them. Alt is the exception in one
direction only: its chord engine is deliberately different and must not be
back-ported without being asked for, but a fix anywhere else in it belongs in
the merged script as well.

`kallums_ScaleView.lua` deliberately has **no white highlight colour**: the
ring around a note being played is white, and a white highlight swallows it.
Do not add one back. Pro still offers white and has the same clash - it was
left alone only because it was not the script being worked on. Simple has no
rings, so white is fine there.

Simple is not a stripped Pro: it keeps the **Swap Sharps & Flats** toggle,
which the key-aware spelling replaced. That is the reason it still exists, so
do not "simplify" it by removing that option.

## Working in this repo

- **The tests are the specification.** Run all five before and after any
  change; they need only `lua5.4` and take under a second:

  ```sh
  lua5.4 tests/test_scaleview.lua
  lua5.4 tests/test_scaleview_alt.lua
  lua5.4 tests/test_scaleview_alt2.lua
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
- **A modal menu's own click comes back afterwards, and not always in the next
  frame.** `gfx.showmenu` is modal, and the click used to choose an item
  reaches the window once the menu closes. Read naively it looks like a fresh
  click. Ignoring the mouse until no button is held is **not enough** - that
  was tried, and a stray click arriving a frame or two later still opened a
  menu, which is what kept happening in REAPER. `kallums_ScaleView.lua` also
  waits `MENU_SETTLE_SECONDS` (0.25) from when the menu closed. Its test proves
  it by firing the stray click 0, 1 and 3 frames late; the buttons-only version
  fails the last two.
- **The merged script has no left/right menus.** Which menu opens depends on
  where the click started - a circle opens the scale list, empty space opens
  the options - so there is no wrong menu to open. `isOverCircle` uses the same
  `layout()` the drawing does, so the hit areas cannot drift from the circles.
  Simple and Pro still use the two-button arrangement and the weaker settle.
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
    file". `kallums_ScaleView.lua` uses this for the scale, so each project
    reopens in its own key; Simple and Pro do not. Only the scale goes in the
    project - colour, note names and window are preferences and stay global.
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
  `set_action_options`. `kallums_ScaleView.lua` calls it with `1|4` at startup -
  toggle on, and re-running the action terminates this instance rather than
  starting a second - and with `8` from its `atexit`. That is what makes a
  toolbar button light up while it runs and toggle it off when clicked again.
  Both calls are guarded on the function existing, so older REAPERs are fine.
  Simple and Pro do not do this.

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

The same engine spells chord roots, so a chord on Gb reads `Gbmaj7` in Gb
major and `F#maj7` in F# major. Keep the split it rests on: **circles follow
the key, chord symbols follow what a musician would write.**

In `kallums_ScaleView.lua`, `chordNoteName` draws chord roots and basses from
the same eighteen spellings `ROOTS` offers - the roots real keys are built on.
Anything else falls back to a plain name leaning the way the key does: the
double accidentals of a key like Gb minor blues (`Amin/C`, never `Bbbmin/Dbb`)
and the theoretical spellings B#, E# and Fb, so B# D# E# in C# major reads
`CminAdd11` rather than `B#minAdd11`. Pro still uses the older rule, which only
falls back on double accidentals.

The chord table is matched exactly and ordered by priority, so a shape's
position decides which reading wins when the bass does not. Two rules learned
by breaking them:

- **A missing fifth is silent, a missing third is not.** The fifth is optional
  in an added-tone chord, so `{0,3,5}` is `minAdd11`; a missing third changes
  the quality, so `{0,7,10}` is `7(no3)`.
- **Do not add sixth chords without their fifth.** `{0,4,9}` and `{0,3,9}` are
  deliberately absent: adding them made C E A read `C6` instead of `Amin/C`,
  because a rooted reading wins outright and stole the complete triad's
  inversion. An incomplete chord should not beat a complete one.

## How Alt names a chord

Alt answers the complaint the table could not: extensions. The table is matched
exactly, so a voicing it does not hold reads out as a list of notes, and
lengthening it does not end - a chord is a quality with any number of tones on
top. Measured over every three-, four- and five-note voicing in every bass
position (6,600), the table names 28% and Alt names all of them.

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
- **A suspension replaces the third; it does not take added tones.**
  "sus4 add6 add9" is not a chord anybody writes, so a sus core pays
  `COST_SUS_EXTRA` for every tone it carries. The one exception is a sus4 with a
  seventh and a ninth, which is how an eleventh chord is voiced and is named
  `11` - and only over an unaltered fifth, or the name would swallow the very
  note that makes the chord odd.
- **The highest natural extension names the chord**, lower ones taken as read,
  which is what `C13` means whether or not the ninth is played. A natural
  eleventh over a major third clashes, so it is written as an add instead.
- `(no3)` goes at the end of the whole symbol, so it reads as a chord with a
  note taken out: `maj7b5(no3)`, not `maj7(no3)b5`.
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

### Alt 2: preferring the complete triad

**Alt 2 is Alt with one expression changed**, and the two files must stay
identical everywhere else - a fix to either belongs in both. The difference is
in what counts as a home for an alteration:

```lua
local complete = (third == "maj" or third == "min") and fifth == "P"
-- Alt:   athome = ... and (token == "#11" or dominant)
-- Alt 2: athome = ... and (token == "#11" or dominant or complete)
```

Alt asks whether an alteration belongs to the chord under it, and only a
dominant is at home with a b9, #9 or b13. Alt 2 also accepts a complete triad,
which is how Scaler 3 reads a chord: given a choice it names the one with a
whole triad in it and hangs the odd notes off that.

`complete` is the right lever, not `COST_CLASHING`. Cheapening the alteration
cost reaches the same answer for C D Eb Gb Cb but takes `C9/E` down with it
(`Emin7b5b13`), because that reading's fifth is flattened - it has no complete
triad, so `complete` leaves it alone. Both engines keep it.

A **b13 is excluded** from the concession, and that was measured rather than
guessed. It is the one alteration whose note is nearly always a chord tone of
something plainer: E G B with a C in it is Cmaj7 in first inversion, not Emin
wearing a b13. Letting a complete triad take one cost 207 misnamed sonorities
across 382 Bach chorales and 7 points on inverted jazz voicings, and bought
nothing - the chord Alt 2 exists for carries a b9 and a #9.

### What the two engines score on real music

| | Alt | Alt 2 |
| --- | --- | --- |
| Bach chorales, 89,108 sonorities of 3+ pitch classes | **100%** | **100%** |
| Standards vocabulary, 537 root-position voicings | **100%** | **100%** |
| Standards vocabulary, 1,142 inverted voicings | **100%** | **100%** |

The corpora are the 382 JSB chorales (`czhuang/JSB-Chorales-dataset`, public
domain) and the 26 chord qualities of the standards repertoire in all twelve
keys, voiced close, as a shell, spread and drop-2, plus every inversion. Both
are driven through a real script by `runner.lua`, rebuilt from the test suite's
mocks: it reads MIDI note numbers on stdin and writes the name the script
shows.

**What 100% means here.** The test is that the printed symbol describes exactly
the notes played and names the right bass - parsed back into pitch classes by
a checker written from music theory alone, which knows nothing about this code.
It is not a claim that the engine picks the name a particular musician would
have written. Where several names describe the same notes, which one is best is
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

### Where Alt and Scaler 3 disagree, and why

- **C D Eb Gb Cb** - Alt `D13b9/C`, Scaler and Alt 2 `Cbaddb9#9/C`. This is the
  case Alt 2 was built for; see above.
- **E G A** - Alt and Alt 2 `EminAdd11/G`, Scaler `G6(sus2)`. Alt's reading has
  a minor third, Scaler's has no third at all, so this one is Scaler
  disagreeing with the third rule rather than Alt getting it wrong. Scaler
  evidently will write a suspension carrying a sixth, which `COST_SUS_EXTRA`
  deliberately suppresses. Change that only if asked, and expect the D E G A
  family to move with it.

Diffing the two engines against each other over all 6,600 voicings is worth
doing after any change to either: that is what turned up `Cmin6` being printed
for C Eb G# A, where the sixth branch assigned the name and dropped the
altered fifth.

**The selected scale only breaks a draw.** At equal cost a root that is a scale
degree wins, then a reading whose notes sit in the scale, then the commoner
quality. It is deliberately no stronger, and it is not a filter: a chord from
outside the key is named for what it is. Two of the three mismatches this work
started from had out-of-scale notes and Scaler named them anyway. Do not
promote it to a filter.

Measured, the key decides the name for 1.6% of voicings - the genuine draws.
Those are mostly semitone clusters but not only: symmetrical chords like
C D# F# A# tie between two equally good roots and something has to choose. An
earlier note here said "only semitone clusters", which was read off the first
few examples printed rather than all of them, and was wrong.

**With no scale selected, Alt assumes C major** (`ASSUMED_KEY`) rather than
going quiet. The assumption must stay invisible: no circle lights, no label
names a key, and choosing C Major explicitly must give identical names. The
test sweeps every three- and four-note voicing both ways to hold that. It works
because C major is also where the note names already fall back to - no
accidentals, so the twelve read C C# D D# E F F# G G# A A# B either way. If the
assumed key is ever changed to something with accidentals, the spelling and the
naming would part company and that property would break.

`tests/test_scaleview_alt.lua` carries a property test that is the real
specification: every three- and four-note voicing must come back as a chord,
never a list of notes. A chord symbol has no spaces in it, which is how it
checks.

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
Its musical core is a port of the spelling engine here and was verified by
diffing all 288 keys against this repo's output - if the spelling changes here, change it there
too.
