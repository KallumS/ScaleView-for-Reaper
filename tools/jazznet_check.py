#!/usr/bin/env python3
"""Name every chord-shaped jazznet pattern with a ScaleView script and compare.

jazznet (MIT, github.com/tosiron/jazznet) is 162,520 labelled piano patterns
generated from interval structures. The voicings here are its own:
`triad`/`tetrad` below are transcribed from its PatternGenerator, over the same
85 bases, so the inversions are laid out as the dataset lays them out.

How many notes each named type has is read off jazznet's own metadata - a dyad
has 2 forms, a triad 3, a tetrad 4 - which is what settles names like `maj6`
(a two-note interval) against `sixth` (a four-note chord). Three of the
interval structures are documented in its README (maj "4 3", maj7 "4 3 4",
min7b5 "3 3 4"); the rest are standard and marked as ours.

What this measures is agreement between two naming conventions, not
correctness: jazznet's label records how the file was generated - root plus
inversion - rather than what a musician would write over the printed voicing.
"""
import os, sys, subprocess, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_symbol import claimed

NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

#  type: (offsets, the symbol we would expect, where the offsets came from)
TRIADS = {
    "maj":  ([4, 3], "",     "jazznet README"),
    "min":  ([3, 4], "min",  "standard"),
    "dim":  ([3, 3], "dim",  "standard"),
    "aug":  ([4, 4], "aug",  "standard"),
    "sus2": ([2, 5], "sus2", "standard"),
    "sus4": ([5, 2], "sus4", "standard"),
}
TETRADS = {
    "maj7":    ([4, 3, 4], "maj7",   "jazznet README"),
    "min7":    ([3, 4, 3], "min7",   "standard"),
    "min7b5":  ([3, 3, 4], "min7b5", "jazznet README"),
    "dim7":    ([3, 3, 3], "dim7",   "standard"),
    "seventh": ([4, 3, 3], "7",      "standard"),
    "sixth":   ([4, 3, 2], "6",      "standard"),
}


def triad(inv, base, o1, o2):
    if inv == 0:
        return [base, base + o1, base + o1 + o2]
    if inv == 1:
        n1 = base + o1
        return [n1, n1 + o2, base + 12]
    n1, n2 = base + o1 + o2, base + 12
    return [n1, n2, n2 + o1]


def tetrad(inv, base, o1, o2, o3):
    if inv == 0:
        n1 = base; n2 = n1 + o1; n3 = n2 + o2
        return [n1, n2, n3, n3 + o3]
    if inv == 1:
        n1 = base + o1; n2 = n1 + o2; n3 = n2 + o3
        return [n1, n2, n3, base + 12]
    if inv == 2:
        n1 = base + o1 + o2; n2 = n1 + o3; n3 = base + 12
        return [n1, n2, n3, n3 + o1]
    n1 = base + o1 + o2 + o3; n2 = base + 12; n3 = n2 + o1
    return [n1, n2, n3, n3 + o2]


def symmetric(pcs):
    return any(all(((p + t) % 12) in pcs for p in pcs) for t in range(1, 12))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--script", default=os.path.join(HERE, "..", "reascripts", "ScaleView Pro.lua"))
    ap.add_argument("--scale", default=None, help='e.g. "C Major"; default is no scale')
    args = ap.parse_args()

    cases = []
    for name, (offs, quality, _) in TRIADS.items():
        for base in range(24, 109):
            for inv in range(3):
                cases.append((name, base, inv, quality, triad(inv, base, *offs)))
    for name, (offs, quality, _) in TETRADS.items():
        for base in range(24, 109):
            for inv in range(4):
                cases.append((name, base, inv, quality, tetrad(inv, base, *offs)))

    cmd = ["lua5.4", os.path.join(HERE, "runner.lua"), args.script]
    if args.scale:
        cmd.append(args.scale)
    inp = "\n".join(" ".join(map(str, c[4])) for c in cases) + "\n"
    names = [l.split("\t")[1] for l in
             subprocess.run(cmd, input=inp, capture_output=True, text=True).stdout.splitlines()]
    if len(names) != len(cases):
        sys.exit(f"runner returned {len(names)} names for {len(cases)} voicings")

    agree = notes_ok = bass_ok = 0
    groups = collections.defaultdict(list)
    for (kind, base, inv, quality, notes), got in zip(cases, names):
        root, bass = base % 12, min(notes) % 12
        played = {n % 12 for n in notes}
        want = NOTE[root] + quality + ("" if inv == 0 else "/" + NOTE[bass])
        c = claimed(got) if " " not in got else None
        if c:
            need, opt, cb = c
            notes_ok += not (need - played) and not (played - (need | opt))
            bass_ok += cb == bass
        if got == want:
            agree += 1
        else:
            groups[(kind, inv)].append((notes, want, got))

    n = len(cases)
    sym = sum(len(v) for (k, _), v in groups.items() if k in ("aug", "dim7"))
    print(f"jazznet chord-shaped patterns: {n} voicings"
          f"{' in ' + args.scale if args.scale else ', no scale selected'}")
    print(f"  symbol accounts for exactly the notes : {100*notes_ok/n:7.3f}%")
    print(f"  names the same bass as the voicing    : {100*bass_ok/n:7.3f}%")
    print(f"  symbol identical to jazznet's label   : {100*agree/n:7.3f}%")
    print(f"  ... on a symmetric set, where no root is derivable: {sym} voicings")
    print(f"  ... agreement elsewhere               : {100*agree/(n-sym):7.3f}%")
    print("\n  where the names differ, by type and inversion:")
    for (kind, inv), items in sorted(groups.items()):
        notes, want, got = items[0]
        print(f"    {kind:8} inv {inv}  x{len(items):<4} e.g. "
              f"{' '.join(NOTE[x % 12] for x in notes):16} jazznet {want:14} -> {got}")


if __name__ == "__main__":
    main()
