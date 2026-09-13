# Every chord type ScaleView Pro recognises

**Pro does not hold a list of chords.** It matches the bottom of the symbol
against a closed vocabulary and *describes* everything above it, so this file
has two halves: the 46 core qualities, which are a table, and the extension
grammar, which is not.

The tables below are generated - run `lua5.4 tools/chord_types.lua` to rebuild
them. It loads the shipped script under the test suite's mocks and asks the
real `core()`, `coreName()` and `rankOf()`, so it cannot drift from what REAPER
shows. Intervals are semitones from the root.

## The core: 46 qualities

The third, fifth and seventh. `rank` is the engine's own ordering by how common
a quality is; it is the first term in the cost that decides which reading wins.

A **missing fifth is silent** - `0 4 10` prints `7`, the same as `0 4 7 10` -
so the fifth-less forms are not listed separately. A **missing third is not**,
which is why the `(no3)` group exists.

### Triads

| symbol | semitones from the root | rank |
| --- | --- | --- |
| `(major)` | 0 4 7 | 1 |
| `min` | 0 3 7 | 2 |
| `dim` | 0 3 6 | 8 |
| `aug` | 0 4 8 | 9 |
| `sus4` | 0 5 7 | 10 |
| `sus2` | 0 2 7 | 11 |

### Seventh chords

| symbol | semitones from the root | rank |
| --- | --- | --- |
| `7` | 0 4 7 10 | 3 |
| `min7` | 0 3 7 10 | 4 |
| `maj7` | 0 4 7 11 | 5 |
| `min7b5` | 0 3 6 10 | 6 |
| `dim7` | 0 3 6 9 | 7 |
| `minMaj7` | 0 3 7 11 | 12 |
| `aug7` | 0 4 8 10 | 13 |
| `7b5` | 0 4 6 10 | 14 |
| `maj7#5` | 0 4 8 11 | 15 |
| `7sus4` | 0 5 7 10 | 16 |
| `7sus2` | 0 2 7 10 | 17 |
| `maj7sus4` | 0 5 7 11 | 18 |
| `maj7sus2` | 0 2 7 11 | 19 |

### Altered fifths with no agreed name

| symbol | semitones from the root | rank |
| --- | --- | --- |
| `(b5)` | 0 4 6 | 25 |
| `min#5` | 0 3 8 | 25 |
| `maj7b5` | 0 4 6 11 | 37 |
| `min7#5` | 0 3 8 10 | 37 |
| `minMaj7#5` | 0 3 8 11 | 37 |
| `minMaj7b5` | 0 3 6 11 | 37 |

### Suspensions over an altered fifth

| symbol | semitones from the root | rank |
| --- | --- | --- |
| `sus4b5` | 0 5 6 | 70 |
| `sus4#5` | 0 5 8 | 70 |
| `sus2b5` | 0 2 6 | 70 |
| `sus2#5` | 0 2 8 | 70 |
| `7sus4b5` | 0 5 6 10 | 82 |
| `7sus4#5` | 0 5 8 10 | 82 |
| `7sus2b5` | 0 2 6 10 | 82 |
| `7sus2#5` | 0 2 8 10 | 82 |
| `maj7sus4b5` | 0 5 6 11 | 82 |
| `maj7sus4#5` | 0 5 8 11 | 82 |
| `maj7sus2b5` | 0 2 6 11 | 82 |
| `maj7sus2#5` | 0 2 8 11 | 82 |

### No third — the one omission stated in the symbol

| symbol | semitones from the root | rank |
| --- | --- | --- |
| `5` | 0 7 | 34 |
| `7(no3)` | 0 7 10 | 30 |
| `maj7(no3)` | 0 7 11 | 31 |
| `7b5(no3)` | 0 6 10 | 33 |
| `maj7b5(no3)` | 0 6 11 | 32 |
| `(b5)(no3)` | 0 6 | 90 |
| `(#5)(no3)` | 0 8 | 90 |
| `7#5(no3)` | 0 8 10 | 102 |
| `maj7#5(no3)` | 0 8 11 | 102 |

