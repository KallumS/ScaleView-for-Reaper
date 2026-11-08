# Scaler vocabulary, 5 to 7 notes: progress backup (2 Nov 2026)

This continues `tools/scaler_vocabulary.py` (2-4 notes, finished) to every
5-, 6- and 7-note pitch-class set containing C: 330 + 462 + 462 = 1,254 chords.

**Done: chords 1-371** (all 330 five-note chords, plus six-note chords 331-371).
**Left: 372-1,254** (421 six-note, then all 462 seven-note).

## Files

| file | what it is |
| --- | --- |
| `readings.txt` | the table so far: chord number, intervals over C, note names, ScaleView Pro's name, Scaler Detector's name, flag |
| `handover_notes.md` | copy (2 Nov 2026) of the short hand-over notes left for the other Claude sessions; everything in it is also in this folder or CLAUDE.md |
| `readings_2to4.txt` | the finished 2-, 3- and 4-note run (231 chords) in the same layout, plus the 45 transposition readings; generated from `../scaler_vocabulary.py` |
| `raw_readings.txt` | the same readings as `n|Pro|Scaler|flag`, one per line; append new ones here |
| `full_list.txt` | all 1,254 chords in order, `intervals: MIDI notes`; line n is chord n |
| `remaining.txt` | lines 372-1,254 of `full_list.txt`, the stepper's input |
| `chord_stepper.lua` | the throwaway ReaScript that plays each chord |

## How to pick it up

1. In REAPER: ScaleView Pro open and set to **C Minor (Natural)**; Scaler
   Detector on the track with **no scale selected**, Detect MIDI on.
2. Actions > "ReaScript: Run ReaScript (EEL2, Lua, or python)..." and open
   `chord_stepper.lua` from this folder. It is not installed as an action.
3. Click its window to step. **Stepper line k is chord 371 + k.** Read both
   plugins after each click (about a second is enough) and append
   `n|Pro|Scaler` to `raw_readings.txt`.
4. Close the stepper window when done: that releases all notes.

## Checks to keep running

- Every ScaleView Pro name should pass `check_symbol.claimed` against its
  notes with C as the bass. All 371 do, after two fixes: chords 105 and 109
  were read off the screen as `G...` and the notes show they are `Gb...`
  (flagged in the files). This check is also what proves the rows line up
  with the right chords.
- Scaler's names should account for the notes too, allowing for its habit of
  dropping a missing perfect fifth without saying so (see CLAUDE.md,
  *Scaler's vocabulary, mapped*). That check has not been run on this batch
  yet; `parse_scaler` from the earlier work lived in a scratchpad that is gone
  and would need extending for names like `maj(11)(#9)`, `min9 b11`, `6(b5) 9`.
- Re-read chords flagged RECHECK (76, 99) and, ideally, 76-100, which were
  read at lower zoom.

## Early observations (not yet analysed)

- Scaler prints `?` for 118 of the 371, mostly clusters with three or more
  adjacent semitones.
- Its 5- and 6-note names add new qualities not in the 4-note list:
  `min11`, `maj11`, `11`, `13(sus4)`, `maj(11)(#9)`, `min9 b11`,
  `min maj11(b9)`, `6 9 b9`, `7 b9 #9` and others.
- Nothing has been written to CLAUDE.md or `scaler_vocabulary.py` for this
  batch, and the algorithm is unchanged.
