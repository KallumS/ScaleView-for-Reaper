# 0001. Read chords rather than look them up

Status   - Accepted
Date     - 2026-09-13, measured against a built alternative 2026-09-14/16
Commits  - `6a27222` (the alternative), `0a1cbca` (its deletion)

## Context

A chord namer can match a voicing against a table of known chords, or it can
read the notes and describe what it finds. The table is obvious, easy and
wrong at the edges: it names what it holds and reads the notes out for
everything else, and a chord is a quality with any number of tones stacked on
top, so the table is never finished. That was an opinion until it was measured.

## Decision

Name a chord **constructively**. The third, fifth and seventh stay a closed
table (`CORE_RANK`, about thirty combinations, each with an agreed name);
everything above them is *described* as a sixth, ninth, eleventh or
thirteenth, altered or not. Every candidate root is costed and the cheapest
wins.

## Consequences

- Every voicing gets a symbol. The engine never prints a list of notes for a
  three- to seven-note chord, and a property test in the Pro suite pins that.
- **The weights are the entire musical judgement.** Retuning one is a change
  to the naming of thousands of voicings, so any change to them is diffed over
  all 6,600 voicings before it is believed.
- The question "why not just match a table" has a number attached to it now
  and does not need re-litigating.

## Evidence

`CLAUDE.md`, *A table cannot be made complete* and *How Pro names a chord*. A
pattern-matching engine was built alongside as a controlled comparison and
measured on the same data: **100% against 23.5%** over 17,688 voicings, and
99.999% against 93.276% on the music21 core corpus. It was deleted once the
comparison was made; the table it produced is the record.