## Above the core: described, not matched

Whatever the core did not consume is read off as an extension. Six interval
slots, one token each:

| semitones above the root | token |
| --- | --- |
| 1 | `b9` |
| 2 | `9` |
| 3 | `#9` |
| 5 | `11` |
| 6 | `#11` |
| 8 | `b13`, printed `b6` with no seventh under it |
| 9 | `13`, printed `6` with no seventh under it |

Also `(maj7)` when a b7 and a major 7th sound together, `6/9`, and `add`/`Add`
when a degree has to be spelled out rather than claimed by a number.

The rules that combine them:

- A stacked number claims every degree beneath it, **but only when the ninth is
  actually played** - otherwise the degree is bracketed after the seventh:
  `min7(11)`, not `min11`. An altered ninth still fills the place, so `13b9`
  keeps its number.
- A **natural 11 over a major third clashes**, so it is bracketed whatever else
  is present. Over a minor third it does not, and names the chord.
- `(no3)` goes at the end of the whole symbol: `maj7b5(no3)`, never
  `maj7(no3)b5`.
- The bass is found separately from the root and named after a slash when they
  differ.
- Past **seven pitch classes** there is no chord left to find, only a cluster,
  so the notes are read out instead.

Over every voicing of three to seven notes in every bass position - 17,688 of
them - that grammar prints **496 distinct chord types**.

## Checked against the standard formulas

Every one of these was run through `tools/runner.lua` and matches:

| chord | formula | Pro prints |
| --- | --- | --- |
| Major | 0 4 7 | `C` |
| Minor | 0 3 7 | `Cmin` |
| Diminished | 0 3 6 | `Cdim` |
| Augmented | 0 4 8 | `Caug` |
| Sus2 | 0 2 7 | `Csus2` |
| Sus4 | 0 5 7 | `Csus4` |
| Major 7th | 0 4 7 11 | `Cmaj7` |
| Minor 7th | 0 3 7 10 | `Cmin7` |
| Dominant 7th | 0 4 7 10 | `C7` |
| Half-diminished 7th | 0 3 6 10 | `Cmin7b5` |
| Fully diminished 7th | 0 3 6 9 | `Cdim7` |
| Major 9th | R 3 5 7 9 | `Cmaj9` |
| Dominant 9th | R 3 5 b7 9 | `C9` |
| Minor 9th | R b3 5 b7 9 | `Cmin9` |
| Minor 11th | R b3 5 b7 9 11 | `Cmin11` |
| Dominant 11th, 3rd dropped | R 5 b7 9 11 | `C11` |
| Dominant 13th, 11th omitted | R 3 5 b7 9 13 | `C13` |

Two of the full stacks come back bracketed, and both are the engine flagging
the clash that players already avoid:

| chord | formula | Pro prints | |
| --- | --- | --- | --- |
| Dominant 11th, complete | R 3 5 b7 9 11 | `C9(11)` | the major 3rd against the 11th |
| Dominant 13th, complete | R 3 5 b7 9 11 13 | `C13(11)` | same clash |

Drop the third from the first and omit the eleventh from the second - which is
how both are voiced in practice - and they print `C11` and `C13` exactly.
`Cmin11` keeps its number with the third present, because a minor third does
not clash with an eleventh.

The shells behave the same way: `R 3 7 9` is `Cmaj9`, `R b3 b7 9 11` is
`Cmin11`, `R 3 b7 9 13` is `C13`. A missing fifth changes nothing, which is the
rule above.

## What is deliberately absent

- **`sus#4`.** Added once and reverted - it is not standard nomenclature, and
  with a natural fifth present a raised fourth is a `#11`. See CLAUDE.md.
- **Sixth chords without their fifth.** `0 4 9` is `Amin/C`, not `C6`: an
  incomplete chord must not beat a complete one.
