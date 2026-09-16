#!/usr/bin/env python3
"""Pair every vertical sonority in an annotated corpus with the chord a human
analyst wrote over it, and save the pairs for `score_labels.py`.

Two corpora, two formats, one output shape:

  dcml  <dir>  DCML's annotated corpora (CC BY-NC-SA). Reads notes/*.tsv beside
               harmonies/*.tsv, which share a quarterbeats timeline, so the
               join needs no alignment guesswork. DCML writes chord_tones, root
               and bass_note as steps on the line of fifths relative to the
               LOCAL key's tonic, and localkey is itself a numeral relative to
               the global key; both conversions are done here and both were
               validated against labels whose answer is known from the numeral
               alone (F minor i = F Ab C, C major V2 = G B D F over F).

  wir   <dir>  When in Rome (CC BY-SA). Reads score.mxl and analysis.txt with
               music21 and matches them by (measure number, beat) rather than
               by offset: they are separate streams, and an anacrusis or a
               repeat makes absolute offsets drift while measure numbering
               stays honest.

Each pair records the notes, the analyst's root and bass, the label, and
whether the WHOLE labelled chord is sounding in that slice - which is the
filter that makes the comparison fair, since a slice inside a labelled span
often holds only part of the chord.
"""
import sys, os, re, csv, glob, json, argparse, collections, warnings
from fractions import Fraction

LETTER = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
MAJOR, MINOR = [0, 2, 4, 5, 7, 9, 11], [0, 2, 3, 5, 7, 8, 10]
NUMERAL = {"I": 1, "II": 2, "III": 3, "IV": 4, "V": 5, "VI": 6, "VII": 7}


def frac(s):
    s = (s or "").strip()
    if not s:
        return None
    try:
        return Fraction(s)
    except Exception:
        try:
            return Fraction(float(s))
        except Exception:
            return None


def key_pc(name):
    m = re.match(r'^([A-Ga-g])([#b]*)$', (name or "").strip())
    if not m:
        return None
    pc = LETTER[m.group(1).upper()] + m.group(2).count("#") - m.group(2).count("b")
    return pc % 12


def local_tonic(global_pc, global_minor, localkey):
    """Pitch class of the local tonic, from a numeral relative to the global key."""
    m = re.match(r'^([#b]*)([ivxIVX]+)', (localkey or "").strip())
    if not m:
        return None
    acc = m.group(1).count("#") - m.group(1).count("b")
    degree = NUMERAL.get(m.group(2).upper())
    if not degree:
        return None
    return (global_pc + (MINOR if global_minor else MAJOR)[degree - 1] + acc) % 12


def dcml_labels(path):
    rows = []
    with open(path, newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh, delimiter="\t"):
            on, dur = frac(r.get("quarterbeats")), frac(r.get("duration_qb"))
            if on is None or dur is None or dur <= 0:
                continue
            gpc = key_pc(r.get("globalkey"))
            if gpc is None:
                continue
            tonic = local_tonic(gpc, str(r.get("globalkey_is_minor")) == "1", r.get("localkey"))
            if tonic is None or not r.get("root") or not r.get("bass_note"):
                continue
            tones = [x for x in (r.get("chord_tones") or "").replace(" ", "").split(",") if x]
            added = [x for x in (r.get("added_tones") or "").replace(" ", "").split(",") if x]
            if not tones:
                continue
            try:
                pcs = {(tonic + 7 * int(f)) % 12 for f in tones + added}
                root = (tonic + 7 * int(r["root"])) % 12
                bass = (tonic + 7 * int(r["bass_note"])) % 12
            except ValueError:
                continue
            rows.append((on, on + dur, pcs, root, bass, r.get("chord", "")))
    rows.sort()
    return rows


def dcml_sonorities(path):
    """Segment at every onset and take what is sounding - what chordify does."""
    events = []
    with open(path, newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh, delimiter="\t"):
            on, dur, midi = frac(r.get("quarterbeats")), frac(r.get("duration_qb")), r.get("midi")
            if on is None or dur is None or not midi or dur <= 0:
                continue
            try:
                events.append((on, on + dur, int(float(midi))))
            except ValueError:
                continue
    out = []
    for t in sorted({e[0] for e in events}):
        sounding = {m for (s, e, m) in events if s <= t < e}
        if len(sounding) >= 3:
            out.append((t, tuple(sorted(sounding))))
    return out


