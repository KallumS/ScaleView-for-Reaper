#!/usr/bin/env python3
"""Every pitch-class set of three to seven notes, over every bass it contains -
17,688 voicings - named by a real script and checked by check_symbol.py.

    python3 tools/sweep.py > before.txt          # one line per voicing
    python3 tools/sweep.py --script other.lua > after.txt
    diff before.txt after.txt                    # the blast radius of a change

The summary goes to stderr so stdout stays diffable. This is the sweep every
weight change in CLAUDE.md was judged by; it was in a scratchpad and is
committed now so the next change can be diffed the same way.

The voicing is built the way CLAUDE.md says and not the way that looks right:
every upper note is placed relative to the bass, `60+bass+((pc-bass)%12)+12`,
so no pitch class can repeat - and that is asserted rather than trusted, since
the wrong construction silently produced two-note "three-note" chords once.
"""
import sys, os, argparse, itertools, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_symbol import claimed, names_bass

NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def voicings(sizes=range(3, 8)):
    for k in sizes:
        for pcs in itertools.combinations(range(12), k):
            for bass in pcs:
                notes = [60 + bass] + [60 + bass + ((pc - bass) % 12) + 12
                                       for pc in pcs if pc != bass]
                assert len({n % 12 for n in notes}) == len(notes) == k
                yield tuple(sorted(notes))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--script", default=os.path.join(HERE, "..", "reascripts", "ScaleView Pro.lua"))
    ap.add_argument("--scale", default=None, help='select a scale first, e.g. "C Major"')
    args = ap.parse_args()

    vs = list(voicings())
    cmd = ["lua5.4", os.path.join(HERE, "runner.lua"), args.script] + ([args.scale] if args.scale else [])
    out = subprocess.run(cmd, input="\n".join(" ".join(map(str, v)) for v in vs) + "\n",
                         capture_output=True, text=True, check=True).stdout.splitlines()
    if len(out) != len(vs):
        sys.exit(f"runner returned {len(out)} names for {len(vs)} voicings")

    exact = 0
    for v, line in zip(vs, out):
        name = line.split("\t")[1]
        played = {n % 12 for n in v}
        c = claimed(name)
        ok = (c is not None and not (c[0] - played) and not (played - (c[0] | c[1]))
              and names_bass(name, v))
        exact += ok
        print(" ".join(NOTE[n % 12] for n in v) + "\t" + name + ("" if ok else "\tNOT EXACT"))
    print(f"{len(vs)} voicings, {exact} named exactly ({100*exact/len(vs):.3f}%)", file=sys.stderr)


if __name__ == "__main__":
    main()
