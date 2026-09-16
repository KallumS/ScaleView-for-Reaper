#!/usr/bin/env python3
"""Score a script's chord symbols against the human labels collected by
`collect_labels.py`: does it name the analyst's root, and the analyst's bass?

Three things are counted apart rather than as errors, because each is a
difference in what the two notations are FOR, not a disagreement about the
notes. The first version of this script counted them and read 68%; every one of
them turned out to be the measurement.

  Partial chords      A slice inside a labelled span often holds only part of
                      the chord - G Bb C inside a C7 whose E has not sounded.
                      Only slices holding the whole labelled chord are scored.
  The cadential 6-4   An analyst writes V(64) for a C major triad over G
                      because of where it goes; a musician writes C/G because
                      of what it is. They can never agree.
  Span against slice  Where an accompaniment arpeggiates, the lowest note at
                      one instant is not the chord's bass, and the analyst's
                      figure describes the span.

Symmetric sets are reported separately too: a set that maps onto itself under
transposition has no root derivable from the notes, so nobody can find one.
"""
import sys, os, json, re, subprocess, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_symbol import note_pc

NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def root_bass_of(symbol):
    """The root and the bass a printed symbol names."""
    sym, _, bass = symbol.rpartition("/")
    if not sym or not re.match(r'^[A-G](?:[#b]+|x)?$', bass):
        sym, bass = symbol, ""
    m = re.match(r'^([A-G](?:[#b]+|x)?)', sym)
    if not m:
        return None, None
    root = note_pc(m.group(1))
    return root, (note_pc(bass) if bass else root)


def symmetric(pcs):
    return any(all(((p + t) % 12) in pcs for p in pcs) for t in range(1, 12))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pairs", help="JSON written by collect_labels.py")
    ap.add_argument("--script", default=os.path.join(HERE, "..", "reascripts", "ScaleView Pro.lua"))
    ap.add_argument("--label", default="")
    ap.add_argument("--examples", type=int, default=12)
    args = ap.parse_args()

    rows = [r for r in json.load(open(args.pairs)) if r["full"]]
    inp = "\n".join(" ".join(map(str, r["notes"])) for r in rows) + "\n"
    out = subprocess.run(["lua5.4", os.path.join(HERE, "runner.lua"), args.script],
                         input=inp, capture_output=True, text=True).stdout.splitlines()
    names = [line.split("\t")[1] for line in out]
    if len(names) != len(rows):
        sys.exit(f"runner returned {len(names)} names for {len(rows)} voicings")

    scored = root_ok = bass_ok = both = sym_miss = span_miss = doubled = spelled = cad64 = 0
    diffs, example = collections.Counter(), {}
    for r, got in zip(rows, names):
        if " " in got:
            spelled += 1
            continue
        if re.search(r'64', r["chord"] or ""):
            cad64 += 1
            continue
        proot, pbass = root_bass_of(got)
        low = min(r["notes"]) % 12
        r_ok, b_ok = proot == r["root"], pbass == r["bass"]
        scored += 1
        root_ok += r_ok
        bass_ok += b_ok
        both += r_ok and b_ok
        if not b_ok:
            if r["bass"] == low:
                doubled += 1           # our doubled-root rule, not a disagreement
            else:
                span_miss += 1         # the analyst's bass is not sounding lowest here
        if not r_ok and symmetric({n % 12 for n in r["notes"]}):
            sym_miss += 1
        if not (r_ok and b_ok):
            key = (r["chord"], got)
            diffs[key] += 1
            example.setdefault(key, " ".join(NOTE[n % 12] for n in r["notes"]))

    print(args.label or args.pairs)
    print(f"  slices holding the whole labelled chord : {len(rows)}")
    print(f"  ... cadential 6-4, counted apart        : {cad64}")
    print(f"  ... read out as notes (cluster guard)   : {spelled}")
    print(f"  scored                                  : {scored}")
    print(f"  names the analyst's root                : {100*root_ok/scored:7.3f}%")
    print(f"  names the analyst's bass                : {100*bass_ok/scored:7.3f}%")
    print(f"  both                                    : {100*both/scored:7.3f}%")
    print(f"  root misses on a symmetric set          : {sym_miss}"
          f"   -> root agreement elsewhere {100*root_ok/(scored-sym_miss):7.3f}%")
    print(f"  bass misses that are a span-level claim : {span_miss}")
    print(f"  bass misses from the doubled-root rule  : {doubled}")
    print(f"  bass agreement with both set aside      : "
          f"{100*(bass_ok+span_miss+doubled)/scored:7.3f}%")
    if args.examples:
        print("\n  commonest disagreements:")
        for (chord, got), n in diffs.most_common(args.examples):
            print(f"    x{n:<5} analyst {chord:14} | {got:18} | {example[(chord, got)]}")


if __name__ == "__main__":
    main()
