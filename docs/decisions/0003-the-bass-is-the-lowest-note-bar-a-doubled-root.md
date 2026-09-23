# 0003. The bass is the lowest note, bar a doubled root

Status   - Accepted
Date     - 2026-09-16
Commits  - `a54d823`

## Context

The bass is found separately from the root and a slash names it, which is what
makes C E A read `Amin/C`. On one family of voicings that parted company with
Scaler: `E G C C` is `C` to Scaler and was `C/E` here. The reading was right
and the bass was not - doubling the root is how a chord is voiced *around* its
root rather than inverted.

## Decision

The bass is the lowest note sounding, with one exception: a root sounding in
**more than one octave** that is a first, third or fifth degree of the
selected key reads as root position, and the slash comes off. That is
`readAsRootPosition`, and it is the whole of the rule.

## Consequences

- **It can only remove a slash, never invent one.** What follows a slash is
  still always the lowest note sounding, so no symbol names a bass that is not
  there.
- The degrees come off the *selected scale*, not an assumed major triad, so
  `F A D D` is `Dmin/F` in C major and `Dmin` in D minor. With no scale
  selected `ASSUMED_TONIC` supplies them, and it has to move if `ASSUMED_KEY`
  ever does.
- The cost model is untouched; the rule decides only how the winner is
  written down.
- It costs the classical reading of those voicings. Measured against human
  analysts who mark first inversions explicitly, the price is **1.8%** in both
  labelled corpora.

## Evidence

`CLAUDE.md`, *How the bass is decided*. It renames 1.2% to 3.3% of distinct
sonorities across six corpora, and every rename is an inversion losing its
slash. The 17,688-voicing sweep is byte identical either way, because nothing
in it is doubled - which is why checking this needed real voicings and not a
sweep.
