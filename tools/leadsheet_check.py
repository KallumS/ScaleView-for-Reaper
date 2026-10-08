#!/usr/bin/env python3
"""Round-trip the chord symbols people actually wrote on lead sheets.

Every `<harmony>` in a set of MusicXML lead sheets is turned back into the
notes it means, voiced with its bass lowest, played into a real script by
`runner.lua` in the song's own key, and the name that comes back is compared
with the one the arranger wrote.

This is the closest test there is to "does ScaleView name a chord the way a
musician writes it", because a lead sheet *is* a musician writing chord
symbols - in the same notation the script prints, not Roman numerals. Two
questions, kept apart as everywhere else in this repo:

  exact      does the printed symbol account for exactly the notes played, with
             the right bass (check_symbol.py, which knows nothing of the Lua)
  same root  does it name the root the arranger wrote

The notes come from the MusicXML *kind* table - the standard's own definition
of each chord kind - plus the degrees the file adds, alters or subtracts. Two
of the kinds are voiced the way they are played rather than as their full
stack, and say so below. Nothing here reads ScaleView's code.

    python3 tools/leadsheet_check.py path/to/OpenEWLD/dataset
    python3 tools/leadsheet_check.py path/to/OpenEWLD/dataset --no-key

OpenEWLD (MIT; the scores themselves are public domain) is the corpus it was
written for: 502 Wikifonia lead sheets, 20,030 chord symbols.
"""
import sys, os, re, glob, zipfile, argparse, subprocess, collections
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_symbol import claimed, names_bass

STEP = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

#  The MusicXML 4.0 <kind> values, as semitones above the root. Two are voiced
#  as played rather than as written out in full: a dominant 11th leaves its
#  major third out, because it would clash with the eleventh, and a 13th leaves
#  out the eleventh for the same reason. Every chord book voices them that way.
KIND = {
    "major": {0, 4, 7}, "minor": {0, 3, 7}, "augmented": {0, 4, 8},
    "diminished": {0, 3, 6}, "dominant": {0, 4, 7, 10},
    "major-seventh": {0, 4, 7, 11}, "minor-seventh": {0, 3, 7, 10},
    "diminished-seventh": {0, 3, 6, 9}, "augmented-seventh": {0, 4, 8, 10},
    "half-diminished": {0, 3, 6, 10}, "major-minor": {0, 3, 7, 11},
    "major-sixth": {0, 4, 7, 9}, "minor-sixth": {0, 3, 7, 9},
    "dominant-ninth": {0, 2, 4, 7, 10}, "major-ninth": {0, 2, 4, 7, 11},
    "minor-ninth": {0, 2, 3, 7, 10},
    "dominant-11th": {0, 2, 5, 7, 10},            # no third, as played
    "major-11th": {0, 2, 4, 5, 7, 11}, "minor-11th": {0, 2, 3, 5, 7, 10},
    "dominant-13th": {0, 2, 4, 7, 9, 10},         # no eleventh, as played
    "major-13th": {0, 2, 4, 7, 9, 11}, "minor-13th": {0, 2, 3, 7, 9, 10},
    "suspended-second": {0, 2, 7}, "suspended-fourth": {0, 5, 7},
    "power": {0, 7},
    #  Not MusicXML kinds, but written by the editor Wikifonia used. Their
    #  meaning is unambiguous from the name, so they are read rather than
    #  dropped: minor-major is the major-minor kind, augmented-ninth is 9#5.
    "minor-major": {0, 3, 7, 11}, "augmented-ninth": {0, 2, 4, 8, 10},
    "maj69": {0, 2, 4, 7, 9},
}

#  A degree's natural position. 7 is the dominant seventh: that is how every
#  lead-sheet editor writes "7sus" (a suspended-fourth kind with 7 added), and
#  the 73 cases in OpenEWLD all carry text "7sus" or "9sus".
DEGREE = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 10, 9: 2, 11: 5, 13: 9}

FIFTHS_MAJOR = {0: "C", 1: "G", 2: "D", 3: "A", 4: "E", 5: "B", 6: "F#", 7: "C#",
                -1: "F", -2: "Bb", -3: "Eb", -4: "Ab", -5: "Db", -6: "Gb", -7: "Cb"}
