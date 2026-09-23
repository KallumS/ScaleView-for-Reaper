# 0008. Adopt the house colour scheme

Status   - Accepted
Date     - 2026-09-18
Commits  - `d144da1`, `1d5e957`, `df49055`, `fa316f9`

## Context

The user is standardising one colour scheme across their projects: an accent
(`#FFF200`), controls (`#A9AFBA`), a ground (`#23272E`), an ink (`#14171C`)
and an eighteen-entry cool grey ramp. ScaleView's palette predated it and had
been chosen by eye.

## Decision

Adopt it. Ground, Ink and Accent are exact; two near-misses were snapped to
ramp entries. The full scheme is transcribed into `CLAUDE.md` because the
message carrying it does not survive a session.

## Consequences

- **Colours are no longer a free choice.** A new grey comes off the ramp, not
  out of a colour picker, and the ramp's load-bearing property is that every
  entry satisfies `R < G < B` - a neutral grey reads flat beside the yellow.
- Light controls force dark text, *including unselected ones*. That is the
  trap the scheme names: the selected button looks fine while the rest go
  unreadable.
- The scripts store colours as 0..1 triplets, so each value sits a hair above
  `n/255` to land on the intended hex whichever way REAPER rounds.
  `{0.14, 0.15, 0.18}` gives `#26262E`, not `#23272E`.

## Two divergences are deliberate and still open

- **The unlit circle is dark with light text**, where the scheme's unchosen
  button is `#A9AFBA` with `#14171C` ink. Following the scheme exactly would
  make the notes *outside* the key the brightest thing in the icon. The two
  constants move together or not at all.
- **Lit circles are one of six chosen highlights, not the Accent.** In a piano
  roll every MIDI note is `#FFF200`; here the accent already means *being
  played*. Two states in one icon cannot share a colour - see 0006 - so
  standardising the lit circle requires moving the ring first, and makes the
  six-colour menu vestigial.

## Evidence

`CLAUDE.md`, *The house colour scheme*, which holds the ramp, both carry-over
rules and the audit of where ScaleView sits against it.
