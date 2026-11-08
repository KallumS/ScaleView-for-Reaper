#!/usr/bin/env python3
"""Checks raw_readings.txt: each ScaleView Pro name must account for exactly the
notes of its chord (line n of full_list.txt) with C as the bass. A shifted or
misread row shows up here. Run: python3 -I check_readings.py"""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
from check_symbol import claimed
full = [l.split(":")[0] for l in open(os.path.join(HERE, "full_list.txt"))]
bad = n = 0
for l in open(os.path.join(HERE, "raw_readings.txt")):
    p = l.rstrip("\n").split("|"); i = int(p[0]); n += 1
    pcs = {int(x) for x in full[i - 1].split()}
    c = claimed(p[1])
    if not (c and not (c[0] - pcs) and not (pcs - (c[0] | c[1])) and c[2] == 0):
        bad += 1; print("MISMATCH", i, full[i - 1], p[1])
print(n, "rows,", bad, "mismatches")
