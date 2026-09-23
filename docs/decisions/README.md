# Architecture decision records

One file per decision that **constrains how the code may change**. A decision
earns a record here when reversing it would cost more than an afternoon, or
when it is the kind of question that gets asked again - by a future session, a
contributor, or the author in six months.

This is not a second copy of `CLAUDE.md`. That file is the standing
instruction set and holds the evidence: the measurements, the corpora, the
REAPER API behaviour, the arithmetic. **A record here is short and says what
was decided, what it rules out, and where the evidence lives.** If the two ever
disagree, `CLAUDE.md` and the code win - see its own warning that it is not
evidence about the code, which applies here twice over.

## Format

```
# NNNN. Title, in the imperative

Status   - Accepted | Superseded by NNNN | Reversed
Date     - when it was taken
Commits  - where it landed

## Context      what forced a choice
## Decision     what was chosen
## Consequences what this now rules out, and what it costs
## Evidence     the section of CLAUDE.md, tool or test that holds the proof
```

## The records

| | | Status |
| --- | --- | --- |
| [0001](0001-read-chords-rather-than-look-them-up.md) | Read chords rather than look them up | Accepted |
| [0002](0002-the-scale-only-breaks-a-draw.md) | The selected scale only breaks a draw | Accepted |
| [0003](0003-the-bass-is-the-lowest-note-bar-a-doubled-root.md) | The bass is the lowest note, bar a doubled root | Accepted |
| [0004](0004-pro-and-simple-are-independent-copies.md) | Pro and Simple are independent copies | Accepted |
| [0005](0005-redraw-on-the-held-set.md) | Redraw on the held set, not the chord name | Accepted |
| [0006](0006-the-played-note-ring-is-unconditional.md) | The played-note ring is unconditional | Accepted |
| [0007](0007-store-settings-by-name.md) | Store settings by name, never by index | Accepted |
| [0008](0008-adopt-the-house-colour-scheme.md) | Adopt the house colour scheme | Accepted |

Records 0001 to 0007 were taken before they were written down; the dates and
commits are when each landed in the code, not when this file was created.