FIFTHS_MINOR = {0: "A", 1: "E", 2: "B", 3: "F#", 4: "C#", 5: "G#", 6: "D#", 7: "A#",
                -1: "D", -2: "G", -3: "C", -4: "F", -5: "Bb", -6: "Eb", -7: "Ab"}


def pitch(el, prefix):
    step = el.findtext(prefix + "-step")
    if not step:
        return None
    return (STEP[step.strip()] + int(float(el.findtext(prefix + "-alter") or 0))) % 12


def realise(h):
    """(root, pitch classes, bass, written) for one <harmony>, or a reason it was skipped."""
    r = h.find("root")
    k = h.find("kind")
    if r is None or k is None:
        return "no root or kind"
    root = pitch(r, "root")
    if root is None:
        return "no root"
    kind = (k.text or "").strip()
    if kind not in KIND:
        return "kind " + (kind or "empty")
    ivs = set(KIND[kind])
    for d in h.findall("degree"):
        try:
            value = int(d.findtext("degree-value"))
            alter = int(float(d.findtext("degree-alter") or 0))
        except (TypeError, ValueError):
            return "unreadable degree"
        kind_of = (d.findtext("degree-type") or "").strip()
        if value not in DEGREE:
            return "degree %d" % value
        natural = DEGREE[value]
        if kind_of == "add":
            ivs.add((natural + alter) % 12)
        elif kind_of == "alter":
            #  An alteration replaces whichever form of that degree the kind
            #  already has; for a fifth that is 7, for a ninth 2.
            ivs.discard(natural)
            ivs.add((natural + alter) % 12)
        elif kind_of == "subtract":
            ivs.discard((natural + alter) % 12)
        else:
            return "degree type " + kind_of
    pcs = {(root + i) % 12 for i in ivs}
    chord = frozenset(pcs)          # before any slash bass is added
    b = h.find("bass")
    bass = pitch(b, "bass") if b is not None else root
    if bass is None:
        bass = root
    pcs.add(bass)
    written = (k.get("text") or kind)
    return root, frozenset(pcs), bass, written, kind, chord


def voicing(pcs, bass):
    """Bass lowest, everything else in close position above it - the generator
    CLAUDE.md warns about, written the way it says: every upper note relative to
    the bass, so no pitch class can repeat."""
    notes = [48 + bass] + [60 + bass + ((pc - bass) % 12) for pc in sorted(pcs) if pc != bass]
    assert len({n % 12 for n in notes}) == len(notes) == len(pcs)
    return tuple(sorted(notes))


def songs(directory):
    for f in sorted(glob.glob(directory + "/**/*.mxl", recursive=True)):
        z = zipfile.ZipFile(f)
        name = [n for n in z.namelist() if n.endswith(".xml") and not n.startswith("META")][0]
        yield f, ET.fromstring(z.read(name))


def key_of(tree):
    k = tree.find(".//key")
    if k is None or k.findtext("fifths") is None:
        return None
    fifths = int(k.findtext("fifths"))
    minor = (k.findtext("mode") or "").strip() == "minor"
    table = FIFTHS_MINOR if minor else FIFTHS_MAJOR
    if fifths not in table:
        return None
    return table[fifths] + (" Minor (Natural)" if minor else " Major")


def run(script, key, voicings):
    args = ["lua5.4", os.path.join(HERE, "runner.lua"), script] + ([key] if key else [])
    inp = "\n".join(" ".join(map(str, v)) for v in voicings) + "\n"
    out = subprocess.run(args, input=inp, capture_output=True, text=True, check=True)
    names = [line.split("\t")[1] for line in out.stdout.splitlines()]
    if len(names) != len(voicings):
        sys.exit(f"runner returned {len(names)} names for {len(voicings)} voicings")
    return dict(zip(voicings, names))


def symmetric(pcs):
    return any(all(((p + t) % 12) in pcs for p in pcs) for t in range(1, 12))


