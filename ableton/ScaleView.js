/* ScaleView - built by ableton/kit/build.py from ableton/device.json. Do not edit; edit the sources and rebuild. */
var DEVICE = {"main": "ScaleView Pro.lua", "size": [200, 100], "title": "ScaleView"};
DEVICE.files = {"ScaleView Pro.lua": "--[[\n * ReaScript Name: ScaleView Pro\n * Description:    The twelve pitch classes drawn as circles - five black keys\n *                 on the top row over seven white keys on the bottom - with\n *                 the notes of the selected scale lit, the notes you play\n *                 ringed, and the chord you are holding named underneath.\n *\n *                 Note names are spelled for the key: each degree of a\n *                 seven-note scale takes the next letter of the alphabet and\n *                 whatever accidental that letter needs, so C# major reads\n *                 C# D# E# F# G# A# B# while Db major - the same seven notes -\n *                 reads Db Eb F Gb Ab Bb C.\n *\n *                 The chord is read rather than looked up. The third, fifth\n *                 and seventh give the quality, and whatever is left over is\n *                 described as sixths, ninths, elevenths and thirteenths, so\n *                 a voicing nobody thought to tabulate still comes out with a\n *                 name. Where two readings fit, the one with a complete triad\n *                 in it wins, and the odd notes hang off that.\n *\n *                 \"Simplify Note Names\" in the options menu turns that off\n *                 and names every note the way a piano key is named: sharps for\n *                 the black keys, and no double accidentals, so Bbb reads A and\n *                 Cb reads B. This is ScaleView Simple's naming, and the two\n *                 scripts merged into this one.\n * Instructions:   Run the script and play.\n *                 Click a circle for the scale list, click anywhere else for\n *                 a random scale and display options. Either mouse button\n *                 does the same thing.\n *                 Press S or Return for the scale list, O for the options,\n *                 D to dock/undock, Esc or the window close box to exit.\n * Author:         kallums\n * Version:        1.3.0\n * Provides:       [main] .\n--]]\n\n------------------------------------------------------------------------------\n-- Configuration\n------------------------------------------------------------------------------\n\nlocal SCRIPT_NAME  = \"ScaleView Pro\"\nlocal EXT_SECTION  = \"ScaleViewPro\"\n\n-- Read only when this script has no settings of its own, so the scale, colour,\n-- window position and dock state survive the rename. The long tail of earlier\n-- sections was dropped with it: the script had one user, whose settings had\n-- already been migrated into the key below.\nlocal EXT_LEGACY   = {\"kallums_ScaleViewAlt2\"}\n\nlocal MIN_TEXT        = 10   -- points: Apple's smallest text on the Mac (decision 0013)\nlocal MIN_NAME_RADIUS = 9    -- a circle this small still holds \"Bbb\" at MIN_TEXT\nlocal FACE            = \"Arial\"  -- the system's own face once the window is open: pickFace()\nlocal DEFAULT_W    = 200\nlocal DEFAULT_H    = 100\n\n-- Colours are 0..1 RGB triplets, tweak to taste.\nlocal COLOR_BG        = {0.1375, 0.1532, 0.1806}  -- icon background, #23272e\nlocal COLOR_OFF       = {0.2275, 0.2510, 0.2902}  -- note not in the selected scale, #3A404A\nlocal COLOR_EDGE      = {0.4275, 0.4588, 0.5059}  -- rim of an unlit circle, #6D7581: 3.2:1 on the background (decision 0013)\nlocal COLOR_LABEL     = {0.7492, 0.7727, 0.8080}  -- scale name text, #BFC5CE\nlocal COLOR_TEXT_OFF  = {0.8667, 0.8824, 0.9059}  -- note name on an unlit circle, #DDE1E7: 8.0:1 (decision 0013)\nlocal COLOR_TEXT_ON   = {0.0786, 0.0904, 0.1100}  -- note name on a lit circle, #14171c\nlocal COLOR_HELD      = {1.00, 0.9492, 0.0000}  -- ring around a played note, always, #FFF200\nlocal COLOR_CHORD     = {0.9492, 0.9570, 0.9688}  -- chord name, brighter than a scale name, #F2F4F7\n\n--[[  Chord analysis, built rather than looked up.\n\n  A chord symbol has two halves. The bottom half - third, fifth and seventh -\n  is a closed vocabulary: those three can only combine so many ways, and each\n  combination has a name musicians agree on. That half is a table, ordered by\n  how common the quality is.\n\n  The top half - sixths, ninths, elevenths, thirteenths and their alterations -\n  is not closed, so it is described rather than matched. Whatever the bottom\n  half did not account for is read off as an extension, which is why a voicing\n  nobody thought to tabulate still comes out with a name.\n]]\n\n-- How exceptional each core quality is. Lower is commoner, and the whole\n-- reading is chosen by adding this to what the extensions cost, so a plain\n-- triad in an inversion beats an outlandish chord in root position.\nlocal CORE_RANK = {\n  [\"maj/P/none\"]  =  1, [\"min/P/none\"]  =  2,\n  [\"maj/P/b7\"]    =  3, [\"min/P/b7\"]    =  4, [\"maj/P/maj7\"] =  5,\n  [\"min/b/b7\"]    =  6, [\"min/b/bb7\"]   =  7, [\"min/b/none\"] =  8,\n  [\"maj/#/none\"]  =  9,\n  [\"sus4/P/none\"] = 10, [\"sus2/P/none\"] = 11,\n  [\"min/P/maj7\"]  = 12,\n  [\"maj/#/b7\"]    = 13, [\"maj/b/b7\"]    = 14, [\"maj/#/maj7\"] = 15,\n  --[[  maj7b5 belongs in this list and was missing from it. The note above\n      says every altered fifth carrying a seventh that musicians play is named\n      here - 7b5, aug7, min7b5, maj7#5 - and players write maj7b5 constantly,\n      as the Lydian tonic. Without it the quality paid RANK_UNNAMED plus\n      RANK_TWICE_ODD, 37 before any slash, and lost to readings with no third\n      in them at all: D D# G A read Dsus4b9 rather than D#maj7b5/D. ]]\n  [\"maj/b/maj7\"]  = 16,\n  [\"sus4/P/b7\"]   = 17, [\"sus2/P/b7\"]   = 18,\n  [\"sus4/P/maj7\"] = 19, [\"sus2/P/maj7\"] = 20,\n\n  --[[  A missing third is a different chord, not a thinner one, so these sit\n      well below anything with a third in it.\n\n      Below, and by more than a slash costs. A third-less shape with a perfect\n      fifth is a real voicing - a seventh over a bare fifth is what a guitarist\n      plays - but one whose fifth is *also* altered is odd twice over, exactly\n      as RANK_TWICE_ODD has it for the qualities that keep their third. Those\n      two sit past COST_INVERSION from an unnamed quality with a third in it\n      (25), so D E A# reads Bb(b5)/E rather than E7b5(no3), the same way F A B\n      reads F(b5) rather than B7b5(no3). The perfect-fifth pair are left where\n      they were, which is what keeps C G Bb reading C7(no3). ]]\n  [\"none/P/b7\"]   = 30, [\"none/P/maj7\"] = 31, [\"none/P/none\"] = 34,\n  [\"none/b/maj7\"] = 41, [\"none/b/b7\"]   = 42,\n}\n\n--[[  A quality the table does not name is still ranked by the interval that\n    decides most about a chord: the third. A real third - major or minor -\n    keeps a chord readable however odd the rest of it is, so F A B reads\n    F(b5) rather than losing to B7b5(no3), which has no third in it at all.\n    A suspension is not a third but a stand-in for one, and a shape with\n    neither is the last thing to reach for. ]]\nlocal RANK_UNNAMED   = {maj = 25, min = 25, sus4 = 70, sus2 = 70, none = 90}\n--[[  Except that a third only excuses one oddity. Every altered fifth carrying\n    a seventh that musicians actually play is named in the table above - 7b5,\n    aug7, min7b5, maj7#5 - so a combination that is not there is strange twice\n    over, and should not win on the strength of its third alone. Without this\n    C D Eb Gb Cb read CminMaj9b5. ]]\nlocal RANK_TWICE_ODD =  12\n--[[  A missing fifth is never spoken, but it is not equally unremarkable. A\n    seventh chord is routinely voiced without one - that is the standard shell -\n    while a triad with no fifth is two notes and a guess, so the two are\n    charged differently. ]]\nlocal RANK_NO_FIFTH  =  20  -- a triad that has lost its fifth\nlocal RANK_NO_FIFTH7 =   4  -- a seventh chord voiced as a shell\nlocal RANK_ELEVENTH  =   6  -- a sus4 carrying a seventh and a ninth: C11\nlocal COST_INVERSION =  14  -- naming the bass after a slash\nlocal COST_NATURAL   =   1  -- a ninth/eleventh/thirteenth the number implies\nlocal COST_ADD       =   2  -- one that has to be spelled out as an add\nlocal COST_CLASH     =   6  -- a natural eleventh fighting a major third\nlocal COST_ALTERED   =   5  -- b9, #9, #11, b13 colouring a plain chord\n--[[  An alteration that does not belong to the chord it is sitting on costs\n    far more, because it usually means the root has been guessed wrong and the\n    notes belong to some plainer chord standing on one of the others. A b9, a\n    #9 and a b13 are the dominant's alterations: over a minor seventh or a\n    plain triad they are not colours a musician hears. A sharpened eleventh is\n    the exception - it is at home on almost anything with a perfect fifth -\n    and any alteration over a fifth that is already altered is suspect. ]]\nlocal COST_CLASHING  =  18\n--[[  A suspension replaces the third rather than decorating it, so it does not\n    carry added tones. \"sus4 add6 add9\" is not a chord anybody writes; those\n    notes are an inversion of something with a third in it. ]]\nlocal COST_SUS_EXTRA =  12\nlocal COST_SIXTH     =   4  -- enough that C E A stays Amin/C\n--[[  A minor sixth is charged one more than any other, because it is the one\n    sixth that is also something else: A C E F# is Amin6 and it is equally the\n    half-diminished on its third, F#min7b5. Those two readings tie exactly at\n    4, and the half-diminished is the name Scaler prints, the name jazznet's\n    labels carry, and the name some 880 analyst labels across DCML and When in\n    Rome give it. One point settles the tie without touching any other sixth. ]]\nlocal COST_MIN_SIXTH =   5\n\n--[[  Reading the intervals present into a third, a fifth and a seventh.\n\n    Where both a flattened and a raised fifth are sounding, which one is *the*\n    fifth is a real choice and not a lookup, so `preferSharpFive` lets the\n    caller ask for the other reading and cost them both. C E F# G# B was named\n    Cmaj7b5b13 because the flattened fifth was taken greedily, leaving the G#\n    to be described as a b13 over a chord that is not at home with one; read\n    the other way round it is Cmaj7#5#11, which costs 14 less. ]]\nlocal function core(has, preferSharpFive)\n  local third, fifth, seventh\n  local used = {[0] = true}\n\n  if     has[4] then third, used[4] = \"maj\",  true\n  elseif has[3] then third, used[3] = \"min\",  true\n  elseif has[5] then third, used[5] = \"sus4\", true\n  elseif has[2] then third, used[2] = \"sus2\", true\n  else               third = \"none\" end\n\n  if has[7] then fifth, used[7] = \"P\", true\n  elseif has[6] and has[8] and preferSharpFive then fifth, used[8] = \"#\", true\n  elseif has[6] then fifth, used[6] = \"b\", true\n  elseif has[8] then fifth, used[8] = \"#\", true\n  else               fifth = \"none\" end\n\n  -- A diminished triad takes the 9 as a doubly flattened seventh.\n  if     has[10] then seventh, used[10] = \"b7\",   true\n  elseif has[11] then seventh, used[11] = \"maj7\", true\n  elseif third == \"min\" and fifth == \"b\" and has[9] then\n                      seventh, used[9]  = \"bb7\",  true\n  else                seventh = \"none\" end\n\n  return third, fifth, seventh, used\nend\n\n-- The name of a core quality. Most are built from their parts; the handful\n-- with names of their own are named.\nlocal SPECIAL = {\n  [\"min/b/none\"] = \"dim\",  [\"min/b/bb7\"]  = \"dim7\", [\"min/b/b7\"] = \"min7b5\",\n  [\"maj/#/none\"] = \"aug\",  [\"maj/#/b7\"]   = \"aug7\", [\"maj/#/maj7\"] = \"maj7#5\",\n  [\"maj/b/b7\"]   = \"7b5\",  [\"min/P/maj7\"] = \"minMaj7\", [\"min/none/maj7\"] = \"minMaj7\",\n}\n\nlocal function coreName(third, fifth, seventh)\n  local special = SPECIAL[third .. \"/\" .. fifth .. \"/\" .. seventh]\n  if special then return special end\n\n  local base = (third == \"min\" and \"min\") or (third == \"sus4\" and \"sus4\")\n            or (third == \"sus2\" and \"sus2\") or \"\"\n  local sev  = (seventh == \"b7\" and \"7\") or (seventh == \"bb7\" and \"dim7\")\n            or (seventh == \"maj7\" and (third == \"min\" and \"Maj7\" or \"maj7\")) or \"\"\n  local alt  = (fifth == \"b\" and \"b5\") or (fifth == \"#\" and \"#5\") or \"\"\n\n  -- Sevenths are written before a sus, not after it: 7sus4, never sus47.\n  local name = (third == \"sus4\" or third == \"sus2\") and (sev .. base)\n                                                     or (base .. sev)\n  name = name .. alt\n  -- A bare altered fifth has to be bracketed or the symbol reads as a note\n  -- name: C(b5) is a chord on C, Cb5 looks like one on C flat.\n  if name == alt and alt ~= \"\" then name = \"(\" .. alt .. \")\" end\n  return name\nend\n\nlocal function rankOf(third, fifth, seventh)\n  if fifth == \"none\" then\n    local rank = CORE_RANK[third .. \"/P/\" .. seventh] or RANK_UNNAMED[third]\n    return rank + (seventh == \"none\" and RANK_NO_FIFTH or RANK_NO_FIFTH7)\n  end\n  local rank = CORE_RANK[third .. \"/\" .. fifth .. \"/\" .. seventh]\n  if rank then return rank end\n  return RANK_UNNAMED[third] + (seventh ~= \"none\" and RANK_TWICE_ODD or 0)\nend\n\n-- What is left over once the core has taken its notes.\n-- interval -> {how it is written, whether it is an alteration, which degree}\nlocal EXTENSION = {\n  [1] = {\"b9\",  true},  [2] = {\"9\",  false, 9},  [3] = {\"#9\",  true},\n  [5] = {\"11\",  false, 11}, [6] = {\"#11\", true}, [8] = {\"b13\", true},\n}\n\nlocal function analyseAs(has, root, bass, preferSharpFive)\n  local third, fifth, seventh, used = core(has, preferSharpFive)\n  local rank = rankOf(third, fifth, seventh)\n  local name, cost = coreName(third, fifth, seventh), rank\n\n  local naturals, altered, sixth = {}, {}, false\n  local asEleventh = false  -- read as an 11 chord, so not a suspension at all\n  for i = 1, 11 do\n    if has[i] and not used[i] then\n      if i == 9 then\n        if seventh == \"none\" then sixth = true else naturals[13] = true end\n      else\n        local ext = EXTENSION[i]\n        if ext and ext[2] then altered[#altered + 1] = ext[1]\n        elseif ext then naturals[ext[3]] = true\n        else\n          -- Only 11 can arrive here: core() always takes 4, 7 and 10 when they\n          -- are present, and 9 was dealt with above. So this is the major\n          -- seventh left over when a flattened one took the seventh's place.\n          altered[#altered + 1] = \"maj7\"\n        end\n      end\n    end\n  end\n\n  if seventh ~= \"none\" and seventh ~= \"bb7\" then\n    --[[  With a seventh underneath, the highest natural extension names the\n        chord - but a stacked number claims everything under it, so it may only\n        be used when the ninth is actually being played. Hutchinson's chord\n        list (Music Theory for the 21st-Century Classroom, 31.4) prints Cm11\n        and Cm7(11) side by side, six noteheads against five: the first has the\n        ninth in it, the second does not. So a ninth that is not there is named\n        in brackets after the seventh instead of being swallowed by a number.\n\n        A natural eleventh over a major third is the other exception: it\n        clashes, so it is bracketed rather than promoted whatever else is\n        present. ]]\n    --[[  A ninth that has been altered still fills its place in the stack: the\n        same list prints C13sus(b9) with six noteheads, the b9 standing where\n        the natural ninth would. So a b9 or a #9 lets the number rise too. ]]\n    local ninth = naturals[9]\n    for _, token in ipairs(altered) do\n      if token == \"b9\" or token == \"#9\" then ninth = true end\n    end\n\n    local number\n    if ninth and naturals[13] then number = 13\n    elseif ninth and naturals[11] and third ~= \"maj\" then number = 11\n    elseif naturals[9] then number = 9 end\n\n    if third == \"sus4\" and seventh == \"b7\" and naturals[9]\n       and (fifth == \"P\" or fifth == \"none\") then\n      -- A sus4 carrying a seventh and a ninth is how an eleventh chord is\n      -- voiced - the third is left out precisely because it would clash with\n      -- the eleventh - so it is named as one rather than as a suspension.\n      name, number, asEleventh = \"11\", 11, true\n      naturals[11] = true\n      cost = RANK_ELEVENTH + (fifth == \"none\" and RANK_NO_FIFTH7 or 0)\n    elseif number then\n      name = name:gsub(\"7\", tostring(number), 1)\n    end\n\n    local spare = {}\n    for _, degree in ipairs({9, 11, 13}) do\n      if naturals[degree] then\n        local implied = number and degree <= number\n                        and not (degree == 11 and third == \"maj\")\n        if implied then cost = cost + COST_NATURAL\n        else\n          cost = cost + (degree == 11 and third == \"maj\" and COST_CLASH or COST_ADD)\n          spare[#spare + 1] = degree\n        end\n      end\n    end\n    -- Everything the number did not account for, bracketed as the chord lists\n    -- print it: Cm7(11), C7(13), C7(11,13).\n    if #spare > 0 then name = name .. \"(\" .. table.concat(spare, \",\") .. \")\" end\n  else\n    -- No seventh, so nothing stacks: everything above the triad is an add.\n    if sixth then\n      cost = cost + ((third == \"min\" and fifth == \"P\") and COST_MIN_SIXTH\n                                                        or COST_SIXTH)\n      --[[  The sixth stands where a seventh would, so the symbol is rebuilt\n          around it rather than having a 6 pasted on the end. An altered fifth\n          has to survive that: C Eb G# A is min6#5, and naming it Cmin6 claims\n          a perfect fifth that is not being played. ]]\n      local mark = (fifth == \"b\" and \"b5\") or (fifth == \"#\" and \"#5\") or \"\"\n      if naturals[9] and (third == \"maj\" or third == \"min\") then\n        naturals[9] = nil\n        name = (third == \"min\" and \"min6/9\" or \"6/9\") .. mark\n        cost = cost + COST_ADD\n      elseif third == \"min\"  then name = \"min6\" .. mark\n      elseif third == \"maj\"  then name = (fifth == \"#\" and \"aug6\") or (\"6\" .. mark)\n      elseif third == \"none\" then name = \"6\" .. mark\n      else name = name .. \"(add6)\" end\n    end\n    --[[  A diminished seventh carrying a ninth is a dim9, not a dim7 with a\n        note stuck on the end. The number rises the way it does under every\n        other seventh - the bb7 only sat in the \"no seventh\" branch here\n        because it is spelled as a sixth - and Cdim9 is what the chord lists\n        and Scaler both print. ]]\n    --  Only the spelling changes. It still costs what an added tone costs, so\n    --  which reading wins is untouched: this renames, it does not re-rank.\n    if seventh == \"bb7\" and naturals[9] then\n      naturals[9] = nil\n      name = name:gsub(\"dim7\", \"dim9\", 1)\n      cost = cost + COST_ADD\n    end\n    for _, degree in ipairs({9, 11, 13}) do\n      if naturals[degree] then\n        cost = cost + (degree == 11 and third == \"maj\" and COST_CLASH or COST_ADD)\n        name = name .. (name == \"\" and \"add\" or \"Add\") .. degree\n      end\n    end\n  end\n\n  --[[  An alteration is written straight onto the symbol - C7b9, Cmin#11 -\n      except where that would read as a note name. \"C#11\" is a chord on C#,\n      so a bare triad says add instead: Cadd#11. ]]\n  --[[  Alt 2 differs from Alt here, and only here. Alt asks whether an\n      alteration belongs to the chord under it, and only a dominant is at home\n      with a b9, a #9 or a b13. Alt 2 also accepts a complete triad - a real\n      third with a perfect fifth underneath it - which is what Scaler 3 does:\n      given the choice it names the chord that has a whole triad in it and\n      hangs the odd notes off that, rather than the thinner reading that needs\n      fewer of them. C D Eb Gb Cb is the case that separates them: Alt reads\n      D13b9/C, Alt 2 and Scaler read Cbaddb9#9/C. ]]\n  local dominant = third == \"maj\" and seventh == \"b7\"\n  local triad = (third == \"maj\" or third == \"min\") and fifth == \"P\"\n  for _, token in ipairs(altered) do\n    --[[  A b13 is excluded from the concession, and measurably so. It is the\n        one alteration whose note is almost always a chord tone of something\n        plainer: E G B with a C in it is Cmaj7 in first inversion, not Emin\n        wearing a b13. Letting a complete triad take one cost 207 misnamed\n        sonorities across the Bach chorales and 7 points of accuracy on\n        inverted jazz voicings, and bought nothing - the chord Alt 2 exists\n        for, Cb maj b9 #9, carries a b9 and a #9, not a b13. ]]\n    --[[  An altered fifth is no bar on a dominant standing on its own root.\n        A b9 or #9 over a b5 or #5 usually means the root has been guessed\n        wrong, but over a major third and a flat seventh with the root in the\n        bass it is the altered dominant - 7#5b9, 7b5#9, 7b9b13 - which every\n        lead sheet writes. Barring it read C7#5b9 as A#min9b5/C. Only from the\n        bass, because that is how the chord is played - the bass takes the\n        root, the hands take the alterations - and allowing it from an\n        inversion as well read F A C G C# over C as Aaug7#9/C, a #9 in the\n        bass, and moved 790 names in the sweep where this moves 455. ]]\n    local plainFifth = fifth ~= \"b\" and fifth ~= \"#\"\n    local athome = token ~= \"maj7\"\n                   and ((dominant and (plainFifth or root == bass))\n                        or (plainFifth and (token == \"#11\"\n                                            or (triad and token ~= \"b13\"))))\n\n    --[[  A flattened sixth is a b13 only when a seventh is under it. Without\n        one it is an added flat sixth, exactly as a natural sixth is a 6 rather\n        than a 13 - \"C#(add b6) means a C# major triad with the b6 added\"\n        (Hutchinson, Music Theory for the 21st-Century Classroom, 31.1-31.2).\n        Only the printed name changes: the cost still reads it as a b13, which\n        is what keeps E G B C reading Cmaj7/E rather than Emin wearing one. ]]\n    --[[  Both sevenths at once is a semitone cluster rather than a colour, and\n        it turns up in real music as a passing note against a seventh chord -\n        G B D F with an F# over it, 83 voicings across the Beethoven quartets\n        and the Chopin mazurkas. Bracket it, or the two seventh names run\n        together into \"G7maj7\", which is not a symbol anybody could read. ]]\n    local shown = (token == \"b13\" and seventh == \"none\") and \"b6\"\n                  or (token == \"maj7\" and \"(maj7)\") or token\n    cost = cost + (athome and COST_ALTERED or COST_CLASHING)\n    name = name .. ((name == \"\" and seventh == \"none\") and \"add\" or \"\") .. shown\n  end\n\n  if (third == \"sus4\" or third == \"sus2\") and not asEleventh then\n    local carried = #altered\n    for _, degree in ipairs({9, 11, 13}) do\n      if naturals[degree] then carried = carried + 1 end\n    end\n    if sixth then carried = carried + 1 end\n    cost = cost + carried * COST_SUS_EXTRA\n  end\n\n  --[[  A missing third is the one omission that has to be said out loud, and\n      it is said last, so the symbol reads as a chord with a note taken out of\n      it: maj7b5(no3), not maj7(no3)b5. A bare fifth with nothing above it is\n      the one chord that is only its root and fifth. ]]\n  if third == \"none\" then name = (name == \"\" and \"5\" or name .. \"(no3)\") end\n\n  if root ~= bass then cost = cost + COST_INVERSION end\n  -- Two readings can cost the same - Emin6 and C#min7b5 are the same four\n  -- notes - so the commoner quality settles it rather than the loop order.\n  return name, cost, rank\nend\n\n--[[  With both fifths sounding and no perfect one between them, neither is\n    obviously the fifth, so both readings are costed and the cheaper wins.\n    Everywhere else there is nothing to choose and the second reading is not\n    even built. ]]\nlocal function analyse(has, root, bass)\n  local name, cost, rank = analyseAs(has, root, bass, false)\n  if has[6] and has[8] and not has[7] then\n    local altName, altCost, altRank = analyseAs(has, root, bass, true)\n    if altCost < cost then return altName, altCost, altRank end\n  end\n  return name, cost, rank\nend\n\n-- Highlight colours offered in the menu. The first is the default.\n-- Keep these pale: the note names drawn on top of them are dark. There is\n-- deliberately nothing here that the ring around a played note could hide in.\n-- That ring is #FFF200, so the colour to keep out is a yellow. White is the\n-- nearest the palette comes, and reads 1.2:1 against it where the two touch -\n-- which is only the antialiased edge: both strokes sit outside the circle.\nlocal HIGHLIGHTS = {\n  {name = \"Teal\",        rgb = {0.20, 0.80, 0.62}},\n  {name = \"Orange\",      rgb = {0.98, 0.55, 0.15}},\n  {name = \"Light Green\", rgb = {0.55, 0.87, 0.40}},\n  {name = \"Light Blue\",  rgb = {0.40, 0.72, 0.98}},\n  {name = \"Light Pink\",  rgb = {0.98, 0.62, 0.78}},\n  {name = \"White\",       rgb = {1.00, 1.00, 1.00}},\n}\n\n------------------------------------------------------------------------------\n-- Musical data\n------------------------------------------------------------------------------\n\n-- Pitch classes: 0 = C ... 11 = B. These plain names are used for the notes\n-- that are *outside* the selected scale, where the key implies no spelling.\nlocal SHARP_NAMES = {\"C\", \"C#\", \"D\", \"D#\", \"E\", \"F\", \"F#\", \"G\", \"G#\", \"A\", \"A#\", \"B\"}\nlocal FLAT_NAMES  = {\"C\", \"Db\", \"D\", \"Eb\", \"E\", \"F\", \"Gb\", \"G\", \"Ab\", \"A\", \"Bb\", \"B\"}\n\n-- The seven letters and the pitch class each one names on its own.\nlocal LETTERS    = {\"C\", \"D\", \"E\", \"F\", \"G\", \"A\", \"B\"}\nlocal LETTER_PCS = {  0,   2,   4,   5,   7,   9,  11}\n\nlocal ACCIDENTALS = {[-2] = \"bb\", [-1] = \"b\", [0] = \"\", [1] = \"#\", [2] = \"x\"}\n\n-- Roots offered in the scale list: both spellings of every pitch class, plus\n-- Cb. C# major and Db major are the same seven notes spelled differently, so\n-- each needs its own entry. letter is an index into LETTERS.\nlocal ROOTS = {\n  {name = \"C\",  letter = 1, acc =  0},\n  {name = \"C#\", letter = 1, acc =  1},\n  {name = \"Db\", letter = 2, acc = -1},\n  {name = \"D\",  letter = 2, acc =  0},\n  {name = \"D#\", letter = 2, acc =  1},\n  {name = \"Eb\", letter = 3, acc = -1},\n  {name = \"E\",  letter = 3, acc =  0},\n  {name = \"F\",  letter = 4, acc =  0},\n  {name = \"F#\", letter = 4, acc =  1},\n  {name = \"Gb\", letter = 5, acc = -1},\n  {name = \"G\",  letter = 5, acc =  0},\n  {name = \"G#\", letter = 5, acc =  1},\n  {name = \"Ab\", letter = 6, acc = -1},\n  {name = \"A\",  letter = 6, acc =  0},\n  {name = \"A#\", letter = 6, acc =  1},\n  {name = \"Bb\", letter = 7, acc = -1},\n  {name = \"B\",  letter = 7, acc =  0},\n  {name = \"Cb\", letter = 1, acc = -1},\n}\n\n-- Bottom row: the seven white keys of an octave\nlocal WHITE_PCS = {0, 2, 4, 5, 7, 9, 11}\n\n-- Top row: the five black keys of an octave\nlocal BLACK_PCS = {1, 3, 6, 8, 10}\n\n-- Which white-key gap each black key sits above (1 = between white 1 and 2).\n-- C#=1, D#=2, (no black key between E and F), F#=4, G#=5, A#=6\nlocal BLACK_SLOTS = {1, 2, 4, 5, 6}\n\n-- Scale definitions as semitone offsets from the root.\n-- Scale definitions. intervals are semitones from the root; letters are how\n-- many letter-names each degree sits above the root letter, which is what\n-- makes the spelling come out right. A seven-note scale simply walks the\n-- letters in order (0..6); the others follow the conventional spelling, so\n-- major blues repeats a letter for its b3 and 3 (C D Eb E G A) and the\n-- diminished scales repeat one letter across their eight notes.\nlocal SCALES = {\n  {name = \"Major\",            intervals = {0, 2, 4, 5, 7, 9, 11},\n                              letters   = {0, 1, 2, 3, 4, 5,  6}},\n  {name = \"Minor (Natural)\",  intervals = {0, 2, 3, 5, 7, 8, 10},\n                              letters   = {0, 1, 2, 3, 4, 5,  6}},\n  {name = \"Harmonic Minor\",   intervals = {0, 2, 3, 5, 7, 8, 11},\n                              letters   = {0, 1, 2, 3, 4, 5,  6}},\n  {name = \"Ionian\",           intervals = {0, 2, 4, 5, 7, 9, 11},\n                              letters   = {0, 1, 2, 3, 4, 5,  6}},\n  {name = \"Dorian\",           intervals = {0, 2, 3, 5, 7, 9, 10},\n                              letters   = {0, 1, 2, 3, 4, 5,  6}},\n  {name = \"Phrygian\",         intervals = {0, 1, 3, 5, 7, 8, 10},\n                              letters   = {0, 1, 2, 3, 4, 5,  6}},\n  {name = \"Lydian\",           intervals = {0, 2, 4, 6, 7, 9, 11},\n                              letters   = {0, 1, 2, 3, 4, 5,  6}},\n  {name = \"Mixolydian\",       intervals = {0, 2, 4, 5, 7, 9, 10},\n                              letters   = {0, 1, 2, 3, 4, 5,  6}},\n  {name = \"Aeolian\",          intervals = {0, 2, 3, 5, 7, 8, 10},\n                              letters   = {0, 1, 2, 3, 4, 5,  6}},\n  {name = \"Major Pentatonic\", intervals = {0, 2, 4, 7, 9},\n                              letters   = {0, 1, 2, 4, 5}},\n  {name = \"Minor Pentatonic\", intervals = {0, 3, 5, 7, 10},\n                              letters   = {0, 2, 3, 4,  6}},\n  {name = \"Major Blues\",      intervals = {0, 2, 3, 4, 7, 9},\n                              letters   = {0, 1, 2, 2, 4, 5}},\n  {name = \"Minor Blues\",      intervals = {0, 3, 5, 6, 7, 10},\n                              letters   = {0, 2, 3, 4, 4,  6}},\n  {name = \"Whole Tone\",       intervals = {0, 2, 4, 6, 8, 10},\n                              letters   = {0, 1, 2, 3, 4,  5}},\n  {name = \"Diminished Whole-Half\", intervals = {0, 2, 3, 5, 6, 8, 9, 11},\n                                   letters   = {0, 1, 2, 3, 4, 5, 5,  6}},\n  {name = \"Diminished Half-Whole\", intervals = {0, 1, 3, 4, 6, 7, 9, 10},\n                                   letters   = {0, 1, 2, 2, 3, 4, 5,  6}},\n}\n\n\n------------------------------------------------------------------------------\n-- State\n------------------------------------------------------------------------------\n\nlocal state = {\n  root      = nil,   -- index into ROOTS, or nil when no scale is selected\n  scale     = nil,   -- index into SCALES, or nil\n  showNames = true,  -- draw note names inside the circles\n  simpleNames = false, -- name notes as piano keys rather than for the key\n  highlight = 1,     -- index into HIGHLIGHTS\n}\n\nlocal active = {}    -- active[pitchClass] = true when that note is in the scale\nlocal names  = {}    -- names[pitchClass] = how to spell it in the current key\n\nlocal keyUsesFlats = false -- whether the selected key spells its notes as flats\n\nlocal held      = {} -- held[midiNote] = true while the note is being played\nlocal heldCount = 0\n--[[  Bumped whenever the held set changes at all. The chord name is not the\n    only thing on the icon that follows the notes - every held note is ringed -\n    and a note can come or go without the name moving, so the name cannot be\n    what decides whether to redraw. ]]\nlocal heldVersion = 0\nlocal chordName = nil   -- what the held notes spell, or nil when nothing is held\n\n-- Declared here because the project watcher renames the chord when the key\n-- changes, and it is defined above the chord reader it has to call.\nlocal detectChord\n\n--[[  Naming a chord needs a key to settle the readings that are a genuine\n    draw, and the script starts with no scale chosen. Rather than go quiet\n    until one is picked, it reads those draws as if the key were C major.\n\n    Nothing on the icon says so - with no scale selected no circle lights up,\n    exactly as before - and choosing C major from the menu gives identical\n    names, which is the property `tests/test_scaleview_pro.lua` checks over\n    every three- and four-note voicing. C major is the right one to assume\n    because it is also what the note names already fall back to: no\n    accidentals, so the twelve read C C# D D# E F F# G G# A A# B either way. ]]\nlocal ASSUMED_KEY = {[0] = true, [2] = true, [4] = true, [5] = true,\n                     [7] = true, [9] = true, [11] = true}\n-- The same assumption's first, third and fifth degrees, for the doubled-degree\n-- rule below. Change the assumed key and this has to change with it.\nlocal ASSUMED_TONIC = {[0] = true, [4] = true, [7] = true}\nlocal lastEventSeq = nil -- newest input event already applied\nlocal midiFailed = false -- set if the input history cannot be read at all\n\nlocal MOUSE_BUTTONS = 1 | 2 | 64   -- left, right, middle; the rest are modifiers\n\n-- How long after a menu closes to keep ignoring the mouse. The click that\n-- chose the item reaches the window afterwards, and not always in the very\n-- next frame, so waiting for the buttons to come up is not enough on its own.\nlocal MENU_SETTLE_SECONDS = 0.25\n\nlocal prevMouseCap  = 0\nlocal settlingMouse = false   -- true from a menu closing until the mouse is idle\nlocal menuClosedAt  = -1      -- time_precise() when the last menu closed\nlocal pressActive   = false   -- a press began on the icon and has not ended\nlocal pressX, pressY = 0, 0   -- where it began, which decides the menu\nlocal needRedraw   = true\nlocal lastW, lastH, lastDock\n\n------------------------------------------------------------------------------\n-- Helpers\n------------------------------------------------------------------------------\n\n-- Reads a saved setting, falling back to the section used under the earlier\n-- name so a rename doesn't reset an existing install's scale, window position\n-- or dock state.\nlocal function getSetting(key)\n  local value = reaper.GetExtState(EXT_SECTION, key)\n  local i = 1\n  while value == \"\" and EXT_LEGACY[i] do\n    value = reaper.GetExtState(EXT_LEGACY[i], key)\n    i = i + 1\n  end\n  return value\nend\n\nlocal function setColor(c)\n  gfx.set(c[1], c[2], c[3], 1)\nend\n\nlocal function rootPitch(root)\n  return (LETTER_PCS[root.letter] + root.acc) % 12\nend\n\n-- Spell pitch class pc using the given letter, e.g. letter G and pc 6 gives\n-- \"Gb\". Returns nil when that would need more than a double accidental, which\n-- only happens in spellings nobody writes.\nlocal function spellAs(letter, pc)\n  letter = (letter - 1) % 7 + 1\n  local offset = ((pc - LETTER_PCS[letter] + 6) % 12) - 6   -- -6..+5, 0 = natural\n  local accidental = ACCIDENTALS[offset]\n  if not accidental then return nil end\n  return LETTERS[letter] .. accidental\nend\n\n-- Two naming schemes. By default a note is named for the key it is in, which\n-- is what makes Gb major read Gb Ab Bb Cb Db Eb F. With \"Simplify Note Names\"\n-- on, every note is named the way its piano key is: sharps for the black keys\n-- and never a double accidental, so Bbb reads A, Gx reads A and Cb reads B.\nlocal function noteName(pc)\n  if state.simpleNames then return SHARP_NAMES[pc + 1] end\n  return names[pc] or SHARP_NAMES[pc + 1]\nend\n\nlocal function highlightColor()\n  return HIGHLIGHTS[state.highlight].rgb\nend\n\n-- Recalculate which pitch classes are lit for the current selection.\nlocal function refreshActive()\n  active, names = {}, {}\n  keyUsesFlats = false\n  if not (state.root and state.scale) then return end\n\n  local root  = ROOTS[state.root]\n  local rootPc = rootPitch(root)\n  local scale = SCALES[state.scale]\n  local sharps, flats = 0, 0\n\n  for degree, interval in ipairs(scale.intervals) do\n    local pc = (rootPc + interval) % 12\n    local name = spellAs(root.letter + scale.letters[degree], pc)\n    active[pc] = true\n    names[pc]  = name\n    if name then\n      if name:find(\"#\") or name:find(\"x\") then sharps = sharps + 1 end\n      if name:find(\"b\", 2) then flats = flats + 1 end   -- skip the note letter B\n    end\n  end\n\n  -- The notes outside the scale have no spelling of their own, so name them\n  -- in whichever direction the key leans.\n  keyUsesFlats = flats > sharps\n  local outside = keyUsesFlats and FLAT_NAMES or SHARP_NAMES\n  for pc = 0, 11 do\n    if not names[pc] then names[pc] = outside[pc + 1] end\n  end\nend\n\nlocal function displayLabel()\n  if chordName then return chordName, true end\n  if midiFailed then return \"MIDI input unavailable\", false end\n  if state.root and state.scale then\n    return ROOTS[state.root].name .. \" \" .. SCALES[state.scale].name, false\n  end\n  return \"No scale selected\", false\nend\n\nlocal function saveState()\n  -- Stored by name throughout, so reordering a table cannot repoint a saved\n  -- choice at a different entry.\n  reaper.SetExtState(EXT_SECTION, \"root\",  state.root  and ROOTS[state.root].name   or \"\", true)\n  reaper.SetExtState(EXT_SECTION, \"scale\", state.scale and SCALES[state.scale].name or \"\", true)\n  reaper.SetExtState(EXT_SECTION, \"shownames\",   state.showNames and \"1\" or \"0\", true)\n  reaper.SetExtState(EXT_SECTION, \"simplenames\", state.simpleNames and \"1\" or \"0\", true)\n  reaper.SetExtState(EXT_SECTION, \"highlight\", HIGHLIGHTS[state.highlight].name, true)\nend\n\n-- The scale belongs to the project, not to the user: SetProjExtState stores it\n-- inside the .RPP, so each project reopens in its own key. Everything else -\n-- colour, note names, window - stays global, because those are preferences\n-- rather than anything about the music.\nlocal PROJECT_SECTION = \"ScaleView\"\n-- What the section was called before the scripts lost their kallums_ prefix.\n-- Read when a project has nothing under the name above, so a project saved\n-- earlier still opens in its own key; the next change writes it across.\nlocal PROJECT_LEGACY  = \"kallums_ScaleView\"\n\nlocal currentProject = nil   -- the project the scale on screen came from\n\nlocal function projectApiAvailable()\n  return reaper.EnumProjects and reaper.GetProjExtState and reaper.SetProjExtState\nend\n\nlocal function activeProject()\n  if not projectApiAvailable() then return nil end\n  return reaper.EnumProjects(-1)\nend\n\nlocal function lookupNamed(list, saved)\n  for i, entry in ipairs(list) do\n    if entry.name == saved then return i end\n  end\nend\n\n-- Writes the scale into the project. This marks the project as edited, which\n-- is the cost of the project remembering it.\nlocal function saveProjectScale()\n  local project = activeProject()\n  if not project then return end\n\n  reaper.SetProjExtState(project, PROJECT_SECTION, \"root\",\n    state.root and ROOTS[state.root].name or \"\")\n  reaper.SetProjExtState(project, PROJECT_SECTION, \"scale\",\n    state.scale and SCALES[state.scale].name or \"\")\nend\n\n-- The scale this project was left in, or nil when it has never had one.\nlocal function projectScale(project)\n  if not project then return nil end\n\n  local _, rootName  = reaper.GetProjExtState(project, PROJECT_SECTION, \"root\")\n  local _, scaleName = reaper.GetProjExtState(project, PROJECT_SECTION, \"scale\")\n\n  if (rootName or \"\") == \"\" and (scaleName or \"\") == \"\" then\n    _, rootName  = reaper.GetProjExtState(project, PROJECT_LEGACY, \"root\")\n    _, scaleName = reaper.GetProjExtState(project, PROJECT_LEGACY, \"scale\")\n  end\n\n  local root  = lookupNamed(ROOTS,  rootName or \"\")\n  local scale = lookupNamed(SCALES, scaleName or \"\")\n\n  if root and scale then return root, scale end\n  return nil\nend\n\nlocal function loadState()\n  local function lookup(list, saved)\n    for i, entry in ipairs(list) do\n      if entry.name == saved then return i end\n    end\n  end\n\n  state.root  = lookup(ROOTS,  getSetting(\"root\"))\n  state.scale = lookup(SCALES, getSetting(\"scale\"))\n  state.highlight = lookup(HIGHLIGHTS, getSetting(\"highlight\")) or 1\n  if getSetting(\"shownames\") == \"0\" then state.showNames = false end\n  if getSetting(\"simplenames\") == \"1\" then state.simpleNames = true end\n\n  -- A root without a scale, or the other way round, would light nothing.\n  if not (state.root and state.scale) then state.root, state.scale = nil, nil end\n\n  -- A scale saved in the project wins over the last one used anywhere, so\n  -- reopening a project puts its own key back on screen.\n  currentProject = activeProject()\n  local root, scale = projectScale(currentProject)\n  if root then state.root, state.scale = root, scale end\n\n  refreshActive()\nend\n\n-- Following the project the user is looking at: switching tab, or opening\n-- another project, brings that project's scale with it. A project that has\n-- never had one is left showing whatever is already up rather than blanking.\nlocal function followProjectChange()\n  local project = activeProject()\n  if not project or project == currentProject then return false end\n\n  currentProject = project\n\n  local root, scale = projectScale(project)\n  if not root then return false end\n  if root == state.root and scale == state.scale then return false end\n\n  state.root, state.scale = root, scale\n  refreshActive()\n  if heldCount > 0 then chordName = detectChord() end\n  return true\nend\n\nlocal function saveWindowState()\n  local dock, x, y, w, h = gfx.dock(-1, 0, 0, 0, 0)\n  reaper.SetExtState(EXT_SECTION, \"wnd\", table.concat({dock, x, y, w, h}, \" \"), true)\nend\n\nlocal function loadWindowState()\n  local dock, x, y, w, h = getSetting(\"wnd\"):match(\n    \"(-?%d+) (-?%d+) (-?%d+) (-?%d+) (-?%d+)\")\n  if not dock then return 0, nil, nil, DEFAULT_W, DEFAULT_H end\n  w, h = tonumber(w), tonumber(h)\n  if w < 60 then w = DEFAULT_W end\n  if h < 40 then h = DEFAULT_H end\n  return tonumber(dock), tonumber(x), tonumber(y), w, h\nend\n\n------------------------------------------------------------------------------\n-- Layout - everything is derived from the current window size so the icon\n-- stays correct if it is resized or docked.\n------------------------------------------------------------------------------\n\nlocal function layout()\n  local aspect = DEFAULT_W / DEFAULT_H\n\n  -- The icon keeps its 2:1 proportions inside whatever window it is given and\n  -- is centred in it, so a wide docker doesn't smear the circles across the\n  -- full width of the dock.\n  local boxW = math.min(gfx.w, gfx.h * aspect)\n  local boxH = math.min(gfx.h, gfx.w / aspect)\n  local originX = (gfx.w - boxW) / 2\n  local originY = (gfx.h - boxH) / 2\n\n  local step   = boxW / 7                              -- one white-key slot\n  local labelH = boxH * 0.20\n  local radius = math.min(step * 0.40, (boxH - labelH) * 0.20)\n\n  return {\n    originX = originX,\n    boxW    = boxW,\n    step    = step,\n    radius  = radius,\n    topY    = originY + (boxH - labelH) * 0.33,\n    botY    = originY + (boxH - labelH) * 0.76,\n    labelY  = originY + boxH - labelH,\n    labelH  = labelH,\n  }\nend\n\n------------------------------------------------------------------------------\n-- Chord detection\n--\n-- The held notes give a set of pitch classes and a bass - the lowest note\n-- actually sounding, which is found separately from the root. Every pitch\n-- class is then tried as a root: the notes above it are read as a third, a\n-- fifth and a seventh, and whatever is left over is described as an extension.\n-- Each reading is costed, the cheapest wins, and a root that is not in the\n-- bass pays for the slash it will need. That is what separates Bsus2 from\n-- F#sus4 and keeps C E A as Amin/C.\n--\n-- The one exception to \"the bass is the lowest note\" is a root sounding in\n-- more than one octave that is a first, third or fifth degree of the key:\n-- that reads as root position and the slash comes off. See\n-- readAsRootPosition.\n------------------------------------------------------------------------------\n\n--[[ A chord is named from the same vocabulary the scale list offers: the\n     eighteen spellings in ROOTS. Those are exactly the roots real keys are\n     built on, which is what makes a chord in Gb major read Gb rather than F#,\n     and one in Cb major read Cb.\n\n     Anything outside that vocabulary falls back to its plain name, leaning the\n     way the key does. That covers the double accidentals a key like Gb minor\n     blues produces - the circles rightly read Bbb and Dbb, but the chord is\n     Amin/C, not Bbbmin/Dbb - and the theoretical spellings no one writes a\n     chord on: B#, E# and Fb. In C# major a chord on B# D# E# reads Cmin add11,\n     the way it would be written. ]]\nlocal CHORD_ROOT_NAMES = {}\nfor _, root in ipairs(ROOTS) do CHORD_ROOT_NAMES[root.name] = true end\n\nlocal function chordNoteName(pc)\n  local name = noteName(pc)\n  if CHORD_ROOT_NAMES[name] then return name end\n  return (keyUsesFlats and FLAT_NAMES or SHARP_NAMES)[pc + 1]\nend\n\nlocal function heldPitchClasses()\n  local classes, bass, voices = {}, nil, {}\n\n  for note in pairs(held) do\n    local pc = note % 12\n    classes[pc] = true\n    voices[pc]  = (voices[pc] or 0) + 1   -- how many octaves it is sounding in\n    if not bass or note < bass then bass = note end\n  end\n\n  return classes, bass and bass % 12 or nil, voices\nend\n\n--[[  The first, third and fifth degrees of the key.\n\n    Taken from the selected scale itself rather than assumed to be a major\n    triad, so a minor key offers its own third and a five-note scale offers\n    whatever its third and fifth degrees are. With no scale selected the\n    assumed key supplies them, exactly as it supplies the draws, so choosing\n    C Major from the menu still gives identical names. ]]\nlocal function tonicDegrees()\n  if not (state.root and state.scale) then return ASSUMED_TONIC end\n\n  local degrees   = {}\n  local rootPc    = rootPitch(ROOTS[state.root])\n  local intervals = SCALES[state.scale].intervals\n  for _, degree in ipairs({1, 3, 5}) do\n    if intervals[degree] then degrees[(rootPc + intervals[degree]) % 12] = true end\n  end\n  return degrees\nend\n\n--[[  A doubled degree of the key claims the bass.\n\n    The bass is the lowest note sounding - that is what a slash chord names,\n    and everything else here rests on it. The one exception is the case this\n    rule exists for: a root that is a first, third or fifth degree of the key\n    and is sounding in more than one octave. A doubled root is how a chord is\n    voiced in root position, so the reading is that the player laid the chord\n    out around its root rather than inverted it, and the slash comes off.\n\n    It can only ever remove a slash, never invent one: the note after a slash\n    is always either the lowest note or nothing at all, so the symbol can never\n    name a bass that is not there. Scaler reads doubling this way, and it is\n    the only place its slash chords and ours parted company on the same notes.\n\n    The cost model is untouched. The reading is still chosen with the lowest\n    note as the bass, which is what the corpora measure; this decides how the\n    winner is written down. ]]\nlocal function readAsRootPosition(root, bass, voices)\n  if root == bass then return true end\n  if (voices[root] or 0) < 2 then return false end\n  return tonicDegrees()[root] == true\nend\n\n--[[  Reading the chord.\n\n    Every note being held is tried as the root and the cheapest reading wins.\n    The cost is the whole of the judgement: how unusual the quality is, what\n    its extensions cost, and whether the root had to be named after a slash.\n    That is what keeps a complete triad in an inversion ahead of a rooted\n    chord with a hole in it - C E A is Amin/C, not a C6 missing its fifth.\n\n    Where two readings cost exactly the same the selected scale settles it: a\n    root that is a degree of the scale is preferred, then a reading whose\n    notes sit in it. With no scale selected `active` is empty and the commoner\n    quality decides instead, so the naming never depends on a scale being\n    chosen - and a chord from outside the key is still named for what it is\n    rather than bent to fit. ]]\nfunction detectChord()\n  local classes, bass, voices = heldPitchClasses()\n  if not bass then return nil end\n\n  local count = 0\n  for _ in pairs(classes) do count = count + 1 end\n  if count == 1 then return chordNoteName(bass) end\n\n  local function spellOut()\n    local spelled = {}\n    for pc = 0, 11 do\n      if classes[pc] then spelled[#spelled + 1] = chordNoteName(pc) end\n    end\n    return table.concat(spelled, \" \")\n  end\n\n  --[[  Two notes are an interval rather than a chord, with two exceptions: the\n      bare fifth, and a third.\n\n      A third is enough to name a chord - B D is a B minor and C E a C major -\n      but the missing fifth cannot be silent here the way it is in a fuller\n      voicing. Printing \"C\" for C E would claim a G that nobody is playing, so\n      the omission is said out loud, which is what Scaler prints too. A third\n      also has only one reading: the notes four semitones apart are a major\n      third one way and a minor sixth the other, and only one of the two has\n      its third.\n\n      Everything else two notes can be - a second, a fourth, a tritone, a\n      sixth, a seventh - is an interval and still reads out as notes. ]]\n  if count == 2 then\n    for root = 0, 11 do\n      if classes[root] and classes[(root + 7) % 12] then\n        local name = chordNoteName(root) .. \"5\"\n        if not readAsRootPosition(root, bass, voices) then\n          name = name .. \"/\" .. chordNoteName(bass)\n        end\n        return name\n      end\n    end\n    for root = 0, 11 do\n      if classes[root] then\n        local quality = (classes[(root + 4) % 12] and \"maj\")\n                     or (classes[(root + 3) % 12] and \"min\")\n        if quality then\n          local name = chordNoteName(root) .. quality .. \"(no5)\"\n          if not readAsRootPosition(root, bass, voices) then\n            name = name .. \"/\" .. chordNoteName(bass)\n          end\n          return name\n        end\n      end\n    end\n    return spellOut()\n  end\n\n  -- Past a certain thickness there is no chord left to find, only a cluster.\n  if count > 7 then return spellOut() end\n\n  local best\n  for root = 0, 11 do\n    if classes[root] then\n      local has = {}\n      for pc = 0, 11 do\n        if classes[pc] then has[(pc - root) % 12] = true end\n      end\n\n      local name, cost, rank = analyse(has, root, bass)\n\n      local key = (state.root and state.scale) and active or ASSUMED_KEY\n      local fit = key[root] and 100 or 0\n      for pc = 0, 11 do\n        if classes[pc] and key[pc] then fit = fit + 1 end\n      end\n\n      --[[  After the key, a draw goes to the reading that needs no slash, and\n          only then to the commoner quality. C D G Bb over C cost the same as\n          C7sus2 and as Gmin add11 over C, and the minor triad's rank won it:\n          a slash nobody needed, chosen by a tiebreak. ]]\n      local slash = root ~= bass\n      if not best or cost < best.cost\n         or (cost == best.cost and fit > best.fit)\n         or (cost == best.cost and fit == best.fit and best.slash and not slash)\n         or (cost == best.cost and fit == best.fit and slash == best.slash\n             and rank < best.rank) then\n        best = {root = root, name = name, cost = cost, rank = rank, fit = fit,\n                slash = slash}\n      end\n    end\n  end\n\n  local name = chordNoteName(best.root) .. best.name\n  if not readAsRootPosition(best.root, bass, voices) then\n    name = name .. \"/\" .. chordNoteName(bass)\n  end\n  return name\nend\n\n------------------------------------------------------------------------------\n-- Live MIDI input\n--\n-- MIDI_GetRecentInputEvent reads REAPER's global input history: idx 0 is the\n-- most recent event and must be asked for first, since it latches the list.\n-- Each event carries a sequence number, so walking back until we meet the one\n-- we finished on last time gives exactly the events we have not seen yet.\n------------------------------------------------------------------------------\n\n--[[  Only a safety stop: the walk ends at the newest event already applied,\n    so a poll costs what has arrived since the last one and no more. It was 64,\n    which a continuous stream of pitch bend or pressure - an MPE controller\n    sends both for every finger - or the pause while a menu is open could\n    exceed, and every event past it was dropped: a note-off among them left\n    the note ringed until something else cleared it. ]]\nlocal MAX_EVENTS_PER_POLL = 16384\n\nlocal function applyEvent(message)\n  if #message < 3 then return end\n\n  local status   = message:byte(1)\n  local command  = status & 0xF0\n  local note     = message:byte(2)\n  local velocity = message:byte(3)\n\n  if command == 0x90 and velocity > 0 then\n    if not held[note] then\n      held[note] = true\n      heldCount = heldCount + 1\n      heldVersion = heldVersion + 1\n    end\n  elseif command == 0x80 or (command == 0x90 and velocity == 0) then\n    if held[note] then\n      held[note] = nil\n      heldCount = heldCount - 1\n      heldVersion = heldVersion + 1\n    end\n  elseif command == 0xB0 and (note == 120 or note == 123) then\n    if heldCount > 0 then heldVersion = heldVersion + 1 end\n    held, heldCount = {}, 0       -- all sound off / all notes off\n  end\nend\n\nlocal function pollMidiInput()\n  if midiFailed then return false end\n\n  local fresh, newestSeq = {}, nil\n\n  for index = 0, MAX_EVENTS_PER_POLL - 1 do\n    local ok, sequence, message = pcall(reaper.MIDI_GetRecentInputEvent, index)\n\n    if not ok or type(sequence) ~= \"number\" or type(message) ~= \"string\" then\n      -- Either the API is missing or it does not return what we expect. Say\n      -- so once rather than throwing in the defer loop on every frame.\n      midiFailed = true\n      return false\n    end\n\n    if sequence == 0 or sequence == lastEventSeq then break end\n    if index == 0 then newestSeq = sequence end\n\n    fresh[#fresh + 1] = message\n  end\n\n  if #fresh == 0 then return false end\n\n  -- The history runs newest first, so apply it backwards to keep note-ons and\n  -- note-offs in the order they were played.\n  local wasVersion = heldVersion\n  for i = #fresh, 1, -1 do applyEvent(fresh[i]) end\n\n  lastEventSeq = newestSeq or lastEventSeq\n\n  local detected = heldCount > 0 and detectChord() or nil\n  if detected ~= chordName then\n    chordName = detected\n    return true\n  end\n\n  --[[  A note can join or leave without the name moving: adding B to D E Ab\n      is E7/D either way, because B is the fifth and a missing fifth is\n      silent. The rings follow the notes, so the held set has to be able to\n      ask for a redraw on its own.\n\n      Reported from REAPER as B never lighting up, then lighting up on a\n      window resize and staying lit for seconds - which is exactly what\n      redrawing only on a name change looks like, since a resize is the other\n      thing that forces one. The suite missed it because its `label()` helper\n      toggles gfx.w to force a redraw, so every assertion was reading a frame\n      the test itself had asked for. ]]\n  return heldVersion ~= wasVersion\nend\n\n------------------------------------------------------------------------------\n-- Drawing\n------------------------------------------------------------------------------\n\n--[[  A note being played is ringed, whether or not it is in the scale, and the\n    ring is **always COLOR_HELD**. No exceptions, and do not make it depend on\n    the circle underneath: it was tried and it looked broken in REAPER.\n\n    The reason it was tried is worth keeping, because the arithmetic was right\n    and the surface was wrong. The ring reads at only 1.4:1 to 2.0:1 against a\n    highlight colour, so a dark ring seemed the obvious fix for a played note\n    inside the scale - but both strokes are drawn at r + 1.5 and r + 2.5,\n    *outside* the filled circle, on the background. #FFF200 reads 12.8:1 there\n    and a dark ring reads almost nothing, which is why it disappeared.\n\n    It is also why no highlight may be the ring's own colour: it would swallow\n    the ring where the two do touch. ]]\nlocal function drawHeldRing(x, y, r, pc)\n  for _, note in ipairs({pc, pc + 12, pc + 24, pc + 36, pc + 48, pc + 60,\n                         pc + 72, pc + 84, pc + 96, pc + 108, pc + 120}) do\n    if held[note] then\n      setColor(COLOR_HELD)\n      gfx.circle(x, y, r + 1.5, false, true)\n      gfx.circle(x, y, r + 2.5, false, true)\n      return\n    end\n  end\nend\n\nlocal function drawCircle(x, y, r, pc)\n  local on = active[pc] == true\n  local fill = on and highlightColor() or COLOR_OFF\n  local inner = r\n  if not on then\n    -- A dark circle on the dark background is 1.4:1, too faint to show where\n    -- the note sits (Apple's 3:1 for a shape that means something). A rim of\n    -- COLOR_EDGE, 3.2:1, shows it and the fill stays dark, so the notes\n    -- outside the key still recede. Drawn filled, so the only unfilled\n    -- strokes are still the played-note ring.\n    setColor(COLOR_EDGE)\n    gfx.circle(x, y, r, true, true)\n    inner = r - math.max(1, r / 12)\n  end\n  setColor(fill)\n  gfx.circle(x, y, inner, true, true)\n\n  if state.showNames and r >= MIN_NAME_RADIUS then\n    local name = noteName(pc)\n    -- \"Bbb\" needs to fit the same circle as \"B\". Never under MIN_TEXT points,\n    -- Apple's smallest for the Mac: a circle too small for that shows no name.\n    local fit = ({0.95, 0.80, 0.62})[#name] or 0.55\n    gfx.setfont(2, FACE, math.max(MIN_TEXT, math.floor(r * fit)))\n    local tw, th = gfx.measurestr(name)\n    setColor(on and COLOR_TEXT_ON or COLOR_TEXT_OFF)\n    gfx.x, gfx.y = x - tw / 2, y - th / 2\n    gfx.drawstr(name)\n  end\n\n  drawHeldRing(x, y, r, pc)\nend\n\nlocal function draw()\n  setColor(COLOR_BG)\n  gfx.rect(0, 0, gfx.w, gfx.h, true)\n\n  local L = layout()\n\n  -- Top row: the five black keys, sitting over the gaps between white keys.\n  for i, pc in ipairs(BLACK_PCS) do\n    drawCircle(L.originX + BLACK_SLOTS[i] * L.step, L.topY, L.radius, pc)\n  end\n\n  -- Bottom row: the seven white keys.\n  for i, pc in ipairs(WHITE_PCS) do\n    drawCircle(L.originX + (i - 0.5) * L.step, L.botY, L.radius, pc)\n  end\n\n  -- Current scale name.\n  if L.labelH > 6 then\n    gfx.setfont(1, FACE, math.max(MIN_TEXT, math.floor(L.labelH * 0.62)))\n    local text, isChord = displayLabel()\n    local tw, th = gfx.measurestr(text)\n    setColor(isChord and COLOR_CHORD or COLOR_LABEL)\n    gfx.x = math.max(2, L.originX + (L.boxW - tw) / 2)\n    gfx.y = L.labelY + (L.labelH - th) / 2\n    gfx.drawstr(text)\n  end\nend\n\n------------------------------------------------------------------------------\n-- Menus\n--\n-- gfx.showmenu() returns the 1-based index of the chosen item counting only\n-- *selectable* items: separators and submenu headers are in the menu string\n-- but are not counted. The action table is therefore keyed by a separate\n-- counter that only advances for selectable items, so the indices line up\n-- whatever gets added to the menu later.\n------------------------------------------------------------------------------\n\nlocal function newMenu()\n  return {fields = {}, actions = {}, selectableCount = 0}\nend\n\nlocal function addField(menu, field)\n  menu.fields[#menu.fields + 1] = field\nend\n\n-- opts.checked draws a tick, opts.last closes the submenu the item is in.\nlocal function addItem(menu, label, action, opts)\n  opts = opts or {}\n  local prefix = (opts.last and \"<\" or \"\") .. (opts.checked and \"!\" or \"\")\n  addField(menu, prefix .. label)\n  menu.selectableCount = menu.selectableCount + 1\n  menu.actions[menu.selectableCount] = action\nend\n\nlocal function addSeparator(menu)\n  addField(menu, \"\")\nend\n\nlocal function addSubmenu(menu, label)\n  addField(menu, \">\" .. label)\nend\n\n-- atX, atY: where a menu opened from the keyboard appears, since the pointer\n-- may be anywhere. A click opens it under the pointer.\nlocal function showMenu(menu, atX, atY)\n  gfx.x, gfx.y = atX or gfx.mouse_x, atY or gfx.mouse_y\n  local choice = gfx.showmenu(table.concat(menu.fields, \"|\"))\n  local action = menu.actions[choice]\n  if action then action() end\n\n  -- showmenu() is modal, and the click that picked an item is reported to the\n  -- window once the menu closes - sometimes a frame or two later. Left alone\n  -- it reads as a fresh click and opens a menu nobody asked for.\n  settlingMouse = true\n  menuClosedAt  = reaper.time_precise()\nend\n\nlocal function selectScale(root, scaleIdx)\n  state.root, state.scale = root, scaleIdx\n  refreshActive()\n  saveProjectScale()\n  -- The chord is spelled for the key, so it has to be renamed when the key\n  -- changes: the same notes read Gb in one key and F# in another.\n  if heldCount > 0 then chordName = detectChord() end\n  saveState()\n  needRedraw = true\nend\n\nlocal function clearScale()\n  selectScale(nil, nil)\nend\n\n-- Picks a scale at random, never the one already showing.\nlocal function randomScale()\n  local root, scale\n  repeat\n    root  = math.random(#ROOTS)\n    scale = math.random(#SCALES)\n  until root ~= state.root or scale ~= state.scale\n  selectScale(root, scale)\nend\n\nlocal function scaleMenu(atX, atY)\n  local menu = newMenu()\n\n  addItem(menu, \"Clear Scale\", clearScale, {checked = state.scale == nil})\n  addSeparator(menu)\n\n  for scaleIdx, scale in ipairs(SCALES) do\n    addSubmenu(menu, scale.name)\n    for rootIdx, root in ipairs(ROOTS) do\n      addItem(menu, root.name .. \" \" .. scale.name,\n        function() selectScale(rootIdx, scaleIdx) end,\n        {\n          last    = rootIdx == #ROOTS,\n          checked = state.root == rootIdx and state.scale == scaleIdx,\n        })\n    end\n  end\n\n  showMenu(menu, atX, atY)\nend\n\n-- The dock state is a bitfield: bit 0 says whether the window is docked, and\n-- the second byte holds the docker index, which is kept even while undocked.\n-- So flip the bit rather than setting 0 or 1 - otherwise an undocked window\n-- that still remembers a docker reads as non-zero and never docks again.\nlocal function isDocked()\n  return gfx.dock(-1) & 1 == 1\nend\n\nlocal function toggleDock()\n  local dock = gfx.dock(-1)\n  gfx.dock(dock & 1 == 1 and dock & ~1 or dock | 1)\n  saveWindowState()\n  needRedraw = true\nend\n\nlocal function optionsMenu(atX, atY)\n  local menu = newMenu()\n\n  addItem(menu, \"Choose a Random Scale\", randomScale)\n  addSeparator(menu)\n\n  addItem(menu, \"Show Note Names\", function()\n    state.showNames = not state.showNames\n    saveState()\n    needRedraw = true\n  end, {checked = state.showNames})\n\n  addItem(menu, \"Simplify Note Names\", function()\n    state.simpleNames = not state.simpleNames\n    -- The chord is spelled from the note names, so it has to be renamed too.\n    if heldCount > 0 then chordName = detectChord() end\n    saveState()\n    needRedraw = true\n  end, {checked = state.simpleNames})\n\n  addSubmenu(menu, \"Highlight Colour\")\n  for i, entry in ipairs(HIGHLIGHTS) do\n    addItem(menu, entry.name, function()\n      state.highlight = i\n      saveState()\n      needRedraw = true\n    end, {last = i == #HIGHLIGHTS, checked = state.highlight == i})\n  end\n\n  addSeparator(menu)\n  addItem(menu, \"Dock Window\", toggleDock, {checked = isDocked()})\n  addSeparator(menu)\n  addItem(menu, \"Close\", function() gfx.quit() end)\n\n  showMenu(menu, atX, atY)\nend\n\n------------------------------------------------------------------------------\n-- Input\n------------------------------------------------------------------------------\n\n-- Which menu a click opens depends on where it is, not which button was used:\n-- the circles are the scale list, everything else is the options. That means\n-- there is no wrong menu to open by mistake.\nlocal function isOverCircle(x, y)\n  local L = layout()\n  local reach = L.radius + 2      -- a little forgiveness around the edge\n\n  for i, _ in ipairs(BLACK_PCS) do\n    local cx = L.originX + BLACK_SLOTS[i] * L.step\n    local dx, dy = x - cx, y - L.topY\n    if dx * dx + dy * dy <= reach * reach then return true end\n  end\n\n  for i, _ in ipairs(WHITE_PCS) do\n    local cx = L.originX + (i - 0.5) * L.step\n    local dx, dy = x - cx, y - L.botY\n    if dx * dx + dy * dy <= reach * reach then return true end\n  end\n\n  return false\nend\n\nlocal function handleMouse()\n  local cap = gfx.mouse_cap\n  local buttons = cap & MOUSE_BUTTONS\n\n  -- After a menu closes, ignore the mouse until nothing is held AND a moment\n  -- has passed. Whatever it did while the menu was up belongs to the menu.\n  if settlingMouse then\n    if buttons == 0 and reaper.time_precise() - menuClosedAt >= MENU_SETTLE_SECONDS then\n      settlingMouse = false\n    end\n    prevMouseCap, pressActive = cap, false\n    return\n  end\n\n  local wasDown = prevMouseCap & MOUSE_BUTTONS ~= 0\n\n  if not wasDown and buttons ~= 0 then\n    -- A press. Remember where it started: a click belongs where it began, so\n    -- pressing on a circle and drifting off still opens the scale list.\n    pressActive = true\n    pressX, pressY = gfx.mouse_x, gfx.mouse_y\n  elseif wasDown and buttons == 0 and pressActive then\n    -- A release, so the click is finished. Firing here rather than on the\n    -- press means dragging the window by its edge does not open a menu.\n    pressActive = false\n    if isOverCircle(pressX, pressY) then scaleMenu() else optionsMenu() end\n  end\n\n  prevMouseCap = cap\nend\n\n-- Returns false when the script should stop.\n-- The keyboard reaches both menus too (decision 0013): S or Return opens the\n-- scale list, O the options, from the middle of the icon. Once open, a menu is\n-- the system's own, so the arrow keys and Return work in it.\nlocal function handleKeys()\n  local char = gfx.getchar()\n  if char < 0 or char == 27 then return false end        -- window closed / Esc\n  if char == 100 or char == 68 then toggleDock() end     -- d / D\n  local L = layout()\n  local mx, my = L.originX + L.boxW / 2, L.labelY\n  if char == 115 or char == 83 or char == 13 then        -- s / S / Return\n    scaleMenu(mx, my)\n  elseif char == 111 or char == 79 then                  -- o / O\n    optionsMenu(mx, my)\n  end\n  return true\nend\n\n------------------------------------------------------------------------------\n-- Main loop\n------------------------------------------------------------------------------\n\nlocal function main()\n  if followProjectChange() then needRedraw = true end\n  if pollMidiInput() then needRedraw = true end\n\n  handleMouse()\n\n  if not handleKeys() then\n    saveWindowState()\n    gfx.quit()\n    return\n  end\n\n  local dock = gfx.dock(-1)\n  if needRedraw or gfx.w ~= lastW or gfx.h ~= lastH or dock ~= lastDock then\n    lastW, lastH, lastDock = gfx.w, gfx.h, dock\n    needRedraw = false\n    draw()\n    gfx.update()\n  end\n\n  reaper.defer(main)\nend\n\n--[[  The system's own face where REAPER can find it (Apple's Typography page):\n    San Francisco on a Mac, Segoe UI on Windows, else Arial as before. gfx takes\n    a face by name and quietly substitutes another when it does not know it, so\n    each is asked for and gfx.getfont() says what was really given. It needs\n    the window, so it runs after gfx.init. As Orchestration Helper does.  ]]\nlocal SYSTEM_FACES = {\n  {\".AppleSystemUIFont\", \"applesystemui\", \".sf\"},   -- reported under either name\n  {\"Segoe UI\", \"segoe\"},\n}\nlocal function pickFace()\n  for _, try in ipairs(SYSTEM_FACES) do\n    gfx.setfont(1, try[1], 12)\n    local _, got = gfx.getfont()\n    got = tostring(got or \"\"):lower()\n    for i = 2, #try do\n      if got:find(try[i], 1, true) then return try[1] end\n    end\n  end\n  return \"Arial\"\nend\n\nlocal function init()\n  --[[  Tell REAPER the script is on, so a toolbar button bound to it lights up,\n      and that re-running the action should stop this instance rather than\n      start a second one - which makes the same button toggle it off.\n      REAPER 7+; harmless to skip on anything older.  ]]\n  if reaper.set_action_options then reaper.set_action_options(1 | 4) end\n\n  math.randomseed(os.time() + math.floor(reaper.time_precise() * 1000))\n  loadState()\n  local dock, x, y, w, h = loadWindowState()\n  if x and y then\n    gfx.init(SCRIPT_NAME, w, h, dock, x, y)\n  else\n    gfx.init(SCRIPT_NAME, w, h, dock)\n  end\n  FACE = pickFace()\n  gfx.setfont(1, FACE, 12)\n  main()\nend\n\nreaper.atexit(function()\n  saveState()\n  if reaper.set_action_options then reaper.set_action_options(8) end   -- toggle off\n  gfx.quit()\nend)\n\ninit()\n"};

