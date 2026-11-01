# 0014. Let maj7(sus2) name a chord, the one root outside Starting Blocks

Status   - Accepted
Date     - 2026-11-01
Commits  - see `git log -- docs/decisions/0014*`

## Context

On 1 November 2026, 37 chords were played into REAPER and read by Pro and
Scaler Detector at once (`tools/scaler_cases.py`, the probes). Scaler names
a chord from its bass whenever the notes, read up from the bass, make a shape
it has a name for. Of the 15 places Pro differs, one group looked like Pro
being wrong rather than a matter of notation: **Pro's slash put its own added
11 in the bass**. F G C E over F read `Cadd11/F` (Scaler `Fmaj7(sus2)`), and
E F# B D# over E read `Badd11/E` (Scaler `Emaj7(sus2)`).

Pro could not offer that root. maj7(sus2), root 2 5 maj7, is not one of
Starting Blocks' 78 chord types, and decision 0011 limits a Blocks chord's
roots to Blocks' own. Its notes are Blocks' add11 on its fifth, so the add11
root was the only one on offer.

## Decision

`{0,2,7,11}` is accepted as a root alongside Blocks' types
(`NOT_BLOCKS_TYPES` in `blocksRoots`). It is the only such exception. The
reader's cost chooses among the roots as always, and it picks maj7(sus2) only
from its own root: over its second, fifth or seventh the add11 still wins,
which is also what Scaler said for E G over C and Eb E Gb B over B. A version
that offered the root only from the bass was built and named every voicing in
all 288 keys identically, so the simpler form was kept.

## Consequences

- **Twelve sweep names move** of 17,688, one shape in twelve keys, all to
  root position: `Cadd11/F` to `Fmaj7sus2`. No other name moves in any of
  the 288 keys. The objective score stays 100%.
- **Scaler: root agreement 31 to 33 of 58**, the two target chords, no losses.
- One pin from 0011 goes back: C D G B is `Cmaj7sus2` again, not `Gadd11/C`
  (G's 11 in the bass - the same pattern).
- **Lead sheets give back 0011's gain**: the arranger's `Eb/Ab` (11 symbols)
  reads `Abmaj7sus2` again rather than `Ebadd11/Ab`, 99.33% to 99.27% on the
  arranger's root. Same notes, a triad over a bass outside it written as one
  chord, the category that section already calls notation.
- jazznet and Wikipedia's list do not move. The music21 corpus: see
  `docs/sessions/2026-11-01-maj7sus2.md`.
- **Blocks agreement goes down by design.** Blocks' add11 voiced over its 11
  is now named on a root Blocks does not use, so 0011's "100% of every chord
  whose notes are all in the key" no longer holds for that one voicing. Not
  re-measured here: that needs Noterator's Blocks toolbox.
- **The copies have not taken it.** The plugin, Midi Suggester, Midi
  Variator, Noterator and Miderator all carry the 0011 reader; each needs the
  same one-line exception and a parity diff before this is complete.
- A second exception should need the same evidence: a chord Scaler names from
  its bass where Pro's slash puts its own added tone there. Not a general
  licence to add Scaler's shapes.

## Evidence

`CLAUDE.md`, *Starting Blocks decides which roots a chord can have* and *What
the probe found*. `tests/test_scaleview_pro.lua`, the maj7(sus2) block in
section 6e. `tools/scaler_cases.py`, `tools/sweep.py`,
`tools/leadsheet_check.py`. `docs/sessions/2026-11-01-maj7sus2.md`.
