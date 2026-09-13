# ScaleView

A small ReaScript (Lua) icon for REAPER that shows the current key signature /
scale at a glance. Four scripts, all self-contained:

| Script | |
| --- | --- |
| `reascripts/kallums_ScaleView.lua` | **The merged one.** Pro, with Simple's naming available from the right-click menu - see [below](#scaleview-the-merged-script) |
| `reascripts/kallums_ScaleView Alt.lua` | **The merged one, with the chord reader.** Same icon, but it works out the chord instead of looking it up - see [below](#scaleview-alt-the-chord-reader) |
| `reascripts/kallums_ScaleView Pro.lua` | Note names spelled for the key, and it names the chord you play - see [below](#scaleview-pro) |
| `reascripts/kallums_ScaleView Simple.lua` | The stripped-back one: note names are always sharps, or always flats |

Everything below describes all four; the later sections cover what each adds.

![ScaleView](docs/preview.svg)

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

Copy whichever script you want (or both) anywhere, then in REAPER:

1. **Actions > Show action list... > New action > Load ReaScript...**
2. Select the file.
3. Run it from the action list (or bind it to a key / toolbar button).

## Using it

| Action | Result |
| --- | --- |
| Left-click the icon | Scale list - pick a root note under a scale type |
| Right-click the icon | Display options - see below |
| `D` | Dock / undock the window |
| `Esc` or the close box | Quit |

### Display options

Right-clicking the icon opens:

| Option | Effect |
| --- | --- |
| Random Scale | Picks a scale at random, for when you can't decide - never the one already showing |
| Show note names | Draws the note name inside each circle |
| Swap Sharps & Flats | Names the five black keys Db Eb Gb Ab Bb instead of C# D# F# G# A#, in the circles and in the scale name underneath (Simple only) |
| Simplify Note Names | Turns off key-aware spelling and names every note like a piano key (merged script only) |
| Highlight Colour | Teal (default), Orange, Light Green, Light Blue, Light Pink or Gold. Simple also offers White; the other two do not, because the ring around a note being played is white |
| Dock window | Dock or undock the icon |
| Close | Quit |

Swapping sharps for flats is purely cosmetic - it renames notes, it does not
change which notes are lit. The scale list itself always shows both spellings
("C# / Db Major"), so it reads correctly either way.

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
| Diminished Whole-Half | 0 2 3 5 6 8 9 11 |
| Diminished Half-Whole | 0 1 3 4 6 7 9 10 |

Ionian is the same set of notes as Major and Aeolian the same as Natural Minor;
both spellings are listed because both names are in common use. The two diminished scales are the eight-note octatonics: whole-half is
W H W H W H W H from the root, half-whole is the same pattern starting with the
semitone. That is 192 selectable key signatures in total, plus **Clear scale**
to go back to all circles the same colour.

## Customising

The colours are 0..1 RGB triplets near the top of the script:

```lua
local COLOR_BG       = {0.10, 0.10, 0.12}  -- icon background
local COLOR_OFF      = {0.30, 0.31, 0.35}  -- note not in the selected scale
```

The highlight colours are the `HIGHLIGHTS` table just below them. Add, remove
or retune entries freely - the menu is built from the table, and the chosen
colour is stored by name, so reordering the list cannot repoint an existing
choice. Keep new entries pale: the note names drawn on top of them are dark,
and the tests check every colour in the table is light enough to read them
against.

`DEFAULT_W` / `DEFAULT_H` set the icon size for a first run (200 x 100), and
the proportions it keeps when docked.

## ScaleView Pro

`reascripts/kallums_ScaleView Pro.lua` is the full version: it spells note
names for the key **and** names the chord you are playing. If you ran an
earlier version of this script - it has also been called ScaleView Enharmonic
and ScaleView Detector - it picks up your saved scale, colour and window
position the first time you run it.

### Chord detection

Notes you play are ringed on the circles, and the label underneath names the
chord you are holding instead of the scale:

| You play | It shows |
| --- | --- |
| C Eb G | `Cmin` |
| C Eb G Bb | `Cmin7` |
| B C# F# | `Bsus2` |
| C E G, with E lowest | `C/E` |
| A C E G | `Amin7` |
| C E G A, with C lowest | `C6` |

It knows added tones and thinner voicings as well as the common chords:
`Cadd9`, `Cadd11`, `Cmin#11`, `C7(no3)`. A missing fifth passes without
comment, since the fifth is optional in an added-tone chord, but a missing
third is said out loud because it changes the quality. A sixth chord without
its fifth is read as the complete triad those notes also make, so C E A is
`Amin/C` rather than `C6`.

Chord roots are spelled for the selected key, so Gb Bb Db reads `Gb` in Gb
major and `F#` in F# major - the same trick the spelling engine already does
for scales.

A chord is named from the same eighteen spellings the scale list offers, which
are the roots real keys are built on. That keeps a chord in Gb major reading
`Gb` and one in Cb major reading `Cb`, while anything outside that vocabulary
falls back to a plain name: the double accidentals a key like Gb minor blues
produces (`Amin/C`, not `Bbbmin/Dbb`) and the theoretical spellings nobody
builds a chord on, so B# D# E# in C# major reads `CminAdd11`.

**The bass note decides the name.** B C# F# is `Bsus2` with B underneath, but
those same notes are F#sus4 with F# underneath; and A C E G is `Amin7` or `C6`
depending which is lowest. When the lowest note is not the root you get a slash
chord (`C/E`). When neither the root nor a familiar shape is in the bass, the
commoner chord wins and the bass is shown after the slash (`Amin7/G`).

Anything it does not recognise is named honestly as its notes (`C E`) rather
than guessed at - which, for extended chords, turned out to be often enough to
be worth fixing. That is what
[ScaleView Alt](#scaleview-alt-the-chord-reader) does.

### What it listens to

Notes come from REAPER's global MIDI input history
(`MIDI_GetRecentInputEvent`), polled in the script's own loop. That means:

- It shows what you play on a controller, anywhere in REAPER, with no track
  or FX setup - just run the script.
- It does **not** see MIDI items playing back, and it is not per-track. Making
  it follow playback would need a small JSFX on the track feeding the script,
  which is a change to where the notes come from and nothing else.

If REAPER's input history cannot be read at all, the label says `MIDI input
unavailable` rather than failing - the script will not throw inside its own
defer loop.


### Spelling that follows the key

The note names are spelled for the key you pick instead of always being sharps
or flats.

![ScaleView Pro](docs/preview-pro.svg)

Each note of a seven-note scale takes the next letter of the alphabet and
whatever accidental that letter then needs, which is how written music works:

| Key | Spelling |
| --- | --- |
| C# Major | C# D# E# F# G# A# B# - an E# rather than F, a B# rather than C |
| Db Major | Db Eb F Gb Ab Bb C - the same seven notes, but F and C stay as they are |
| F# Major | F# G# A# B C# D# E# - a B, but an E# rather than F |
| Gb Major | Gb Ab Bb Cb Db Eb F - a Cb rather than B, but an F |
| Cb Major | Cb Db Eb Fb Gb Ab Bb - an Fb rather than E, a Cb rather than B |

Because the spelling follows how the key is written rather than which notes
sound, C# major and Db major are different keys here even though they light the
same seven circles. **Random Scale** picks from those spellings too, so it can
land on Gb Major or F# Major. The scale list offers **both spellings of every
root** - C# and Db, F# and Gb, and so on - plus Cb, 18 roots in all. There is no
"Swap Sharps & Flats" option: the key decides. The five notes outside the
selected scale have no spelling of their own, so they are named in whichever
direction the key leans - flats in F major, sharps in G major.

Theoretical keys are spelled honestly rather than being tidied up, so D# major
comes out as D# E# Fx G# A# B# Cx (`x` is a double sharp, `bb` a double flat).
The fifteen real major keys never need one.

The shorter and longer scales follow their conventional spellings rather than
the one-letter-per-degree rule, which cannot apply to them: major blues repeats
a letter for its b3 and 3 (C D Eb E G A), and the eight-note diminished scales
repeat one letter (C D Eb F Gb Ab A B).

Simple and Pro are independent - separate files, separate saved settings -
so you can run either, or both at the same time.

## ScaleView: the merged script

`reascripts/kallums_ScaleView.lua` is ScaleView Pro with Simple's naming
available as an option, so one script covers both. It starts in Pro's
key-aware spelling; **Simplify Note Names** switches to piano-key naming, and
the choice is remembered.

### Clicking

It has no left-click and right-click menus. **Where** you click decides, and
either button does the same thing:

| Click | Opens |
| --- | --- |
| On a circle | The scale list |
| On empty space | Random Scale, note names, Simplify Note Names, highlight colour, dock, close |

A click belongs where it began, so pressing on a circle and drifting off still
opens the scale list. This replaces the two-button arrangement the other two
scripts use, where a menu's own click could be mistaken for a fresh one and
open the wrong menu.

| | Gb Major | Cb Major | A# Harmonic Minor |
| --- | --- | --- | --- |
| Default (spelled for the key) | Gb Ab Bb Cb Db Eb F | Cb Db Eb Fb Gb Ab Bb | A# B# C# D# E# F# Gx |
| Simplify Note Names | F# G# A# B C# D# F | B C# D# E F# G# A# | A# C C# D# F F# A |

Simplified, every note is named the way its piano key is: sharps for the black
keys, and never a double accidental, so Cb reads B, Fb reads E and Gx reads A.

**Chord detection is unchanged** - it finds the same chords either way, and
only the names it reports follow the scheme. Gb Bb Db F reads `Gbmaj7` by
default and `F#maj7` simplified.

The **scale name underneath stays as you picked it** from the list: choose Gb
Major and it says Gb Major, even simplified, because that is the key you chose
and the name it has in the menu. Only the note names change.

If you ran ScaleView Pro, the merged script picks up its saved scale, colour
and window position the first time you run it.

### Each project remembers its own key

The scale is saved **into the project**, so reopening a project puts its key
back, and switching between open projects follows them. A project that has
never had a scale set is left showing whatever is already up rather than
blanking.

Everything else - highlight colour, note names, Simplify Note Names, window
position and dock state - stays global, because those are preferences rather
than anything about the music.

One consequence worth knowing: choosing a scale marks the project as edited,
since it is now part of the project. That is the cost of the project
remembering it.

### On a toolbar

The script reports its on/off state to REAPER, so a toolbar button bound to it
lights up while it is running, and clicking that button again closes it rather
than opening a second copy.

REAPER does not reopen scripts by itself when you restart it or reload a
project - a script runs until you stop it, and nothing records that it was
running. To have it start automatically, use a startup action: the SWS
extension offers both a global and a per-project one.

## ScaleView Alt: the chord reader

Alt is the merged script with one thing changed: how it names the chord you
are holding. Everything else - the icon, the scales, the spelling, the
clicking, the per-project key - behaves exactly as described above.

The other scripts match the notes you play against a table of chord shapes.
That works until you play something the table does not contain, and then there
is nothing to fall back on, so the label reads out the notes instead. The table
can always be made longer, but it cannot be made complete: a chord is a quality
with any number of tones stacked on top, and those combinations do not run out.

Alt reads the chord instead of looking it up. It splits the symbol in two:

- **The bottom half** - the third, the fifth and the seventh - is a closed
  vocabulary. Those three can only combine in about thirty ways and each
  combination has a name musicians agree on, so that half is still a table,
  ordered by how common each quality is.
- **The top half** - sixths, ninths, elevenths, thirteenths and their
  alterations - is not closed, so it is described rather than matched.
  Whatever the bottom half did not account for is read off as an extension.

Every note being held is tried as the root and the cheapest reading wins, where
the cost covers how unusual the quality is, what its extensions cost, and
whether the root had to be named after a slash. That last part is what keeps a
complete triad in an inversion ahead of a rooted chord with a hole in it: C E A
stays `Amin/C` rather than becoming a C6 with no fifth.

The practical difference, measured over every three-, four- and five-note
voicing in every bass position - 6,600 in all:

| | Merged script | Alt |
| --- | --- | --- |
| Named as a chord | 28% | **100%** |
| Read out as a list of notes | 72% | none |

Chords the table could not name and Alt can include `C7b13`, `Cmaj7#11`,
`Cmaj9#11`, `C13b9`, `C13#11`, `C7#9#11`, `Cadd9Add11` and `Cmin11b5`, along
with extended chords voiced without the tones underneath them - `C13` with no
ninth in it, or a `Cmin11` played as root, third, eleventh and seventh.

Two rules do most of the work, and both come from the way musicians read:

- **The highest natural extension names the chord** and the ones below it are
  taken as read, which is what `C13` means whether or not the ninth is played.
  A natural eleventh over a major third is the exception - it clashes - so it
  is written as an add rather than swallowed by the number.
- **An alteration has to belong to the chord it sits on.** A b9, a #9 and a b13
  are the dominant's alterations; over a minor seventh or a plain triad they
  are not colours a musician hears, they are a sign the root has been guessed
  wrong and the notes belong to some plainer chord standing on one of the
  others.

### What the selected scale does

The scale you have chosen is used, but only to settle a draw. Where two
readings come out at exactly the same cost, a root that is a degree of the
scale wins, and then a reading whose notes sit in it.

It is deliberately no stronger than that. A chord from outside the key is
named for what it is rather than bent to fit - play F# A# C# with C major
selected and it is `F#`, not something contorted into the key - and with no
scale selected at all, which is how the script starts, the commoner quality
decides instead. Measured across every voicing and every key, the scale only
ever changes the answer for semitone clusters, which have no good name either
way.

## Tests

`tests/` runs the scripts headlessly against a mock of
REAPER's `gfx` API, clicking menu entries by label and reading back which
circles were drawn lit. It checks all 192 scale/root combinations against the
interval formulas, the menu index mapping, the clear/options menus, the docked
layout, the sharps/flats swap, every highlight colour and its legibility,
that settings survive a restart and that settings saved under the script's
previous name still load:

```
lua5.4 tests/test_scaleview.lua
lua5.4 tests/test_scaleview_alt.lua
lua5.4 tests/test_scaleview_simple.lua
lua5.4 tests/test_scaleview_pro.lua
```

Both suites also replay click sequences frame by frame, including the stray
click a modal menu reports after it closes, to check each mouse button keeps
opening its own menu. They check that Random Scale only ever lands on a real
root and scale, that the circles match the name it shows, and that it never hands back
the scale already on screen.

The Alt suite adds the chords its reader can name and the table could not,
and one property test standing behind the whole approach: it plays every
three- and four-note voicing - 715 of them - and fails if any single one comes
back as a list of notes rather than a chord. Each of those tests was run
against the merged script first and watched to fail, because a regression test
that passes against the bug is worthless.

It plays MIDI at the script through a mocked input history and
reads the chord name back off the icon: the examples above, triads and
sevenths, inversions and slash chords, the C6/Amin7 ambiguity in all three
bass positions, note-offs and all-notes-off, that re-polling never applies an
event twice, and that a missing or misbehaving input API degrades to a message
instead of throwing.

The merged script's suite is the Pro suite plus the naming option: that each
key reads correctly both ways, that double accidentals become piano keys, that
the same chords are found with only their names changing, and that the setting
survives a restart.

The Pro suite also checks the spellings above, that each sharp/flat pair of
keys lights the same circles while reading differently, that all 288 root and
scale combinations light the right notes, and that every seven-note scale uses
each of the seven letters exactly once - the property that makes the spelling
correct.

The mock reproduces REAPER's real `gfx.showmenu` contract: the returned index
counts **only selectable items**, so separators and submenu headers must not be
counted when mapping the result back to an action.
