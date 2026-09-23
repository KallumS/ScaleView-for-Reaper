# 0004. Pro and Simple are independent copies, not a shared library

Status   - Accepted
Date     - standing; Simple rebuilt as Pro-minus-detection 2026-09-16
Commits  - the merge that folded five scripts into two

## Context

Two ReaScripts draw the same icon. Simple is Pro with the chord reader taken
out and nothing else changed. The obvious engineering move is a shared module
both `dofile` - one copy of the spelling engine, one copy of `handleMouse`.

## Decision

Keep them as **two independent files**. A ReaScript is installed and run as a
single file through ReaPack; a shared library means a second package, a path
that has to resolve on someone else's machine, and a version skew that can
leave one script running against the other's engine.

## Consequences

- **A fix to either script belongs in both.** This is the standing cost and it
  has been paid repeatedly: the docking fix, the menu settle, the toolbar
  toggle state, every colour change. Check both before considering a bug
  fixed.
- The two suites are near-duplicates by design, and both must be run.
- Divergence is invisible unless it is tested for. The two `handleMouse`
  functions were claimed identical and only *proved* identical by diffing
  them; several claims in `CLAUDE.md` about Simple turned out to describe a
  version that no longer existed.
- Simple must never read MIDI. Its suite counts calls into
  `MIDI_GetRecentInputEvent` and fails on any - "no chord detection" means it
  never looks, not that it looks and says nothing.

## Evidence

`CLAUDE.md`, opening section and *Simple is now Pro minus the chord reader*.
The JUCE plugin is a **third** copy of the musical core, held to parity by
diffing output - about 53,000 names byte-identical, then 584,076 more for the
doubled-root rule.
