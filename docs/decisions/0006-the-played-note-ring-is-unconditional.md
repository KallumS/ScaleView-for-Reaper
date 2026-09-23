# 0006. The played-note ring is one colour, unconditionally

Status   - Accepted
Date     - 2026-09-17, colour changed 2026-09-18
Commits  - `28bbce3`, `8cb6ddb`, `1d5e957`

## Context

A ring is drawn round each note being played. Making it contrast with the
circle underneath looks obviously right, and a contrast calculation supported
it: the ring reads at only 1.4:1 to 2.0:1 against a highlight colour. A
conditional ring was built on that arithmetic and **looked broken in REAPER**.

The arithmetic was right about the wrong surface. Both strokes are drawn at
`r + 1.5` and `r + 2.5` - *outside* the filled circle, on the background.

## Decision

The ring is always `COLOR_HELD` and never depends on what is under it. The
**hue is the user's to choose** and has already changed once, from white to
`#FFF200`; what must not change is that it is unconditional.

## Consequences

- No highlight may be the ring's own colour, or it would swallow the ring
  where the two touch. That bar moves with the ring: it barred white for
  years, and freed white the moment the ring turned yellow.
- The contrast figure is pinned to the background and must be recomputed
  whenever either colour moves. It is currently **12.8:1**.
- A test asserts every ring stroke is the one colour, so the rule cannot be
  made conditional again by accident.

## Evidence

`CLAUDE.md`, opening section. The numbers: `#FFF200` reads 12.8:1 on the
background against 1.4:1 to 2.0:1 on a highlight fill. Keep the failed
calculation in mind as the shape of the mistake, not as a reason to retry it -
**ask which surface a thing is actually drawn on before measuring contrast.**