def collect_dcml(root_dir):
    pairs = []
    repos = sorted(d for d in glob.glob(f"{root_dir}/*") if os.path.isdir(f"{d}/harmonies"))
    for repo in repos:
        for harm in sorted(glob.glob(f"{repo}/harmonies/*.tsv")):
            notes = f"{repo}/notes/" + os.path.basename(harm).replace(".harmonies.", ".notes.")
            if not os.path.exists(notes):
                continue
            try:
                labels, sons = dcml_labels(harm), dcml_sonorities(notes)
            except Exception:
                continue
            i = 0
            for t, sounding in sons:
                while i < len(labels) and labels[i][1] <= t:
                    i += 1
                if i >= len(labels) or labels[i][0] > t:
                    continue
                _, _, pcs, root, bass, chord = labels[i]
                played = {m % 12 for m in sounding}
                if len(played) < 3 or (played - pcs):
                    continue
                pairs.append({"notes": list(sounding), "root": root, "bass": bass,
                              "chord": chord, "full": sorted(played) == sorted(pcs),
                              "source": os.path.basename(repo)})
        print(f"  {os.path.basename(repo)}: {len(pairs)} pairs so far", flush=True)
    return pairs


def _wir_one(pair):
    from music21 import converter, roman, chord as m21chord
    score_f, analysis_f = pair
    try:
        analysis = converter.parse(analysis_f, format="romanText")
        score = converter.parse(score_f).chordify()
    except Exception as e:
        return (type(e).__name__, [])
    by_measure = collections.defaultdict(list)
    for rn in analysis.recurse().getElementsByClass(roman.RomanNumeral):
        try:
            by_measure[rn.measureNumber].append((float(rn.beat), rn))
        except Exception:
            continue
    for m in by_measure:
        by_measure[m].sort(key=lambda x: x[0])
    out = []
    for ch in score.recurse().getElementsByClass(m21chord.Chord):
        here = by_measure.get(ch.measureNumber)
        if not here:
            continue
        try:
            beat = float(ch.beat)
        except Exception:
            continue
        active = [rn for b, rn in here if b <= beat + 1e-6]
        if not active:
            continue
        rn = active[-1]
        notes = sorted({p.midi for p in ch.pitches})
        played = {n % 12 for n in notes}
        if len(played) < 3:
            continue
        rn_pcs = {p.pitchClass for p in rn.pitches}
        if played - rn_pcs:
            continue
        try:
            root, bass = rn.root().pitchClass, rn.bass().pitchClass
        except Exception:
            continue
        out.append({"notes": notes, "root": root, "bass": bass, "chord": rn.figure,
                    "full": sorted(played) == sorted(rn_pcs),
                    "source": os.path.basename(os.path.dirname(score_f))})
    return (None, out)


def collect_wir(root_dir, workers=4):
    from multiprocessing import Pool
    warnings.filterwarnings("ignore")
    scores = []
    for a in sorted(glob.glob(f"{root_dir}/Corpus/**/analysis.txt", recursive=True)):
        s = os.path.join(os.path.dirname(a), "score.mxl")
        if os.path.exists(s):
            scores.append((s, a))
    print(f"  {len(scores)} scores with a human analysis beside them", flush=True)
    pairs, failed = [], collections.Counter()
    with Pool(workers) as pool:
        for n, (err, rows) in enumerate(pool.imap_unordered(_wir_one, scores), 1):
            if err:
                failed[err] += 1
            else:
                pairs += rows
            if n % 50 == 0:
                print(f"  {n}/{len(scores)}  pairs {len(pairs)}", flush=True)
    print(f"  {sum(failed.values())} scores unreadable: {dict(failed)}", flush=True)
    return pairs


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("corpus", choices=["dcml", "wir"])
    ap.add_argument("directory")
    ap.add_argument("out")
    args = ap.parse_args()
    rows = collect_dcml(args.directory) if args.corpus == "dcml" else collect_wir(args.directory)
    json.dump(rows, open(args.out, "w"))
    print(f"DONE {len(rows)} pairs -> {args.out}")