/* ---- kit/palette.js ---- */
/* The devices' colours in Live: after Ableton Live 8's default theme.
 *
 * The scheme is Starting Blocks' own experiment of 18 September 2026
 * (commit 2765b0a3, "theme the window after Live 8"): a neutral grey chrome
 * meant to sit quietly under brightly coloured clips, controls raised off it,
 * and one warm amber spent where Live spends its accent, on what is switched
 * on. It was built from the theme's described character, not Live's own
 * files, so it is a likeness, not a match.
 *
 * Two changes from that experiment, both for the family's rules (every word
 * 7:1 on what it sits on, ink on every button, marks and edges 3:1):
 *   - the chrome is #3E3E3E, a step darker than its #4A4A4A, because on
 *     #4A4A4A a secondary word cannot reach 7:1 and still look secondary;
 *   - buttons are a light grey with dark ink, as the house scheme's are,
 *     because light words on its #5E5E5E buttons reach only 5:1.
 * The greys are neutral (R = G = B), as Live's are: the house rule that
 * every grey leans blue is the yellow scheme's, and Live's look is not that.
 *
 * Palette.tone(r, g, b) is how the REAPER windows (the JSFX and Lua scripts,
 * drawn through gfx.js) take the scheme without a line of theirs changing:
 *   - the house scheme's own colours map one for one (HOUSE below), each
 *     chosen so the pairs the scripts rely on stay 7:1 for words and 3:1
 *     for edges;
 *   - the house yellow, and the shades the scripts make of it, become the
 *     amber, shaded the same way;
 *   - any other grey loses its tint at the same brightness, so a script
 *     with a palette of its own keeps every contrast it had;
 *   - every other colour (a material, an engine, a part) is left alone.
 */
