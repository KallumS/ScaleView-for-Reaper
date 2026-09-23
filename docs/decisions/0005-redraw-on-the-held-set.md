# 0005. Redraw on the held set, not the chord name

Status   - Accepted
Date     - 2026-09-17
Commits  - `f9125e7`

## Context

The script polls MIDI in a defer loop and redraws when something changes. It
decided "something changed" by comparing the chord *name* against the last
one, which is cheap and looks equivalent.

It is not equivalent. Adding B to D E Ab leaves the name `E7/D`, because B is
the fifth and a missing fifth is silent. The note was held, the ring was not
drawn, and nothing forced a frame until the window was resized.

## Decision

A counter, `heldVersion`, is bumped on **every** change to the held set.
`pollMidiInput` returns whether it moved. The chord name is not consulted.

## Consequences

- **Anything else drawn from the notes has to go through `heldVersion` too.**
  A future feature that reads the held set and draws from it will reintroduce
  this bug if it invents its own change detection.
- The JUCE plugin never had the defect - its editor repaints on the held-note
  mask - which is the same decision reached independently.

## Evidence

`CLAUDE.md`, *What decides a redraw is the held set*. Test 9b in the Pro suite
pins it, and it is worth knowing **why the old suite could not see this**: the
`label()` helper toggles `gfx.w` to force a frame, and `play()` called it, so
every chord assertion in the file was reading a frame the test itself had
demanded. Test 9b calls `frame()` alone. The mock was not wrong, it was
helpful, which is worse.
