# 0009. An altered dominant on its root keeps its alterations

Status   - Accepted
Date     - 2026-10-07
Commits  - `f9e2691`

## Context

Pro treats a b9, #9 or b13 over an altered fifth as a sign the root has been
guessed wrong, and charges it `COST_CLASHING`. That is right for most chords
and backwards for the dominant seventh, where those alterations over a b5 or
#5 are the altered dominant itself. C7#5b9 read `A#min9b5/C`, C7b5b9
`F#7#11/C`, C7b5#9 `D#min6b9/C` - each naming exactly the notes, which is why
no objective figure in the repository could see it. A round trip through
20,027 chord symbols on public-domain lead sheets found it: `E7#5b9` came
back `Dmin9b5/E`.

## Decision

A major third and a flat seventh **with the root in the bass** are at home
with any alteration whatever the fifth is doing. Everything else about
`athome` is unchanged.

## Consequences

- The altered dominants read as themselves: `Caug7b9`, `C7b5b9`, `C7b5#9`,
  `Caug7#11`. 455 of the 17,688 sweep names move, none of three or four notes;
  the five-note moves are exactly those four shapes in twelve keys. On the
  music21 core corpus it renames 11 of 363,963 sonorities, all real altered
  dominants.
- **Not from an inversion.** That was measured: it moved 790 names, read
  F A C G C# over C as `Aaug7#9/C` with the #9 in the bass, and broke
  `Cmaj7#5#11`. Do not widen it without re-running that comparison.
- The full seven-note 7alt still reads as its tritone substitute,
  `F#13#11/C` - the same notes as natural tensions. Left alone deliberately.
- **The plugin does not have it yet.** `KallumS/ScaleView` ports this engine
  and must take the same change, followed by the parity diff.

## Evidence

`CLAUDE.md`, *How Pro names a chord* ("An altered dominant keeps its root") and
*Against the symbols people write*. `tests/test_scaleview_pro.lua` section 3e.
`tools/sweep.py` for the blast radius, `tools/leadsheet_check.py` for the
lead sheets.
