"""Chordify every score in music21's core corpus and collect the distinct
vertical sonorities. music21 is the file reader only - nothing here asks it to
name a chord."""
import os, sys, json, collections, traceback
from multiprocessing import Pool
OUT = os.environ.get("SCAN_OUT", "corpus_parts")
os.makedirs(OUT, exist_ok=True)

def collection_of(path):
    return str(path).split("corpus/")[-1].split("/")[0]

def scan(path):
    from music21 import converter
    try:
        sc = converter.parse(path)
    except Exception:
        return (str(path), None, "parse failed")
    try:
        counts = collections.Counter()
        for c in sc.chordify().recurse().getElementsByClass('Chord'):
            ns = tuple(sorted({int(round(p.midi)) for p in c.pitches}))
            if len(ns) >= 2: counts[ns] += 1
        return (str(path), counts, None)
    except Exception:
        return (str(path), None, "chordify failed")

if __name__ == "__main__":
    from music21 import corpus
    paths = [str(p) for p in corpus.getCorePaths()]
    start = int(sys.argv[1]); stop = min(int(sys.argv[2]), len(paths))
    chunk = paths[start:stop]
    totals = collections.Counter()
    percol = collections.defaultdict(collections.Counter)
    failed = collections.Counter()
    done = 0
    with Pool(4) as pool:
        for path, counts, err in pool.imap_unordered(scan, chunk, chunksize=4):
            done += 1
            col = collection_of(path)
            if err: failed[err] += 1; continue
            for k, v in counts.items():
                totals[k] += v
                percol[col][k] += v
            if done % 200 == 0:
                print("  %d/%d  distinct so far %d" % (done, len(chunk), len(totals)), flush=True)
    json.dump({" ".join(map(str, k)): v for k, v in totals.items()},
              open("%s/part_%d_%d.json" % (OUT, start, stop), "w"))
    json.dump({c: {" ".join(map(str, k)): v for k, v in d.items()} for c, d in percol.items()},
              open("%s/percol_%d_%d.json" % (OUT, start, stop), "w"))
    print("chunk %d-%d done: %d sonorities, %d distinct, failures %s"
          % (start, stop, sum(totals.values()), len(totals), dict(failed)), flush=True)