var Palette = (function () {
  'use strict';
  var C = {
    ground: 0x3E3E3E,     // the chrome: Live 8's #4A4A4A, a step darker (see above)
    raised: 0x484848,     // a control that is off
    sunken: 0x2E2E2E,     // lists, fields, a roll or a page: Live 8's roll ground
    deep: 0x262626,       // a roll's own ground under a sunken frame
    popup: 0x333333,      // menus
    rule: 0x555555,       // separators: they group, they do not act
    edge: 0x8C8C8C,       // the edge of anything that acts: 3.2:1 on the chrome
    control: 0xB4B4B4,    // buttons, with ink on them
    controlHover: 0xC4C4C4,
    controlHeld: 0xAAAAAA,
    accent: 0xD7A93C,     // Live 8's warm amber: what is on
    accentHeld: 0xCDA139,  // held: ink on it still 7.2:1
    ink: 0x1A1A1A,        // words on a button, grey or amber; also a window's darkest ground
                          // (AutoCC paints its window in the ink), so words are 7:1 on it too
    text: 0xF0F0F0,       // 9.4:1 on the chrome
    label: 0xD8D8D8,      // 7.5:1
    dim: 0xD4D4D4,        // secondary words, 7.2:1
    mark: 0xA8A8A8,       // a mark that is not a word, or a control that is off
    note: 0xA8D8E8,       // Live 8's cool note colour, for a roll
    ring: 0xFAFAFA,       // the keyboard's place
    warn: 0xF0605A,       // a warning's mark, never its words: 3.3:1 on the chrome
    warnText: 0xFFC8C2    // a warning's words, 7.3:1
  };
  // The house scheme (HousePalette, every family repo's docs/COLOUR.md) to this one.
  var HOUSE = {
    0x111419: C.deep, 0x14171C: C.ink, 0x1A1D23: C.sunken, 0x1B1F25: C.popup, 0x1E2228: 0x343434,
    0x22262D: 0x363636, 0x23272E: C.ground, 0x2A2F37: C.raised, 0x3A404A: C.rule, 0x585F6B: 0x707070,
    0x646B77: 0x7A7A7A, 0x6D7581: C.edge, 0x8A919C: C.mark, 0x8F96A2: C.controlHeld, 0xA9AFBA: C.control,
    0xB0B6C0: C.dim, 0xB6BCC6: C.dim, 0xBFC5CE: C.label, 0xC0C6CF: C.controlHover, 0xDDE1E7: C.text,
    0xF2F4F7: C.ring, 0xFFF200: C.accent, 0xD1C600: C.accentHeld, 0xFF9E96: C.warnText, 0xFFA6A0: C.warnText, 0xD2483F: C.warn
  };
  function rgb(hex, a) {
    return [((hex >> 16) & 255) / 255, ((hex >> 8) & 255) / 255, (hex & 255) / 255, a === undefined ? 1 : a];
  }
  function lin(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
  function unlin(l) { return l <= 0.0031308 ? l * 12.92 : 1.055 * Math.pow(l, 1 / 2.4) - 0.055; }
  function luminance(r, g, b) { return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b); }
  function contrast(a, b) {
    var la = luminance(a[0], a[1], a[2]), lb = luminance(b[0], b[1], b[2]);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
  }
  function clamp(x) { return x < 0 ? 0 : x > 1 ? 1 : x; }
  var AMBER = rgb(C.accent);
  // r, g, b from 0 to 1; returns [r, g, b].
  function tone(r, g, b) {
    r = clamp(r); g = clamp(g); b = clamp(b);
    var R = Math.round(r * 255), G = Math.round(g * 255), B = Math.round(b * 255);
    var hex = (R << 16) | (G << 8) | B;
    if (HOUSE[hex] !== undefined) { var t = rgb(HOUSE[hex]); return [t[0], t[1], t[2]]; }
    // The house yellow and its shades: lighter ones mix in white (blue rises
    // from 0), darker ones scale down (red and green fall together).
    if (R >= 120 && G >= 110 && Math.abs(R - G) <= 40 && B <= Math.min(R, G) - 90) {
      var w = B / 255, k = Math.max(R, G) / 255;
      return [0, 1, 2].map(function (i) { return clamp(AMBER[i] * k + (1 - AMBER[i] * k) * w); });
    }
    // A grey with a tint, from any palette: neutral at the same brightness.
    var hi = Math.max(R, G, B), lo = Math.min(R, G, B);
    if (hi - lo <= 28) { var n = unlin(luminance(r, g, b)); return [n, n, n]; }
    return [r, g, b];
  }
  return { C: C, HOUSE: HOUSE, rgb: rgb, tone: tone, luminance: luminance, contrast: contrast };
})();


/* ---- kit/runtime/polyfill.js ---- */
/* What JavaScriptCore lacks and the Lua runtime uses: TextEncoder and
 * TextDecoder, UTF-8 only, as the web defines them (an invalid byte decodes
 * to U+FFFD and decoding goes on). Installed only where they are missing, so
 * Node and browsers keep their own; MiddawUTF8 is the same code, always, for
 * the tests to hold against the real thing.
 */
(function (G) {
  'use strict';
  function encode(str) {
    var out = [];
    for (var i = 0; i < str.length; i++) {
      var c = str.charCodeAt(i);
      if (c >= 0xD800 && c <= 0xDBFF && i + 1 < str.length) {
        var d = str.charCodeAt(i + 1);
        if (d >= 0xDC00 && d <= 0xDFFF) { c = 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00); i++; }
        else c = 0xFFFD;
      } else if (c >= 0xD800 && c <= 0xDFFF) c = 0xFFFD;
      if (c < 0x80) out.push(c);
      else if (c < 0x800) out.push(0xC0 | (c >> 6), 0x80 | (c & 63));
      else if (c < 0x10000) out.push(0xE0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      else out.push(0xF0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    }
    return new Uint8Array(out);
  }
  function decode(bytes) {
    var b = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || []);
    var out = '', i = 0, n = b.length;
    while (i < n) {
      var c = b[i], need = 0, cp = 0, min = 0;
      if (c < 0x80) { out += String.fromCharCode(c); i++; continue; }
      else if (c >= 0xC2 && c <= 0xDF) { need = 1; cp = c & 0x1F; min = 0x80; }
      else if (c >= 0xE0 && c <= 0xEF) { need = 2; cp = c & 0x0F; min = 0x800; }
      else if (c >= 0xF0 && c <= 0xF4) { need = 3; cp = c & 0x07; min = 0x10000; }
      else { out += '�'; i++; continue; }
      var j = 1, ok = true;
      for (; j <= need; j++) {
        if (i + j >= n) { ok = false; break; }
        var x = b[i + j];
        // the second byte's range is narrower for a few leads (no overlongs, no surrogates)
        var lo = 0x80, hi = 0xBF;
        if (j === 1) {
          if (c === 0xE0) lo = 0xA0; else if (c === 0xED) hi = 0x9F;
          else if (c === 0xF0) lo = 0x90; else if (c === 0xF4) hi = 0x8F;
        }
        if (x < lo || x > hi) { ok = false; break; }
        cp = (cp << 6) | (x & 0x3F);
      }
      if (!ok || cp < min) { out += '�'; i += Math.max(1, j); continue; }
      if (cp >= 0x10000) { cp -= 0x10000; out += String.fromCharCode(0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF)); }
      else out += String.fromCharCode(cp);
      i += need + 1;
    }
    return out;
  }
  function Enc() {}
  Enc.prototype.encode = function (s) { return encode(String(s === undefined ? '' : s)); };
  function Dec() {}
  Dec.prototype.decode = function (b) { return decode(b); };
  G.MiddawUTF8 = { TextEncoder: Enc, TextDecoder: Dec };
  if (typeof G.TextEncoder === 'undefined') G.TextEncoder = Enc;
  if (typeof G.TextDecoder === 'undefined') G.TextDecoder = Dec;
})(typeof globalThis !== 'undefined' ? globalThis : this);


/* ---- kit/runtime/lua_parse.js ---- */
/* Middaw's Lua 5.4, part 1 of 3: the lexer and the parser.
 *
 * Middaw runs the family's Lua engines (Good Idea, Midi Suggester, Midi
 * Variator, Midi Catalogue, Starting Blocks, DAW Battle Pass...) unchanged, in
 * the browser, with no third-party code: this file reads Lua source into a
 * syntax tree, lua_compile.js turns the tree into JavaScript, lua_runtime.js
 * supplies the values and the standard library. tests/js/test_lua.js holds
 * all three to what the real Lua 5.4 prints for the same programs.
 *
 * Source is a "byte string": one JS character per byte of the file, which is
 * how Lua itself sees a string, so `#s` and string.sub count bytes as Lua does.
 */
