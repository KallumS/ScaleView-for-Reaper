#!/usr/bin/env python3
"""The twelve chords that were put through Scaler 3 and reported back, one per
major key, with what ScaleView prints beside what Scaler printed.

They are the only hard evidence about Scaler in this repository. Every one of
the 24 names accounts for exactly the notes played, and the bass agreed in all
twelve: the disagreements were only ever about the root.

A thirteenth reading settled a rule that the twelve had only suggested. The
first chord was played again in F#/Gb major and came back Db6(sus4) - the same
root as in C major, respelled - so Scaler does not choose its root by the
selected scale. See CLAUDE.md, *Where Pro and Scaler 3 disagree*.

The voicing is reconstructed from the bass each reading implies - bass lowest,
the rest stacked above it - which is how the notes were played. A NOTE line
records what Scaler and ScaleView still spell differently while reading the
chord the same way.
"""
import os, sys, subprocess, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
      "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}

#  key, notes, the bass, what Scaler printed, and a note where the two read the
#  chord the same way but write it differently.
CASES = [
    #  Also played in F#/Gb major, where Scaler says Db6(sus4): the same root,
    #  respelled for the flat key. That is what settled the question of whether
    #  Scaler picks its root by the selected scale - it does not, it uses the
    #  key for spelling, exactly as ScaleView does.
    ("C Major",  "C# F# G# A#", "C#", "C#6(sus4)",      "Scaler roots it on the bass; not because of the key"),
    ("C# Major", "D D# G A",    "D",  "D#maj7(b5)/D",   "same reading, Scaler brackets the b5"),
    ("D Major",  "C F F# A#",   "F",  "F#maj7(b5)/F",   "same reading, Scaler brackets the b5"),
    ("Eb Major", "Eb E Gb B",   "Eb", "Emaj7(sus2)/D#", "Scaler refuses an 11 over a major third"),
    ("E Major",  "C# D# G# A",  "C#", "Amaj7(b5)/C#",   "same reading, Scaler brackets the b5"),
    ("F Major",  "C D Eb Gb A", "C",  "Cdim9",          ""),
    ("F# Major", "D E A#",      "E",  "Bbmaj(b5)/E",    "same reading; Scaler spells A# as Bb and writes maj"),
    ("G Major",  "C E F# A",    "C",  "F#min7(b5)/C",   "same reading, Scaler brackets the b5"),
    ("Ab Major", "D E Ab B",    "D",  "D6(sus2 b5)",    "Scaler roots it on the bass; not because of the key"),
    ("A Major",  "D B",         "B",  "Bmin(no5)",      ""),
    ("Bb Major", "C E",         "C",  "Cmaj(no5)",      ""),
    ("B Major",  "C D# F B",    "C",  "Bmaj(b5)b9/C",   "Scaler roots it elsewhere; why is not known"),
]


def voicing(notes, bass):
    pcs = [PC[n] for n in notes.split()]
    b = PC[bass]
    v = [60 + b] + sorted(60 + b + ((pc - b) % 12) + 12 for pc in pcs if pc != b)
    assert len({x % 12 for x in v}) == len(v), notes
    return v


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--script", default=os.path.join(HERE, "..", "reascripts", "ScaleView Pro.lua"))
    args = ap.parse_args()

    same = 0
    for scale, notes, bass, scaler, note in CASES:
        got = subprocess.run(["lua5.4", os.path.join(HERE, "runner.lua"), args.script, scale],
                             input=" ".join(map(str, voicing(notes, bass))) + "\n",
                             capture_output=True, text=True).stdout.strip().split("\t")[-1]
        hit = got.replace(" ", "") == scaler.replace(" ", "")
        same += hit
        print(f"  {'SAME ' if hit else '     '} {scale:9} {notes:13} "
              f"{got:16} | Scaler {scaler}")
        if note and not hit:
            print(f"          {note}")
    print(f"\n  {same}/12 printed identically; see CLAUDE.md, "
          f"*Where Pro and Scaler 3 disagree*, for the rest")


if __name__ == "__main__":
    main()
