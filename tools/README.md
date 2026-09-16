# How the chord naming is measured

Three small tools, kept because the measurements in `CLAUDE.md` are worth being
able to repeat. None of them is needed to *use* ScaleView; they exist to check
it.

## `runner.lua` — drive a real script over a corpus

Loads one of the ReaScripts under the same `gfx`/`reaper` mocks the test suites
use, reads MIDI note numbers on stdin (one chord per line, space separated) and
writes `notes<TAB>name`. Because it drives the shipped file, what it prints is
what REAPER shows.

```sh
printf '60 64 67\n60 63 67 70\n' | lua5.4 tools/runner.lua "reascripts/ScaleView Pro.lua"
#   60 64 67       C
#   60 63 67 70    Cmin7
```

A second argument selects a scale from the menu first, e.g. `"Gb Major"`.

## `check_symbol.py` — read a chord symbol back into notes

Parses a printed symbol into the pitch classes it claims, written from music
theory alone: it knows nothing about the Lua. A name is correct when everything
it names is played, nothing played is left unaccounted for, and the bass is
right. A perfect fifth is optional, because the engine never states a missing
one; so are the stack members under a 13.

**Keep it in step with the engine.** It parses symbols independently, so a
quality the engine can print but the checker cannot parse reads as a *wrong
symbol* rather than an unknown one. That has happened: a quality was added to
the engine and not here, and 84 voicings came back as failures that were
entirely the tool's. Whenever `CORE_RANK` or `coreName` gains a token, add it
here in the same change.

**Validate it on known-good data before believing a number it produces.** Every
bad accuracy figure this project has quoted came from the checker or the
expected answers being wrong, never from the engine - four separate times.

`claimed` reports the bass a symbol names, and by the strict rule that is the
lowest note sounding. The engine has one convention on top of it - a doubled
root that is a 1st, 3rd or 5th degree of the key reads as root position, so the
slash comes off - and that lives in `names_bass`, separately, because it is a
preference rather than theory. Score with `claimed` alone for the strict
figure and with `names_bass` for what the engine is actually trying to do;
`CLAUDE.md` quotes both.

## `chord_types.lua` — dump the closed half of the vocabulary

Loads the shipped script under the same mocks and asks the real `core()`,
`coreName()` and `rankOf()` for every third/fifth/seventh combination they can
reach, so the list cannot drift from what REAPER shows.

```sh
lua5.4 tools/chord_types.lua "reascripts/ScaleView Pro.lua"
```

`CHORD_TYPES.md` is the written-up version - the 46 core qualities, the
extension grammar that sits on top of them, and the standard chord formulas
checked against what Pro prints. Regenerate the tables there from this script
rather than editing them by hand.

## `corpus_scan.py` — chordify a whole music21 corpus

Parses every score in music21's core corpus on four processes, chordifies each,
and writes the distinct vertical sonorities with counts as JSON chunks that
checkpoint. About twenty minutes for all 3,194 files.

```sh
python3 tools/corpus_scan.py 0 200        # first chunk; repeat in steps of 200
```

music21 is used here only as a file reader. It is never asked to name a chord.