(function (NS) {
  'use strict';

  var KEYWORDS = {};
  ('and break do else elseif end false for function goto if in local nil not ' +
   'or repeat return then true until while').split(' ').forEach(function (k) { KEYWORDS[k] = true; });

  function LuaSyntaxError(message, chunk, line) {
    this.message = chunk + ':' + line + ': ' + message;
    this.line = line;
  }
  LuaSyntaxError.prototype = Object.create(Error.prototype);
  LuaSyntaxError.prototype.name = 'LuaSyntaxError';

  function isDigit(c) { return c >= 48 && c <= 57; }
  function isHex(c) { return isDigit(c) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70); }
  function isAlpha(c) { return (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c === 95; }
  function isSpace(c) { return c === 32 || (c >= 9 && c <= 13); }

  // ---------------------------------------------------------------- lexer --
  function lex(src, chunk) {
    var toks = [];
    var i = 0, n = src.length, line = 1;
    function err(msg) { throw new LuaSyntaxError(msg, chunk, line); }
    function longBracketLevel(at) {   // at points to '['; returns level or -1
      var j = at + 1, level = 0;
      while (src.charCodeAt(j) === 61) { level++; j++; }
      return src.charCodeAt(j) === 91 ? level : -1;
    }
    function readLong(at, level) {    // returns [content, end index]
      var start = at + level + 2;
      // a newline straight after the opening bracket is skipped
      if (src[start] === '\r') { start++; if (src[start] === '\n') start++; }
      else if (src[start] === '\n') { start++; if (src[start] === '\r') start++; }
      var close = ']' + '='.repeat(level) + ']';
      var end = src.indexOf(close, start);
      if (end < 0) err('unfinished long string');
      var body = src.slice(start, end);
      for (var k = at; k < end + close.length; k++) if (src.charCodeAt(k) === 10) line++;
      return [body, end + close.length];
    }
    while (i < n) {
      var c = src.charCodeAt(i);
      if (c === 10) { line++; i++; continue; }
      if (isSpace(c)) { i++; continue; }
      if (c === 45 && src.charCodeAt(i + 1) === 45) {           // comment
        i += 2;
        if (src.charCodeAt(i) === 91) {
          var lvl = longBracketLevel(i);
          if (lvl >= 0) { i = readLong(i, lvl)[1]; continue; }
        }
        while (i < n && src.charCodeAt(i) !== 10) i++;
        continue;
      }
      var tline = line;
      if (isAlpha(c)) {
        var j = i + 1;
        while (j < n && (isAlpha(src.charCodeAt(j)) || isDigit(src.charCodeAt(j)))) j++;
        var word = src.slice(i, j);
        toks.push(KEYWORDS[word] ? { t: word, line: tline } : { t: 'name', v: word, line: tline });
        i = j; continue;
      }
      if (isDigit(c) || (c === 46 && isDigit(src.charCodeAt(i + 1)))) {
        var j2 = i, isFloat = false, text;
        if (c === 48 && (src[i + 1] === 'x' || src[i + 1] === 'X')) {
          j2 = i + 2;
          while (j2 < n) {
            var d = src.charCodeAt(j2);
            if (isHex(d) || d === 46) { if (d === 46) isFloat = true; j2++; }
            else if ((d === 112 || d === 80)) {
              isFloat = true; j2++;
              if (src[j2] === '+' || src[j2] === '-') j2++;
            } else break;
          }
        } else {
          while (j2 < n) {
            var e = src.charCodeAt(j2);
            if (isDigit(e) || e === 46) { if (e === 46) isFloat = true; j2++; }
            else if (e === 101 || e === 69) {
              isFloat = true; j2++;
              if (src[j2] === '+' || src[j2] === '-') j2++;
            } else break;
          }
        }
        text = src.slice(i, j2);
        if (j2 < n && (isAlpha(src.charCodeAt(j2)))) err("malformed number near '" + text + src[j2] + "'");
        toks.push({ t: 'number', v: text, line: tline });
        i = j2; continue;
      }
      if (c === 34 || c === 39) {                                // short string
        var q = c, out = [], k = i + 1;
        for (;;) {
          if (k >= n) err('unfinished string');
          var ch = src.charCodeAt(k);
          if (ch === q) { k++; break; }
          if (ch === 10) err('unfinished string');
          if (ch === 92) {
            var x = src[k + 1];
            k += 2;
            switch (x) {
              case 'n': out.push('\n'); break;
              case 't': out.push('\t'); break;
              case 'r': out.push('\r'); break;
              case 'a': out.push('\x07'); break;
              case 'b': out.push('\b'); break;
              case 'f': out.push('\f'); break;
              case 'v': out.push('\v'); break;
              case '\\': out.push('\\'); break;
              case '"': out.push('"'); break;
              case "'": out.push("'"); break;
              case '\n': line++; out.push('\n'); break;
              case 'x': {
                var hx = src.slice(k, k + 2);
                if (!/^[0-9a-fA-F]{2}$/.test(hx)) err('hexadecimal digit expected');
                out.push(String.fromCharCode(parseInt(hx, 16))); k += 2; break;
              }
              case 'z': {
                while (k < n && isSpace(src.charCodeAt(k))) { if (src.charCodeAt(k) === 10) line++; k++; }
                break;
              }
              case 'u': {
                if (src[k] !== '{') err("missing '{' in \\u{xxxx}");
                var close = src.indexOf('}', k);
                var cp = parseInt(src.slice(k + 1, close), 16);
                k = close + 1;
                out.push(utf8Bytes(cp)); break;
              }
              default: {
                if (x !== undefined && isDigit(x.charCodeAt(0))) {
                  var digits = x; var m = 0;
                  while (m < 2 && isDigit(src.charCodeAt(k))) { digits += src[k]; k++; m++; }
                  var val = parseInt(digits, 10);
                  if (val > 255) err('decimal escape too large');
                  out.push(String.fromCharCode(val));
                } else err('invalid escape sequence');
              }
            }
            continue;
          }
          out.push(src[k]); k++;
        }
        toks.push({ t: 'string', v: out.join(''), line: tline });
        i = k; continue;
      }
      if (c === 91) {
        var lv = longBracketLevel(i);
        if (lv >= 0) {
          var r = readLong(i, lv);
          toks.push({ t: 'string', v: r[0], line: tline });
          i = r[1]; continue;
        }
      }
      var three = src.substr(i, 3), two = src.substr(i, 2);
      if (three === '...') { toks.push({ t: '...', line: tline }); i += 3; continue; }
      if (two === '==' || two === '~=' || two === '<=' || two === '>=' || two === '//' ||
          two === '::' || two === '<<' || two === '>>' || two === '..') {
        toks.push({ t: two, line: tline }); i += 2; continue;
      }
      var one = src[i];
      if ('+-*/%^#&~|<>=(){}[];:,.'.indexOf(one) >= 0) { toks.push({ t: one, line: tline }); i++; continue; }
      err("unexpected symbol near '" + one + "'");
    }
    toks.push({ t: '<eof>', line: line });
    return toks;
  }

  function utf8Bytes(cp) {
    if (cp < 0x80) return String.fromCharCode(cp);
    if (cp < 0x800) return String.fromCharCode(0xC0 | (cp >> 6), 0x80 | (cp & 63));
    if (cp < 0x10000) return String.fromCharCode(0xE0 | (cp >> 12), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
    return String.fromCharCode(0xF0 | (cp >> 18), 0x80 | ((cp >> 12) & 63), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
  }

  // --------------------------------------------------------------- parser --
  // Binary priorities exactly as lparser.c has them: { left, right }.
  var BINARY = {
    '+': [10, 10], '-': [10, 10], '*': [11, 11], '%': [11, 11], '^': [14, 13],
    '/': [11, 11], '//': [11, 11], '&': [6, 6], '|': [4, 4], '~': [5, 5],
    '<<': [7, 7], '>>': [7, 7], '..': [9, 8],
    '==': [3, 3], '<': [3, 3], '<=': [3, 3], '~=': [3, 3], '>': [3, 3], '>=': [3, 3],
    'and': [2, 2], 'or': [1, 1]
  };
  var UNARY_PRIORITY = 12;

  function parse(src, chunk) {
    chunk = chunk || '?';
    var toks = lex(src, chunk);
    var p = 0;
    function peek() { return toks[p]; }
    function next() { return toks[p++]; }
    function check(t) { return toks[p].t === t; }
    function err(msg, tok) {
      tok = tok || toks[p];
      var near = tok.t === '<eof>' ? '<eof>' : (tok.v !== undefined ? tok.v : tok.t);
      throw new LuaSyntaxError(msg + " near '" + near + "'", chunk, tok.line);
    }
    function expect(t, what) {
      if (toks[p].t !== t) err("'" + t + "' expected" + (what ? ' (to close ' + what + ')' : ''));
      return toks[p++];
    }
    function accept(t) { if (toks[p].t === t) { p++; return true; } return false; }
    function name() {
      if (toks[p].t !== 'name') err('<name> expected');
      return toks[p++].v;
    }

    function blockFollow(withUntil) {
      var t = toks[p].t;
      return t === 'else' || t === 'elseif' || t === 'end' || t === '<eof>' || (withUntil && t === 'until');
    }

    function block() {
      var body = [];
      while (!blockFollow(true)) {
        if (check('return')) { body.push(retstat()); break; }
        var s = statement();
        if (s) body.push(s);
      }
      return body;
    }

    function retstat() {
      var tok = next();
      var exprs = [];
      if (!blockFollow(true) && !check(';')) exprs = exprlist();
      accept(';');
      return { k: 'Return', exprs: exprs, line: tok.line };
    }

    function statement() {
      var tok = peek(), line = tok.line;
      switch (tok.t) {
        case ';': next(); return null;
        case 'if': return ifstat();
        case 'while': {
          next(); var cond = expr(); expect('do'); var b = block(); expect('end', 'while');
          return { k: 'While', cond: cond, body: b, line: line };
        }
        case 'do': { next(); var b2 = block(); expect('end', 'do'); return { k: 'Do', body: b2, line: line }; }
        case 'for': return forstat();
        case 'repeat': {
          next(); var b3 = block(); expect('until', 'repeat'); var c3 = expr();
          return { k: 'Repeat', body: b3, cond: c3, line: line };
        }
        case 'function': {
          next();
          var target = { k: 'Name', name: name(), line: line }, isMethod = false;
          while (check('.') || check(':')) {
            var sep = next().t;
            var key = name();
            target = { k: 'Index', obj: target, key: { k: 'String', v: key }, line: line };
            if (sep === ':') { isMethod = true; break; }
          }
          var f = funcbody(isMethod, line);
          return { k: 'Assign', targets: [target], exprs: [f], line: line };
        }
        case 'local': {
          next();
          if (accept('function')) {
            var nm = name();
            return { k: 'LocalFunction', name: nm, func: funcbody(false, line), line: line };
          }
          var names = [], attribs = [];
          do {
            names.push(name());
            if (accept('<')) { attribs.push(name()); expect('>'); } else attribs.push(null);
          } while (accept(','));
          var exprs = accept('=') ? exprlist() : [];
          return { k: 'Local', names: names, attribs: attribs, exprs: exprs, line: line };
        }
        case '::': { next(); var label = name(); expect('::'); return { k: 'Label', name: label, line: line }; }
        case 'return': return retstat();
        case 'break': next(); return { k: 'Break', line: line };
        case 'goto': next(); return { k: 'Goto', name: name(), line: line };
        default: return exprstat();
      }
    }

    function ifstat() {
      var line = next().line;
      var clauses = [];
      var cond = expr(); expect('then');
      clauses.push({ cond: cond, body: block() });
      var orelse = null;
      for (;;) {
        if (accept('elseif')) { var c = expr(); expect('then'); clauses.push({ cond: c, body: block() }); }
        else if (accept('else')) { orelse = block(); expect('end', 'if'); break; }
        else { expect('end', 'if'); break; }
      }
      return { k: 'If', clauses: clauses, orelse: orelse, line: line };
    }

    function forstat() {
      var line = next().line;
      var n1 = name();
      if (accept('=')) {
        var start = expr(); expect(',');
        var limit = expr();
        var step = accept(',') ? expr() : null;
        expect('do'); var b = block(); expect('end', 'for');
        return { k: 'NumFor', name: n1, start: start, limit: limit, step: step, body: b, line: line };
      }
      var names = [n1];
      while (accept(',')) names.push(name());
      expect('in');
      var exprs = exprlist();
      expect('do'); var body = block(); expect('end', 'for');
      return { k: 'GenFor', names: names, exprs: exprs, body: body, line: line };
    }

    function exprstat() {
      var line = peek().line;
      var e = suffixedexp();
      if (check('=') || check(',')) {
        var targets = [e];
        while (accept(',')) targets.push(suffixedexp());
        expect('=');
        var exprs = exprlist();
        targets.forEach(function (t) { if (t.k !== 'Name' && t.k !== 'Index') err('syntax error'); });
        return { k: 'Assign', targets: targets, exprs: exprs, line: line };
      }
      if (e.k !== 'Call' && e.k !== 'Method') err('syntax error');
      return { k: 'ExprStat', expr: e, line: line };
    }

    function exprlist() {
      var list = [expr()];
      while (accept(',')) list.push(expr());
      return list;
    }

    function funcbody(isMethod, line) {
      var params = isMethod ? ['self'] : [], vararg = false;
      expect('(');
      if (!check(')')) {
        do {
          if (accept('...')) { vararg = true; break; }
          params.push(name());
        } while (accept(','));
      }
      expect(')');
      var b = block();
      var endTok = expect('end', 'function');
      return { k: 'Function', params: params, vararg: vararg, body: b, line: line, endLine: endTok.line };
    }

    function primaryexp() {
      var tok = peek();
      if (tok.t === 'name') { next(); return { k: 'Name', name: tok.v, line: tok.line }; }
      if (tok.t === '(') {
        next(); var e = expr(); expect(')');
        return { k: 'Paren', expr: e, line: tok.line };
      }
      err('unexpected symbol');
    }

    function suffixedexp() {
      var e = primaryexp();
      for (;;) {
        var tok = peek();
        switch (tok.t) {
          case '.': next(); e = { k: 'Index', obj: e, key: { k: 'String', v: name() }, line: tok.line }; break;
          case '[': next(); var key = expr(); expect(']'); e = { k: 'Index', obj: e, key: key, line: tok.line }; break;
          case ':': next(); var m = name(); e = { k: 'Method', obj: e, name: m, args: callargs(), line: tok.line }; break;
          case '(': case 'string': case '{': e = { k: 'Call', fn: e, args: callargs(), line: tok.line }; break;
          default: return e;
        }
      }
    }

    function callargs() {
      var tok = peek();
      if (tok.t === 'string') { next(); return [{ k: 'String', v: tok.v }]; }
      if (tok.t === '{') return [tablecons()];
      expect('(');
      if (accept(')')) return [];
      var args = exprlist();
      expect(')');
      return args;
    }

    function tablecons() {
      var line = expect('{').line;
      var items = [];   // { kind: 'pos'|'named'|'keyed', key, value }
      while (!check('}')) {
        if (check('name') && toks[p + 1].t === '=') {
          var key = next().v; next();
          items.push({ kind: 'keyed', key: { k: 'String', v: key }, value: expr() });
        } else if (check('[')) {
          next(); var k = expr(); expect(']'); expect('=');
          items.push({ kind: 'keyed', key: k, value: expr() });
        } else {
          items.push({ kind: 'pos', value: expr() });
        }
        if (!accept(',') && !accept(';')) break;
      }
      expect('}', 'table');
      return { k: 'Table', items: items, line: line };
    }

    function simpleexp() {
      var tok = peek();
      switch (tok.t) {
        case 'number': next(); return { k: 'Number', v: tok.v, line: tok.line };
        case 'string': next(); return { k: 'String', v: tok.v };
        case 'nil': next(); return { k: 'Nil' };
        case 'true': next(); return { k: 'True' };
        case 'false': next(); return { k: 'False' };
        case '...': next(); return { k: 'Vararg', line: tok.line };
        case '{': return tablecons();
        case 'function': next(); return funcbody(false, tok.line);
        default: return suffixedexp();
      }
    }

    function expr(limit) {
      limit = limit || 0;
      var left, tok = peek();
      if (tok.t === 'not' || tok.t === '-' || tok.t === '#' || tok.t === '~') {
        next();
        left = { k: 'Unop', op: tok.t, expr: expr(UNARY_PRIORITY), line: tok.line };
      } else {
        left = simpleexp();
      }
      for (;;) {
        var op = peek().t, pr = BINARY[op];
        if (!pr || pr[0] <= limit) break;
        var line = next().line;
        var right = expr(pr[1]);
        left = { k: 'Binop', op: op, left: left, right: right, line: line };
      }
      return left;
    }

    var body = block();
    if (!check('<eof>')) err("'<eof>' expected");
    return { k: 'Chunk', body: body };
  }

  NS.lex = lex;
  NS.parse = parse;
  NS.LuaSyntaxError = LuaSyntaxError;
  NS.utf8Bytes = utf8Bytes;
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawLua = globalThis.MiddawLua || {}))
  : (globalThis.MiddawLua = globalThis.MiddawLua || {}));


/* ---- kit/runtime/lua_runtime.js ---- */
/* Middaw's Lua 5.4, part 3 of 3: values, operators and the standard library.
 *
 * Values, as JavaScript sees them:
 *   nil      undefined
 *   boolean  true / false
 *   number   a JS number. An integral JS number is a Lua *integer*; a
 *            non-integral one (or inf, nan) is a Lua *float*. A float whose
 *            value happens to be integral (4.0, 2/2) is an LFloat, so that it
 *            still prints "4.0" and math.type still says "float".
 *   string   a JS string with one character per byte (0-255)
 *   table    LuaTable
 *   function a JS function: Lua arguments in, and undefined, one value, or a
 *            Multi for two or more results.
 *
 * Wherever the result has to match the real Lua byte for byte - table.sort
 * with ties, the pattern matcher, math.random, number formatting - the code
 * is a port of Lua 5.4's own C, not a lookalike.
 */
(function (NS) {
  'use strict';

  // ------------------------------------------------------------ values ----
  function LFloat(n) { this.n = n; }
  LFloat.prototype.valueOf = function () { return this.n; };

  function mkf(x) { return Number.isInteger(x) ? new LFloat(x) : x; }
  function isNum(v) { return typeof v === 'number' || v instanceof LFloat; }
  function num(v) { return typeof v === 'number' ? v : v.n; }
  function isFloatVal(v) { return v instanceof LFloat || (typeof v === 'number' && !Number.isInteger(v)); }

  function Multi(a) { this.a = a; }
  function first(v) { return v instanceof Multi ? v.a[0] : v; }
  // `return` with no values gives NONE; a bare undefined is one nil.
  var NONE = new Multi([]);
  var NIL1 = Object.freeze([undefined]);
  function sp(v) {
    if (v instanceof Multi) return v.a;
    return v === undefined ? NIL1 : [v];
  }
  function ret(list) {
    if (list.length === 0) return NONE;
    if (list.length === 1) return list[0];
    return new Multi(list);
  }

  var tableIds = 0;
  function LuaTable() { this.arr = []; this.hash = null; this.mt = null; this.id = 0; this.hver = 0; }
  LuaTable.prototype.get = function (k) {
    if (typeof k === 'number') {
      var a = this.arr;
      if (k > 0 && k <= a.length && Number.isInteger(k)) return a[k - 1];
    } else if (typeof k === 'string') {
      return this.hash === null ? undefined : this.hash.get(k);
    } else if (k instanceof LFloat) {
      return this.get(k.n);
    }
    return this.hash === null ? undefined : this.hash.get(k);
  };
  LuaTable.prototype.set = function (k, v) {
    if (typeof k === 'number') {
      if (Number.isInteger(k) && k > 0) {
        var a = this.arr, n = a.length;
        if (k <= n) {
          a[k - 1] = v;
          if (v === undefined && k === n) { while (a.length && a[a.length - 1] === undefined) a.pop(); }
          return;
        }
        if (k === n + 1) {
          if (v === undefined) { if (this.hash !== null) this.hash.delete(k); return; }
          a.push(v);
          if (this.hash !== null && this.hash.size) {
            var h = this.hash;
            while (h.has(a.length + 1)) { var nk = a.length + 1; a.push(h.get(nk)); h.delete(nk); }
          }
          return;
        }
      } else if (k !== k) {
        throw rterror('table index is NaN');
      }
    } else if (k instanceof LFloat) {
      return this.set(k.n, v);
    } else if (k === undefined) {
      throw rterror('table index is nil');
    }
    if (v === undefined) { if (this.hash !== null) this.hash.delete(k); return; }
    if (this.hash === null) this.hash = new Map();
    if (!this.hash.has(k)) this.hver++;
    this.hash.set(k, v);
  };
  LuaTable.prototype.length = function () { return this.arr.length; };

  // ------------------------------------------------------------ errors ----
  // Compiled chunks register their line maps here, so an error can say
  // "gi_idea.lua:1234:" as the real Lua would.
  var lineMaps = {};
  function luaPosition(level) {
    var stack = new Error().stack || '';
    var re = /lua:([^:\s()]+):(\d+):\d+/g, m, found = 0;
    while ((m = re.exec(stack)) !== null) {
      found++;
      if (found >= level) {
        var map = lineMaps[m[1]];
        var line = map ? map[Number(m[2]) - 1] : undefined;
        if (line) return m[1] + ':' + line + ': ';
        return m[1] + ': ';
      }
    }
    return '';
  }
  function LuaError(value, traceback) {
    this.value = value;
    this.message = typeof value === 'string' ? value : tostring(value);
    this.luaTraceback = traceback;
    this.stack = new Error().stack;
  }
  LuaError.prototype = Object.create(Error.prototype);
  LuaError.prototype.name = 'LuaError';
  function rterror(msg) { return new LuaError(luaPosition(1) + msg); }

  function typeName(v) {
    if (v === undefined || v === null) return 'nil';
    switch (typeof v) {
      case 'boolean': return 'boolean';
      case 'number': return 'number';
      case 'string': return 'string';
      case 'function': return 'function';
    }
    if (v instanceof LFloat) return 'number';
    if (v instanceof LuaTable) return 'table';
    return 'userdata';
  }

  // --------------------------------------------------------- numbers ----
  // Exact decimal expansion of a double: x = D * 10^-s, D a BigInt.
  var F64 = new Float64Array(1), U32 = new Uint32Array(F64.buffer);
  function exactDecimal(x) {
    F64[0] = x;
    var hi = U32[1], lo = U32[0];
    var exp = (hi >>> 20) & 0x7ff;
    var mant = (BigInt(hi & 0xfffff) << 32n) | BigInt(lo);
    if (exp === 0) exp = 1; else mant |= 1n << 52n;
    var e = exp - 1075;
    if (e >= 0) return { D: mant << BigInt(e), s: 0 };
    return { D: mant * (5n ** BigInt(-e)), s: -e };
  }
  function roundDiv(N, div) {      // round N/div half to even
    var q = N / div, r = N % div;
    var twice = r * 2n;
    if (twice > div || (twice === div && (q & 1n) === 1n)) q += 1n;
    return q;
  }
  function fixedDigits(x, f) {     // |x| to f decimals, C-exact; returns string
    var ex = exactDecimal(Math.abs(x));
    var q;
    if (f >= ex.s) q = ex.D * (10n ** BigInt(f - ex.s));
    else q = roundDiv(ex.D, 10n ** BigInt(ex.s - f));
    var s = q.toString();
    if (f === 0) return s;
    while (s.length <= f) s = '0' + s;
    return s.slice(0, s.length - f) + '.' + s.slice(s.length - f);
  }
  function expDigits(x, prec) {    // |x| as d.ddd with prec decimals; returns [mantissa, exponent]
    if (x === 0) return [prec > 0 ? '0.' + '0'.repeat(prec) : '0', 0];
    var ex = exactDecimal(Math.abs(x));
    var D = ex.D.toString();
    var X = D.length - 1 - ex.s;
    var P = prec + 1, q;
    if (D.length > P) {
      q = roundDiv(ex.D, 10n ** BigInt(D.length - P)).toString();
      if (q.length > P) { q = q.slice(0, P); X++; }
    } else q = D + '0'.repeat(P - D.length);
    return [prec > 0 ? q[0] + '.' + q.slice(1) : q, X];
  }
  function fmtExp(x, prec, upper) {
    var r = expDigits(x, prec);
    var X = r[1];
    var s = r[0] + (upper ? 'E' : 'e') + (X < 0 ? '-' : '+') + (Math.abs(X) < 10 ? '0' : '') + Math.abs(X);
    return s;
  }
  function stripZeros(s) {
    if (s.indexOf('.') < 0) return s;
    s = s.replace(/0+$/, '');
    return s.replace(/\.$/, '');
  }
  function fmtG(x, P, upper, alt) {   // C's %g of |x|
    if (P === 0) P = 1;
    if (x === 0) return '0';
    var X = expDigits(x, P - 1)[1];
    var s;
    if (X < -4 || X >= P) {
      var r = expDigits(x, P - 1);
      var m = alt ? r[0] : stripZeros(r[0]);
      s = m + (upper ? 'E' : 'e') + (r[1] < 0 ? '-' : '+') + (Math.abs(r[1]) < 10 ? '0' : '') + Math.abs(r[1]);
    } else {
      s = fixedDigits(x, P - 1 - X);
      if (!alt) s = stripZeros(s);
    }
    return s;
  }
  function floatStr(x) {
    if (x === Infinity) return 'inf';
    if (x === -Infinity) return '-inf';
    if (x !== x) return (1 / x) < 0 ? 'nan' : '-nan';
    var neg = x < 0 || (x === 0 && 1 / x < 0);
    var s = (neg ? '-' : '') + fmtG(x, 14, false, false);
    if (/^-?\d+$/.test(s)) s += '.0';
    return s;
  }
  function intStr(n) {
    if (Math.abs(n) <= 9007199254740992) return String(n === 0 ? 0 : n);
    return BigInt(n).toString();
  }
  // io.write prints a float with LUA_NUMBER_FMT alone: 1.0 is "1".
  function writeNum(v) {
    if (!isNum(v)) throw rterror('bad argument to \'write\' (string expected, got ' + typeName(v) + ')');
    if (typeof v === 'number' && Number.isInteger(v)) return intStr(v);
    var x = num(v);
    if (x === Infinity) return 'inf';
    if (x === -Infinity) return '-inf';
    if (x !== x) return '-nan';
    return (x < 0 || (x === 0 && 1 / x < 0) ? '-' : '') + fmtG(Math.abs(x), 14, false, false);
  }
  function numStr(v) {
    if (typeof v === 'number') return Number.isInteger(v) ? intStr(v) : floatStr(v);
    return floatStr(v.n);
  }

  // lua_stringtonumber: a whole numeral, spaces either side, or undefined.
  function str2num(s) {
    var t = s.replace(/^[ \f\n\r\t\v]+|[ \f\n\r\t\v]+$/g, '');
    var m;
    if ((m = /^([+-])?0[xX]([0-9a-fA-F]*)(?:\.([0-9a-fA-F]*))?(?:[pP]([+-]?\d+))?$/.exec(t))) {
      var ip = m[2], fp = m[3], ex = m[4];
      if (!ip && !fp) return undefined;
      var neg = m[1] === '-';
      if (fp === undefined && ex === undefined) {
        var big = BigInt.asIntN(64, BigInt('0x' + ip));
        var n = Number(big);
        return neg ? 0 - n : n;
      }
      var val = 0;
      for (var i = 0; i < ip.length; i++) val = val * 16 + parseInt(ip[i], 16);
      var scale = 1 / 16;
      fp = fp || '';
      for (var j = 0; j < fp.length; j++) { val += parseInt(fp[j], 16) * scale; scale /= 16; }
      if (ex) val *= Math.pow(2, Number(ex));
      return mkf(neg ? -val : val);
    }
    if ((m = /^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.exec(t))) {
      var isInt = m[1].indexOf('.') < 0 && !m[2];
      var v = Number(t);
      if (isInt) {
        if (Math.abs(v) <= 9223372036854775807) return v;
        return mkf(v);
      }
      return mkf(v);
    }
    return undefined;
  }

  function toNumberArith(v, op) {
    if (typeof v === 'number') return v;
    if (v instanceof LFloat) return v;
    if (typeof v === 'string') { var n = str2num(v); if (n !== undefined) return n; }
    return null;
  }
  function arithError(op, a, b) {
    var bad = (isNum(a) || (typeof a === 'string' && str2num(a) !== undefined)) ? b : a;
    if (op === 'concat') return rterror('attempt to concatenate a ' + typeName(bad) + ' value');
    if (op === 'bit') return rterror('attempt to perform bitwise operation on a ' + typeName(bad) + ' value');
    return rterror('attempt to perform arithmetic on a ' + typeName(bad) + ' value');
  }
  function metaOf(v) {
    if (v instanceof LuaTable) return v.mt;
    if (typeof v === 'string') return stringMeta;
    return null;
  }
  function metaBin(ev, a, b) {
    var mt = metaOf(a), h = mt && mt.get(ev);
    if (h === undefined) { mt = metaOf(b); h = mt && mt.get(ev); }
    if (h === undefined || h === null) return NOMETA;
    return first(call(h)(a, b));
  }
  var NOMETA = {};

  function arithSlow(op, a, b, ev) {
    var x = toNumberArith(a), y = toNumberArith(b);
    if (x === null || y === null) {
      var r = metaBin(ev, a, b);
      if (r !== NOMETA) return r;
      throw arithError(op, a, b);
    }
    switch (op) {
      case 'add': return add(x, y);
      case 'sub': return sub(x, y);
      case 'mul': return mul(x, y);
      case 'div': return div(x, y);
      case 'mod': return mod(x, y);
      case 'idiv': return idiv(x, y);
      case 'pow': return pow(x, y);
    }
  }
  function add(a, b) {
    if (typeof a === 'number' && typeof b === 'number') {
      var r = a + b;
      return (Number.isInteger(a) && Number.isInteger(b)) ? r : mkf(r);
    }
    if (isNum(a) && isNum(b)) return mkf(num(a) + num(b));
    return arithSlow('add', a, b, '__add');
  }
  function sub(a, b) {
    if (typeof a === 'number' && typeof b === 'number') {
      var r = a - b;
      return (Number.isInteger(a) && Number.isInteger(b)) ? r : mkf(r);
    }
    if (isNum(a) && isNum(b)) return mkf(num(a) - num(b));
    return arithSlow('sub', a, b, '__sub');
  }
  function mul(a, b) {
    if (typeof a === 'number' && typeof b === 'number') {
      var r = a * b;
      if (Number.isInteger(a) && Number.isInteger(b)) return r === 0 ? 0 : r;
      return mkf(r);
    }
    if (isNum(a) && isNum(b)) return mkf(num(a) * num(b));
    return arithSlow('mul', a, b, '__mul');
  }
  function div(a, b) {
    if (isNum(a) && isNum(b)) return mkf(num(a) / num(b));
    return arithSlow('div', a, b, '__div');
  }
  function idiv(a, b) {
    if (typeof a === 'number' && typeof b === 'number' && Number.isInteger(a) && Number.isInteger(b)) {
      if (b === 0) throw rterror("attempt to perform 'n//0'");
      var q = Math.floor(a / b);
      return q === 0 ? 0 : q;
    }
    if (isNum(a) && isNum(b)) return mkf(Math.floor(num(a) / num(b)));
    return arithSlow('idiv', a, b, '__idiv');
  }
  function mod(a, b) {
    if (typeof a === 'number' && typeof b === 'number' && Number.isInteger(a) && Number.isInteger(b)) {
      if (b === 0) throw rterror("attempt to perform 'n%%0'");
      var r = a % b;
      if (r !== 0 && (r < 0) !== (b < 0)) r += b;
      return r === 0 ? 0 : r;
    }
    if (isNum(a) && isNum(b)) {
      var x = num(a), y = num(b);
      var m;
      if (y === Infinity || y === -Infinity) m = x;
      else m = x % y;
      if ((m > 0) ? y < 0 : (m < 0 && y !== m)) m += y;
      return mkf(m);
    }
    return arithSlow('mod', a, b, '__mod');
  }
  function pow(a, b) {
    if (isNum(a) && isNum(b)) return mkf(Math.pow(num(a), num(b)));
    return arithSlow('pow', a, b, '__pow');
  }
  function unm(a) {
    if (typeof a === 'number') return Number.isInteger(a) ? 0 - a : -a;
    if (a instanceof LFloat) return new LFloat(-a.n);
    var x = toNumberArith(a);
    if (x !== null) return unm(x);
    var mt = metaOf(a), h = mt && mt.get('__unm');
    if (h !== undefined && h !== null) return first(call(h)(a, a));
    throw rterror('attempt to perform arithmetic on a ' + typeName(a) + ' value');
  }

  // Bitwise operations work on 64-bit integers.
  function toInt64(v, a, b) {
    var x = typeof v === 'string' ? str2num(v) : v;
    if (typeof x === 'number' && Number.isInteger(x)) return BigInt(x);
    if (x instanceof LFloat) return BigInt(x.n);
    if (typeof x === 'number') throw rterror('number has no integer representation');
    throw arithError('bit', a, b);
  }
  function fromInt64(big) { return Number(BigInt.asIntN(64, big)); }
  function small(a, b) {
    return typeof a === 'number' && typeof b === 'number' && (a | 0) === a && (b | 0) === b;
  }
  function band(a, b) { if (small(a, b)) return a & b; return bitSlow('__band', a, b, function (x, y) { return x & y; }); }
  function bor(a, b) { if (small(a, b)) return a | b; return bitSlow('__bor', a, b, function (x, y) { return x | y; }); }
  function bxor(a, b) { if (small(a, b)) return a ^ b; return bitSlow('__bxor', a, b, function (x, y) { return x ^ y; }); }
  function shiftLeft(x, n) {
    if (n <= -64n || n >= 64n) return 0n;
    if (n >= 0n) return BigInt.asUintN(64, x << n);
    return BigInt.asUintN(64, x) >> (-n);
  }
  function shl(a, b) { return bitSlow('__shl', a, b, function (x, y) { return shiftLeft(x, y); }); }
  function shr(a, b) { return bitSlow('__shr', a, b, function (x, y) { return shiftLeft(x, -y); }); }
  function bnot(a) {
    if (typeof a === 'number' && (a | 0) === a) return ~a;
    var mt = metaOf(a), h = mt && mt.get('__bnot');
    if (h !== undefined && h !== null && !isNum(a)) return first(call(h)(a, a));
    return fromInt64(~toInt64(a, a, a));
  }
  function bitSlow(ev, a, b, f) {
    if (!((isNum(a) || typeof a === 'string') && (isNum(b) || typeof b === 'string'))) {
      var r = metaBin(ev, a, b);
      if (r !== NOMETA) return r;
    }
    return fromInt64(f(toInt64(a, a, b), toInt64(b, a, b)));
  }

  function concat(a, b) {
    var ta = typeof a, tb = typeof b;
    if (ta === 'string' && tb === 'string') return a + b;
    if ((ta === 'string' || isNum(a)) && (tb === 'string' || isNum(b))) {
      return (ta === 'string' ? a : numStr(a)) + (tb === 'string' ? b : numStr(b));
    }
    var r = metaBin('__concat', a, b);
    if (r !== NOMETA) return r;
    throw arithError('concat', a, b);
  }

  function len(v) {
    if (typeof v === 'string') return v.length;
    if (v instanceof LuaTable) {
      if (v.mt !== null) {
        var h = v.mt.get('__len');
        if (h !== undefined) return first(call(h)(v));
      }
      return v.arr.length;
    }
    var mt = metaOf(v), h2 = mt && mt.get('__len');
    if (h2 !== undefined && h2 !== null) return first(call(h2)(v));
    throw rterror('attempt to get length of a ' + typeName(v) + ' value');
  }

  function eq(a, b) {
    if (a === b) return true;
    var ta = typeof a, tb = typeof b;
    if (ta === 'object' || tb === 'object') {
      if (isNum(a) && isNum(b)) return num(a) === num(b);
      if (a instanceof LuaTable && b instanceof LuaTable) {
        var h = (a.mt && a.mt.get('__eq')) || (b.mt && b.mt.get('__eq'));
        if (h) return truthy(first(call(h)(a, b)));
      }
    }
    return false;
  }
  function lt(a, b) {
    if (typeof a === 'number' && typeof b === 'number') return a < b;
    if (isNum(a) && isNum(b)) return num(a) < num(b);
    if (typeof a === 'string' && typeof b === 'string') return a < b;
    var r = metaBin('__lt', a, b);
    if (r !== NOMETA) return truthy(r);
    throw compareError(a, b);
  }
  function le(a, b) {
    if (typeof a === 'number' && typeof b === 'number') return a <= b;
    if (isNum(a) && isNum(b)) return num(a) <= num(b);
    if (typeof a === 'string' && typeof b === 'string') return a <= b;
    var r = metaBin('__le', a, b);
    if (r !== NOMETA) return truthy(r);
    throw compareError(a, b);
  }
  function gt(a, b) { return lt(b, a); }
  function ge(a, b) { return le(b, a); }
  function compareError(a, b) {
    var t1 = typeName(a), t2 = typeName(b);
    if (t1 === t2) return rterror('attempt to compare two ' + t1 + ' values');
    return rterror('attempt to compare ' + t1 + ' with ' + t2);
  }
  function truthy(v) { return v !== undefined && v !== false && v !== null; }

  // ------------------------------------------------------- indexing ----
  function index(o, k, desc) {
    if (o instanceof LuaTable) {
      var v = o.get(k);
      if (v !== undefined || o.mt === null) return v;
      return metaIndex(o, k, desc);
    }
    if (typeof o === 'string') return stringLib.get(k);
    return metaIndex(o, k, desc);
  }
  function metaIndex(o, k, desc) {
    for (var loop = 0; loop < 100; loop++) {
      var h;
      if (o instanceof LuaTable) {
        var v = o.get(k);
        if (v !== undefined) return v;
        if (o.mt === null) return undefined;
        h = o.mt.get('__index');
        if (h === undefined) return undefined;
      } else {
        var mt = metaOf(o);
        h = mt && mt.get('__index');
        if (h === undefined || h === null) {
          throw rterror('attempt to index a ' + typeName(o) + ' value' + (desc ? ' (' + desc + ')' : ''));
        }
      }
      if (typeof h === 'function') return first(h(o, k));
      o = h;
    }
    throw rterror("'__index' chain too long; possible loop");
  }
  function setindex(o, k, v, desc) {
    if (o instanceof LuaTable) {
      if (o.mt === null) { o.set(k, v); return; }
      var h = o.mt.get('__newindex');
      if (h === undefined || o.get(k) !== undefined) { o.set(k, v); return; }
      if (typeof h === 'function') { h(o, k, v); return; }
      return setindex(h, k, v);
    }
    throw rterror('attempt to index a ' + typeName(o) + ' value' + (desc ? ' (' + desc + ')' : ''));
  }

  function call(f, desc) {
    if (typeof f === 'function') return f;
    var mt = metaOf(f), h = mt && mt.get('__call');
    if (typeof h === 'function') return function () {
      var args = [f];
      for (var i = 0; i < arguments.length; i++) args.push(arguments[i]);
      return h.apply(null, args);
    };
    throw rterror('attempt to call a ' + typeName(f) + ' value' + (desc ? ' (' + desc + ')' : ''));
  }
  function method(o, name) {
    var f = index(o, name, 'method \'' + name + '\'');
    if (typeof f !== 'function') f = call(f, "method '" + name + "'");
    var args = [o];
    for (var i = 2; i < arguments.length; i++) args.push(arguments[i]);
    return f.apply(null, args);
  }

  function tbl(list, keyed) {
    var t = new LuaTable();
    if (list.length) {
      var a = list.slice();
      while (a.length && a[a.length - 1] === undefined) a.pop();
      t.arr = a;
    }
    if (keyed) {
      for (var i = 0; i < keyed.length; i += 2) {
        if (keyed[i] === undefined) throw rterror('table index is nil');
        if (keyed[i + 1] !== undefined) t.set(keyed[i], keyed[i + 1]);
      }
    }
    return t;
  }

  // ------------------------------------------------------- iteration ----
  function IpairsIter(t) { this.t = t; this.i = 0; this.a = undefined; this.b = undefined; }
  IpairsIter.prototype.step = function () {
    var i = this.i + 1, v = this.t.get(i);
    if (v === undefined) return false;
    this.i = i; this.a = i; this.b = v; return true;
  };
  function PairsIter(t) { this.t = t; this.i = 0; this.it = null; this.a = undefined; this.b = undefined; }
  PairsIter.prototype.step = function () {
    var arr = this.t.arr;
    while (this.it === null && this.i < arr.length) {
      var v = arr[this.i++];
      if (v !== undefined) { this.a = this.i; this.b = v; return true; }
    }
    if (this.it === null) {
      if (this.t.hash === null) return false;
      this.it = this.t.hash.entries();
    }
    var n = this.it.next();
    if (n.done) return false;
    this.a = n.value[0]; this.b = n.value[1];
    return true;
  };
  function GenIter(f, s, c) { this.f = call(f, 'for iterator'); this.s = s; this.c = c; this.a = undefined; this.b = undefined; this.v = NONE; }
  GenIter.prototype.step = function () {
    var r = this.f(this.s, this.c);
    var v = r instanceof Multi ? r.a : [r];
    if (v[0] === undefined) return false;
    this.c = v[0]; this.a = v[0]; this.b = v[1]; this.v = v;
    return true;
  };
  function iter(f, s, c) {
    if (f === ipairsAux && s instanceof LuaTable && s.mt === null) return new IpairsIter(s);
    if (f === luaNext && s instanceof LuaTable && c === undefined && s.mt === null) return new PairsIter(s);
    return new GenIter(f, s, c);
  }

  function forprep(a, b, c) {
    if (c === undefined) c = 1;
    if (!isNum(a)) throw rterror("'for' initial value must be a number");
    if (!isNum(b)) throw rterror("'for' limit must be a number");
    if (!isNum(c)) throw rterror("'for' step must be a number");
    var x = num(a), lim = num(b), st = num(c);
    if (st === 0) throw rterror("'for' step is zero");
    var intLoop = typeof a === 'number' && Number.isInteger(a) && typeof c === 'number' && Number.isInteger(c);
    if (intLoop) {
      if (!(typeof b === 'number' && Number.isInteger(b))) {
        if (lim !== lim) return [1, 0, 1, false];
        lim = st > 0 ? Math.floor(lim) : Math.ceil(lim);
      }
      return [x, lim, st, false];
    }
    return [x, lim, st, true];
  }

  // ------------------------------------------------------- tostring ----
  function tostring(v) {
    if (v === undefined || v === null) return 'nil';
    switch (typeof v) {
      case 'string': return v;
      case 'number': return numStr(v);
      case 'boolean': return v ? 'true' : 'false';
      case 'function': return 'function: ' + addressOf(v);
    }
    if (v instanceof LFloat) return floatStr(v.n);
    if (v instanceof LuaTable) {
      if (v.mt !== null) {
        var h = v.mt.get('__tostring');
        if (h !== undefined) {
          var s = first(call(h)(v));
          if (typeof s !== 'string') throw rterror("'__tostring' must return a string");
          return s;
        }
        var nm = v.mt.get('__name');
        if (typeof nm === 'string') return nm + ': ' + addressOf(v);
      }
      return 'table: ' + addressOf(v);
    }
    return 'userdata: ' + addressOf(v);
  }
  var addresses = new WeakMap(), nextAddress = 0x55d0c0de0000;
  function addressOf(o) {
    var a = addresses.get(o);
    if (a === undefined) { a = nextAddress; nextAddress += 0x40; addresses.set(o, a); }
    return '0x' + a.toString(16).padStart(14, '0');
  }

  // ===================================================== the library ======
  function argError(n, fname, msg) { return rterror("bad argument #" + n + " to '" + fname + "' (" + msg + ')'); }
  function checkTable(v, n, fname) {
    if (!(v instanceof LuaTable)) throw argError(n, fname, 'table expected, got ' + typeNameArg(v));
    return v;
  }
  function typeNameArg(v) { return v === undefined ? 'no value' : typeName(v); }
  function checkInt(v, n, fname) {
    if (typeof v === 'number' && Number.isInteger(v)) return v;
    if (v instanceof LFloat) return v.n;
    if (typeof v === 'string') { var x = str2num(v); if (x !== undefined) return checkInt(x, n, fname); }
    if (typeof v === 'number') throw argError(n, fname, 'number has no integer representation');
    throw argError(n, fname, 'number expected, got ' + typeNameArg(v));
  }
  function optInt(v, n, fname, d) { return v === undefined ? d : checkInt(v, n, fname); }
  function checkNum(v, n, fname) {
    if (typeof v === 'number') return v;
    if (v instanceof LFloat) return v.n;
    if (typeof v === 'string') { var x = str2num(v); if (x !== undefined) return num(x); }
    throw argError(n, fname, 'number expected, got ' + typeNameArg(v));
  }
  function checkStr(v, n, fname) {
    if (typeof v === 'string') return v;
    if (isNum(v)) return numStr(v);
    throw argError(n, fname, 'string expected, got ' + typeNameArg(v));
  }

  function rawLen(t) { return t instanceof LuaTable ? t.arr.length : (typeof t === 'string' ? t.length : 0); }

  // ---------------------------------------------------------- base ------
  function luaNext(t, k) {
    checkTable(t, 1, 'next');
    var arr = t.arr, i = 0;
    if (k !== undefined) {
      if (typeof k === 'number' && Number.isInteger(k) && k >= 1 && k <= arr.length) i = k;
      else if (k instanceof LFloat && k.n >= 1 && k.n <= arr.length) i = k.n;
      else i = -1;
    }
    if (i >= 0) {
      for (; i < arr.length; i++) if (arr[i] !== undefined) return new Multi([i + 1, arr[i]]);
      if (t.hash === null) return undefined;
      var it = t.hash.entries().next();
      return it.done ? undefined : new Multi([it.value[0], it.value[1]]);
    }
    if (t.hash === null) throw rterror("invalid key to 'next'");
    if (t._nkver !== t.hver || !t._nk) {
      t._nk = Array.from(t.hash.keys());
      t._nki = new Map();
      for (var j = 0; j < t._nk.length; j++) t._nki.set(t._nk[j], j);
      t._nkver = t.hver;
    }
    var key = k instanceof LFloat ? k.n : k;
    var pos = t._nki.get(key);
    if (pos === undefined) throw rterror("invalid key to 'next'");
    for (pos++; pos < t._nk.length; pos++) {
      var kk = t._nk[pos];
      if (t.hash.has(kk)) return new Multi([kk, t.hash.get(kk)]);
    }
    return undefined;
  }
  function ipairsAux(t, i) {
    i = i + 1;
    var v = index(t, i);
    return v === undefined ? undefined : new Multi([i, v]);
  }

  function makeEnv(host) {
    host = host || {};
    var G = new LuaTable();
    function reg(t, name, f) { t.set(name, f); }

    reg(G, 'print', function () {
      var parts = [];
      for (var i = 0; i < arguments.length; i++) parts.push(tostring(arguments[i]));
      (host.print || function (s) { console.log(s); })(parts.join('\t'));
      return NONE;
    });
    reg(G, 'type', function (v) {
      if (arguments.length === 0) throw argError(1, 'type', 'value expected');
      return typeName(v);
    });
    reg(G, 'tostring', function (v) { return tostring(v); });
    reg(G, 'tonumber', function (v, base) {
      if (base === undefined) {
        if (isNum(v)) return v;
        if (typeof v === 'string') return str2num(v);
        if (arguments.length === 0) throw argError(1, 'tonumber', 'value expected');
        return undefined;
      }
      var b = checkInt(base, 2, 'tonumber');
      var s = checkStr(v, 1, 'tonumber').replace(/^\s+|\s+$/g, '').toLowerCase();
      var neg = false;
      if (s[0] === '-') { neg = true; s = s.slice(1); }
      if (!s.length) return undefined;
      var n = 0;
      for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        var d = c >= 48 && c <= 57 ? c - 48 : (c >= 97 && c <= 122 ? c - 87 : 99);
        if (d >= b) return undefined;
        n = n * b + d;
      }
      return neg ? -n : n;
    });
    reg(G, 'ipairs', function (t) {
      if (arguments.length === 0) throw argError(1, 'ipairs', 'table expected, got no value');
      return new Multi([ipairsAux, t, 0]);
    });
    reg(G, 'pairs', function (t) {
      if (t instanceof LuaTable && t.mt !== null) {
        var h = t.mt.get('__pairs');
        if (h !== undefined) { var r = sp(call(h)(t)); return new Multi([r[0], r[1], r[2]]); }
      }
      checkTable(t, 1, 'pairs');
      return new Multi([luaNext, t, undefined]);
    });
    reg(G, 'next', luaNext);
    reg(G, 'select', function (n) {
      var count = arguments.length - 1;
      if (n === '#') return count;
      var i = checkInt(n, 1, 'select');
      if (i < 0) i = count + i; else if (i === 0) throw argError(1, 'select', 'index out of range');
      else i = i - 1;
      if (i < 0) throw argError(1, 'select', 'index out of range');
      var out = [];
      for (var j = i + 1; j < arguments.length; j++) out.push(arguments[j]);
      return ret(out);
    });
    reg(G, 'rawget', function (t, k) { checkTable(t, 1, 'rawget'); return t.get(k); });
    reg(G, 'rawset', function (t, k, v) { checkTable(t, 1, 'rawset'); t.set(k, v); return t; });
    reg(G, 'rawequal', function (a, b) { return a === b || (isNum(a) && isNum(b) && num(a) === num(b)); });
    reg(G, 'rawlen', function (t) { return rawLen(t); });
    reg(G, 'setmetatable', function (t, mt) {
      checkTable(t, 1, 'setmetatable');
      if (t.mt && t.mt.get('__metatable') !== undefined) throw rterror('cannot change a protected metatable');
      t.mt = mt === undefined ? null : mt;
      return t;
    });
    reg(G, 'getmetatable', function (v) {
      var mt = metaOf(v);
      if (!mt) return undefined;
      var p = mt.get('__metatable');
      return p !== undefined ? p : mt;
    });
    reg(G, 'assert', function (v, msg) {
      if (truthy(v)) { return ret(Array.prototype.slice.call(arguments)); }
      if (arguments.length < 1) throw argError(1, 'assert', 'value expected');
      throw new LuaError(arguments.length >= 2 ? msg : 'assertion failed!');
    });
    reg(G, 'error', function (v, level) {
      var lv = level === undefined ? 1 : num(level);
      if (typeof v === 'string' && lv > 0) v = luaPosition(lv + 1) + v;
      throw new LuaError(v);
    });
    reg(G, 'pcall', function (f) {
      var args = Array.prototype.slice.call(arguments, 1);
      try {
        var r = call(f).apply(null, args);
        return new Multi([true].concat(sp(r)));
      } catch (e) {
        return new Multi([false, errorValue(e)]);
      }
    });
    reg(G, 'xpcall', function (f, handler) {
      var args = Array.prototype.slice.call(arguments, 2);
      try {
        var r = call(f).apply(null, args);
        return new Multi([true].concat(sp(r)));
      } catch (e) {
        return new Multi([false].concat(sp(call(handler)(errorValue(e)))));
      }
    });
    reg(G, 'collectgarbage', function (opt) { return opt === 'count' ? mkf(1024) : 0; });
    reg(G, 'load', function (chunk, name, mode, env) {
      var src = chunk;
      if (typeof chunk === 'function') {
        var pieces = [], piece;
        while ((piece = first(chunk())) !== undefined && piece !== '') pieces.push(piece);
        src = pieces.join('');
      }
      try {
        return NS.load(src, typeof name === 'string' ? name.replace(/^[=@]/, '') : 'chunk', env || G);
      } catch (e) {
        return new Multi([undefined, errorValue(e)]);
      }
    });
    reg(G, 'loadfile', function (path, mode, env) {
      var src = host.readFile ? host.readFile(path) : null;
      if (src === null || src === undefined) return new Multi([undefined, 'cannot open ' + path]);
      try { return NS.load(src, path, env || G); }
      catch (e) { return new Multi([undefined, errorValue(e)]); }
    });
    reg(G, 'dofile', function (path) {
      var src = host.readFile ? host.readFile(path) : null;
      if (src === null || src === undefined) throw rterror('cannot open ' + path);
      return NS.load(src, path, G)();
    });
    reg(G, 'require', function (name) {
      var loaded = G.get('package').get('loaded');
      var v = loaded.get(name);
      if (v !== undefined) return v;
      if (!host.require) throw rterror("module '" + name + "' not found");
      v = host.require(name);
      loaded.set(name, v === undefined ? true : v);
      return v === undefined ? true : v;
    });
    var pkg = new LuaTable(); pkg.set('loaded', new LuaTable()); pkg.set('path', './?.lua');
    G.set('package', pkg);
    G.set('_G', G);
    G.set('_VERSION', 'Lua 5.4');

    G.set('string', stringLib);
    G.set('table', makeTableLib());
    G.set('math', makeMathLib());
    G.set('os', makeOsLib(host));
    G.set('io', makeIoLib(host));
    G.set('utf8', makeUtf8Lib());
    pkg.get('loaded').set('string', stringLib);
    pkg.get('loaded').set('_G', G);
    return G;
  }
  function errorValue(e) {
    if (e instanceof LuaError) return e.value;
    if (e instanceof RangeError) return 'stack overflow';
    if (e && e.name === 'LuaSyntaxError') return e.message;
    return String(e && e.message ? e.message : e);
  }

  // --------------------------------------------------------- table ------
  function makeTableLib() {
    var T = new LuaTable();
    T.set('insert', function (t, a, b) {
      checkTable(t, 1, 'insert');
      var e = len(t) + 1;
      if (arguments.length === 2) { setindex(t, e, a); return NONE; }
      if (arguments.length !== 3) throw rterror("wrong number of arguments to 'insert'");
      var pos = checkInt(a, 2, 'insert');
      if (pos < 1 || pos > e) throw argError(2, 'insert', 'position out of bounds');
      if (t.mt === null && e - 1 === t.arr.length) {
        t.arr.splice(pos - 1, 0, b);
        if (b === undefined) { while (t.arr.length && t.arr[t.arr.length - 1] === undefined) t.arr.pop(); }
        return NONE;
      }
      for (var i = e; i > pos; i--) setindex(t, i, index(t, i - 1));
      setindex(t, pos, b);
      return NONE;
    });
    T.set('remove', function (t, p) {
      checkTable(t, 1, 'remove');
      var size = len(t);
      var pos = p === undefined ? size : checkInt(p, 2, 'remove');
      if (p !== undefined && pos !== size && (pos < 1 || pos > size + 1)) throw argError(2, 'remove', 'position out of bounds');
      var result = index(t, pos);
      if (t.mt === null && size === t.arr.length && pos >= 1 && pos <= size) {
        t.arr.splice(pos - 1, 1);
        while (t.arr.length && t.arr[t.arr.length - 1] === undefined) t.arr.pop();
        return result;
      }
      for (; pos < size; pos++) setindex(t, pos, index(t, pos + 1));
      setindex(t, pos, undefined);
      return result;
    });
    T.set('concat', function (t, sep, i, j) {
      checkTable(t, 1, 'concat');
      sep = sep === undefined ? '' : checkStr(sep, 2, 'concat');
      var a = optInt(i, 3, 'concat', 1), b = j === undefined ? len(t) : checkInt(j, 4, 'concat');
      var parts = [];
      for (var k = a; k <= b; k++) {
        var v = index(t, k);
        if (typeof v === 'string') parts.push(v);
        else if (isNum(v)) parts.push(numStr(v));
        else throw rterror("invalid value (at index " + k + ") in table for 'concat'");
      }
      return parts.join(sep);
    });
    T.set('unpack', function (t, i, j) {
      var a = optInt(i, 2, 'unpack', 1), b = j === undefined ? len(t) : checkInt(j, 3, 'unpack');
      var out = [];
      for (var k = a; k <= b; k++) out.push(index(t, k));
      return ret(out);
    });
    T.set('pack', function () {
      var t = tbl(Array.prototype.slice.call(arguments));
      t.set('n', arguments.length);
      return t;
    });
    T.set('move', function (a1, f, e, t, a2) {
      if (a2 === undefined) a2 = a1;
      f = checkInt(f, 2, 'move'); e = checkInt(e, 3, 'move'); t = checkInt(t, 4, 'move');
      if (e >= f) {
        if (t > e || t <= f || a1 !== a2) for (var i = 0; i <= e - f; i++) setindex(a2, t + i, index(a1, f + i));
        else for (var k = e - f; k >= 0; k--) setindex(a2, t + k, index(a1, f + k));
      }
      return a2;
    });
    T.set('sort', function (t, comp) {
      checkTable(t, 1, 'sort');
      var n = len(t);
      if (n > 1) {
        var a = new Array(n + 1);
        for (var i = 1; i <= n; i++) a[i] = index(t, i);
        var less;
        if (comp !== undefined) {
          var cf = call(comp);
          less = function (x, y) { return truthy(first(cf(x, y))); };
        } else less = lt;
        auxsort(a, 1, n, 0, less);
        for (var j = 1; j <= n; j++) setindex(t, j, a[j]);
      }
      return NONE;
    });
    return T;
  }

  // Lua 5.4's ltablib.c sort, line for line: ties come out in the same
  // order as in the real Lua, which matters to engines that sort with them.
  var RANLIMIT = 100;
  function auxsort(a, lo, up, rnd, less) {
    var t;
    while (lo < up) {
      if (less(a[up], a[lo])) { t = a[lo]; a[lo] = a[up]; a[up] = t; }
      if (up - lo === 1) break;
      var p;
      if (up - lo < RANLIMIT || rnd === 0) p = Math.floor((lo + up) / 2);
      else { var r4 = Math.floor((up - lo) / 4); p = rnd % (r4 * 2) + (lo + r4); }
      if (less(a[p], a[lo])) { t = a[p]; a[p] = a[lo]; a[lo] = t; }
      else if (less(a[up], a[p])) { t = a[p]; a[p] = a[up]; a[up] = t; }
      if (up - lo === 2) break;
      var P = a[p];
      t = a[p]; a[p] = a[up - 1]; a[up - 1] = t;
      // partition
      var i = lo, j = up - 1;
      for (;;) {
        while (less(a[++i], P)) {
          if (i === up - 1) throw rterror('invalid order function for sorting');
        }
        while (less(P, a[--j])) {
          if (j < i) throw rterror('invalid order function for sorting');
        }
        if (j < i) { t = a[up - 1]; a[up - 1] = a[i]; a[i] = t; break; }
        t = a[i]; a[i] = a[j]; a[j] = t;
      }
      p = i;
      var n;
      if (p - lo < up - p) { auxsort(a, lo, p - 1, rnd, less); n = p - lo; lo = p + 1; }
      else { auxsort(a, p + 1, up, rnd, less); n = up - p; up = p - 1; }
      if ((up - lo) / 128 > n) rnd = 0x5bd1e995;   // real Lua randomises here
    }
  }

  // ---------------------------------------------------------- math ------
  function makeMathLib() {
    var M = new LuaTable();
    M.set('pi', Math.PI);
    M.set('huge', Infinity);
    M.set('maxinteger', 9223372036854775807);
    M.set('mininteger', -9223372036854775808);
    M.set('abs', function (x) {
      if (typeof x === 'number') return Number.isInteger(x) ? (x < 0 ? 0 - x : x) : Math.abs(x);
      if (x instanceof LFloat) return new LFloat(Math.abs(x.n));
      return mkfOrInt(Math.abs(checkNum(x, 1, 'abs')), x);
    });
    M.set('floor', function (x) {
      if (typeof x === 'number' && Number.isInteger(x)) return x;
      var r = Math.floor(checkNum(x, 1, 'floor'));
      return r === 0 ? 0 : r;
    });
    M.set('ceil', function (x) {
      if (typeof x === 'number' && Number.isInteger(x)) return x;
      var r = Math.ceil(checkNum(x, 1, 'ceil'));
      return r === 0 ? 0 : r;
    });
    function minmax(isMax, name) {
      return function () {
        if (arguments.length === 0) throw argError(1, name, 'number expected, got no value');
        var best = arguments[0]; checkNum(best, 1, name);
        for (var i = 1; i < arguments.length; i++) {
          var v = arguments[i]; checkNum(v, i + 1, name);
          if (isMax ? lt(best, v) : lt(v, best)) best = v;
        }
        return best;
      };
    }
    M.set('max', minmax(true, 'max'));
    M.set('min', minmax(false, 'min'));
    function fl(f, name) { return function (x) { return mkf(f(checkNum(x, 1, name))); }; }
    M.set('sqrt', fl(Math.sqrt, 'sqrt'));
    M.set('sin', fl(Math.sin, 'sin'));
    M.set('cos', fl(Math.cos, 'cos'));
    M.set('tan', fl(Math.tan, 'tan'));
    M.set('asin', fl(Math.asin, 'asin'));
    M.set('acos', fl(Math.acos, 'acos'));
    M.set('exp', fl(Math.exp, 'exp'));
    M.set('atan', function (y, x) { return mkf(Math.atan2(checkNum(y, 1, 'atan'), x === undefined ? 1 : checkNum(x, 2, 'atan'))); });
    M.set('log', function (x, base) {
      var v = checkNum(x, 1, 'log');
      if (base === undefined) return mkf(Math.log(v));
      var b = checkNum(base, 2, 'log');
      if (b === 2) return mkf(Math.log2(v));
      if (b === 10) return mkf(Math.log10(v));
      return mkf(Math.log(v) / Math.log(b));
    });
    M.set('fmod', function (a, b) {
      if (typeof a === 'number' && typeof b === 'number' && Number.isInteger(a) && Number.isInteger(b)) {
        if (b === 0) throw argError(2, 'fmod', 'zero');
        return a % b === 0 ? 0 : a % b;
      }
      return mkf(checkNum(a, 1, 'fmod') % checkNum(b, 2, 'fmod'));
    });
    M.set('modf', function (x) {
      var v = checkNum(x, 1, 'modf');
      var ip = v >= 0 ? Math.floor(v) : Math.ceil(v);
      var fp = (v === Infinity || v === -Infinity) ? 0 : v - ip;
      return new Multi([mkf(ip), mkf(fp)]);
    });
    M.set('tointeger', function (x) {
      if (typeof x === 'number' && Number.isInteger(x)) return x;
      if (x instanceof LFloat) return x.n;
      if (typeof x === 'string') { var n = str2num(x); return n === undefined ? undefined : (typeof n === 'number' && Number.isInteger(n) ? n : (n instanceof LFloat ? n.n : undefined)); }
      return undefined;
    });
    M.set('type', function (x) {
      if (arguments.length === 0) throw argError(1, 'type', 'value expected');
      if (typeof x === 'number') return Number.isInteger(x) ? 'integer' : 'float';
      if (x instanceof LFloat) return 'float';
      return undefined;
    });
    M.set('ult', function (a, b) {
      return BigInt.asUintN(64, BigInt(checkInt(a, 1, 'ult'))) < BigInt.asUintN(64, BigInt(checkInt(b, 2, 'ult')));
    });

    // xoshiro256**, as lmathlib.c has it, on 64-bit BigInts.
    var MASK = (1n << 64n) - 1n;
    var state = [0n, 0n, 0n, 0n];
    function rotl(x, n) { return ((x << BigInt(n)) | (x >> BigInt(64 - n))) & MASK; }
    function nextrand() {
      var s0 = state[0], s1 = state[1], s2 = state[2] ^ s0, s3 = state[3] ^ s1;
      var res = (rotl((s1 * 5n) & MASK, 7) * 9n) & MASK;
      state[0] = s0 ^ s3;
      state[1] = s1 ^ s2;
      state[2] = s2 ^ ((s1 << 17n) & MASK);
      state[3] = rotl(s3, 45);
      return res;
    }
    function setseed(n1, n2) {
      state = [BigInt.asUintN(64, n1), 0xffn, BigInt.asUintN(64, n2), 0n];
      for (var i = 0; i < 16; i++) nextrand();
    }
    setseed(BigInt(Date.now()), 0n);
    function project(ran, n) {
      if ((n & (n + 1n)) === 0n) return ran & n;
      var lim = n;
      lim |= lim >> 1n; lim |= lim >> 2n; lim |= lim >> 4n; lim |= lim >> 8n;
      lim |= lim >> 16n; lim |= lim >> 32n;
      while ((ran &= lim) > n) ran = nextrand();
      return ran;
    }
    M.set('random', function (m, n) {
      var rv = nextrand();
      var low, up;
      switch (arguments.length) {
        case 0: return mkf(Number(rv >> 11n) * Math.pow(2, -53));
        case 1:
          low = 1n; up = BigInt(checkInt(m, 1, 'random'));
          if (up === 0n) return fromInt64(rv);
          break;
        case 2:
          low = BigInt(checkInt(m, 1, 'random')); up = BigInt(checkInt(n, 2, 'random'));
          break;
        default: throw rterror('wrong number of arguments');
      }
      if (!(low <= up)) throw argError(1, 'random', 'interval is empty');
      var p = project(rv, BigInt.asUintN(64, up - low));
      return fromInt64(p + BigInt.asUintN(64, low));
    });
    M.set('randomseed', function (a, b) {
      if (arguments.length === 0) { setseed(BigInt(Date.now()), 0n); return; }
      var n1 = isFloatVal(a) ? BigInt(Math.trunc(num(a))) : BigInt(checkInt(a, 1, 'randomseed'));
      var n2 = b === undefined ? 0n : BigInt(checkInt(b, 2, 'randomseed'));
      setseed(n1, n2);
      return new Multi([fromInt64(n1), fromInt64(n2)]);
    });
    return M;
  }
  function mkfOrInt(r, orig) { return isFloatVal(orig) ? mkf(r) : r; }

  // ------------------------------------------------------------ os ------
  function makeOsLib(host) {
    var O = new LuaTable();
    var now = host.now || function () { return Date.now(); };
    O.set('time', function (t) {
      if (t === undefined) return Math.floor(now() / 1000);
      checkTable(t, 1, 'time');
      function field(k, d) {
        var v = t.get(k);
        if (v === undefined) { if (d === undefined) throw rterror("field '" + k + "' missing in date table"); return d; }
        return num(v);
      }
      var d = new Date(field('year'), field('month') - 1, field('day'), field('hour', 12), field('min', 0), field('sec', 0));
      return Math.floor(d.getTime() / 1000);
    });
    O.set('clock', function () {
      var p = (typeof performance !== 'undefined') ? performance.now() : Date.now();
      return mkf(p / 1000);
    });
    O.set('date', function (fmt, t) {
      fmt = fmt === undefined ? '%c' : checkStr(fmt, 1, 'date');
      var ms = t === undefined ? now() : num(t) * 1000;
      var utc = fmt[0] === '!';
      if (utc) fmt = fmt.slice(1);
      var d = new Date(ms);
      var g = utc
        ? { Y: d.getUTCFullYear(), m: d.getUTCMonth(), d: d.getUTCDate(), H: d.getUTCHours(), M: d.getUTCMinutes(), S: d.getUTCSeconds(), w: d.getUTCDay() }
        : { Y: d.getFullYear(), m: d.getMonth(), d: d.getDate(), H: d.getHours(), M: d.getMinutes(), S: d.getSeconds(), w: d.getDay() };
      var start = utc ? Date.UTC(g.Y, 0, 1) : new Date(g.Y, 0, 1).getTime();
      var cur = utc ? Date.UTC(g.Y, g.m, g.d) : new Date(g.Y, g.m, g.d).getTime();
      var yday = Math.round((cur - start) / 86400000) + 1;
      if (fmt.slice(0, 2) === '*t') {
        var r = new LuaTable();
        r.set('year', g.Y); r.set('month', g.m + 1); r.set('day', g.d);
        r.set('hour', g.H); r.set('min', g.M); r.set('sec', g.S);
        r.set('wday', g.w + 1); r.set('yday', yday); r.set('isdst', false);
        return r;
      }
      var DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      function p2(n) { return (n < 10 ? '0' : '') + n; }
      return fmt.replace(/%(.)/g, function (_, c) {
        switch (c) {
          case 'Y': return String(g.Y);
          case 'y': return p2(g.Y % 100);
          case 'm': return p2(g.m + 1);
          case 'd': return p2(g.d);
          case 'e': return (g.d < 10 ? ' ' : '') + g.d;
          case 'H': return p2(g.H);
          case 'I': return p2(((g.H + 11) % 12) + 1);
          case 'M': return p2(g.M);
          case 'S': return p2(g.S);
          case 'p': return g.H < 12 ? 'AM' : 'PM';
          case 'A': return DAYS[g.w];
          case 'a': return DAYS[g.w].slice(0, 3);
          case 'B': return MONTHS[g.m];
          case 'b': return MONTHS[g.m].slice(0, 3);
          case 'j': return String(yday).padStart(3, '0');
          case 'w': return String(g.w);
          case 'u': return String(g.w === 0 ? 7 : g.w);
          case 'x': return p2(g.m + 1) + '/' + p2(g.d) + '/' + p2(g.Y % 100);
          case 'X': return p2(g.H) + ':' + p2(g.M) + ':' + p2(g.S);
          case 'c': return DAYS[g.w].slice(0, 3) + ' ' + MONTHS[g.m].slice(0, 3) + ' ' + (g.d < 10 ? ' ' : '') + g.d + ' ' + p2(g.H) + ':' + p2(g.M) + ':' + p2(g.S) + ' ' + g.Y;
          case '%': return '%';
          default: return '%' + c;
        }
      });
    });
    O.set('getenv', function () { return undefined; });
    O.set('remove', function (path) {
      if (host.removeFile && host.removeFile(path)) return true;
      return new Multi([undefined, path + ': No such file or directory', 2]);
    });
    O.set('rename', function (a, b) {
      if (host.renameFile && host.renameFile(a, b)) return true;
      return new Multi([undefined, a + ': No such file or directory', 2]);
    });
    O.set('exit', function () { throw new LuaError('os.exit called'); });
    O.set('tmpname', function () { return '/tmp/lua_' + Math.random().toString(36).slice(2); });
    return O;
  }

  // ------------------------------------------------------------ io ------
  // Files live wherever the host keeps them (host.readFile / host.writeFile):
  // Battle Pass keeps its save file this way.
  function makeIoLib(host) {
    var IO = new LuaTable();
    var fileMeta = new LuaTable();
    var fileMethods = new LuaTable();
    fileMeta.set('__index', fileMethods);
    fileMeta.set('__name', 'FILE*');
    function newFile(path, mode, data) {
      var f = new LuaTable();
      f.mt = fileMeta;
      f._path = path; f._mode = mode; f._data = data; f._pos = 0; f._closed = false;
      return f;
    }
    IO.set('open', function (path, mode) {
      path = checkStr(path, 1, 'open');
      mode = mode === undefined ? 'r' : checkStr(mode, 2, 'open');
      var m = mode.replace('b', '');
      if (m[0] === 'r') {
        var data = host.readFile ? host.readFile(path) : null;
        if (data === null || data === undefined) return new Multi([undefined, path + ': No such file or directory', 2]);
        return newFile(path, m, data);
      }
      if (m[0] === 'w') return newFile(path, m, '');
      if (m[0] === 'a') {
        var old = host.readFile ? host.readFile(path) : null;
        var f = newFile(path, m, old || '');
        f._pos = f._data.length;
        return f;
      }
      throw argError(2, 'open', 'invalid mode');
    });
    fileMethods.set('read', function (f) {
      var fmts = Array.prototype.slice.call(arguments, 1);
      if (!fmts.length) fmts = ['l'];
      var out = [];
      for (var i = 0; i < fmts.length; i++) {
        var fm = fmts[i];
        if (isNum(fm)) {
          var n = num(fm);
          if (f._pos >= f._data.length && n > 0) { out.push(undefined); break; }
          out.push(f._data.substr(f._pos, n)); f._pos += n; continue;
        }
        fm = String(fm).replace(/^\*/, '');
        if (fm[0] === 'a') { out.push(f._data.slice(f._pos)); f._pos = f._data.length; continue; }
        if (fm[0] === 'l' || fm[0] === 'L') {
          if (f._pos >= f._data.length) { out.push(undefined); break; }
          var e = f._data.indexOf('\n', f._pos);
          var line = e < 0 ? f._data.slice(f._pos) : f._data.slice(f._pos, fm[0] === 'L' ? e + 1 : e);
          f._pos = e < 0 ? f._data.length : e + 1;
          out.push(line); continue;
        }
        if (fm[0] === 'n') {
          var m = /^\s*[-+]?(0[xX][0-9a-fA-F.]+|\d*\.?\d+(?:[eE][-+]?\d+)?)/.exec(f._data.slice(f._pos));
          if (!m) { out.push(undefined); break; }
          f._pos += m[0].length; out.push(str2num(m[0])); continue;
        }
      }
      return ret(out);
    });
    fileMethods.set('write', function (f) {
      for (var i = 1; i < arguments.length; i++) {
        var v = arguments[i];
        var s = typeof v === 'string' ? v : writeNum(v);
        f._data = f._data.slice(0, f._pos) + s + f._data.slice(f._pos + s.length);
        f._pos += s.length;
      }
      return f;
    });
    fileMethods.set('lines', function (f) {
      return function () { return first(fileMethods.get('read')(f, 'l')); };
    });
    fileMethods.set('seek', function (f, whence, off) {
      whence = whence || 'cur'; off = off === undefined ? 0 : num(off);
      if (whence === 'set') f._pos = off;
      else if (whence === 'end') f._pos = f._data.length + off;
      else f._pos += off;
      return f._pos;
    });
    fileMethods.set('flush', function (f) {
      if (f._mode[0] !== 'r' && host.writeFile) host.writeFile(f._path, f._data);
      return f;
    });
    fileMethods.set('close', function (f) {
      if (!f._closed && f._mode[0] !== 'r' && host.writeFile) host.writeFile(f._path, f._data);
      f._closed = true;
      return true;
    });
    fileMethods.set('setvbuf', function () { return true; });
    IO.set('write', function () {
      var s = '';
      for (var i = 0; i < arguments.length; i++) s += typeof arguments[i] === 'string' ? arguments[i] : writeNum(arguments[i]);
      (host.write || host.print || function (x) { if (typeof process !== 'undefined') process.stdout.write(x); })(s);
      return NONE;
    });
    IO.set('lines', function (path) {
      var data = host.readFile ? host.readFile(path) : null;
      if (data === null || data === undefined) throw rterror(path + ': No such file or directory');
      var f = newFile(path, 'r', data);
      return function () { return first(fileMethods.get('read')(f, 'l')); };
    });
    return IO;
  }

  // ---------------------------------------------------------- utf8 ------
  function makeUtf8Lib() {
    var U = new LuaTable();
    U.set('char', function () {
      var s = '';
      for (var i = 0; i < arguments.length; i++) s += NS.utf8Bytes(checkInt(arguments[i], i + 1, 'char'));
      return s;
    });
    U.set('charpattern', '[\x00-\x7F\xC2-\xFD][\x80-\xBF]*');
    function decodeAt(s, i) {   // i 0-based; returns [codepoint, length] or null
      var c = s.charCodeAt(i);
      if (c < 0x80) return [c, 1];
      var n = c >= 0xF0 ? 4 : c >= 0xE0 ? 3 : c >= 0xC0 ? 2 : 0;
      if (!n) return null;
      var cp = c & (0x7F >> n);
      for (var k = 1; k < n; k++) {
        var cc = s.charCodeAt(i + k);
        if ((cc & 0xC0) !== 0x80) return null;
        cp = (cp << 6) | (cc & 0x3F);
      }
      return [cp, n];
    }
    U.set('len', function (s, i, j) {
      s = checkStr(s, 1, 'len');
      var a = (i === undefined ? 1 : num(i)) - 1, b = j === undefined ? s.length : num(j);
      var n = 0;
      while (a < b) {
        var d = decodeAt(s, a);
        if (!d) return new Multi([undefined, a + 1]);
        a += d[1]; n++;
      }
      return n;
    });
    U.set('codepoint', function (s, i, j) {
      s = checkStr(s, 1, 'codepoint');
      var a = (i === undefined ? 1 : num(i)), b = j === undefined ? a : num(j);
      var out = [], p = a - 1;
      while (p < b) {
        var d = decodeAt(s, p);
        if (!d) throw rterror('invalid UTF-8 code');
        out.push(d[0]); p += d[1];
      }
      return ret(out);
    });
    U.set('offset', function (s, n, i) {
      s = checkStr(s, 1, 'offset');
      n = num(n);
      var p = i === undefined ? (n >= 0 ? 1 : s.length + 1) : num(i);
      p -= 1;
      function cont(k) { return (s.charCodeAt(k) & 0xC0) === 0x80; }
      if (n === 0) { while (p > 0 && cont(p)) p--; return p + 1; }
      if (n > 0) { n--; while (n > 0 && p < s.length) { p++; while (cont(p)) p++; n--; } return n === 0 ? p + 1 : undefined; }
      while (n < 0 && p > 0) { p--; while (p > 0 && cont(p)) p--; n++; }
      return n === 0 ? p + 1 : undefined;
    });
    U.set('codes', function (s) {
      s = checkStr(s, 1, 'codes');
      return new Multi([function (str, i) {
        var p = num(i);
        if (p > 0) { var d0 = decodeAt(str, p - 1); p += d0 ? d0[1] - 1 : 0; }
        if (p >= str.length) return undefined;
        var d = decodeAt(str, p);
        if (!d) throw rterror('invalid UTF-8 code');
        return new Multi([p + 1, d[0]]);
      }, s, 0]);
    });
    return U;
  }

  // ======================================================== strings =======
  var stringLib = new LuaTable();
  var stringMeta = new LuaTable();
  stringMeta.set('__index', stringLib);

  function posrelatI(pos, l) {
    if (pos > 0) return pos;
    if (pos === 0) return 1;
    if (pos < -l) return 1;
    return l + pos + 1;
  }
  function getendpos(pos, l) {
    if (pos > l) return l;
    if (pos >= 0) return pos;
    if (pos < -l) return 0;
    return l + pos + 1;
  }
  stringLib.set('len', function (s) { return checkStr(s, 1, 'len').length; });
  stringLib.set('sub', function (s, i, j) {
    s = checkStr(s, 1, 'sub');
    var l = s.length;
    var st = posrelatI(checkInt(i === undefined ? 1 : i, 2, 'sub'), l);
    var en = getendpos(j === undefined ? -1 : checkInt(j, 3, 'sub'), l);
    if (st < 1) st = 1;
    if (en > l) en = l;
    return st <= en ? s.slice(st - 1, en) : '';
  });
  stringLib.set('upper', function (s) {
    s = checkStr(s, 1, 'upper');
    return s.replace(/[a-z]+/g, function (m) { return m.toUpperCase(); });
  });
  stringLib.set('lower', function (s) {
    s = checkStr(s, 1, 'lower');
    return s.replace(/[A-Z]+/g, function (m) { return m.toLowerCase(); });
  });
  stringLib.set('rep', function (s, n, sep) {
    s = checkStr(s, 1, 'rep'); n = checkInt(n, 2, 'rep');
    if (n <= 0) return '';
    if (sep === undefined || sep === '') return s.repeat(n);
    sep = checkStr(sep, 3, 'rep');
    return Array(n).fill(s).join(sep);
  });
  stringLib.set('reverse', function (s) { return checkStr(s, 1, 'reverse').split('').reverse().join(''); });
  stringLib.set('byte', function (s, i, j) {
    s = checkStr(s, 1, 'byte');
    var l = s.length;
    var pi = posrelatI(optInt(i, 2, 'byte', 1), l);
    var pe = getendpos(j === undefined ? pi : checkInt(j, 3, 'byte'), l);
    if (pi > pe) return undefined;
    var out = [];
    for (var k = pi; k <= pe; k++) out.push(s.charCodeAt(k - 1));
    return ret(out);
  });
  stringLib.set('char', function () {
    var out = '';
    for (var i = 0; i < arguments.length; i++) {
      var c = checkInt(arguments[i], i + 1, 'char');
      if (c < 0 || c > 255) throw argError(i + 1, 'char', 'value out of range');
      out += String.fromCharCode(c);
    }
    return out;
  });

  // string.format, with C's own rounding.
  stringLib.set('format', function (fmt) {
    fmt = checkStr(fmt, 1, 'format');
    var args = arguments, argi = 1;
    var out = '', i = 0, n = fmt.length;
    while (i < n) {
      var c = fmt[i++];
      if (c !== '%') { out += c; continue; }
      if (fmt[i] === '%') { out += '%'; i++; continue; }
      var m = /^([-+ #0]*)(\d*)(?:\.(\d*))?([a-zA-Z])/.exec(fmt.slice(i));
      if (!m) throw rterror("invalid conversion '%" + fmt.slice(i, i + 5) + "' to 'format'");
      i += m[0].length;
      var flags = m[1], width = m[2] ? Number(m[2]) : 0, prec = m[3] === undefined ? undefined : Number(m[3] || 0);
      var conv = m[4];
      var argn = ++argi;
      if (argn > args.length - 1 + 1 && conv !== '%') {
        if (args[argn - 1] === undefined && argn > args.length) throw argError(argn, 'format', 'no value');
      }
      var v = args[argn - 1], body, sign = '';
      switch (conv) {
        case 'd': case 'i': {
          var iv = checkInt(v, argn, 'format');
          body = String(Math.abs(iv) < 1e21 ? Math.abs(iv) : BigInt(iv) * (iv < 0 ? -1n : 1n));
          if (prec !== undefined) { body = body.padStart(prec, '0'); if (prec === 0 && iv === 0) body = ''; }
          sign = iv < 0 ? '-' : (flags.indexOf('+') >= 0 ? '+' : (flags.indexOf(' ') >= 0 ? ' ' : ''));
          out += pad(sign, body, width, flags, prec === undefined);
          break;
        }
        case 'u': {
          var uv = checkInt(v, argn, 'format');
          body = BigInt.asUintN(64, BigInt(uv)).toString();
          out += pad('', body, width, flags, true);
          break;
        }
        case 'c': out += pad('', String.fromCharCode(checkInt(v, argn, 'format')), width, flags.replace('0', ''), false); break;
        case 'x': case 'X': case 'o': {
          var xv = BigInt.asUintN(64, BigInt(checkInt(v, argn, 'format')));
          body = xv.toString(conv === 'o' ? 8 : 16);
          if (conv === 'X') body = body.toUpperCase();
          if (prec !== undefined) body = body.padStart(prec, '0');
          var pre = (flags.indexOf('#') >= 0 && xv !== 0n) ? (conv === 'o' ? '0' : (conv === 'x' ? '0x' : '0X')) : '';
          out += pad(pre, body, width, flags, prec === undefined);
          break;
        }
        case 'e': case 'E': case 'f': case 'F': case 'g': case 'G': case 'a': case 'A': {
          var fv = checkNum(v, argn, 'format');
          var neg = fv < 0 || (fv === 0 && 1 / fv < 0);
          var ax = Math.abs(fv);
          var up = conv === 'E' || conv === 'G' || conv === 'F' || conv === 'A';
          if (ax === Infinity || fv !== fv) {
            body = fv !== fv ? 'nan' : 'inf';
            if (up) body = body.toUpperCase();
            sign = neg && fv === fv ? '-' : (flags.indexOf('+') >= 0 ? '+' : (flags.indexOf(' ') >= 0 ? ' ' : ''));
            out += pad(sign, body, width, flags.replace('0', ''), false);
            break;
          }
          var p = prec === undefined ? 6 : prec;
          var alt = flags.indexOf('#') >= 0;
          if (conv === 'f' || conv === 'F') { body = fixedDigits(ax, p); if (alt && p === 0) body += '.'; }
          else if (conv === 'e' || conv === 'E') body = fmtExp(ax, p, up);
          else if (conv === 'g' || conv === 'G') body = fmtG(ax, p, up, alt);
          else body = hexFloat(ax, prec, up);
          sign = neg ? '-' : (flags.indexOf('+') >= 0 ? '+' : (flags.indexOf(' ') >= 0 ? ' ' : ''));
          out += pad(sign, body, width, flags, true);
          break;
        }
        case 's': {
          var sv = tostring(v);
          if (args.length < argn) throw argError(argn, 'format', 'no value');
          if (prec !== undefined) sv = sv.slice(0, prec);
          out += pad('', sv, width, flags.replace('0', ''), false);
          break;
        }
        case 'q': out += quoteString(v); break;
        default:
          throw rterror("invalid conversion '%" + m[0] + "' to 'format'");
      }
    }
    return out;
  });
  function pad(sign, body, width, flags, zeroOk) {
    var total = sign.length + body.length;
    if (total >= width) return sign + body;
    if (flags.indexOf('-') >= 0) return sign + body + ' '.repeat(width - total);
    if (zeroOk && flags.indexOf('0') >= 0) return sign + '0'.repeat(width - total) + body;
    return ' '.repeat(width - total) + sign + body;
  }
  function hexFloat(x, prec, up) {
    if (x === 0) return up ? '0X0P+0' : '0x0p+0';
    var e = Math.floor(Math.log2(x)), m = x / Math.pow(2, e);
    if (m >= 2) { m /= 2; e++; } else if (m < 1) { m *= 2; e--; }
    var frac = (m - 1).toString(16).slice(2);
    if (prec !== undefined) frac = frac.slice(0, prec).padEnd(prec, '0');
    var s = '0x1' + (frac ? '.' + frac : '') + 'p' + (e >= 0 ? '+' : '') + e;
    return up ? s.toUpperCase() : s;
  }
  function quoteString(v) {
    if (typeof v === 'string') {
      var o = '"';
      for (var i = 0; i < v.length; i++) {
        var c = v.charCodeAt(i), ch = v[i];
        if (ch === '"' || ch === '\\') o += '\\' + ch;
        else if (ch === '\n') o += '\\\n';
        else if (ch === '\r') o += '\\r';
        else if (c === 0) o += (i + 1 < v.length && /\d/.test(v[i + 1])) ? '\\000' : '\\0';
        else if (c < 32 || c === 127) o += '\\' + ((i + 1 < v.length && /\d/.test(v[i + 1])) ? String(c).padStart(3, '0') : c);
        else o += ch;
      }
      return o + '"';
    }
    if (typeof v === 'number' && Number.isInteger(v)) return intStr(v);
    if (isNum(v)) {
      var x = num(v);
      if (x === Infinity) return '1e9999';
      if (x === -Infinity) return '-1e9999';
      if (x !== x) return '(0/0)';
      if (x === Math.floor(x)) return (x < 0 ? '-' : '') + hexFloat(Math.abs(x)) ;
      return (x < 0 ? '-' : '') + hexFloat(Math.abs(x));
    }
    if (v === undefined || typeof v === 'boolean') return tostring(v);
    throw rterror("bad argument to 'format' (value has no literal form)");
  }

  // ----------------------------------------------------- patterns ------
  // lstrlib.c's matcher, ported line for line.
  var L_ESC = 37, CAP_UNFINISHED = -1, CAP_POSITION = -2, MAXCCALLS = 200, MAXCAPTURES = 32;
  function MatchState(src, pat) {
    this.src = src; this.pat = pat; this.level = 0; this.matchdepth = MAXCCALLS;
    this.capInit = new Array(MAXCAPTURES); this.capLen = new Array(MAXCAPTURES);
  }
  function classEnd(ms, p) {
    var pat = ms.pat, pe = pat.length;
    var c = pat.charCodeAt(p++);
    if (c === L_ESC) {
      if (p >= pe) throw rterror("malformed pattern (ends with '%')");
      return p + 1;
    }
    if (c === 91) {   // '['
      if (pat.charCodeAt(p) === 94) p++;
      do {
        if (p >= pe) throw rterror("malformed pattern (missing ']')");
        if (pat.charCodeAt(p++) === L_ESC && p < pe) p++;
      } while (pat.charCodeAt(p) !== 93);
      return p + 1;
    }
    return p;
  }
  function isalpha(c) { return (c >= 65 && c <= 90) || (c >= 97 && c <= 122); }
  function isdigit(c) { return c >= 48 && c <= 57; }
  function islower(c) { return c >= 97 && c <= 122; }
  function isupper(c) { return c >= 65 && c <= 90; }
  function isspace(c) { return c === 32 || (c >= 9 && c <= 13); }
  function iscntrl(c) { return c < 32 || c === 127; }
  function ispunct(c) { return c >= 33 && c <= 126 && !isalpha(c) && !isdigit(c); }
  function isxdigit(c) { return isdigit(c) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70); }
  function matchClass(c, cl) {
    var res;
    var low = cl >= 65 && cl <= 90 ? cl + 32 : cl;
    switch (low) {
      case 97: res = isalpha(c); break;            // a
      case 99: res = iscntrl(c); break;            // c
      case 100: res = isdigit(c); break;           // d
      case 103: res = c >= 33 && c <= 126; break;  // g
      case 108: res = islower(c); break;           // l
      case 112: res = ispunct(c); break;           // p
      case 115: res = isspace(c); break;           // s
      case 117: res = isupper(c); break;           // u
      case 119: res = isalpha(c) || isdigit(c); break; // w
      case 120: res = isxdigit(c); break;          // x
      default: return cl === c;
    }
    if (isupper(cl)) res = !res;
    return res;
  }
  function matchBracketClass(ms, c, p, ec) {
    var pat = ms.pat, sig = true;
    if (pat.charCodeAt(p + 1) === 94) { sig = false; p++; }
    while (++p < ec) {
      var pc = pat.charCodeAt(p);
      if (pc === L_ESC) {
        p++;
        if (matchClass(c, pat.charCodeAt(p))) return sig;
      } else if (pat.charCodeAt(p + 1) === 45 && p + 2 < ec) {
        p += 2;
        if (pat.charCodeAt(p - 2) <= c && c <= pat.charCodeAt(p)) return sig;
      } else if (pc === c) return sig;
    }
    return !sig;
  }
  function singleMatch(ms, s, p, ep) {
    if (s >= ms.src.length) return false;
    var c = ms.src.charCodeAt(s);
    var pc = ms.pat.charCodeAt(p);
    switch (pc) {
      case 46: return true;                                  // '.'
      case L_ESC: return matchClass(c, ms.pat.charCodeAt(p + 1));
      case 91: return matchBracketClass(ms, c, p, ep - 1);
      default: return pc === c;
    }
  }
  function matchBalance(ms, s, p) {
    if (p >= ms.pat.length - 1) throw rterror("malformed pattern (missing arguments to '%b')");
    var src = ms.src;
    if (src.charCodeAt(s) !== ms.pat.charCodeAt(p)) return -1;
    var b = ms.pat.charCodeAt(p), e = ms.pat.charCodeAt(p + 1), cont = 1;
    while (++s < src.length) {
      var c = src.charCodeAt(s);
      if (c === e) { if (--cont === 0) return s + 1; }
      else if (c === b) cont++;
    }
    return -1;
  }
  function maxExpand(ms, s, p, ep) {
    var i = 0;
    while (singleMatch(ms, s + i, p, ep)) i++;
    while (i >= 0) {
      var res = doMatch(ms, s + i, ep + 1);
      if (res !== -1) return res;
      i--;
    }
    return -1;
  }
  function minExpand(ms, s, p, ep) {
    for (;;) {
      var res = doMatch(ms, s, ep + 1);
      if (res !== -1) return res;
      else if (singleMatch(ms, s, p, ep)) s++;
      else return -1;
    }
  }
  function startCapture(ms, s, p, what) {
    var level = ms.level;
    if (level >= MAXCAPTURES) throw rterror('too many captures');
    ms.capInit[level] = s; ms.capLen[level] = what;
    ms.level = level + 1;
    var res = doMatch(ms, s, p);
    if (res === -1) ms.level--;
    return res;
  }
  function captureToClose(ms) {
    var level = ms.level;
    for (level--; level >= 0; level--) if (ms.capLen[level] === CAP_UNFINISHED) return level;
    throw rterror('invalid pattern capture');
  }
  function endCapture(ms, s, p) {
    var l = captureToClose(ms);
    ms.capLen[l] = s - ms.capInit[l];
    var res = doMatch(ms, s, p);
    if (res === -1) ms.capLen[l] = CAP_UNFINISHED;
    return res;
  }
  function checkCapture(ms, l) {
    l -= 49;
    if (l < 0 || l >= ms.level || ms.capLen[l] === CAP_UNFINISHED) throw rterror('invalid capture index %' + (l + 1));
    return l;
  }
  function matchCapture(ms, s, l) {
    l = checkCapture(ms, l);
    var len = ms.capLen[l];
    var cap = ms.src.substr(ms.capInit[l], len);
    if (ms.src.length - s >= len && ms.src.substr(s, len) === cap) return s + len;
    return -1;
  }
  function doMatch(ms, s, p) {
    if (ms.matchdepth-- === 0) throw rterror('pattern too complex');
    var pat = ms.pat, pe = pat.length;
    for (;;) {
      if (p === pe) break;
      var pc = pat.charCodeAt(p);
      if (pc === 40) {                                     // '('
        if (pat.charCodeAt(p + 1) === 41) s = startCapture(ms, s, p + 2, CAP_POSITION);
        else s = startCapture(ms, s, p + 1, CAP_UNFINISHED);
        break;
      }
      if (pc === 41) { s = endCapture(ms, s, p + 1); break; }   // ')'
      if (pc === 36 && p + 1 === pe) {                     // '$' at the end
        s = (s === ms.src.length) ? s : -1;
        break;
      }
      if (pc === L_ESC) {
        var nx = pat.charCodeAt(p + 1);
        if (nx === 98) {                                   // %b
          s = matchBalance(ms, s, p + 2);
          if (s !== -1) { p += 4; continue; }
          break;
        }
        if (nx === 102) {                                  // %f
          p += 2;
          if (pat.charCodeAt(p) !== 91) throw rterror("missing '[' after '%f' in pattern");
          var ep0 = classEnd(ms, p);
          var prev = (s === 0) ? 0 : ms.src.charCodeAt(s - 1);
          var cur = s < ms.src.length ? ms.src.charCodeAt(s) : 0;
          if (!matchBracketClass(ms, prev, p, ep0 - 1) && matchBracketClass(ms, cur, p, ep0 - 1)) { p = ep0; continue; }
          s = -1; break;
        }
        if (nx >= 48 && nx <= 57) {                        // %0-%9
          s = matchCapture(ms, s, nx);
          if (s !== -1) { p += 2; continue; }
          break;
        }
      }
      // default: a single class with an optional suffix
      var ep = classEnd(ms, p);
      var epc = pat.charCodeAt(ep);
      if (!singleMatch(ms, s, p, ep)) {
        if (epc === 42 || epc === 63 || epc === 45) { p = ep + 1; continue; }   // * ? -
        s = -1; break;
      }
      if (epc === 63) {                                    // ?
        var res = doMatch(ms, s + 1, ep + 1);
        if (res !== -1) { s = res; break; }
        p = ep + 1; continue;
      }
      if (epc === 43) { s = maxExpand(ms, s + 1, p, ep); break; }   // +
      if (epc === 42) { s = maxExpand(ms, s, p, ep); break; }       // *
      if (epc === 45) { s = minExpand(ms, s, p, ep); break; }       // -
      s++; p = ep;
    }
    ms.matchdepth++;
    return s;
  }
  function getCapture(ms, i, s, e) {
    if (i >= ms.level) {
      if (i !== 0) throw rterror('invalid capture index %' + (i + 1));
      return ms.src.slice(s, e);
    }
    var l = ms.capLen[i];
    if (l === CAP_UNFINISHED) throw rterror('unfinished capture');
    if (l === CAP_POSITION) return ms.capInit[i] + 1;
    return ms.src.substr(ms.capInit[i], l);
  }
  function captures(ms, s, e, wholeIfNone) {
    var n = (ms.level === 0 && wholeIfNone) ? 1 : ms.level;
    var out = [];
    for (var i = 0; i < n; i++) out.push(getCapture(ms, i, s, e));
    return out;
  }
  var SPECIALS = /[\^$*+?.()[\]%-]/;
  function strFindAux(find, s, p, init, plain, fname) {
    s = checkStr(s, 1, fname); p = checkStr(p, 2, fname);
    var ls = s.length;
    var st = posrelatI(optInt(init, 3, fname, 1), ls) - 1;
    if (st > ls) return undefined;
    if (find && (truthy(plain) || !SPECIALS.test(p))) {
      var idx = s.indexOf(p, st);
      if (idx >= 0) return new Multi([idx + 1, idx + p.length]);
      return undefined;
    }
    var anchor = p.charCodeAt(0) === 94;
    var pp = anchor ? p.slice(1) : p;
    var ms = new MatchState(s, pp);
    var s1 = st;
    do {
      ms.level = 0; ms.matchdepth = MAXCCALLS;
      var res = doMatch(ms, s1, 0);
      if (res !== -1) {
        if (find) return new Multi([s1 + 1, res].concat(captures(ms, -1, 0, false)));
        return ret(captures(ms, s1, res, true));
      }
    } while (s1++ < ls && !anchor);
    return undefined;
  }
  stringLib.set('find', function (s, p, init, plain) { return strFindAux(true, s, p, init, plain, 'find'); });
  stringLib.set('match', function (s, p, init) { return strFindAux(false, s, p, init, false, 'match'); });
  stringLib.set('gmatch', function (s, p, init) {
    s = checkStr(s, 1, 'gmatch'); p = checkStr(p, 2, 'gmatch');
    var ls = s.length;
    var src = posrelatI(optInt(init, 3, 'gmatch', 1), ls) - 1;
    if (src > ls) src = ls + 1;
    var ms = new MatchState(s, p), lastmatch = -1;
    return function () {
      for (; src <= ls; src++) {
        ms.level = 0; ms.matchdepth = MAXCCALLS;
        var e = doMatch(ms, src, 0);
        if (e !== -1 && e !== lastmatch) {
          var start = src;
          src = lastmatch = e;
          return ret(captures(ms, start, e, true));
        }
      }
      return undefined;
    };
  });
  stringLib.set('gsub', function (s, p, repl, maxn) {
    s = checkStr(s, 1, 'gsub'); p = checkStr(p, 2, 'gsub');
    var tr = typeName(repl);
    if (!(tr === 'number' || tr === 'string' || tr === 'table' || tr === 'function')) {
      throw argError(3, 'gsub', 'string/function/table expected, got ' + typeNameArg(repl));
    }
    var maxS = maxn === undefined ? s.length + 1 : checkInt(maxn, 4, 'gsub');
    var anchor = p.charCodeAt(0) === 94;
    var pp = anchor ? p.slice(1) : p;
    var ms = new MatchState(s, pp);
    var src = 0, lastmatch = -1, n = 0, out = '';
    var rs = tr === 'string' || tr === 'number' ? (typeof repl === 'string' ? repl : numStr(repl)) : null;
    while (n < maxS) {
      ms.level = 0; ms.matchdepth = MAXCCALLS;
      var e = doMatch(ms, src, 0);
      if (e !== -1 && e !== lastmatch) {
        n++;
        out += addValue(ms, src, e, repl, rs, tr);
        src = lastmatch = e;
      } else if (src < s.length) out += s[src++];
      else break;
      if (anchor) break;
    }
    if (src < s.length) out += s.slice(src);
    return new Multi([out, n]);
  });
  function addValue(ms, s, e, repl, rs, tr) {
    var whole = ms.src.slice(s, e), v;
    if (rs !== null) {
      var o = '';
      for (var i = 0; i < rs.length; i++) {
        var c = rs[i];
        if (c !== '%') { o += c; continue; }
        i++;
        var d = rs[i];
        if (d === '%') o += '%';
        else if (d !== undefined && d >= '0' && d <= '9') {
          var cap = d === '0' ? whole : getCapture(ms, d.charCodeAt(0) - 49, s, e);
          o += typeof cap === 'string' ? cap : numStr(cap);
        } else throw rterror("invalid use of '%' in replacement string");
      }
      return o;
    }
    var caps = captures(ms, s, e, true);
    if (tr === 'table') v = index(repl, caps[0]);
    else v = first(call(repl).apply(null, caps));
    if (v === undefined || v === false) return whole;
    if (typeof v === 'string') return v;
    if (isNum(v)) return numStr(v);
    throw rterror('invalid replacement value (a ' + typeName(v) + ')');
  }

  // ===================================================== conversion =======
  // Between JS values (UTF-16 strings, arrays, objects) and Lua values.
  var encoder = typeof TextEncoder !== 'undefined' ? new TextEncoder() : null;
  var decoder = typeof TextDecoder !== 'undefined' ? new TextDecoder('utf-8') : null;
  function toBytes(str) {        // JS string -> Lua byte string
    if (/^[\x00-\x7f]*$/.test(str)) return str;
    var b = encoder.encode(str), s = '';
    for (var i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
    return s;
  }
  function fromBytes(s) {        // Lua byte string -> JS string
    if (/^[\x00-\x7f]*$/.test(s)) return s;
    var b = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) b[i] = s.charCodeAt(i);
    return decoder.decode(b);
  }
  function toLua(v) {
    if (v === null || v === undefined) return undefined;
    if (typeof v === 'string') return toBytes(v);
    if (typeof v === 'number' || typeof v === 'boolean' || typeof v === 'function') return v;
    if (v instanceof LuaTable || v instanceof LFloat) return v;
    var t = new LuaTable();
    if (Array.isArray(v)) { for (var i = 0; i < v.length; i++) t.set(i + 1, toLua(v[i])); return t; }
    Object.keys(v).forEach(function (k) { t.set(toBytes(k), toLua(v[k])); });
    return t;
  }
  function toJS(v, seen) {
    if (v instanceof LFloat) return v.n;
    if (typeof v === 'string') return fromBytes(v);
    if (!(v instanceof LuaTable)) return v;
    seen = seen || new Map();
    if (seen.has(v)) return seen.get(v);
    var n = v.arr.length, hashSize = v.hash ? v.hash.size : 0;
    if (hashSize === 0) {
      var a = [];
      seen.set(v, a);
      for (var i = 0; i < n; i++) a.push(toJS(v.arr[i], seen));
      return a;
    }
    var o = {};
    seen.set(v, o);
    for (var j = 0; j < n; j++) if (v.arr[j] !== undefined) o[j + 1] = toJS(v.arr[j], seen);
    v.hash.forEach(function (val, key) {
      var k = typeof key === 'string' ? fromBytes(key) : (isNum(key) ? numStr(key) : tostring(key));
      o[k] = toJS(val, seen);
    });
    return o;
  }

  NS.LFloat = LFloat; NS.mkf = mkf; NS.Multi = Multi; NS.first = first; NS.sp = sp; NS.ret = ret;
  NS.LuaTable = LuaTable; NS.NONE = NONE; NS.LuaError = LuaError; NS.lineMaps = lineMaps;
  NS.add = add; NS.sub = sub; NS.mul = mul; NS.div = div; NS.idiv = idiv; NS.mod = mod; NS.pow = pow;
  NS.unm = unm; NS.band = band; NS.bor = bor; NS.bxor = bxor; NS.shl = shl; NS.shr = shr; NS.bnot = bnot;
  NS.concat = concat; NS.len = len; NS.eq = eq; NS.lt = lt; NS.le = le; NS.gt = gt; NS.ge = ge;
  NS.T = truthy; NS.index = index; NS.setindex = setindex; NS.call = call; NS.method = method;
  NS.tbl = tbl; NS.iter = iter; NS.forprep = forprep; NS.tostring = tostring; NS.typeName = typeName;
  NS.makeEnv = makeEnv; NS.toLua = toLua; NS.toJS = toJS; NS.toBytes = toBytes; NS.fromBytes = fromBytes;
  NS.numStr = numStr; NS.str2num = str2num; NS.errorValue = errorValue; NS.rterror = rterror;
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawLua = globalThis.MiddawLua || {}))
  : (globalThis.MiddawLua = globalThis.MiddawLua || {}));


