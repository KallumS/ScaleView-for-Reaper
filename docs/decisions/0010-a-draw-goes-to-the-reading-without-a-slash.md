# 0010. A draw goes to the reading without a slash

Status   - Accepted
Date     - 2026-10-07
Commits  - `f9e2691`

## Context

When two readings cost exactly the same and fit the key equally, Pro took the
commoner quality. That sometimes picked a reading that needs a slash over one
that does not: C D G Bb over C read `GminAdd11/C` rather than `C7sus2`, because
a minor triad outranks a sus, and C D F G over C - `G7sus/C` on a lead sheet -
read `Dmin7(11)/C`.

## Decision

The tie order is: lower cost, then a root that is a scale degree, then notes in
the scale, **then no slash**, then the commoner quality.

## Consequences

- 132 of the 17,688 sweep names move, 28 of them four-note, all of those to
  the bass as root. jazznet, the Scaler cases and Wikipedia's list do not move.
- **On real music it is not small**: 0.81% of the music21 core corpus's
  sonorities (2,955 of 363,963), nearly all quartal and suspended voicings
  that read as a minor chord over a slash - G D F A was `DminAdd11/G` and is
  `G7sus2`. Every one now names the lowest note as its root. If that reads
  wrong in classical music, this is the decision to revisit.
- It only ever decides an exact draw. A real difference in cost still wins:
  A C E G over A is `Amin7`, over C it is `C6`, and over G it is still
  `Amin7/G`.
- The key still breaks a draw first, so decision 0002 stands - this adds a
  step after it, not before.
- **Every copy took it the same day**; see 0009.

## Evidence

`CLAUDE.md`, *The selected scale only breaks a draw*.
`tests/test_scaleview_pro.lua` section 3f. `tools/sweep.py`.
