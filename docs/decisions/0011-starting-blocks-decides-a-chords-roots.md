# 0011. Let Starting Blocks decide which roots a chord can have

Status   - Accepted
Date     - 2026-10-10
Commits  - `df4ea43`

## Context

Noterator and Miderator name chords in a lane above the score with this
reader, and their Blocks toolbox builds chords with Starting Blocks. The
user found the two disagreeing over inversions and asked for every Blocks
chord in every key to be checked, with **Blocks right wherever they
disagree** - its construction is the correct one, and should be the
dictionary for Pro. Measured in Noterator: every Blocks chord in all 288
keys, every family, type, degree and inversion, 670,248 chords. No name
claimed notes that were not played, but only 52% were named on Blocks' root.
And 19% cannot all be, from the notes alone: they are note for note, bass
included, a Blocks chord on another root (C E G A over C is I6 and vi7 in
first inversion).

## Decision

Where the notes held are a Blocks chord, the name is on **a root Blocks
builds them on**, and the reader's cost chooses between Blocks' roots as it
always chooses. A Blocks chord is one of Starting Blocks' 78 chord types
(`M.CHORDS`) on any root with any of its notes in the bass - a ninth chord's
fourth inversion has its ninth there - or one of the key's own chords
(`M.DIATONIC`) on its degrees. Notes that are no Blocks chord are read as
before. Tables copied unchanged from Starting Blocks' `sb_engine.lua` at
`fc4dd32`.

Two other designs were measured and put to the user, who chose this one:

| | Blocks' own chords on Blocks' root | lead sheets on the arranger's root |
| --- | --- | --- |
| before | 52% | 99.27% |
| only roots Blocks builds the notes on **in the selected key** | 83.4% | 97.93% |
| **this: Blocks' chord types on any root, the key's chords on its degrees** | **74.4%** | **99.33%** |

The first loses real music: a Bm7 in F major read D6/B, because in F major
Blocks only builds those notes as a D6. Majority voting among Blocks'
readings scored 85% but read C F G as Fsus2/C, because Blocks has more ways
to build it from F; the reader's cost keeps it Csus4.

## Consequences

- **The sweep moves 1,074 of 17,688 names** (6.1%), every one still naming
  exactly the notes. On the music21 core corpus **8,400 of 363,963
  sonorities (2.31%)** are renamed - mostly suspended and quartal voicings,
  which are also Blocks' quartal and whole-tone chords: G C D A from
  `Gsus4Add9` to `Amin7(11)/G`, G A F from `G7sus2` to `Fadd9/G`. The
  objective score does not move: 363,959 of 363,963.
- Six pinned names change, each to the Blocks chord the notes are:
  `Cdim9` is `D7b9/C`, `Csus4Add9` is `Dmin7(11)/C`, `C7#9#11` is
  `F#13b5b9/C`, `Cmin7b5(11)` is `D#min6/9/C`, `Caddb6` is `G#maj7#5/C` and
  `Cmaj7sus2` is `Gadd11/C`. Unpinned before, `Baddb9/C` is now
  `CminMaj7b5`, Blocks' diminished major seventh. Decisions 0009 and 0010
  still hold for notes that are no Blocks chord.
- A tritone is named where it is a Blocks chord in the key - B F is
  `B(b5)(no3)` in C major, Blocks' fifth on B - and read out as notes where
  it is not.
- The key now matters a little more than a draw (decision 0002): it decides
  which of the key's own chords count. Choosing C Major still names exactly
  as no scale does.
- **Every copy took it**, diffed against Pro over every one- to seven-note
  voicing and every distinct sonority of the music21 core corpus with its
  doublings: the plugin 457,336 names in nine keys, Midi Suggester 439,504
  in eight, byte-identical; Midi Variator (Suggester's file whole), Noterator
  and Miderator (the plugin's file). Against the previous Pro the rig
  reports 1,076 differences on the voicings alone. Middaw's Python
  port, already behind decisions 0003, 0009 and 0010, is left for now - the
  user's call.
- If Starting Blocks' tables change, these copies change with them.

## Evidence

`tests/test_scaleview_pro.lua` section 4b, and the nine changed pins.
`tools/sweep.py`, `tools/leadsheet_check.py`, `tools/corpus_scan.py`.
Noterator's `generators: every Blocks chord reads in the Chords lane...`
test, and `docs/sessions/2026-10-10.md` for the measurements.