def root_of(symbol):
    sym, _, bass = symbol.rpartition("/")
    if not sym or not re.match(r'^[A-G](?:[#b]+|x)?$', bass):
        sym = symbol
    m = re.match(r'^([A-G])((?:[#b]+|x)?)', sym)
    if not m:
        return None
    return (STEP[m.group(1)] + m.group(2).count("#") - m.group(2).count("b")
            + (2 if m.group(2) == "x" else 0)) % 12


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("directory")
    ap.add_argument("--script", default=os.path.join(HERE, "..", "reascripts", "ScaleView Pro.lua"))
    ap.add_argument("--no-key", action="store_true", help="name everything with no scale selected")
    ap.add_argument("--examples", type=int, default=25)
    args = ap.parse_args()

    rows, skipped, nfiles = [], collections.Counter(), 0
    for f, tree in songs(args.directory):
        nfiles += 1
        key = None if args.no_key else key_of(tree)
        for h in tree.iter("harmony"):
            got = realise(h)
            if isinstance(got, str):
                skipped[got] += 1
                continue
            root, pcs, bass, written, kind, chord = got
            rows.append({"key": key, "root": root, "pcs": pcs, "bass": bass, "chord": chord,
                         "written": written, "kind": kind, "notes": voicing(pcs, bass)})

    by_key = collections.defaultdict(set)
    for r in rows:
        by_key[r["key"]].add(r["notes"])
    named = {}
    for key, vs in by_key.items():
        vs = sorted(vs)
        for v, n in run(args.script, key, vs).items():
            named[(key, v)] = n

    total = exact = same_root = spelled = 0
    distinct, distinct_exact, distinct_root = set(), set(), set()
    misses = collections.Counter()
    example = {}
    classes = collections.Counter()
    for r in rows:
        got = named[(r["key"], r["notes"])]
        total += 1
        played = set(r["pcs"])
        c = claimed(got)
        fits = (c is not None and not (c[0] - played) and not (played - (c[0] | c[1]))
                and names_bass(got, r["notes"]))
        exact += fits
        shape = (r["kind"], r["written"], tuple(sorted((p - r["root"]) % 12 for p in played)),
                 (r["bass"] - r["root"]) % 12)
        distinct.add(shape)
        if fits:
            distinct_exact.add(shape)
        if " " in got:
            spelled += 1
        ok_root = root_of(got) == r["root"]
        same_root += ok_root
        if ok_root:
            distinct_root.add(shape)
        else:
            if symmetric(played):
                why = "symmetric set - no root derivable"
            elif r["bass"] not in r["chord"]:
                why = "slash over a bass outside the chord"
            elif r["bass"] != r["root"]:
                why = "inversion"
            else:
                why = "root position"
            classes[why] += 1
            sig = (why, r["kind"], r["written"], tuple(sorted((p - r["root"]) % 12 for p in played)),
                   (r["bass"] - r["root"]) % 12)
            misses[sig] += 1
            example.setdefault(sig, (NOTE[r["root"]], got, " ".join(NOTE[n % 12] for n in r["notes"]), r["key"]))

    print(f"{nfiles} lead sheets, {total} chord symbols read"
          f" ({sum(skipped.values())} skipped: {dict(skipped)})")
    print(f"  distinct chord shapes (kind, text, notes, bass)  : {len(distinct)}")
    print(f"  symbol accounts for exactly the notes, right bass : "
          f"{100*exact/total:8.3f}%  ({exact}/{total}; distinct {len(distinct_exact)}/{len(distinct)})")
    print(f"  read out as notes rather than named               : {spelled}")
    print(f"  names the arranger's root                         : "
          f"{100*same_root/total:8.3f}%  ({same_root}/{total}; distinct {len(distinct_root)}/{len(distinct)})")
    for why, n in classes.most_common():
        print(f"      root differs - {why:38}: {n}")
    if args.examples:
        print("\n  where the root differs, commonest first:")
        for sig, n in misses.most_common(args.examples):
            why, kind, written, _, _ = sig
            root, got, notes, key = example[sig]
            print(f"    x{n:<4} {why:36} written {root}{written:10} -> {got:16} {notes:22} [{key}]")


if __name__ == "__main__":
    main()
