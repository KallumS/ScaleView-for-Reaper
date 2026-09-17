# How the chord naming is measured

Eight small tools, kept because the measurements in `CLAUDE.md` are worth being
able to repeat. None of them is needed to *use* ScaleView; they exist to check
it.

The first three check the symbol against the notes - is it a name for exactly
what is being played. The last three check it against somebody else's name for
the same notes, which is a different question and worth keeping separate: where
two notations disagree, usually neither is wrong.

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

## `collect_labels.py` — pair sonorities with a human analyst's label

Two annotated corpora, one output shape. `dcml` reads DCML's `notes/*.tsv`
beside `harmonies/*.tsv`, which share a timeline, so the join needs no
alignment guesswork; `wir` reads When in Rome's `score.mxl` and `analysis.txt`
with music21 and matches them by measure and beat, because the two are separate
streams whose absolute offsets drift at an anacrusis.

```sh
python3 tools/collect_labels.py dcml  path/to/dcml  dcml_pairs.json
python3 tools/collect_labels.py wir   path/to/when-in-rome  wir_pairs.json
```

Neither corpus is in this repository - both are non-commercial or share-alike,
and these are measurements, not redistribution.

**The fifths arithmetic is the part to validate first.** DCML writes chord
tones, roots and basses as steps on the line of fifths relative to the *local*
key, and the local key is itself a numeral relative to the global one. Both
conversions were checked against labels whose answer is known from the numeral
alone - F minor `i` is F Ab C, C major `V2` is G B D F with F underneath -
before any score was believed.

## `score_labels.py` — does the symbol name the analyst's root and bass

```sh
python3 tools/score_labels.py wir_pairs.json --label "When in Rome"
```

**Three things are counted apart rather than as errors**, and the first version
of this script counted them and read 68%:

- **Partial chords.** A slice inside a labelled span often holds only part of
  the chord. Only slices holding the whole labelled chord are scored.
- **The cadential six-four.** An analyst writes `V(64)` for a C major triad
  over G because of where it goes; a musician writes `C/G` because of what it
  is. They can never agree.
- **Span against slice.** Where the accompaniment arpeggiates, the lowest note
  at one instant is not the chord's bass, and the analyst's figure describes
  the whole span.

Symmetric sets are also separated: a set that maps onto itself under
transposition has no root derivable from the notes, so nobody can find one.

## `jazznet_check.py` — against a labelled chord dataset

Generates the chord-shaped patterns of jazznet (MIT) from its own generator's
inversion formulas and compares each symbol with its label.

```sh
python3 tools/jazznet_check.py
python3 tools/jazznet_check.py --scale "C Major"
```

Its label records how the file was generated - a root and an inversion - not
what a musician would write over the printed voicing, so what this measures is
agreement between two naming conventions.

## `scaler_cases.py` — the twelve chords Scaler 3 was asked about

One per major key, with what ScaleView prints beside what Scaler printed. They
are the only hard evidence about Scaler in this repository; four rules came out
of them and two more are recorded in `CLAUDE.md` as not implemented.

```sh
python3 tools/scaler_cases.py
```

Every one of the 24 names accounts for exactly the notes played, and the bass
agreed in all twelve, so what is left is which root to name and how to
punctuate it.

## `wikipedia_chords.py` — is anything missing from the vocabulary

Every chord in Wikipedia's *List of chords*, 75 pitch-class sets, named by the
engine and checked with `check_symbol.py`.

```sh
python3 tools/wikipedia_chords.py --all
```

It asks whether each is named at all and whether the symbol accounts for
exactly the notes - **not** whether the name matches Wikipedia's. Many of those
rows are names for a function (Tonic, Subdominant, Secondary dominant are all
plain triads) or for one sonority in one piece (Tristan, Elektra, Petrushka),
and the three augmented sixths are enharmonically dominant sevenths, which is
what the engine prints.
