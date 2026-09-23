# 0002. The selected scale only breaks a draw

Status   - Accepted
Date     - 2026-09-17
Commits  - `bb8b076`, `67759da`

## Context

ScaleView knows which key the user selected, so it is tempting to let that
decide which root a chord is named on. It reads as free accuracy: prefer the
diatonic root and ambiguous chords resolve themselves.

## Decision

The scale **breaks ties and nothing more**. At equal cost a root that is a
scale degree wins, then a reading whose notes sit in the scale, then the
commoner quality. It is not a filter: a chord from outside the key is named
for what it is.

## Consequences

- A chord borrowed from outside the key keeps its real name. This is the
  behaviour users expect and the one Scaler has.
- Nobody should wire scale degrees into root choice expecting accuracy, and
  a future session proposing it can be pointed here.
- The key still decides *spelling* everywhere - `Gbmaj7` in Gb major, `F#maj7`
  in F# major. Spelling and detection are deliberately separate.

## Evidence

`CLAUDE.md`, *The selected scale only breaks a draw*. **Three independent
nulls**, which is what closed the question:

| | effect of tying detection to the key |
| --- | --- |
| Pro | no movement at all |
| A pattern-matching engine, different architecture | 22.07% to 22.08% |
| Scaler 3 itself, the reference | same root in two keys, respelled only |

The third was the cheapest: one chord (C# F# G# A#) in two keys, with what
each answer would mean written down in advance.
