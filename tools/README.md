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
printf '60 64 67\n60 63 67 70\n' | lua5.4 tools/runner.lua "reascripts/kallums_ScaleView Pro.lua"
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

**Validate it on known-good data before believing a number it produces.** Every
bad accuracy figure this project has quoted came from the checker or the
expected answers being wrong, never from the engine - four separate times.

## `corpus_scan.py` — chordify a whole music21 corpus

Parses every score in music21's core corpus on four processes, chordifies each,
and writes the distinct vertical sonorities with counts as JSON chunks that
checkpoint. About twenty minutes for all 3,194 files.

```sh
python3 tools/corpus_scan.py 0 200        # first chunk; repeat in steps of 200
```

music21 is used here only as a file reader. It is never asked to name a chord.
