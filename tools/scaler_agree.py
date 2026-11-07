#!/usr/bin/env python3
"""How often ScaleView Pro names the same chord as Scaler Detector.

Every chord in the two Scaler vocabulary runs - all 1,485 pitch-class sets of
two to seven notes containing C, voiced with C lowest (MIDI 48) and the rest
close above it, exactly as they were played into REAPER - is named afresh by
the script under test, in C Minor (Natural) as it was that day. Scaler's
reading is the one recorded. Rows where Scaler printed `?` are left out: there
is nothing to agree with.

"The same chord" is the same root and the same bass. The notes are the same by
construction, so two names that agree on both differ only in how the quality
is written (`C maj add 13` against `C6`), which is spelling, not reading.

One line per chord on stdout, so two builds can be diffed; the summary goes to
stderr.

    python3 tools/scaler_agree.py
    python3 tools/scaler_agree.py --script candidate.lua > after.txt
"""
import os, sys, re, argparse, subprocess, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from scaler_vocabulary import VOCAB  # noqa: E402

PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
      "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11,
      "Cb": 11, "B#": 0, "E#": 5, "Fb": 4}


def chords():
    """(intervals over C, Scaler's name) for every reading, `?` included."""
    for iv, scaler, _, _, _ in VOCAB:
        yield iv, scaler
    d = os.path.join(HERE, "scaler_vocabulary_5to7")
    full = [l.split(":")[0].strip() for l in open(os.path.join(d, "full_list.txt"))]
    for line in open(os.path.join(d, "raw_readings.txt")):
        n, _, scaler = line.rstrip("\n").split("|")[:3]
        yield full[int(n) - 1], scaler


def scaler_reading(name):
    """(root pc, bass pc) of a Scaler name, or None for `?`."""
    if "?" in name:
        return None
    head, _, bass = name.partition(" / ")
    root = PC[re.match(r"([A-G][#b]?)", head).group(1)]
    return root, PC[bass.split("/")[0]] if bass else root


def pro_reading(name):
    """(root pc, bass pc) of a Pro name, or None where it spelled out notes."""
    if " " in name:
        return None
    root = PC[re.match(r"[A-G][#b]?", name).group(0)]
    bass = re.search(r"/([A-G][#b]?)$", name)   # not the slash in 6/9
    return root, PC[bass.group(1)] if bass else root


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--script", default=os.path.join(HERE, "..", "reascripts", "ScaleView Pro.lua"))
    ap.add_argument("--scale", default="C Minor (Natural)")
    args = ap.parse_args()

    rows = [(iv, sc) for iv, sc in chords() if scaler_reading(sc)]
    voicings = [" ".join(str(48 + int(i)) for i in iv.split()) for iv, _ in rows]
    out = subprocess.run(["lua5.4", os.path.join(HERE, "runner.lua"), args.script, args.scale],
                         input="\n".join(voicings) + "\n", capture_output=True, text=True,
                         check=True).stdout.splitlines()
    assert len(out) == len(rows), (len(out), len(rows))

    total, same = collections.Counter(), collections.Counter()
    for (iv, sc), line in zip(rows, out):
        pro = line.split("\t")[1]
        size = len(iv.split())
        root_s, bass_s = scaler_reading(sc)
        # Scaler names two notes as an interval with no bass ("F 5" for C F),
        # so for dyads only the root is compared.
        if size == 2:
            bass_s = None
        p = pro_reading(pro)
        hit = p is not None and p[0] == root_s and (bass_s is None or p[1] == bass_s)
        total[size] += 1
        same[size] += hit
        print(f"{'SAME' if hit else '    '}  {iv:20} {pro:26} {sc}")

    for size in sorted(total):
        print(f"{size} notes: {same[size]:4} of {total[size]:4} "
              f"({100 * same[size] / total[size]:.1f}%)", file=sys.stderr)
    t, s = sum(total.values()), sum(same.values())
    print(f"all:     {s:4} of {t:4} ({100 * s / t:.1f}%) name Scaler's root and bass",
          file=sys.stderr)


if __name__ == "__main__":
    main()
