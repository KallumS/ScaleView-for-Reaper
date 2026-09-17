#!/usr/bin/env python3
"""Every chord in Wikipedia's "List of chords", named by a ScaleView script.

The question it answers is "are we missing any": does the engine produce a
symbol for each, and does that symbol account for exactly the notes. It does
NOT check that the name matches Wikipedia's - several rows are names for a
function rather than a symbol (Tonic, Subdominant, Secondary dominant are all
plain triads), several are named sonorities from one piece (the Tristan,
Elektra, Petrushka and magic chords), and the three augmented sixths are
enharmonically dominant sevenths, which is what the engine prints.

The pitch-class sets below are transcribed from that article's table, which is
CC BY-SA; they are facts about the chords rather than prose. Source:
https://en.wikipedia.org/wiki/List_of_chords
"""
import os, sys, subprocess, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_symbol import claimed

NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

CHORDS = [
    ("Augmented chord", (0, 4, 8)),
    ("Augmented eleventh chord", (0, 2, 4, 6, 7, 10)),
    ("Augmented major seventh chord", (0, 4, 8, 11)),
    ("Augmented seventh chord", (0, 4, 8, 10)),
    ("Augmented sixth chord", (0, 4, 10)),
    ("Augmented sixth chord", (0, 4, 6, 10)),
    ("Augmented sixth chord", (0, 4, 7, 10)),
    ("Diminished chord", (0, 3, 6)),
    ("Diminished major seventh chord", (0, 3, 6, 11)),
    ("Diminished seventh chord ( leading-tone and secondary chord )", (0, 3, 6, 9)),
    ("Dominant", (0, 4, 7)),
    ("Dominant eleventh chord", (0, 2, 4, 5, 7, 10)),
    ("Dominant minor ninth", (0, 1, 4, 7, 10)),
    ("Dominant ninth", (0, 2, 4, 7, 10)),
    ("Dominant parallel", (0, 3, 7)),
    ("Dominant seventh chord", (0, 4, 7, 10)),
    ("Dominant seventh flat five chord", (0, 4, 6, 10)),
    ("Dominant seventh sharp nine / Hendrix chord", (0, 3, 4, 7, 10)),
    ("Dominant thirteenth chord", (0, 2, 4, 5, 7, 9, 10)),
    ("Dream chord", (0, 5, 6, 7)),
    ("Elektra chord", (0, 1, 4, 7, 9)),
    ("Farben chord", (0, 4, 8, 9, 11)),
    ("Half-diminished seventh chord", (0, 3, 6, 10)),
    ("Harmonic seventh chord", (0, 4, 7, 10)),
    ("Leading-tone triad", (0, 3, 6)),
    ("Lydian chord", (0, 4, 6, 7, 11)),
    ("Magic chord", (0, 1, 5, 6, 10)),
    ("Magic chord", (0, 3, 5)),
    ("Major chord", (0, 4, 7)),
    ("Major added-second chord", (0, 2, 4, 7)),
    ("Major eleventh chord", (0, 2, 4, 5, 7, 11)),
    ("Major seventh chord", (0, 4, 7, 11)),
    ("Major seventh sharp eleventh chord", (0, 4, 6, 8, 11)),
    ("Major sixth chord", (0, 4, 7, 9)),
    ("Major sixth ninth chord (\"6 add 9\", Nine six, 6/9)", (0, 2, 4, 7, 9)),
    ("Major ninth chord", (0, 2, 4, 7, 11)),
    ("Major thirteenth chord", (0, 2, 4, 5, 7, 9, 11)),
    ("Mediant", (0, 3, 7)),
    ("Minor chord", (0, 3, 7)),
    ("Minor added-second chord", (0, 2, 3, 7)),
    ("Minor eleventh chord", (0, 2, 3, 5, 7, 10)),
    ("Minor major seventh chord", (0, 3, 7, 11)),
    ("Minor ninth chord", (0, 2, 3, 7, 10)),
    ("Minor seventh chord", (0, 3, 7, 10)),
    ("Minor sixth chord", (0, 3, 7, 9)),
    ("Minor sixth ninth chord (6/9)", (0, 2, 3, 7, 9)),
    ("Minor thirteenth chord", (0, 2, 3, 5, 7, 9, 10)),
    ("Mystic chord", (0, 2, 4, 6, 9, 10)),
    ("Neapolitan chord", (1, 5, 8)),
    ("Ninth augmented fifth chord", (0, 2, 4, 8, 10)),
    ("Ninth flat fifth chord", (0, 2, 4, 6, 10)),
    ("Northern lights chord", (1, 2, 8)),
    ("Northern lights chord", (0, 3, 4, 6, 7, 10, 11)),
    ("\"Ode-to-Napoleon\" hexachord", (0, 1, 4, 5, 8, 9)),
    ("Petrushka chord", (0, 1, 4, 6, 7, 10)),
    ("Power chord P5", (0, 7)),
    ("Psalms chord", (0, 3, 7)),
    ("Secondary dominant", (0, 4, 7)),
    ("Secondary leading-tone chord", (0, 3, 6)),
    ("Secondary supertonic chord", (0, 3, 7)),
    ("Seven six chord", (0, 4, 7, 9, 10)),
    ("Seventh suspension four chord", (0, 5, 7, 10)),
    ("So What chord", (0, 3, 5, 7, 10)),
    ("Suspended chord", (0, 5, 7)),
    ("Subdominant", (0, 4, 7)),
    ("Subdominant parallel", (0, 3, 7)),
    ("Submediant", (0, 3, 7)),
    ("Subtonic", (0, 4, 7)),
    ("Supertonic", (0, 3, 7)),
    ("Tonic counter parallel", (0, 3, 7)),
    ("Tonic", (0, 4, 7)),
    ("Tonic parallel", (0, 3, 7)),
    ("Tristan chord", (0, 3, 6, 10)),
    ("Viennese trichord", (0, 1, 6)),
    ("Viennese trichord", (0, 6, 7)),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--script", default=os.path.join(HERE, "..", "reascripts", "ScaleView Pro.lua"))
    ap.add_argument("--all", action="store_true", help="print every row, not just the failures")
    args = ap.parse_args()

    inp = "\n".join(" ".join(str(60 + p) for p in pcs) for _, pcs in CHORDS) + "\n"
    named = [line.split("\t")[1] for line in
             subprocess.run(["lua5.4", os.path.join(HERE, "runner.lua"), args.script],
                            input=inp, capture_output=True, text=True).stdout.splitlines()]
    if len(named) != len(CHORDS):
        sys.exit(f"runner returned {len(named)} names for {len(CHORDS)} chords")

    ok, bad = 0, []
    for (name, pcs), got in zip(CHORDS, named):
        played = set(pcs)
        fits = False
        if " " not in got:
            c = claimed(got)
            fits = bool(c) and not (c[0] - played) and not (played - (c[0] | c[1]))
        ok += fits
        if not fits:
            bad.append((name, pcs, got))
        if args.all:
            print(f"  {name:36} {' '.join(NOTE[p] for p in pcs):24} {got}")

    print(f"\n  {ok}/{len(CHORDS)} named, with the symbol accounting for exactly the notes")
    for name, pcs, got in bad:
        print(f"    MISS {name:32} {' '.join(NOTE[p] for p in pcs):24} -> {got}")


if __name__ == "__main__":
    main()