/* ---- kit/runtime/lua_compile.js ---- */
/* Middaw's Lua 5.4, part 2 of 3: syntax tree in, JavaScript out.
 *
 * Every Lua local becomes a JS `let` with a name of its own ($x, $x$2...), so
 * shadowing and closures behave as in Lua: a fresh binding per declaration,
 * and per loop iteration. Every operator goes through the runtime, so the
 * integer/float distinction and the error messages are Lua's. Each statement
 * starts a new line carrying a marker with its Lua line number, which is how
 * an error raised in the generated code is reported at the Lua line.
 */
(function (NS) {
  'use strict';

  var ARITH = { '+': 'add', '-': 'sub', '*': 'mul', '/': 'div', '%': 'mod', '^': 'pow', '//': 'idiv',
                '&': 'band', '|': 'bor', '~': 'bxor', '<<': 'shl', '>>': 'shr', '..': 'concat' };
  var COMPARE = { '==': 'eq', '<': 'lt', '<=': 'le', '>': 'gt', '>=': 'ge' };

  function compile(ast, chunk) {
    var consts = [];
    var nameCounts = Object.create(null);

    function uniqueName(luaName) {
      var n = (nameCounts[luaName] || 0) + 1;
      nameCounts[luaName] = n;
      return n === 1 ? '$' + luaName : '$' + luaName + '$' + n;
    }

    function FuncState(parent, vararg) {
      this.parent = parent; this.vararg = vararg; this.temps = 0; this.scopes = [];
    }
    var fs = null;
    var stmtUid = 0;

    function newTemp() { fs.temps++; return '$$' + fs.temps; }
    function lookup(name) {
      for (var f = fs; f; f = f.parent) {
        for (var i = f.scopes.length - 1; i >= 0; i--) {
          var js = f.scopes[i][name];
          if (js !== undefined) return js;
        }
      }
      return null;
    }
    function declare(name) {
      var js = uniqueName(name);
      fs.scopes[fs.scopes.length - 1][name] = js;
      return js;
    }
    function openScope() { fs.scopes.push(Object.create(null)); }
    function closeScope() { fs.scopes.pop(); }

    function err(msg, line) {
      throw new NS.LuaSyntaxError(msg, chunk, line || 0);
    }

    function str(s) { return JSON.stringify(s); }

    function numberLiteral(text) {
      var v;
      if (/^0[xX]/.test(text)) {
        if (/[.pP]/.test(text)) v = NS.str2num(text);
        else {
          var big = BigInt.asIntN(64, BigInt('0x' + text.slice(2)));
          return String(Number(big));
        }
      } else if (/[.eE]/.test(text)) {
        v = NS.mkf(Number(text));
      } else {
        var n = Number(text);
        if (Math.abs(n) > 9223372036854775807) v = NS.mkf(n);
        else return String(n);
      }
      if (v instanceof NS.LFloat) {
        var idx = consts.length;
        consts.push(v);
        return '$$K[' + idx + ']';
      }
      var s = String(v);
      return s === 'Infinity' ? 'Infinity' : (s === 'NaN' ? 'NaN' : (v < 0 ? '(' + s + ')' : s));
    }

    function describe(e) {
      if (e.k === 'Name') return lookup(e.name) ? "local '" + e.name + "'" : "global '" + e.name + "'";
      if (e.k === 'Index' && e.key.k === 'String') return "field '" + e.key.v + "'";
      if (e.k === 'Method') return "method '" + e.name + "'";
      return '';
    }

    function isMultiExpr(e) { return e.k === 'Call' || e.k === 'Method' || e.k === 'Vararg'; }

    // A JS expression for the raw result of a call: possibly a Multi.
    function callRaw(e) {
      if (e.k === 'Method') {
        var o = ex(e.obj);
        var args = argList(e.args);
        return 'L.method(' + o + ', ' + str(e.name) + (args ? ', ' + args : '') + ')';
      }
      var fn = ex(e.fn), a = argList(e.args), d = describe(e.fn);
      if (/^\$[A-Za-z_][\w$]*$/.test(fn)) {
        return '(typeof ' + fn + " === 'function' ? " + fn + ' : L.call(' + fn + ', ' + str(d) + '))(' + a + ')';
      }
      var t = newTemp();
      return '(typeof (' + t + ' = ' + fn + ") === 'function' ? " + t + ' : L.call(' + t + ', ' + str(d) + '))(' + a + ')';
    }

    function argList(exprs) {
      var out = [];
      for (var i = 0; i < exprs.length; i++) {
        var e = exprs[i], last = i === exprs.length - 1;
        if (last && (e.k === 'Call' || e.k === 'Method')) out.push('...L.sp(' + callRaw(e) + ')');
        else if (last && e.k === 'Vararg') { checkVararg(e); out.push('...$$va'); }
        else out.push(ex(e));
      }
      return out.join(', ');
    }
    function checkVararg(e) {
      if (!fs.vararg) err("cannot use '...' outside a vararg function", e.line);
    }

    // A JS expression for exactly one Lua value.
    function ex(e) {
      switch (e.k) {
        case 'Nil': return 'undefined';
        case 'True': return 'true';
        case 'False': return 'false';
        case 'Number': return numberLiteral(e.v);
        case 'String': return str(e.v);
        case 'Vararg': checkVararg(e); return '$$va[0]';
        case 'Function': return funcExpr(e);
        case 'Paren': return ex(e.expr);
        case 'Name': {
          var js = lookup(e.name);
          if (js) return js;
          return 'L.index($$G, ' + str(e.name) + ')';
        }
        case 'Index':
          return 'L.index(' + ex(e.obj) + ', ' + ex(e.key) + ', ' + str(describe(e.obj)) + ')';
        case 'Call': case 'Method':
          return 'L.first(' + callRaw(e) + ')';
        case 'Table': return tableExpr(e);
        case 'Unop': {
          if (e.op === 'not') return '!' + cond(e.expr);
          if (e.op === '-') {
            if (e.expr.k === 'Number') {
              var lit = numberLiteral(e.expr.v);
              if (/^\d+$/.test(lit)) return lit === '0' ? '0' : '(-' + lit + ')';
              if (/^[\d.e+-]+$/.test(lit)) return '(-' + lit + ')';
            }
            return 'L.unm(' + ex(e.expr) + ')';
          }
          if (e.op === '#') return 'L.len(' + ex(e.expr) + ')';
          if (e.op === '~') return 'L.bnot(' + ex(e.expr) + ')';
          break;
        }
        case 'Binop': {
          if (e.op === 'and') {
            var t = newTemp();
            return '(L.T(' + t + ' = ' + ex(e.left) + ') ? ' + ex(e.right) + ' : ' + t + ')';
          }
          if (e.op === 'or') {
            var t2 = newTemp();
            return '(L.T(' + t2 + ' = ' + ex(e.left) + ') ? ' + t2 + ' : ' + ex(e.right) + ')';
          }
          if (e.op === '~=') return '!L.eq(' + ex(e.left) + ', ' + ex(e.right) + ')';
          if (COMPARE[e.op]) return 'L.' + COMPARE[e.op] + '(' + ex(e.left) + ', ' + ex(e.right) + ')';
          return 'L.' + ARITH[e.op] + '(' + ex(e.left) + ', ' + ex(e.right) + ')';
        }
      }
      err('cannot compile expression ' + e.k, e.line);
    }

    // A JS boolean expression for Lua truth, without building a Lua value.
    function cond(e) {
      switch (e.k) {
        case 'True': return 'true';
        case 'False': case 'Nil': return 'false';
        case 'Paren': return cond(e.expr);
        case 'Unop': if (e.op === 'not') return '!' + cond(e.expr); break;
        case 'Binop':
          if (e.op === 'and') return '(' + cond(e.left) + ' && ' + cond(e.right) + ')';
          if (e.op === 'or') return '(' + cond(e.left) + ' || ' + cond(e.right) + ')';
          if (e.op === '~=' || COMPARE[e.op]) return ex(e);
          break;
      }
      return 'L.T(' + ex(e) + ')';
    }

    function tableExpr(e) {
      var pos = [], keyed = [];
      for (var i = 0; i < e.items.length; i++) {
        var it = e.items[i];
        if (it.kind === 'pos') {
          var lastPos = true;
          for (var j = i + 1; j < e.items.length; j++) if (e.items[j].kind === 'pos') { lastPos = false; break; }
          if (lastPos && (it.value.k === 'Call' || it.value.k === 'Method')) pos.push('...L.sp(' + callRaw(it.value) + ')');
          else if (lastPos && it.value.k === 'Vararg') { checkVararg(it.value); pos.push('...$$va'); }
          else pos.push(ex(it.value));
        } else {
          keyed.push(ex(it.key), ex(it.value));
        }
      }
      if (!keyed.length) return 'L.tbl([' + pos.join(', ') + '])';
      return 'L.tbl([' + pos.join(', ') + '], [' + keyed.join(', ') + '])';
    }

    function funcExpr(f) {
      var saved = fs;
      fs = new FuncState(saved, f.vararg);
      openScope();
      var params = f.params.map(function (p) { return declare(p); });
      if (f.vararg) params.push('...$$va');
      var body = block(f.body);
      closeScope();
      var temps = '';
      if (fs.temps) {
        var names = [];
        for (var i = 1; i <= fs.temps; i++) names.push('$$' + i);
        temps = 'let ' + names.join(', ') + ';';
      }
      fs = saved;
      return 'function (' + params.join(', ') + ') {' + temps + body + '\n/*@' + (f.endLine || f.line) + '*/return L.NONE;}';
    }

    function block(stmts) {
      var out = '';
      for (var i = 0; i < stmts.length; i++) out += statement(stmts[i]);
      return out;
    }
    function scoped(stmts) {
      openScope();
      var b = block(stmts);
      closeScope();
      return b;
    }

    function assignTo(target, value) {
      if (target.k === 'Name') {
        var js = lookup(target.name);
        if (js) return js + ' = ' + value + ';';
        return 'L.setindex($$G, ' + str(target.name) + ', ' + value + ');';
      }
      return 'L.setindex(' + ex(target.obj) + ', ' + ex(target.key) + ', ' + value + ', ' + str(describe(target.obj)) + ');';
    }

    function valuesArray(exprs) { return '[' + argList(exprs) + ']'; }

    function statement(s) {
      var mark = '\n/*@' + (s.line || 0) + '*/';
      switch (s.k) {
        case 'Local': {
          var attrs = s.attribs || [];
          attrs.forEach(function (a) {
            if (a && a !== 'const' && a !== 'close') err("unknown attribute '" + a + "'", s.line);
          });
          if (s.names.length === 1 && s.exprs.length <= 1) {
            var v = s.exprs.length ? ex(s.exprs[0]) : 'undefined';
            return mark + 'let ' + declare(s.names[0]) + ' = ' + v + ';';
          }
          if (s.exprs.length === s.names.length && !s.exprs.some(isMultiExpr)) {
            var vals = s.exprs.map(ex);
            var tmpNames = vals.map(function () { return '$$l' + (++stmtUid); });
            var pre = 'const ' + tmpNames.map(function (t, i) { return t + ' = ' + vals[i]; }).join(', ') + ';';
            var decl = s.names.map(function (n, i) { return declare(n) + ' = ' + tmpNames[i]; });
            return mark + pre + ' let ' + decl.join(', ') + ';';
          }
          var r = '$$r' + (++stmtUid);
          var code = 'const ' + r + ' = ' + valuesArray(s.exprs) + ';';
          var decls = s.names.map(function (n, i) { return declare(n) + ' = ' + r + '[' + i + ']'; });
          return mark + code + ' let ' + decls.join(', ') + ';';
        }
        case 'LocalFunction': {
          var name = declare(s.name);
          return mark + 'let ' + name + '; ' + name + ' = ' + funcExpr(s.func) + ';';
        }
        case 'Assign': {
          if (s.targets.length === 1 && s.exprs.length === 1) {
            return mark + assignTo(s.targets[0], ex(s.exprs[0]));
          }
          var rr = '$$r' + (++stmtUid);
          var c2 = 'const ' + rr + ' = ' + valuesArray(s.exprs) + ';';
          s.targets.forEach(function (t, i) { c2 += ' ' + assignTo(t, rr + '[' + i + ']'); });
          return mark + c2;
        }
        case 'ExprStat':
          return mark + callRaw(s.expr) + ';';
        case 'Do':
          return mark + '{' + scoped(s.body) + '\n}';
        case 'While':
          return mark + 'while (' + cond(s.cond) + ') {' + scoped(s.body) + '\n}';
        case 'Repeat': {
          openScope();
          var body = block(s.body);
          var cnd = cond(s.cond);
          closeScope();
          return mark + 'for (;;) {' + body + '\nif (' + cnd + ') break;\n}';
        }
        case 'If': {
          var o = mark;
          s.clauses.forEach(function (c, i) {
            o += (i ? ' else if (' : 'if (') + cond(c.cond) + ') {' + scoped(c.body) + '\n}';
          });
          if (s.orelse) o += ' else {' + scoped(s.orelse) + '\n}';
          return o;
        }
        case 'NumFor': {
          var u = ++stmtUid;
          var I = '$$i' + u, LIM = '$$m' + u, ST = '$$s' + u, FL = '$$f' + u;
          var start = ex(s.start), limit = ex(s.limit);
          var stepLit = !s.step ? 1 : (s.step.k === 'Number' && /^\d+$/.test(s.step.v) ? Number(s.step.v) : null);
          var step = s.step ? ex(s.step) : '1';
          var intStart = s.start.k === 'Number' && /^\d+$/.test(s.start.v);
          var test = stepLit !== null && stepLit > 0 ? I + ' <= ' + LIM : '(' + ST + ' > 0 ? ' + I + ' <= ' + LIM + ' : ' + I + ' >= ' + LIM + ')';
          openScope();
          var v2 = declare(s.name);
          var bindVal = (intStart && stepLit !== null) ? I : FL + ' ? L.mkf(' + I + ') : ' + I;
          var bd = block(s.body);
          closeScope();
          return mark + 'for (let [' + I + ', ' + LIM + ', ' + ST + ', ' + FL + '] = L.forprep(' + start + ', ' + limit + ', ' + step + '); ' +
                 test + '; ' + I + ' += ' + ST + ') { let ' + v2 + ' = ' + bindVal + ';' + bd + '\n}';
        }
        case 'GenFor': {
          var it = '$$it' + (++stmtUid);
          var head = 'const ' + it + ' = L.iter(' + argList(s.exprs) + ');';
          openScope();
          var binds = s.names.map(function (n, i) {
            var src = i === 0 ? it + '.a' : (i === 1 ? it + '.b' : it + '.v[' + i + ']');
            return declare(n) + ' = ' + src;
          });
          var gb = block(s.body);
          closeScope();
          return mark + '{' + head + ' while (' + it + '.step()) { let ' + binds.join(', ') + ';' + gb + '\n}}';
        }
        case 'Return': {
          var ex0 = s.exprs;
          if (!ex0.length) return mark + 'return L.NONE;';
          if (ex0.length === 1) {
            if (ex0[0].k === 'Call' || ex0[0].k === 'Method') return mark + 'return ' + callRaw(ex0[0]) + ';';
            if (ex0[0].k === 'Vararg') { checkVararg(ex0[0]); return mark + 'return L.ret($$va);'; }
            return mark + 'return ' + ex(ex0[0]) + ';';
          }
          return mark + 'return L.ret(' + valuesArray(ex0) + ');';
        }
        case 'Break': return mark + 'break;';
        case 'Goto': case 'Label':
          err('goto and labels are not supported by Middaw\'s Lua', s.line);
      }
      err('cannot compile statement ' + s.k, s.line);
    }

    fs = new FuncState(null, true);
    openScope();
    var body = block(ast.body);
    closeScope();
    var temps = '';
    if (fs.temps) {
      var names = [];
      for (var i = 1; i <= fs.temps; i++) names.push('$$' + i);
      temps = 'let ' + names.join(', ') + ';';
    }
    return { body: temps + body, consts: consts };
  }

  // The line the first line of a `new Function` body is reported as.
  var lineOffset = null;
  function probeOffset() {
    if (lineOffset !== null) return lineOffset;
    try {
      new Function('throw new Error("probe");\n//# sourceURL=lua:__probe__')();
    } catch (e) {
      var m = /lua:__probe__:(\d+)/.exec(e.stack || '');
      lineOffset = m ? Number(m[1]) - 1 : 0;
    }
    return lineOffset;
  }

  var chunkUid = 0;
  // Lua source (a byte string) -> a JS function, as `load` gives it.
  function load(src, chunkname, env) {
    var name = String(chunkname || 'chunk').replace(/[^A-Za-z0-9_.\/-]/g, '_');
    if (NS.lineMaps[name]) name = name + '#' + (++chunkUid);
    var ast = NS.parse(src, name);
    var out = compile(ast, name);
    var code = 'return function (...$$va) {' + out.body + '\nreturn L.NONE;\n};';
    var offset = probeOffset();
    var lines = code.split('\n'), map = [], cur = 0;
    for (var i = 0; i < offset; i++) map.push(0);
    for (var j = 0; j < lines.length; j++) {
      var m = /^\/\*@(\d+)\*\//.exec(lines[j]);
      if (m) cur = Number(m[1]);
      map.push(cur);
    }
    NS.lineMaps[name.replace(/#/g, '_')] = map;
    var factory = new Function('L', '$$G', '$$K', code + '\n//# sourceURL=lua:' + name.replace(/#/g, '_'));
    return factory(NS, env || NS.defaultEnv(), out.consts);
  }

  var sharedEnv = null;
  NS.defaultEnv = function () { return sharedEnv || (sharedEnv = NS.makeEnv()); };
  NS.compile = compile;
  NS.load = load;
})(typeof module === 'object' && module.exports
  ? (module.exports = (globalThis.MiddawLua = globalThis.MiddawLua || {}))
  : (globalThis.MiddawLua = globalThis.MiddawLua || {}));


/* ---- kit/gfx.js ---- */
/* REAPER's gfx_* drawing, on Max's mgraphics: the host a JSFX's @gfx runs on
 * (MiddawJSFX's runGfx). Each method takes the JSFX first, reads gfx_r, gfx_x
 * and the rest from its variables, and draws as REAPER would: text from its
 * top-left, gfx_x moved on past it, angles from twelve o'clock clockwise.
 *
 * gfx_showmenu cannot wait for a choice inside a frame, so it asks for one:
 * `menu` is set, the frame returns 0, and the device draws the menu. When an
 * item is chosen the device puts the variables back as they were at the start
 * of that frame and runs it again, and this time gfx_showmenu returns the item.
 */
var Gfx = (function () {
  'use strict';
  function Host(g) {
    this.g = g;
    this.fonts = { 0: { name: 'Arial', size: 13, flags: 0 } };
    this.font = 0;
    this.menu = null;        // { text, x, y } asked for this frame
    this.choice = 0;         // the item to give gfx_showmenu on the replayed frame
    this.slots = null;
  }
  Host.prototype.begin = function (g, fx) {
    this.g = g;
    if (!this.slots || this.fx !== fx) {
      this.fx = fx;
      var s = fx.slots;
      this.slots = { r: s.gfx_r, g: s.gfx_g, b: s.gfx_b, a: s.gfx_a, x: s.gfx_x, y: s.gfx_y, texth: s.gfx_texth,
                     mx: s.mouse_x, my: s.mouse_y, clear: s.gfx_clear };
    }
    this.menu = null;
    this.applyFont();
  };
  Host.prototype.v = function (k) { return this.fx.v[this.slots[k]]; };
  Host.prototype.set = function (k, x) { this.fx.v[this.slots[k]] = x; };
  // Every colour the script sets goes through Palette.tone: the house scheme
  // becomes Live's, other greys lose their tint, other colours stay.
  function toned(r, g, b) { return typeof Palette !== 'undefined' ? Palette.tone(r, g, b) : [clamp(r), clamp(g), clamp(b)]; }
  Host.prototype.colour = function () {
    var c = toned(this.v('r') || 0, this.v('g') || 0, this.v('b') || 0);
    this.g.set_source_rgba(c[0], c[1], c[2], clamp(this.v('a')));
  };
  // EEL2 strings are bytes; REAPER draws them as UTF-8.
  function utf8(s) { try { return decodeURIComponent(escape(s)); } catch (e) { return s; } }
  function clamp(x) { return x < 0 ? 0 : x > 1 ? 1 : (x || 0); }
  function num(x, d) { return x === undefined || x !== x ? d : x; }

  // ------------------------------------------------------------ colour ---
  Host.prototype.gfx_set = function (fx, r, g, b, a) {
    r = num(r, 0);
    this.set('r', r); this.set('g', num(g, r)); this.set('b', num(b, r)); this.set('a', num(a, 1));
    return 0;
  };

  // ------------------------------------------------------------ shapes ---
  Host.prototype.gfx_rect = function (fx, x, y, w, h, filled) {
    if (!(w > 0 && h > 0)) return 0;
    this.colour();
    if (num(filled, 1)) { this.g.rectangle(x, y, w, h); this.g.fill(); }
    else { this.g.set_line_width(1); this.g.rectangle(x + 0.5, y + 0.5, w - 1, h - 1); this.g.stroke(); }
    return 0;
  };
  Host.prototype.gfx_line = function (fx, x1, y1, x2, y2) {
    this.colour();
    this.g.set_line_width(1);
    this.g.move_to(x1 + 0.5, y1 + 0.5); this.g.line_to(x2 + 0.5, y2 + 0.5); this.g.stroke();
    return 0;
  };
  Host.prototype.gfx_lineto = function (fx, x, y) {
    this.gfx_line(fx, this.v('x'), this.v('y'), x, y);
    this.set('x', x); this.set('y', y);
    return 0;
  };
  Host.prototype.gfx_circle = function (fx, x, y, r, fill) {
    this.colour();
    this.g.arc(x, y, Math.max(0, r), 0, Math.PI * 2);
    if (num(fill, 0)) this.g.fill(); else { this.g.set_line_width(1); this.g.stroke(); }
    return 0;
  };
  Host.prototype.gfx_arc = function (fx, x, y, r, a1, a2) {
    this.colour();
    this.g.set_line_width(1);
    this.g.arc(x, y, Math.max(0, r), a1 - Math.PI / 2, a2 - Math.PI / 2);
    this.g.stroke();
    return 0;
  };
  Host.prototype.gfx_roundrect = function (fx, x, y, w, h, radius) {
    this.colour();
    this.g.set_line_width(1);
    this.g.rectangle_rounded(x + 0.5, y + 0.5, w, h, radius * 2, radius * 2);
    this.g.stroke();
    return 0;
  };
  Host.prototype.gfx_triangle = function (fx) {
    var p = Array.prototype.slice.call(arguments, 1);
    if (p.length < 6) return 0;
    this.colour();
    this.g.move_to(p[0], p[1]);
    for (var i = 2; i + 1 < p.length; i += 2) this.g.line_to(p[i], p[i + 1]);
    this.g.close_path();
    this.g.fill();
    return 0;
  };
  Host.prototype.gfx_gradrect = function (fx, x, y, w, h, r, g, b, a) {
    var c = toned(r || 0, g || 0, b || 0);
    this.g.set_source_rgba(c[0], c[1], c[2], clamp(num(a, 1)));
    this.g.rectangle(x, y, w, h); this.g.fill();
    return 0;
  };

  // -------------------------------------------------------------- text ---
  // gfx_setfont(idx, name, size, flags): flags is a character code, 'b' bold, 'i' italic.
  Host.prototype.gfx_setfont = function (fx, idx, name, size, flags) {
    idx = Math.trunc(num(idx, 0));
    if (name !== undefined && idx > 0) {
      this.fonts[idx] = { name: fx.str(name) || 'Arial', size: num(size, 13), flags: Math.trunc(num(flags, 0)) };
    }
    this.font = this.fonts[idx] ? idx : 0;
    this.applyFont();
    return 1;
  };
  Host.prototype.gfx_getfont = function () { return this.font; };
  Host.prototype.applyFont = function () {
    var f = this.fonts[this.font] || this.fonts[0], fl = f.flags;
    // REAPER's names for the system face are not names Max can ask for
    var face = /^\./.test(f.name) || /^segoe/i.test(f.name) ? 'Arial' : f.name;
    var bold = fl === 98 || ((fl >> 8) & 255) === 98 || ((fl >> 16) & 255) === 98;
    var italic = fl === 105 || ((fl >> 8) & 255) === 105 || ((fl >> 16) & 255) === 105;
    this.g.select_font_face(face, italic ? 'italic' : 'normal', bold ? 'bold' : 'normal');
    this.g.set_font_size(f.size);
    this.size = f.size;
    if (this.slots) this.set('texth', Math.round(f.size));
  };
  Host.prototype.measure = function (s) {
    var m = this.g.text_measure(s);
    return [m[0], Math.max(m[1], this.size)];
  };
  Host.prototype.gfx_measurestr = function (fx, s) { this.fx.gm = this.measure(utf8(fx.str(s))); return this.fx.gm[0]; };
  Host.prototype.gfx_measurechar = function (fx, c) { this.fx.gm = this.measure(String.fromCharCode(c)); return this.fx.gm[0]; };
  Host.prototype.text = function (s, flags, right, bottom) {
    var x = this.v('x'), y = this.v('y'), m = this.measure(s);
    flags = Math.trunc(num(flags, 0));
    if (right !== undefined && !(flags & 256)) {
      if (flags & 1) x = x + (right - x - m[0]) / 2; else if (flags & 2) x = right - m[0];
      if (flags & 4) y = y + (bottom - y - m[1]) / 2; else if (flags & 8) y = bottom - m[1];
    }
    this.colour();
    this.g.move_to(x, y + this.size * 0.8);
    this.g.show_text(s);
    this.set('x', x + m[0]);
    return 0;
  };
  Host.prototype.gfx_drawstr = function (fx, s, flags, right, bottom) { return this.text(utf8(fx.str(s)), flags, right, bottom); };
  Host.prototype.gfx_drawchar = function (fx, c) { return this.text(String.fromCharCode(c)); };
  Host.prototype.gfx_drawnumber = function (fx, n, digits) { return this.text(Number(n).toFixed(Math.max(0, Math.trunc(num(digits, 0))))); };
  Host.prototype.gfx_printf = function (fx, fmt) {
    var args = Array.prototype.slice.call(arguments, 2);
    var s = fx.str(fmt).replace(/%(-?\d*)(?:\.(\d+))?([dfsxXc%])/g, function (m, w, p, k) {
      if (k === '%') return '%';
      var a = args.shift();
      if (k === 's') return fx.str(a);
      if (k === 'c') return String.fromCharCode(a);
      if (k === 'x' || k === 'X') { var h = Math.trunc(a).toString(16); return k === 'X' ? h.toUpperCase() : h; }
      return k === 'd' ? String(Math.trunc(a)) : Number(a).toFixed(p === undefined ? 6 : +p);
    });
    return this.text(utf8(s));
  };

  // ------------------------------------------------------------- input ---
  // gfx_getchar(65536) asks about the window: 1 it has focus, 2 it is shown,
  // 4 the mouse is in it. With no argument it is the next key typed, which the
  // window's [key] hands in (Host.key); with a key it asks whether it is held.
  Host.prototype.gfx_getchar = function (fx, c) {
    if (c === 65536) return 1 | 2 | (this.mouseIn ? 4 : 0);
    if (c) return 0;
    return this.keys && this.keys.length ? this.keys.shift() : 0;
  };
  // Max's key codes as REAPER's gfx_getchar gives them: the arrows and the
  // editing keys are four-letter codes there.
  var KEYS = { 28: 0x6C656674, 29: 0x72676874, 30: 0x7570, 31: 0x646F776E, 127: 0x64656C, 8: 8, 9: 9, 13: 13, 27: 27,
               '-9': 0x6C656674, '-10': 0x72676874, '-11': 0x7570, '-12': 0x646F776E };
  Host.prototype.key = function (code) {
    (this.keys = this.keys || []).push(KEYS[code] !== undefined ? KEYS[code] : code);
    if (this.keys.length > 32) this.keys.shift();
  };
  Host.prototype.gfx_showmenu = function (fx, s) {
    if (this.choice) { var k = this.choice; this.choice = 0; return k; }
    this.menu = { text: utf8(fx.str(s)), x: this.v('x'), y: this.v('y') };
    return 0;
  };
  Host.prototype.gfx_setcursor = function () { return 0; };
  Host.prototype.gfx_getdropfile = function () { return 0; };
  Host.prototype.gfx_update = function () { return 0; };

  // A menu as gfx_showmenu writes it: items split by |, '#' greyed, '!'
  // ticked, '>' opens a submenu, '<' closes one. Numbered as REAPER numbers
  // them: every item that is not a submenu's title, in order, from 1.
  function parseMenu(text) {
    var out = [], depth = 0, n = 0;
    String(text).split('|').forEach(function (raw) {
      var t = raw, grey = false, tick = false, opens = false, closes = false;
      for (;;) {
        var c = t.charAt(0);
        if (c === '#') { grey = true; t = t.slice(1); } else if (c === '!') { tick = true; t = t.slice(1); }
        else if (c === '>') { opens = true; t = t.slice(1); } else if (c === '<') { closes = true; t = t.slice(1); } else break;
      }
      if (opens) { out.push({ label: t, title: true, depth: depth }); depth++; return; }
      if (t === '' && !closes) { out.push({ rule: true, depth: depth }); return; }
      n++;
      out.push({ label: t, index: n, grey: grey, tick: tick, depth: depth });
      if (closes) depth = Math.max(0, depth - 1);
    });
    return out;
  }

  // gfx_clear's colour (r + g * 256 + b * 65536) as Live draws it.
  function clearColour(c) { return toned((c & 255) / 255, ((c >> 8) & 255) / 255, ((c >> 16) & 255) / 255); }

  // The menu gfx_showmenu asked for, drawn the same in every device.
  var ITEM_H = 20;
  function drawMenu(g, r, items, hover) {
    var P = Palette.C, rgb = Palette.rgb, c;
    c = rgb(P.popup); g.set_source_rgba(c[0], c[1], c[2], 1); g.rectangle(r[0], r[1], r[2], r[3]); g.fill();
    c = rgb(P.edge); g.set_source_rgba(c[0], c[1], c[2], 1); g.set_line_width(1); g.rectangle(r[0] + 0.5, r[1] + 0.5, r[2] - 1, r[3] - 1); g.stroke();
    items.forEach(function (it, i) {
      var y = r[1] + 4 + i * ITEM_H;
      if (it.rule) { c = rgb(P.rule); g.set_source_rgba(c[0], c[1], c[2], 1); g.rectangle(r[0] + 6, y + ITEM_H / 2, r[2] - 12, 1); g.fill(); return; }
      var on = i === hover && it.index && !it.grey;
      if (on) { c = rgb(P.accent); g.set_source_rgba(c[0], c[1], c[2], 1); g.rectangle(r[0] + 2, y, r[2] - 4, ITEM_H); g.fill(); }
      c = rgb(on ? P.ink : it.grey || it.title ? P.dim : P.text);
      g.set_source_rgba(c[0], c[1], c[2], 1);
      g.move_to(r[0] + 22 + it.depth * 12, y + 14);
      g.show_text(it.label);
      if (it.tick) { g.move_to(r[0] + 7 + it.depth * 12, y + 14); g.show_text('✓'); }
    });
  }

  return { Host: Host, parseMenu: parseMenu, clearColour: clearColour, drawMenu: drawMenu, ITEM_H: ITEM_H };
})();


/* ---- kit/lua_device.js ---- */
/* A family ReaScript that draws with gfx, as a Max for Live device: the .lua
 * itself, unchanged, on Middaw's Lua 5.4 runtime, with REAPER's gfx and the
 * parts of the reaper table it uses supplied here.
 *
 * REAPER runs such a script as a loop of reaper.defer callbacks drawing into
 * a window that keeps what was drawn. Here every repaint runs the deferred
 * callback once, its drawing is recorded, and the last frame that drew is
 * shown again until another draws (ScaleView draws only when something
 * changes).
 *
 * gfx.showmenu is modal in REAPER. Middaw's Lua has no coroutines, so a frame
 * that asks for a menu is stopped there (nothing after the call runs) and the
 * menu is drawn; no frame runs while it is open. When an item is chosen the
 * click that opened it is played again at the same place - released, pressed,
 * released - or the same keys typed again, and the menu call it reaches
 * returns the item. That works whether a script acts on the press (Orchestration
 * Helper) or the release (ScaleView), whatever it noted before asking.
 *
 * Expects, before it: Gfx (gfx.js), MiddawLua, and DEVICE = { main, files,
 * size: [w, h], midi }. ExtState and ProjExtState are kept with the Live set.
 * Inlet 0: bang, MIDI bytes, restore, key. Outlets: 0 MIDI bytes (MIDI
 * passes through), 1 the saved state to [pattr], 2 the status line.
 */
inlets = 1;
outlets = 3;
mgraphics.init();
mgraphics.relative_coords = 0;
mgraphics.autofill = 0;

var L = MiddawLua;
var R = {
  pending: null, atexit: null, quit: false, ext: {}, proj: {}, lastSaved: '', ready: false, started: false,
  mouse: { x: -1, y: -1, cap: 0, wheel: 0 }, release: false, frameSaw: true,
  menu: null, choice: 0, asking: null, keys: [], frameKeys: [],
  ops: [], lastOps: [], recording: null, midi: [], seq: 0, running: [], error: null,
  host: new Gfx.Host(mgraphics)
};
function say(msg) { outlet(2, 'set', msg || ''); }

// ------------------------------------------------------------ the gfx table --
var G = new L.LuaTable();
function gnum(k) { var v = G.get(k); return v === undefined ? 0 : +(v instanceof L.LFloat ? v.n : v); }
function gset(k, x) { G.set(k, Number.isInteger(x) ? x : L.mkf ? L.mkf(x) : x); }
// gfx.js's Host reads and writes REAPER's variables through fx.v[slot]; for a
// script they are the fields of the gfx table.
var FX = {
  v: new Proxy({}, { get: function (t, k) { return gnum(k); }, set: function (t, k, x) { gset(k, x); return true; } }),
  slots: { gfx_r: 'r', gfx_g: 'g', gfx_b: 'b', gfx_a: 'a', gfx_x: 'x', gfx_y: 'y', gfx_texth: 'texth',
           mouse_x: 'mouse_x', mouse_y: 'mouse_y', gfx_clear: 'clear' },
  str: null,
  gm: [0, 0]
};
FX.str = function (s) { return typeof s === 'string' ? s : (s === undefined ? '' : String(s instanceof L.LFloat ? s.n : s)); };
['r', 'g', 'b'].forEach(function (k) { gset(k, 1); });
gset('a', 1); gset('x', 0); gset('y', 0); gset('clear', 0); gset('ext_retina', 1); gset('texth', 13);
gset('mouse_x', 0); gset('mouse_y', 0); gset('mouse_cap', 0); gset('mouse_wheel', 0); gset('mouse_hwheel', 0);

var MENU_PENDING = { menuPending: true };
function call(name) {
  var a = Array.prototype.slice.call(arguments, 1);
  return R.host[name].apply(R.host, [FX].concat(a));
}
function flagsOf(f) { return typeof f === 'string' ? (f.length ? f.charCodeAt(0) : 0) : (f instanceof L.LFloat ? f.n : f); }
var GFX = {
  init: function (name, w, h) {
    if (w !== undefined) { gset('w', DEVICE.size[0]); gset('h', DEVICE.size[1]); }
    return 1;
  },
  quit: function () { R.quit = true; return L.NONE; },
  update: function () { return L.NONE; },
  dock: function (v) { return new L.Multi([0, 0, 0, DEVICE.size[0], DEVICE.size[1]]); },
  set: function (r, g, b, a) { call('gfx_set', +r, g === undefined ? undefined : +g, b === undefined ? undefined : +b, a === undefined ? undefined : +a); return L.NONE; },
  rect: function (x, y, w, h, filled) { call('gfx_rect', +x, +y, +w, +h, filled === undefined ? 1 : (filled === true ? 1 : filled === false ? 0 : +filled)); return L.NONE; },
  line: function (x1, y1, x2, y2) { call('gfx_line', +x1, +y1, +x2, +y2); return L.NONE; },
  lineto: function (x, y) { call('gfx_lineto', +x, +y); return L.NONE; },
  circle: function (x, y, r, fill) { call('gfx_circle', +x, +y, +r, fill === true ? 1 : fill === false || fill === undefined ? 0 : +fill); return L.NONE; },
  arc: function (x, y, r, a1, a2) { call('gfx_arc', +x, +y, +r, +a1, +a2); return L.NONE; },
  roundrect: function (x, y, w, h, r) { call('gfx_roundrect', +x, +y, +w, +h, +r); return L.NONE; },
  triangle: function () { call.apply(null, ['gfx_triangle'].concat(Array.prototype.map.call(arguments, Number))); return L.NONE; },
  gradrect: function (x, y, w, h, r, g, b, a) { call('gfx_gradrect', +x, +y, +w, +h, +r, +g, +b, +a); return L.NONE; },
  setfont: function (idx, name, size, flags) { call('gfx_setfont', +idx || 0, name, size === undefined ? undefined : +size, flagsOf(flags)); return 1; },
  getfont: function () { var f = R.host.fonts[R.host.font] || R.host.fonts[0]; return new L.Multi([R.host.font, f.name]); },
  measurestr: function (s) { call('gfx_measurestr', s); return new L.Multi([L.mkf(FX.gm[0]), L.mkf(FX.gm[1])]); },
  measurechar: function (c) { call('gfx_measurechar', +c); return new L.Multi([L.mkf(FX.gm[0]), L.mkf(FX.gm[1])]); },
  drawstr: function (s, flags, right, bottom) { call('gfx_drawstr', s, flags === undefined ? undefined : +flags, right === undefined ? undefined : +right, bottom === undefined ? undefined : +bottom); return L.NONE; },
  drawnumber: function (n, d) { call('gfx_drawnumber', +n, +d); return L.NONE; },
  drawchar: function (c) { call('gfx_drawchar', +c); return L.NONE; },
  printf: function (fmt) { var a = Array.prototype.slice.call(arguments, 1); call.apply(null, ['gfx_printf', fmt].concat(a)); return L.NONE; },
  // Keys typed this frame; the frame that asked for a menu sees the same ones again.
  getchar: function (c) {
    if (c !== undefined && +c === 65536) return 1 | 2 | 8;
    if (c !== undefined && +c !== 0) return 0;
    return R.frameKeys.length ? R.frameKeys.shift() : 0;
  },
  showmenu: function (s) {
    if (R.choice) { var k = R.choice; R.choice = 0; R.menu = null; return k; }
    if (!R.menu) R.menu = { items: Gfx.parseMenu(L.fromBytes ? decode(s) : s), x: gnum('x'), y: gnum('y'), hover: -1 };
    throw MENU_PENDING;
  },
  setcursor: function () { return L.NONE; },
  clienttoscreen: function (x, y) { return new L.Multi([x, y]); },
  screentoclient: function (x, y) { return new L.Multi([x, y]); },
  getimgdim: function () { return new L.Multi([0, 0]); },
  blit: function () { return L.NONE; },
  setimgdim: function () { return L.NONE; },
  loadimg: function () { return -1; },
  getdropfile: function () { return 0; },
  getpixel: function () { return new L.Multi([0, 0, 0]); },
  muloffset: function () { return L.NONE; }
};
function decode(s) { try { return decodeURIComponent(escape(String(s))); } catch (e) { return String(s); } }
Object.keys(GFX).forEach(function (k) { G.set(k, GFX[k]); });

// ------------------------------------------------------- the reaper table --
// What the family's gfx scripts use; anything else is nil, as on an old REAPER.
function str(v) { return v === undefined || v === null ? '' : typeof v === 'string' ? v : String(v instanceof L.LFloat ? v.n : v); }
var REAPER = {
  defer: function (f) { R.pending = f; return L.NONE; },
  atexit: function (f) { R.atexit = f; return L.NONE; },
  time_precise: function () { return L.mkf(Date.now() / 1000); },
  GetOS: function () { return 'macOS-arm64'; },
  GetResourcePath: function () { return '/Live'; },
  GetAppVersion: function () { return '7.0/macOS-arm64'; },
  get_action_context: function () { return new L.Multi([false, '/Live/' + DEVICE.main, 0, 0, 0, 0, 0]); },
  set_action_options: function () { return L.NONE; },
  SetToggleCommandState: function () { return true; },
  RefreshToolbar2: function () { return L.NONE; },
  ShowMessageBox: function (msg) { say(decode(str(msg)).split('\n')[0]); return 1; },
  MB: function (msg) { say(decode(str(msg)).split('\n')[0]); return 1; },
  ShowConsoleMsg: function (msg) { post(decode(str(msg))); return L.NONE; },
  GetExtState: function (sec, key) { var v = R.ext[str(sec) + '\u0000' + str(key)]; return v === undefined ? '' : v; },
  HasExtState: function (sec, key) { return R.ext[str(sec) + '\u0000' + str(key)] !== undefined; },
  SetExtState: function (sec, key, val) { R.ext[str(sec) + '\u0000' + str(key)] = str(val); return L.NONE; },
  DeleteExtState: function (sec, key) { delete R.ext[str(sec) + '\u0000' + str(key)]; return L.NONE; },
  GetProjExtState: function (proj, sec, key) {
    var v = R.proj[str(sec) + '\u0000' + str(key)];
    return new L.Multi([v === undefined ? 0 : v.length, v === undefined ? '' : v]);
  },
  SetProjExtState: function (proj, sec, key, val) { R.proj[str(sec) + '\u0000' + str(key)] = str(val); return 1; },
  EnumProjects: function (idx) { return +idx <= 0 ? new L.Multi([PROJECT, 'Live Set']) : undefined; },
  MarkProjectDirty: function () { return L.NONE; },
  // REAPER's recent MIDI input, newest first: what came into the device.
  MIDI_GetRecentInputEvent: function (idx) {
    var e = R.midi[R.midi.length - 1 - (+idx)];
    if (!e) return new L.Multi([0, '', 0, 0, 0, 0]);
    return new L.Multi([e.seq, e.bytes, 0, 0, 0, 0]);
  }
};
var PROJECT = new L.LuaTable();
var RT = new L.LuaTable();
Object.keys(REAPER).forEach(function (k) { RT.set(k, REAPER[k]); });

// ------------------------------------------------------------- the script --
// Files the script reads (dofile) are found by their name, wherever it asks.
function readFile(path) {
  var p = String(path), base = p.replace(/^.*[\/\\]/, '');
  if (DEVICE.files[p] !== undefined) return DEVICE.files[p];
  if (DEVICE.files[base] !== undefined) return DEVICE.files[base];
  return null;
}
var env = L.makeEnv({ print: function (s) { post(String(s) + '\n'); }, readFile: readFile, writeFile: function () {} });
env.set('gfx', G);
env.set('reaper', RT);
// what a Mac's Lua says about its paths (scripts read the separator from it)
env.get('package').set('config', '/\n;\n?\n!\n-\n');

function start() {
  if (R.started) return;
  R.started = true;
  gset('w', DEVICE.size[0]); gset('h', DEVICE.size[1]);
  frame(function () { L.call(L.load(DEVICE.files[DEVICE.main], DEVICE.main, env))(); });
}

// One frame: the deferred callback, its drawing recorded. A frame stopped by a
// menu leaves nothing behind but the menu; it runs again until it is answered.
function frame(f, input) {
  var rec = recorder(mgraphics);
  R.host.begin(rec, FX);
  R.frameKeys = input ? input.keys.slice() : R.keys.splice(0);
  var mouse = input ? input.mouse : { x: R.mouse.x, y: R.mouse.y, cap: R.mouse.cap, wheel: R.mouse.wheel };
  if (!input) R.mouse.wheel = 0;
  gset('mouse_x', mouse.x); gset('mouse_y', mouse.y); gset('mouse_cap', mouse.cap);
  if (mouse.wheel) gset('mouse_wheel', gnum('mouse_wheel') + mouse.wheel);
  var keys = R.frameKeys.slice();
  R.pending = null;
  try {
    f();
    R.asking = null;
    // a frame that drew (not one that only set a font) is the one shown
    if (rec.ops.some(function (op) { return op[0] === 'fill' || op[0] === 'stroke' || op[0] === 'show_text'; })) R.lastOps = rec.ops;
  } catch (e) {
    if (e === MENU_PENDING || (e && e.value === MENU_PENDING)) {
      R.asking = { f: f, mouse: mouse, keys: keys, button: R.button || 1 };
      R.pending = f;
      return;
    }
    R.error = String(e && (e.message || (e.value !== undefined ? L.tostring(e.value) : e)));
    say('The script stopped: ' + R.error);
    post('ReaScript error: ' + R.error + '\n');
  }
  R.frameSaw = true;
  if (R.release) { R.release = false; R.mouse.cap = 0; }
}

// mgraphics, recorded: what is drawn is kept to be drawn again; measuring and
// font changes also reach the real one, so text is measured as it will look.
function recorder(g) {
  var ops = [];
  var r = { ops: ops };
  ['set_source_rgba', 'rectangle', 'rectangle_rounded', 'fill', 'fill_preserve', 'stroke', 'move_to', 'line_to',
   'close_path', 'arc', 'ellipse', 'show_text', 'set_line_width', 'new_path'].forEach(function (m) {
    r[m] = function () { ops.push([m, Array.prototype.slice.call(arguments)]); };
  });
  ['select_font_face', 'set_font_size'].forEach(function (m) {
    r[m] = function () { var a = Array.prototype.slice.call(arguments); ops.push([m, a]); g[m].apply(g, a); };
  });
  r.text_measure = function (s) { return g.text_measure(s); };
  return r;
}

// --------------------------------------------------------------- paint ---
function size() {
  var rc = (typeof box !== 'undefined' && box.rect) ? box.rect : [0, 0, DEVICE.size[0], DEVICE.size[1]];
  return [rc[2] - rc[0], rc[3] - rc[1]];
}
function paint() {
  var g = mgraphics, sz = size();
  gset('w', sz[0]); gset('h', sz[1]);
  if (R.started && !R.quit && R.pending && !R.error && !R.menu) frame(R.pending);
  var c = gnum('clear');
  if (c >= 0) { var k = Gfx.clearColour(c); g.set_source_rgba(k[0], k[1], k[2], 1); g.rectangle(0, 0, sz[0], sz[1]); g.fill(); }
  R.lastOps.forEach(function (op) { g[op[0]].apply(g, op[1]); });
  if (R.menu) drawMenu(g, sz);
}

// The menu gfx.showmenu asked for, over the window.
var ITEM_H = Gfx.ITEM_H;
function menuRect(sz) {
  var m = R.menu, w = 40;
  mgraphics.select_font_face('Arial', 'normal', 'normal');
  mgraphics.set_font_size(12);
  m.items.forEach(function (it) { if (it.label) w = Math.max(w, mgraphics.text_measure(it.label)[0] + 40 + it.depth * 12); });
  var h = m.items.length * ITEM_H + 8;
  return [Math.max(0, Math.min(m.x, sz[0] - w - 2)), Math.max(0, Math.min(m.y, sz[1] - h - 2)), w, h];
}
function drawMenu(g, sz) {
  g.select_font_face('Arial', 'normal', 'normal'); g.set_font_size(12);
  Gfx.drawMenu(g, menuRect(sz), R.menu.items, R.menu.hover);
}
function menuAt(x, y) {
  var r = menuRect(size());
  if (x < r[0] || x >= r[0] + r[2] || y < r[1] + 4 || y >= r[1] + r[3] - 4) return -1;
  return Math.floor((y - r[1] - 4) / ITEM_H);
}
// An item chosen: the frame that asked runs again and is given it. Clicking
// away gives it 0, as closing REAPER's menu does.
function chooseMenu(i) {
  var it = i >= 0 ? R.menu.items[i] : null;
  if (it && (!it.index || it.grey)) return;          // a title, a rule or a greyed item: the menu stays
  frameAnswer(R.asking ? R.asking.f : R.pending, it ? it.index : 0);
  save();
  mgraphics.redraw();
}
function frameAnswer(f, k) {
  var ask = R.asking, keep = GFX.showmenu, answered = false;
  // the next gfx.showmenu, wherever the script calls it from, is given the answer
  G.set('showmenu', function () { answered = true; G.set('showmenu', keep); return k; });
  R.menu = null; R.asking = null;
  var x = ask.mouse.x, y = ask.mouse.y, steps = ask.keys.length
    ? [{ cap: 0, keys: [] }, { cap: 0, keys: ask.keys }]
    : [{ cap: 0, keys: [] }, { cap: ask.button, keys: [] }, { cap: 0, keys: [] }];
  steps.forEach(function (st) {
    if (answered || R.error) return;
    var g = R.pending || f;
    frame(g, { mouse: { x: x, y: y, cap: st.cap, wheel: 0 }, keys: st.keys });
  });
  G.set('showmenu', keep);
  R.mouse.cap = 0;
}

// --------------------------------------------------------------- input ---
function onclick(x, y, but, cmd, shift, capslock, opt, ctrl) {
  if (R.menu) { chooseMenu(menuAt(x, y)); return; }
  R.mouse.x = x; R.mouse.y = y;
  R.mouse.cap = (ctrl ? 2 : 1) | (cmd ? 4 : 0) | (shift ? 8 : 0) | (opt ? 16 : 0);
  R.button = R.mouse.cap;
  R.frameSaw = false;
  mgraphics.redraw();
}
function ondrag(x, y, but) {
  if (R.menu) return;
  R.mouse.x = x; R.mouse.y = y;
  if (!but) { if (R.frameSaw) R.mouse.cap = 0; else R.release = true; save(); }
  mgraphics.redraw();
}
function onidle(x, y) {
  if (R.menu) { var i = menuAt(x, y); if (i !== R.menu.hover) { R.menu.hover = i; mgraphics.redraw(); } return; }
  R.mouse.x = x; R.mouse.y = y;
}
function onidleout() { if (!R.menu) { R.mouse.x = -1; R.mouse.y = -1; } }
function onwheel(x, y, dx, dy) { R.mouse.wheel += Math.round(dy * 120); mgraphics.redraw(); }
var KEYS = { 28: 0x6C656674, 29: 0x72676874, 30: 0x7570, 31: 0x646F776E, 127: 0x64656C };
function key(code) {
  if (R.menu && code === 27) { chooseMenu(-1); return; }
  R.keys.push(KEYS[code] !== undefined ? KEYS[code] : code);
  if (R.keys.length > 32) R.keys.shift();
  mgraphics.redraw();
}

// ---------------------------------------------------------------- MIDI ---
// Bytes from [midiin]: passed straight on, and kept as REAPER's recent input.
function msg_int(b) {
  b = b & 255;
  outlet(0, b);
  if (b >= 0xF8) return;
  if (b & 0x80) { R.running = [b]; return; }
  if (!R.running.length || R.running[0] >= 0xF0) return;
  R.running.push(b);
  var st = R.running[0] & 0xF0, need = (st === 0xC0 || st === 0xD0) ? 2 : 3;
  if (R.running.length === need) {
    R.midi.push({ seq: ++R.seq, bytes: String.fromCharCode.apply(null, R.running) });
    if (R.midi.length > 4096) R.midi.splice(0, 1024);
    R.running = [R.running[0]];
    mgraphics.redraw();
  }
}

// ----------------------------------------------------------- the device --
var drawTask = null;
function bang() {
  R.ready = true;
  start();
  if (!drawTask) { drawTask = new Task(function () { mgraphics.redraw(); }, this); drawTask.interval = 33; drawTask.repeat(); }
  mgraphics.redraw();
}
// What the script keeps (ExtState, ProjExtState), with the Live set.
function save() {
  var s = JSON.stringify({ v: 1, ext: R.ext, proj: R.proj });
  if (s === R.lastSaved) return;
  R.lastSaved = s;
  outlet(1, 'set', s);
}
function restore(text) {
  var st = null;
  try { st = JSON.parse(String(text)); } catch (e) { return; }
  if (!st || st.v !== 1) return;
  R.ext = st.ext || {}; R.proj = st.proj || {};
  R.lastSaved = JSON.stringify(st);
  // a script reads its state when it starts: start again with it
  if (R.started) { R.started = false; R.pending = null; R.lastOps = []; R.quit = false; R.error = null; start(); }
}
var saveTask = new Task(function () { save(); }, this);
saveTask.interval = 2000;
saveTask.repeat();

