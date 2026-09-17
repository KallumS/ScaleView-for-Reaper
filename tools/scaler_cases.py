#!/usr/bin/env python3
"""The twenty-four chords put through Scaler 3 and reported back - one per major
key, then one per natural minor key - with what ScaleView prints beside what
Scaler printed.

They are the only hard evidence about Scaler in this repository. Every one of
the 48 names - both engines, all 24 chords - accounts for exactly the notes
played, and the bass agrees everywhere it can be compared: the disagreements
are only ever about which root to name. The one exception is C minor's
D F G# A#, where Scaler prints Ddim#5 with no slash over an F bass; every
other non-bass root it gives carries one, so that reading is unconfirmed.

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
PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "Fb": 4,
      "E#": 5, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9,
      "A#": 10, "Bb": 10, "B": 11, "B#": 0, "Cb": 11}

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

    #  The natural minor round. Same story: every name on both sides accounts
    #  for exactly the notes, and what differs is which root to name.
    ("C Minor (Natural)",  "D F G# A#",  "F",  "Ddim#5",
     "the one reading nobody has confirmed - Scaler prints no slash over an F bass"),
    ("C# Minor (Natural)", "C# D G A",   "C#", "Dmaj7(sus4)/C#",   ""),
    ("D Minor (Natural)",  "Db F Gb A",  "A",  "Aaug add13",
     "same root, same notes: Scaler calls the sixth a 13 with no seventh under it"),
    ("D# Minor (Natural)", "D E# B",     "D",  "Dmin6",            ""),
    ("E Minor (Natural)",  "D E B",      "D",  "D6sus2",
     "the E G A family: a suspension carrying a sixth"),
    ("F Minor (Natural)",  "Eb E Gb A",  "Eb", "Ebdim b9",         ""),
    ("F# Minor (Natural)", "E F",        "E",  "E min second",
     "Scaler names every two-note interval; ScaleView names only a fifth or a third"),
    ("G Minor (Natural)",  "C F Gb",     "F",  "F#maj7(no3 b5)/F",
     "one of the two where ScaleView is on the bass and Scaler is not"),
    ("G# Minor (Natural)", "C# D# F G#", "D#", "D#9(sus4)",
     "same root, same notes: 11 against 9sus4, both standard"),
    ("A Minor (Natural)",  "E F G#",     "F",  "Fmin(no5)maj7",
     "same root, same notes: Scaler says the missing fifth out loud"),
    ("A# Minor (Natural)", "B# D# E#",   "D#", "Eb6(sus2)",
     "the E G A family again"),
    ("B Minor (Natural)",  "C D F A#",   "D",  "C9(sus4)/D",       ""),
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
    print(f"\n  {same}/{len(CASES)} printed identically; see CLAUDE.md, "
          f"*Where Pro and Scaler 3 disagree*, for the rest")


if __name__ == "__main__":
    main()
