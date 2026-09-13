"""Reads a printed chord symbol back into the notes it claims, from music
theory alone - nothing here knows how ScaleView works. If the set it produces
is not exactly the set that was played, the symbol is wrong."""
import re
LETTER = {"C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11}

def note_pc(name):
    m = re.match(r'^([A-G])([#b]*|x)$', name)
    if not m: return None
    pc = LETTER[m.group(1)]
    acc = m.group(2)
    if acc == "x": pc += 2
    else:
        pc += acc.count("#") - acc.count("b")
    return pc % 12

def intervals(q):
    """Intervals above the root that the quality string claims."""
    iv, no3, lower, thirdOptional = {0}, False, set(), False
    # A bracketed group lists degrees the number did not account for, and they
    # are definitely present: Cm7(11), C7(13), C7(11,13).
    DEGREE = {"9": 2, "11": 5, "13": 9}
    for grp in re.findall(r'\(([0-9,]+)\)', q):
        for d in grp.split(","):
            if d not in DEGREE: return None
            iv.add(DEGREE[d])
    q = re.sub(r'\([0-9,]+\)', '', q)
    if q.endswith("(no3)"):
        no3, q = True, q[:-5]
    third, fifth, seventh, sixth = 4, 7, None, False

    def take(*opts):
        nonlocal q
        for o in opts:
            if q.startswith(o):
                q = q[len(o):]
                return o
        return None

    if take("dim7"):   third, fifth, seventh = 3, 6, 9
    elif take("dim"):  third, fifth = 3, 6
    elif take("aug"):  third, fifth = 4, 8
    elif take("min"):
        third = 3
        if take("Maj"): seventh = 11
    elif take("maj"):  seventh = 11

    n = take("13", "11", "9", "7", "6/9", "6", "5")
    if n == "5":
        if q: return None
        return {0, 7}, set()
    #  The number names the HIGHEST extension; the ones below it are implied
    #  but optional, which is what C13 means whether or not the 11th is played.
    lower = set()
    if n == "6/9":  sixth, iv = True, iv | {2}
    elif n == "6":  sixth = True
    elif n:
        if seventh is None: seventh = 10
        if n == "9":  iv |= {2}
        #  A plain eleventh chord leaves the major third out - it would clash
        #  with the eleventh - so the third is optional rather than required.
        if n == "11": iv |= {5}; lower |= {2}; thirdOptional = (third == 4)
        if n == "13": iv |= {9}; lower |= {2, 5}
    elif seventh == 11:
        return None                      # a bare "maj" is not a symbol

    #  sus#4 is tried first: it is a longer token than sus4 and does not
    #  start with it, but keeping them together says they are one family.
    if take("sus#4"): third = 6
    elif take("sus4"): third = 5
    elif take("sus2"): third = 2

    while q:
        t = take("b5", "#5", "(b5)", "(#5)",
                 "add#11", "Add#11", "addb9", "Addb9", "add#9", "Add#9",
                 "addb13", "Addb13", "addb6", "Addb6", "add9", "Add9",
                 "add11", "Add11",
                 "add13", "Add13", "add6", "(add6)",
                 "b9", "#9", "#11", "b13", "b6", "(maj7)", "sus4", "sus2")
        if t is None: return None
        t = t.strip("()").lower()
        if t.startswith("add"): t = t[3:] or "6"
        if   t == "b5":  fifth = 6
        elif t == "#5":  fifth = 8
        elif t == "b9":  iv |= {1}
        elif t == "9":   iv |= {2}
        elif t == "#9":  iv |= {3}
        elif t == "11":  iv |= {5}
        elif t == "#11": iv |= {6}
        elif t == "b13": iv |= {8}
        elif t == "b6":  iv |= {8}
        elif t == "maj7": iv |= {11}
        elif t == "13":  iv |= {9}
        elif t == "6":   sixth = True
        elif t == "sus4": third = 5
        elif t == "sus2": third = 2

    if not no3:
        (lower if thirdOptional else iv).add(third)
    if fifth != 7: iv |= {fifth}
    if seventh is not None: iv |= {seventh}
    if sixth: iv |= {9}
    return iv, lower | ({7} if fifth == 7 else set())

def claimed(symbol):
    """The pitch classes a symbol claims, and the bass it names, or None."""
    #  Split on the LAST slash, and only when what follows it is a note name -
    #  a 6/9 chord has a slash of its own, and it can also be inverted, so
    #  "C6/9/D" is a six-nine on C with a D underneath.
    sym, _, bass = symbol.rpartition("/")
    if not sym or not re.match(r'^[A-G](?:[#b]+|x)?$', bass):
        sym, bass = symbol, ""
    m = re.match(r'^([A-G](?:[#b]+|x)?)(.*)$', sym)
    if not m: return None
    root = note_pc(m.group(1))
    if root is None: return None
    got = intervals(m.group(2))
    if got is None: return None
    need, opt = got
    return ({(root + i) % 12 for i in need},
            {(root + i) % 12 for i in opt},
            note_pc(bass) if bass else root)
