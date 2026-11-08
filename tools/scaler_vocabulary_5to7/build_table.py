#!/usr/bin/env python3
"""Rebuilds readings.txt (the readable table) from raw_readings.txt and
full_list.txt. It never touches remaining.txt: the stepper counts by position in
that file (line k = chord 371 + k), so it must not change. Run after appending readings:
    python3 -I build_table.py"""
import os
H = os.path.dirname(os.path.abspath(__file__))
N = ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"]
full = [l.rstrip("\n") for l in open(os.path.join(H, "full_list.txt"))]
rows = [l.rstrip("\n").split("|") for l in open(os.path.join(H, "raw_readings.txt"))]
done = len(rows)
assert [int(r[0]) for r in rows] == list(range(1, done + 1)), "rows must be 1..n in order"
out = ["# Scaler Detector vs ScaleView Pro: 5-, 6- and 7-note chords over C (IN PROGRESS)",
"# Played 1-7 Nov 2026 in REAPER 7.84, notes held live. C = MIDI 48 lowest, the rest close above (49-59).",
"# ScaleView Pro set to C Minor (Natural); Scaler Detector with no scale selected.",
f"# Done: chords 1-{done} of 1,254 (5-note = 1-330, 6-note = 331-792, 7-note = 793-1254). Left: {done+1}-1254.",
"# RECHECK = hard to read on screen; replay before trusting. Chords 76-100 were read at lower zoom.",
"# Scaler '?' = it named no chord. Every Pro name is checked against its notes (check_readings.py).",
"",
f"{'n':>4} | {'intervals':16} | {'notes':26} | {'ScaleView Pro':26} | {'Scaler Detector':36} | flag"]
for r in rows:
    n = int(r[0]); iv = full[n - 1].split(":")[0]
    out.append(f"{n:4} | {iv:16} | {' '.join(N[int(x)] for x in iv.split()):26} | {r[1]:26} | {r[2]:36} | {r[3] if len(r) > 3 else ''}")
open(os.path.join(H, "readings.txt"), "w").write("\n".join(out) + "\n")
print("table rebuilt:", done, "done,", len(full) - done, "left")
