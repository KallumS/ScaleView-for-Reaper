# Scaler probes, 1 Nov 2026 (computer-use session)

37 chords played live into REAPER (ScaleView Pro in C minor; Scaler Detector, no scale).
Full table: ScaleView-for-Reaper-main/CLAUDE.md, "What the probe found (1 November 2026)".
Rows: tools/scaler_cases.py, last block of CASES (58 rows now; 24 old + 34 new).

- Scaler's root = the bass whenever the notes read up from the bass make a shape it names; otherwise another root plus a slash.
- Old "Ddim#5 over F" was a wrong bass: over F Scaler says F min6 11. CASES row corrected to D.
- Dominant 7th inversions are never slashed by Scaler (dim #5 / min6 11 / 6(sus2 b5)). maj7, min7, m7b5 inversions keep slashes. Recommend: Pro keeps X7/bass.
- Natural 11 over a major 3rd is NOT forbidden (Cadd11, Cmaj7 11, C7 11, Badd11 over B all agree).
- Only candidate change: Pro puts its added 11 in the bass (Cadd11/F, Badd11/E), where Scaler says Fmaj7(sus2), Emaj7(sus2). Pro can't offer that root because maj7(sus2) isn't a Starting Blocks type (decision 0011). The user decides.
- Not run: tools/scaler_cases.py (lua5.4 not installed). Pro names in CASES notes were read off REAPER's screen.
- REAPER: a throwaway driver script was run once from the scratchpad via "Run ReaScript". Nothing saved, no settings changed. The action-list filter text now reads "run reascript".

## Vocabulary map (231 chords over C) - same day, later
- Data: tools/scaler_vocabulary.py (VOCAB 231 rows + TRANSPOSED 45 rows). Write-up: CLAUDE.md "Scaler's vocabulary, mapped".
- Named from the bass: 8 two-note, 30 three-note, 71 four-note shapes. `?` for 17, all with 3 adjacent semitones or two semitone pairs a tritone apart.
- All 102 slash names = a listed shape on another root. With C bass, the lowest pc candidate won 43/43 multi-candidate cases.
- BUT not transposition-invariant: 0 4 6 9 / 0 3 5 8 / 0 2 5 9 over all 12 basses flip between min7-type and 6-type at fixed bass pitch classes; octave shifts don't change it. Mechanism unknown.
- Scaler omits a missing 5th silently in 90/214 names.
- Pro = Scaler's root on 134/214.
- Not touched: reascripts/ScaleView Pro.lua. Lua not installed.

## 5-7 note run - paused 2 Nov 2026 (user's weekly limit)
- Backup + resume steps: ScaleView-for-Reaper-main/tools/scaler_vocabulary_5to7/README.md
- Done chords 1-371 of 1,254 (all 5-note, 6-note up to 371). readings.txt = table; remaining.txt + chord_stepper.lua to continue.
- Nothing added to CLAUDE.md or scaler_vocabulary.py for this batch yet.
