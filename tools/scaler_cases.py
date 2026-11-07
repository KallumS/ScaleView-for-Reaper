#!/usr/bin/env python3
"""The twenty-four chords put through Scaler 3 and reported back - one per major
key, then one per natural minor key - with what ScaleView prints beside what
Scaler printed.

They are the only hard evidence about Scaler in this repository. Every one of
the 48 names - both engines, all 24 chords - accounts for exactly the notes
played, and the bass agrees everywhere it can be compared: the disagreements
are only ever about which root to name. C minor's D F G# A# was recorded here
as Ddim#5 over an F bass, the one non-bass root Scaler printed with no slash.
The four-voicing probe of 1 November 2026 showed the bass was D: over F the
same notes are F min6 11, and Scaler names every inversion of that chord from
its bass. The row now says D. See CLAUDE.md.

The last block of CASES, the probes, was played into REAPER on 1 November 2026
with the notes held live, so ScaleView Pro and Scaler Detector read the same
MIDI at once. Scaler Detector is Scaler's detection plugin, not Scaler 3
itself. It was checked against three earlier rows it could not have been tuned
to (E G C, Eb E Gb B over Eb, C E F# A over C) and gave Scaler 3's names each
time, only spaced out and with "maj" written in. ScaleView
was set to C Minor (Natural) and Scaler had no scale selected. Scaler Detector
prints both enharmonic names for a black-key root ("G#/Ab 6(sus2 b5)"); only
the first is kept here, so the slash in a name is always the bass.

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
    #  Recorded with F as the bass until 1 November 2026. Over F, Scaler
    #  says F min6 11 (see PROBES), so the voicing that gave Ddim#5 had D
    #  lowest. That is why it carried no slash.
    ("C Minor (Natural)",  "D F G# A#",  "D",  "Ddim#5",
     "Scaler names a dominant seventh's inversions from the bass; see PROBES"),
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

    #  The probes, 1 November 2026 - see the docstring. All in C minor for
    #  ScaleView. What ScaleView printed in REAPER is in each note, because
    #  lua5.4 was not installed to run this file that day.
    #
    #  1. One set in all four positions: a dominant seventh's inversions are
    #     named from the bass, with no slash, in a quality Scaler has for that
    #     rotation. Repeated on C7 and G7. Maj7, min7 and min7b5 inversions
    #     keep their slash, so it is the dominant only.
    ("C Minor (Natural)", "Bb D F Ab", "Bb", "A#7",              "Pro Bb7: same"),
    ("C Minor (Natural)", "Bb D F Ab", "F",  "Fmin6 11",         "Pro Bb7/F"),
    ("C Minor (Natural)", "Bb D F Ab", "Ab", "G#6(sus2 b5)",     "Pro Bb7/Ab"),
    ("C Minor (Natural)", "C E G Bb",  "C",  "C7",               "Pro C7: same"),
    ("C Minor (Natural)", "C E G Bb",  "E",  "Edim#5",           "Pro C7/E"),
    ("C Minor (Natural)", "C E G Bb",  "G",  "Gmin6 11",         "Pro C7/G"),
    ("C Minor (Natural)", "C E G Bb",  "Bb", "A#6(sus2 b5)",     "Pro C7/Bb"),
    ("C Minor (Natural)", "G B D F",   "B",  "Bdim#5",           "Pro G7/B"),
    #     The controls: the same move on other qualities keeps the slash.
    ("C Minor (Natural)", "C E G",     "E",  "Cmaj/E",           "Pro C/E: same"),
    ("C Minor (Natural)", "C E G B",   "E",  "Cmaj7/E",          "Pro Cmaj7/E: same"),
    ("C Minor (Natural)", "C E G B",   "B",  "Cmaj7/B",          "Pro Cmaj7/B: same"),
    ("C Minor (Natural)", "A C E G",   "A",  "Amin7",            "Pro Amin7: same"),
    ("C Minor (Natural)", "A C E G",   "G",  "Amin7/G",          "Pro Amin7/G: same"),
    ("C Minor (Natural)", "C Eb G Bb", "Eb", "D#maj add 13",     "Pro Eb6: same reading"),
    ("C Minor (Natural)", "E G A",     "E",  "Emin add 11",      "Pro EminAdd11: same"),
    ("C Minor (Natural)", "G A D F",   "G",  "G7(sus2)",         "Pro G7sus2: same"),
    #     A sixth against a seventh on another root, with neither in the bass.
    #     Scaler's choice here is not consistent: it takes the major sixth over
    #     the minor seventh twice, but the minor sixth over the half-diminished
    #     on F A B D and the opposite on C E F# A.
    ("C Minor (Natural)", "C E G A",   "C",  "Cmaj add 13",      "Pro C6: same reading"),
    ("C Minor (Natural)", "C E G A",   "E",  "Cmaj add 13/E",    "Pro Amin7/E"),
    ("C Minor (Natural)", "C Eb G Bb", "Bb", "D#maj add 13/A#",  "Pro Cmin7/Bb"),
    ("C Minor (Natural)", "B D F A",   "F",  "Dmin6/F",          "Pro Bmin7b5/F"),
    ("C Minor (Natural)", "C E F# A",  "E",  "F#min7(b5)/E",     "Pro Gbmin7b5/E: same"),
    ("C Minor (Natural)", "C E F# A",  "F#", "F#min7(b5)",       "Pro Gbmin7b5: same"),
    ("C Minor (Natural)", "C E F# A",  "A",  "Amin6",            "Pro Amin6: same"),
    #  2. A natural 11 over a major third is not forbidden: Scaler writes it
    #     whenever the root it wants is the bass or the chord has a seventh.
    ("C Minor (Natural)", "C E F G",   "C",  "Cmaj add 11",      "Pro Cadd11: same"),
    ("C Minor (Natural)", "C E F",     "C",  "Cmaj add 11",      "Pro Cadd11: same"),
    ("C Minor (Natural)", "C D E F G", "C",  "Cmaj add 9 11",    "Pro Cadd9Add11: same"),
    ("C Minor (Natural)", "C E G B F", "C",  "Cmaj7 11",         "Pro Cmaj7(11): same"),
    ("C Minor (Natural)", "C E G Bb F","C",  "C7 11",            "Pro C7(11): same"),
    ("C Minor (Natural)", "F A Bb E",  "E",  "Fmaj7 11/E",       "Pro Fmaj7(11)/E: same"),
    ("C Minor (Natural)", "Eb E Gb B", "B",  "Bmaj add 11",      "Pro Badd11: same"),
    #     Without a seventh and with the add11's root not in the bass, Scaler
    #     takes the maj7(sus2) on the 11 instead. Pro could not while decision
    #     0011 limited roots to Starting Blocks' chord types; since it was
    #     reversed (7 November 2026) Pro agrees where its 11 would be the bass.
    ("C Minor (Natural)", "Eb E Gb B", "E",  "Emaj7(sus2)",      "was Badd11/E under 0011, the 11 in the bass"),
    ("C Minor (Natural)", "Eb E Gb B", "Gb", "Emaj7(sus2)/F#",   "Pro Badd11/Gb"),
    ("C Minor (Natural)", "C E F G",   "E",  "Fmaj7(sus2)/E",    "Pro Cadd11/E"),
    ("C Minor (Natural)", "C E F G",   "F",  "Fmaj7(sus2)",      "was Cadd11/F under 0011, the 11 in the bass"),
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
