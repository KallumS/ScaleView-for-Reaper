--[[
 * ReaScript Name: ScaleView Pro
 * Description:    The twelve pitch classes drawn as circles - five black keys
 *                 on the top row over seven white keys on the bottom - with
 *                 the notes of the selected scale lit, the notes you play
 *                 ringed, and the chord you are holding named underneath.
 *
 *                 Note names are spelled for the key: each degree of a
 *                 seven-note scale takes the next letter of the alphabet and
 *                 whatever accidental that letter needs, so C# major reads
 *                 C# D# E# F# G# A# B# while Db major - the same seven notes -
 *                 reads Db Eb F Gb Ab Bb C.
 *
 *                 The chord is read rather than looked up. The third, fifth
 *                 and seventh give the quality, and whatever is left over is
 *                 described as sixths, ninths, elevenths and thirteenths, so
 *                 a voicing nobody thought to tabulate still comes out with a
 *                 name. Where two readings fit, the one with a complete triad
 *                 in it wins, and the odd notes hang off that.
 *
 *                 "Simplify Note Names" in the right-click menu turns that off
 *                 and names every note the way a piano key is named: sharps for
 *                 the black keys, and no double accidentals, so Bbb reads A and
 *                 Cb reads B. This is ScaleView Simple's naming, and the two
 *                 scripts merged into this one.
 * Instructions:   Run the script and play.
 *                 Click a circle for the scale list, click anywhere else for
 *                 a random scale and display options. Either mouse button
 *                 does the same thing.
 *                 Press D to dock/undock, Esc or the window close box to exit.
 * Author:         kallums
 * Version:        1.0
 * Provides:       [main] .
--]]

------------------------------------------------------------------------------
-- Configuration
------------------------------------------------------------------------------

local SCRIPT_NAME  = "ScaleView Pro"
local EXT_SECTION  = "ScaleViewPro"

-- Read only when this script has no settings of its own, so the scale, colour,
-- window position and dock state survive the rename. The long tail of earlier
-- sections was dropped with it: the script had one user, whose settings had
-- already been migrated into the key below.
local EXT_LEGACY   = {"kallums_ScaleViewAlt2"}

local DEFAULT_W    = 200
local DEFAULT_H    = 100

-- Colours are 0..1 RGB triplets, tweak to taste.
local COLOR_BG        = {0.10, 0.10, 0.12}  -- icon background
local COLOR_OFF       = {0.30, 0.31, 0.35}  -- note not in the selected scale
local COLOR_LABEL     = {0.72, 0.74, 0.80}  -- scale name text
local COLOR_TEXT_OFF  = {0.62, 0.64, 0.70}  -- note name on an unlit circle
local COLOR_TEXT_ON   = {0.06, 0.12, 0.11}  -- note name on a highlighted circle
local COLOR_HELD      = {1.00, 1.00, 1.00}  -- ring around a note being played
local COLOR_CHORD     = {0.95, 0.96, 0.98}  -- the chord name, brighter than a scale name

--[[  Chord analysis, built rather than looked up.

  A chord symbol has two halves. The bottom half - third, fifth and seventh -
  is a closed vocabulary: those three can only combine so many ways, and each
  combination has a name musicians agree on. That half is a table, ordered by
  how common the quality is.

  The top half - sixths, ninths, elevenths, thirteenths and their alterations -
  is not closed, so it is described rather than matched. Whatever the bottom
  half did not account for is read off as an extension, which is why a voicing
  nobody thought to tabulate still comes out with a name.
]]

-- How exceptional each core quality is. Lower is commoner, and the whole
-- reading is chosen by adding this to what the extensions cost, so a plain
-- triad in an inversion beats an outlandish chord in root position.
local CORE_RANK = {
  ["maj/P/none"]  =  1, ["min/P/none"]  =  2,
  ["maj/P/b7"]    =  3, ["min/P/b7"]    =  4, ["maj/P/maj7"] =  5,
  ["min/b/b7"]    =  6, ["min/b/bb7"]   =  7, ["min/b/none"] =  8,
  ["maj/#/none"]  =  9,
  ["sus4/P/none"] = 10, ["sus2/P/none"] = 11,
  ["min/P/maj7"]  = 12,
  ["maj/#/b7"]    = 13, ["maj/b/b7"]    = 14, ["maj/#/maj7"] = 15,
  ["sus4/P/b7"]   = 16, ["sus2/P/b7"]   = 17,
  ["sus4/P/maj7"] = 18, ["sus2/P/maj7"] = 19,

  -- A missing third is a different chord, not a thinner one, so these sit
  -- well below anything with a third in it.
  ["none/P/b7"]   = 30, ["none/P/maj7"] = 31,
  ["none/b/maj7"] = 32, ["none/b/b7"]   = 33, ["none/P/none"] = 34,
}

--[[  A quality the table does not name is still ranked by the interval that
    decides most about a chord: the third. A real third - major or minor -
    keeps a chord readable however odd the rest of it is, so F A B reads
    F(b5) rather than losing to B7b5(no3), which has no third in it at all.
    A suspension is not a third but a stand-in for one, and a shape with
    neither is the last thing to reach for. ]]
local RANK_UNNAMED   = {maj = 25, min = 25, sus4 = 70, sus2 = 70, none = 90}
--[[  Except that a third only excuses one oddity. Every altered fifth carrying
    a seventh that musicians actually play is named in the table above - 7b5,
    aug7, min7b5, maj7#5 - so a combination that is not there is strange twice
    over, and should not win on the strength of its third alone. Without this
    C D Eb Gb Cb read CminMaj9b5. ]]
local RANK_TWICE_ODD =  12
--[[  A missing fifth is never spoken, but it is not equally unremarkable. A
    seventh chord is routinely voiced without one - that is the standard shell -
    while a triad with no fifth is two notes and a guess, so the two are
    charged differently. ]]
local RANK_NO_FIFTH  =  20  -- a triad that has lost its fifth
local RANK_NO_FIFTH7 =   4  -- a seventh chord voiced as a shell
local RANK_ELEVENTH  =   6  -- a sus4 carrying a seventh and a ninth: C11
local COST_INVERSION =  14  -- naming the bass after a slash
local COST_NATURAL   =   1  -- a ninth/eleventh/thirteenth the number implies
local COST_ADD       =   2  -- one that has to be spelled out as an add
local COST_CLASH     =   6  -- a natural eleventh fighting a major third
local COST_ALTERED   =   5  -- b9, #9, #11, b13 colouring a plain chord
--[[  An alteration that does not belong to the chord it is sitting on costs
    far more, because it usually means the root has been guessed wrong and the
    notes belong to some plainer chord standing on one of the others. A b9, a
    #9 and a b13 are the dominant's alterations: over a minor seventh or a
    plain triad they are not colours a musician hears. A sharpened eleventh is
    the exception - it is at home on almost anything with a perfect fifth -
    and any alteration over a fifth that is already altered is suspect. ]]
local COST_CLASHING  =  18
--[[  A suspension replaces the third rather than decorating it, so it does not
    carry added tones. "sus4 add6 add9" is not a chord anybody writes; those
    notes are an inversion of something with a third in it. ]]
local COST_SUS_EXTRA =  12
local COST_SIXTH     =   4  -- enough that C E A stays Amin/C

-- Reading the intervals present into a third, a fifth and a seventh.
local function core(has)
  local third, fifth, seventh
  local used = {[0] = true}

  if     has[4] then third, used[4] = "maj",  true
  elseif has[3] then third, used[3] = "min",  true
  elseif has[5] then third, used[5] = "sus4", true
  elseif has[2] then third, used[2] = "sus2", true
  else               third = "none" end

  if     has[7] then fifth, used[7] = "P", true
  elseif has[6] then fifth, used[6] = "b", true
  elseif has[8] then fifth, used[8] = "#", true
  else               fifth = "none" end

  -- A diminished triad takes the 9 as a doubly flattened seventh.
  if     has[10] then seventh, used[10] = "b7",   true
  elseif has[11] then seventh, used[11] = "maj7", true
  elseif third == "min" and fifth == "b" and has[9] then
                      seventh, used[9]  = "bb7",  true
  else                seventh = "none" end

  return third, fifth, seventh, used
end

-- The name of a core quality. Most are built from their parts; the handful
-- with names of their own are named.
local SPECIAL = {
  ["min/b/none"] = "dim",  ["min/b/bb7"]  = "dim7", ["min/b/b7"] = "min7b5",
  ["maj/#/none"] = "aug",  ["maj/#/b7"]   = "aug7", ["maj/#/maj7"] = "maj7#5",
  ["maj/b/b7"]   = "7b5",  ["min/P/maj7"] = "minMaj7", ["min/none/maj7"] = "minMaj7",
}

local function coreName(third, fifth, seventh)
  local special = SPECIAL[third .. "/" .. fifth .. "/" .. seventh]
  if special then return special end

  local base = (third == "min" and "min") or (third == "sus4" and "sus4")
            or (third == "sus2" and "sus2") or ""
  local sev  = (seventh == "b7" and "7") or (seventh == "bb7" and "dim7")
            or (seventh == "maj7" and (third == "min" and "Maj7" or "maj7")) or ""
  local alt  = (fifth == "b" and "b5") or (fifth == "#" and "#5") or ""

  -- Sevenths are written before a sus, not after it: 7sus4, never sus47.
  local name = (third == "sus4" or third == "sus2") and (sev .. base)
                                                     or (base .. sev)
  name = name .. alt
  -- A bare altered fifth has to be bracketed or the symbol reads as a note
  -- name: C(b5) is a chord on C, Cb5 looks like one on C flat.
  if name == alt and alt ~= "" then name = "(" .. alt .. ")" end
  return name
end

local function rankOf(third, fifth, seventh)
  if fifth == "none" then
    local rank = CORE_RANK[third .. "/P/" .. seventh] or RANK_UNNAMED[third]
    return rank + (seventh == "none" and RANK_NO_FIFTH or RANK_NO_FIFTH7)
  end
  local rank = CORE_RANK[third .. "/" .. fifth .. "/" .. seventh]
  if rank then return rank end
  return RANK_UNNAMED[third] + (seventh ~= "none" and RANK_TWICE_ODD or 0)
end

-- What is left over once the core has taken its notes.
-- interval -> {how it is written, whether it is an alteration, which degree}
local EXTENSION = {
  [1] = {"b9",  true},  [2] = {"9",  false, 9},  [3] = {"#9",  true},
  [5] = {"11",  false, 11}, [6] = {"#11", true}, [8] = {"b13", true},
}

local function analyse(has, root, bass)
  local third, fifth, seventh, used = core(has)
  local rank = rankOf(third, fifth, seventh)
  local name, cost = coreName(third, fifth, seventh), rank

  local naturals, altered, sixth = {}, {}, false
  local asEleventh = false  -- read as an 11 chord, so not a suspension at all
  for i = 1, 11 do
    if has[i] and not used[i] then
      if i == 9 then
        if seventh == "none" then sixth = true else naturals[13] = true end
      else
        local ext = EXTENSION[i]
        if ext and ext[2] then altered[#altered + 1] = ext[1]
        elseif ext then naturals[ext[3]] = true
        else
          -- Only 11 can arrive here: core() always takes 4, 7 and 10 when they
          -- are present, and 9 was dealt with above. So this is the major
          -- seventh left over when a flattened one took the seventh's place.
          altered[#altered + 1] = "maj7"
        end
      end
    end
  end

  if seventh ~= "none" and seventh ~= "bb7" then
    --[[  With a seventh underneath, the highest natural extension names the
        chord - but a stacked number claims everything under it, so it may only
        be used when the ninth is actually being played. Hutchinson's chord
        list (Music Theory for the 21st-Century Classroom, 31.4) prints Cm11
        and Cm7(11) side by side, six noteheads against five: the first has the
        ninth in it, the second does not. So a ninth that is not there is named
        in brackets after the seventh instead of being swallowed by a number.

        A natural eleventh over a major third is the other exception: it
        clashes, so it is bracketed rather than promoted whatever else is
        present. ]]
    --[[  A ninth that has been altered still fills its place in the stack: the
        same list prints C13sus(b9) with six noteheads, the b9 standing where
        the natural ninth would. So a b9 or a #9 lets the number rise too. ]]
    local ninth = naturals[9]
    for _, token in ipairs(altered) do
      if token == "b9" or token == "#9" then ninth = true end
    end

    local number
    if ninth and naturals[13] then number = 13
    elseif ninth and naturals[11] and third ~= "maj" then number = 11
    elseif naturals[9] then number = 9 end

    if third == "sus4" and seventh == "b7" and naturals[9]
       and (fifth == "P" or fifth == "none") then
      -- A sus4 carrying a seventh and a ninth is how an eleventh chord is
      -- voiced - the third is left out precisely because it would clash with
      -- the eleventh - so it is named as one rather than as a suspension.
      name, number, asEleventh = "11", 11, true
      naturals[11] = true
      cost = RANK_ELEVENTH + (fifth == "none" and RANK_NO_FIFTH7 or 0)
    elseif number then
      name = name:gsub("7", tostring(number), 1)
    end

    local spare = {}
    for _, degree in ipairs({9, 11, 13}) do
      if naturals[degree] then
        local implied = number and degree <= number
                        and not (degree == 11 and third == "maj")
        if implied then cost = cost + COST_NATURAL
        else
          cost = cost + (degree == 11 and third == "maj" and COST_CLASH or COST_ADD)
          spare[#spare + 1] = degree
        end
      end
    end
    -- Everything the number did not account for, bracketed as the chord lists
    -- print it: Cm7(11), C7(13), C7(11,13).
    if #spare > 0 then name = name .. "(" .. table.concat(spare, ",") .. ")" end
  else
    -- No seventh, so nothing stacks: everything above the triad is an add.
    if sixth then
      cost = cost + COST_SIXTH
      --[[  The sixth stands where a seventh would, so the symbol is rebuilt
          around it rather than having a 6 pasted on the end. An altered fifth
          has to survive that: C Eb G# A is min6#5, and naming it Cmin6 claims
          a perfect fifth that is not being played. ]]
      local mark = (fifth == "b" and "b5") or (fifth == "#" and "#5") or ""
      if naturals[9] and (third == "maj" or third == "min") then
        naturals[9] = nil
        name = (third == "min" and "min6/9" or "6/9") .. mark
        cost = cost + COST_ADD
      elseif third == "min"  then name = "min6" .. mark
      elseif third == "maj"  then name = (fifth == "#" and "aug6") or ("6" .. mark)
      elseif third == "none" then name = "6" .. mark
      else name = name .. "(add6)" end
    end
    for _, degree in ipairs({9, 11, 13}) do
      if naturals[degree] then
        cost = cost + (degree == 11 and third == "maj" and COST_CLASH or COST_ADD)
        name = name .. (name == "" and "add" or "Add") .. degree
      end
    end
  end

  --[[  An alteration is written straight onto the symbol - C7b9, Cmin#11 -
      except where that would read as a note name. "C#11" is a chord on C#,
      so a bare triad says add instead: Cadd#11. ]]
  --[[  Alt 2 differs from Alt here, and only here. Alt asks whether an
      alteration belongs to the chord under it, and only a dominant is at home
      with a b9, a #9 or a b13. Alt 2 also accepts a complete triad - a real
      third with a perfect fifth underneath it - which is what Scaler 3 does:
      given the choice it names the chord that has a whole triad in it and
      hangs the odd notes off that, rather than the thinner reading that needs
      fewer of them. C D Eb Gb Cb is the case that separates them: Alt reads
      D13b9/C, Alt 2 and Scaler read Cbaddb9#9/C. ]]
  local dominant = third == "maj" and seventh == "b7"
  local triad = (third == "maj" or third == "min") and fifth == "P"
  for _, token in ipairs(altered) do
    --[[  A b13 is excluded from the concession, and measurably so. It is the
        one alteration whose note is almost always a chord tone of something
        plainer: E G B with a C in it is Cmaj7 in first inversion, not Emin
        wearing a b13. Letting a complete triad take one cost 207 misnamed
        sonorities across the Bach chorales and 7 points of accuracy on
        inverted jazz voicings, and bought nothing - the chord Alt 2 exists
        for, Cb maj b9 #9, carries a b9 and a #9, not a b13. ]]
    local athome = fifth ~= "b" and fifth ~= "#" and token ~= "maj7"
                   and (token == "#11" or dominant
                        or (triad and token ~= "b13"))

    --[[  A flattened sixth is a b13 only when a seventh is under it. Without
        one it is an added flat sixth, exactly as a natural sixth is a 6 rather
        than a 13 - "C#(add b6) means a C# major triad with the b6 added"
        (Hutchinson, Music Theory for the 21st-Century Classroom, 31.1-31.2).
        Only the printed name changes: the cost still reads it as a b13, which
        is what keeps E G B C reading Cmaj7/E rather than Emin wearing one. ]]
    --[[  Both sevenths at once is a semitone cluster rather than a colour, and
        it turns up in real music as a passing note against a seventh chord -
        G B D F with an F# over it, 83 voicings across the Beethoven quartets
        and the Chopin mazurkas. Bracket it, or the two seventh names run
        together into "G7maj7", which is not a symbol anybody could read. ]]
    local shown = (token == "b13" and seventh == "none") and "b6"
                  or (token == "maj7" and "(maj7)") or token
    cost = cost + (athome and COST_ALTERED or COST_CLASHING)
    name = name .. ((name == "" and seventh == "none") and "add" or "") .. shown
  end

  if (third == "sus4" or third == "sus2") and not asEleventh then
    local carried = #altered
    for _, degree in ipairs({9, 11, 13}) do
      if naturals[degree] then carried = carried + 1 end
    end
    if sixth then carried = carried + 1 end
    cost = cost + carried * COST_SUS_EXTRA
  end

  --[[  A missing third is the one omission that has to be said out loud, and
      it is said last, so the symbol reads as a chord with a note taken out of
      it: maj7b5(no3), not maj7(no3)b5. A bare fifth with nothing above it is
      the one chord that is only its root and fifth. ]]
  if third == "none" then name = (name == "" and "5" or name .. "(no3)") end

  if root ~= bass then cost = cost + COST_INVERSION end
  -- Two readings can cost the same - Emin6 and C#min7b5 are the same four
  -- notes - so the commoner quality settles it rather than the loop order.
  return name, cost, rank
end

-- Highlight colours offered in the menu. The first is the default.
-- Keep these pale: the note names drawn on top of them are dark. There is
-- deliberately no white here - the ring around a note being played is white,
-- and a white highlight would swallow it.
local HIGHLIGHTS = {
  {name = "Teal",        rgb = {0.20, 0.80, 0.62}},
  {name = "Orange",      rgb = {0.98, 0.55, 0.15}},
  {name = "Light Green", rgb = {0.55, 0.87, 0.40}},
  {name = "Light Blue",  rgb = {0.40, 0.72, 0.98}},
  {name = "Light Pink",  rgb = {0.98, 0.62, 0.78}},
  {name = "Gold",        rgb = {0.95, 0.78, 0.22}},
}

------------------------------------------------------------------------------
-- Musical data
------------------------------------------------------------------------------

-- Pitch classes: 0 = C ... 11 = B. These plain names are used for the notes
-- that are *outside* the selected scale, where the key implies no spelling.
local SHARP_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local FLAT_NAMES  = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"}

-- The seven letters and the pitch class each one names on its own.
local LETTERS    = {"C", "D", "E", "F", "G", "A", "B"}
local LETTER_PCS = {  0,   2,   4,   5,   7,   9,  11}

local ACCIDENTALS = {[-2] = "bb", [-1] = "b", [0] = "", [1] = "#", [2] = "x"}

-- Roots offered in the scale list: both spellings of every pitch class, plus
-- Cb. C# major and Db major are the same seven notes spelled differently, so
-- each needs its own entry. letter is an index into LETTERS.
local ROOTS = {
  {name = "C",  letter = 1, acc =  0},
  {name = "C#", letter = 1, acc =  1},
  {name = "Db", letter = 2, acc = -1},
  {name = "D",  letter = 2, acc =  0},
  {name = "D#", letter = 2, acc =  1},
  {name = "Eb", letter = 3, acc = -1},
  {name = "E",  letter = 3, acc =  0},
  {name = "F",  letter = 4, acc =  0},
  {name = "F#", letter = 4, acc =  1},
  {name = "Gb", letter = 5, acc = -1},
  {name = "G",  letter = 5, acc =  0},
  {name = "G#", letter = 5, acc =  1},
  {name = "Ab", letter = 6, acc = -1},
  {name = "A",  letter = 6, acc =  0},
  {name = "A#", letter = 6, acc =  1},
  {name = "Bb", letter = 7, acc = -1},
  {name = "B",  letter = 7, acc =  0},
  {name = "Cb", letter = 1, acc = -1},
}

-- Bottom row: the seven white keys of an octave
local WHITE_PCS = {0, 2, 4, 5, 7, 9, 11}

-- Top row: the five black keys of an octave
local BLACK_PCS = {1, 3, 6, 8, 10}

-- Which white-key gap each black key sits above (1 = between white 1 and 2).
-- C#=1, D#=2, (no black key between E and F), F#=4, G#=5, A#=6
local BLACK_SLOTS = {1, 2, 4, 5, 6}

-- Scale definitions as semitone offsets from the root.
-- Scale definitions. intervals are semitones from the root; letters are how
-- many letter-names each degree sits above the root letter, which is what
-- makes the spelling come out right. A seven-note scale simply walks the
-- letters in order (0..6); the others follow the conventional spelling, so
-- major blues repeats a letter for its b3 and 3 (C D Eb E G A) and the
-- diminished scales repeat one letter across their eight notes.
local SCALES = {
  {name = "Major",            intervals = {0, 2, 4, 5, 7, 9, 11},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Minor (Natural)",  intervals = {0, 2, 3, 5, 7, 8, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Harmonic Minor",   intervals = {0, 2, 3, 5, 7, 8, 11},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Ionian",           intervals = {0, 2, 4, 5, 7, 9, 11},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Dorian",           intervals = {0, 2, 3, 5, 7, 9, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Phrygian",         intervals = {0, 1, 3, 5, 7, 8, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Lydian",           intervals = {0, 2, 4, 6, 7, 9, 11},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Mixolydian",       intervals = {0, 2, 4, 5, 7, 9, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Aeolian",          intervals = {0, 2, 3, 5, 7, 8, 10},
                              letters   = {0, 1, 2, 3, 4, 5,  6}},
  {name = "Major Pentatonic", intervals = {0, 2, 4, 7, 9},
                              letters   = {0, 1, 2, 4, 5}},
  {name = "Minor Pentatonic", intervals = {0, 3, 5, 7, 10},
                              letters   = {0, 2, 3, 4,  6}},
  {name = "Major Blues",      intervals = {0, 2, 3, 4, 7, 9},
                              letters   = {0, 1, 2, 2, 4, 5}},
  {name = "Minor Blues",      intervals = {0, 3, 5, 6, 7, 10},
                              letters   = {0, 2, 3, 4, 4,  6}},
  {name = "Whole Tone",       intervals = {0, 2, 4, 6, 8, 10},
                              letters   = {0, 1, 2, 3, 4,  5}},
  {name = "Diminished Whole-Half", intervals = {0, 2, 3, 5, 6, 8, 9, 11},
                                   letters   = {0, 1, 2, 3, 4, 5, 5,  6}},
  {name = "Diminished Half-Whole", intervals = {0, 1, 3, 4, 6, 7, 9, 10},
                                   letters   = {0, 1, 2, 2, 3, 4, 5,  6}},
}


------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

local state = {
  root      = nil,   -- index into ROOTS, or nil when no scale is selected
  scale     = nil,   -- index into SCALES, or nil
  showNames = true,  -- draw note names inside the circles
  simpleNames = false, -- name notes as piano keys rather than for the key
  highlight = 1,     -- index into HIGHLIGHTS
}

local active = {}    -- active[pitchClass] = true when that note is in the scale
local names  = {}    -- names[pitchClass] = how to spell it in the current key

local keyUsesFlats = false -- whether the selected key spells its notes as flats

local held      = {} -- held[midiNote] = true while the note is being played
local heldCount = 0
local chordName = nil   -- what the held notes spell, or nil when nothing is held

-- Declared here because the project watcher renames the chord when the key
-- changes, and it is defined above the chord reader it has to call.
local detectChord

--[[  Naming a chord needs a key to settle the readings that are a genuine
    draw, and the script starts with no scale chosen. Rather than go quiet
    until one is picked, it reads those draws as if the key were C major.

    Nothing on the icon says so - with no scale selected no circle lights up,
    exactly as before - and choosing C major from the menu gives identical
    names, which is the property `tests/test_scaleview_pro.lua` checks over
    every three- and four-note voicing. C major is the right one to assume
    because it is also what the note names already fall back to: no
    accidentals, so the twelve read C C# D D# E F F# G G# A A# B either way. ]]
local ASSUMED_KEY = {[0] = true, [2] = true, [4] = true, [5] = true,
                     [7] = true, [9] = true, [11] = true}
local lastEventSeq = nil -- newest input event already applied
local midiFailed = false -- set if the input history cannot be read at all

local MOUSE_BUTTONS = 1 | 2 | 64   -- left, right, middle; the rest are modifiers

-- How long after a menu closes to keep ignoring the mouse. The click that
-- chose the item reaches the window afterwards, and not always in the very
-- next frame, so waiting for the buttons to come up is not enough on its own.
local MENU_SETTLE_SECONDS = 0.25

local prevMouseCap  = 0
local settlingMouse = false   -- true from a menu closing until the mouse is idle
local menuClosedAt  = -1      -- time_precise() when the last menu closed
local pressActive   = false   -- a press began on the icon and has not ended
local pressX, pressY = 0, 0   -- where it began, which decides the menu
local needRedraw   = true
local lastW, lastH, lastDock

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

-- Reads a saved setting, falling back to the section used under the earlier
-- name so a rename doesn't reset an existing install's scale, window position
-- or dock state.
local function getSetting(key)
  local value = reaper.GetExtState(EXT_SECTION, key)
  local i = 1
  while value == "" and EXT_LEGACY[i] do
    value = reaper.GetExtState(EXT_LEGACY[i], key)
    i = i + 1
  end
  return value
end

local function setColor(c)
  gfx.set(c[1], c[2], c[3], 1)
end

local function rootPitch(root)
  return (LETTER_PCS[root.letter] + root.acc) % 12
end

-- Spell pitch class pc using the given letter, e.g. letter G and pc 6 gives
-- "Gb". Returns nil when that would need more than a double accidental, which
-- only happens in spellings nobody writes.
local function spellAs(letter, pc)
  letter = (letter - 1) % 7 + 1
  local offset = ((pc - LETTER_PCS[letter] + 6) % 12) - 6   -- -6..+5, 0 = natural
  local accidental = ACCIDENTALS[offset]
  if not accidental then return nil end
  return LETTERS[letter] .. accidental
end

-- Two naming schemes. By default a note is named for the key it is in, which
-- is what makes Gb major read Gb Ab Bb Cb Db Eb F. With "Simplify Note Names"
-- on, every note is named the way its piano key is: sharps for the black keys
-- and never a double accidental, so Bbb reads A, Gx reads A and Cb reads B.
local function noteName(pc)
  if state.simpleNames then return SHARP_NAMES[pc + 1] end
  return names[pc] or SHARP_NAMES[pc + 1]
end

local function highlightColor()
  return HIGHLIGHTS[state.highlight].rgb
end

-- Recalculate which pitch classes are lit for the current selection.
local function refreshActive()
  active, names = {}, {}
  keyUsesFlats = false
  if not (state.root and state.scale) then return end

  local root  = ROOTS[state.root]
  local rootPc = rootPitch(root)
  local scale = SCALES[state.scale]
  local sharps, flats = 0, 0

  for degree, interval in ipairs(scale.intervals) do
    local pc = (rootPc + interval) % 12
    local name = spellAs(root.letter + scale.letters[degree], pc)
    active[pc] = true
    names[pc]  = name
    if name then
      if name:find("#") or name:find("x") then sharps = sharps + 1 end
      if name:find("b", 2) then flats = flats + 1 end   -- skip the note letter B
    end
  end

  -- The notes outside the scale have no spelling of their own, so name them
  -- in whichever direction the key leans.
  keyUsesFlats = flats > sharps
  local outside = keyUsesFlats and FLAT_NAMES or SHARP_NAMES
  for pc = 0, 11 do
    if not names[pc] then names[pc] = outside[pc + 1] end
  end
end

local function displayLabel()
  if chordName then return chordName, true end
  if midiFailed then return "MIDI input unavailable", false end
  if state.root and state.scale then
    return ROOTS[state.root].name .. " " .. SCALES[state.scale].name, false
  end
  return "No scale selected", false
end

local function saveState()
  -- Stored by name throughout, so reordering a table cannot repoint a saved
  -- choice at a different entry.
  reaper.SetExtState(EXT_SECTION, "root",  state.root  and ROOTS[state.root].name   or "", true)
  reaper.SetExtState(EXT_SECTION, "scale", state.scale and SCALES[state.scale].name or "", true)
  reaper.SetExtState(EXT_SECTION, "shownames",   state.showNames and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "simplenames", state.simpleNames and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "highlight", HIGHLIGHTS[state.highlight].name, true)
end

-- The scale belongs to the project, not to the user: SetProjExtState stores it
-- inside the .RPP, so each project reopens in its own key. Everything else -
-- colour, note names, window - stays global, because those are preferences
-- rather than anything about the music.
local PROJECT_SECTION = "ScaleView"
-- What the section was called before the scripts lost their kallums_ prefix.
-- Read when a project has nothing under the name above, so a project saved
-- earlier still opens in its own key; the next change writes it across.
local PROJECT_LEGACY  = "kallums_ScaleView"

local currentProject = nil   -- the project the scale on screen came from

local function projectApiAvailable()
  return reaper.EnumProjects and reaper.GetProjExtState and reaper.SetProjExtState
end

local function activeProject()
  if not projectApiAvailable() then return nil end
  return reaper.EnumProjects(-1)
end

local function lookupNamed(list, saved)
  for i, entry in ipairs(list) do
    if entry.name == saved then return i end
  end
end

-- Writes the scale into the project. This marks the project as edited, which
-- is the cost of the project remembering it.
local function saveProjectScale()
  local project = activeProject()
  if not project then return end

  reaper.SetProjExtState(project, PROJECT_SECTION, "root",
    state.root and ROOTS[state.root].name or "")
  reaper.SetProjExtState(project, PROJECT_SECTION, "scale",
    state.scale and SCALES[state.scale].name or "")
end

-- The scale this project was left in, or nil when it has never had one.
local function projectScale(project)
  if not project then return nil end

  local _, rootName  = reaper.GetProjExtState(project, PROJECT_SECTION, "root")
  local _, scaleName = reaper.GetProjExtState(project, PROJECT_SECTION, "scale")

  if (rootName or "") == "" and (scaleName or "") == "" then
    _, rootName  = reaper.GetProjExtState(project, PROJECT_LEGACY, "root")
    _, scaleName = reaper.GetProjExtState(project, PROJECT_LEGACY, "scale")
  end

  local root  = lookupNamed(ROOTS,  rootName or "")
  local scale = lookupNamed(SCALES, scaleName or "")

  if root and scale then return root, scale end
  return nil
end

local function loadState()
  local function lookup(list, saved)
    for i, entry in ipairs(list) do
      if entry.name == saved then return i end
    end
  end

  state.root  = lookup(ROOTS,  getSetting("root"))
  state.scale = lookup(SCALES, getSetting("scale"))
  state.highlight = lookup(HIGHLIGHTS, getSetting("highlight")) or 1
  if getSetting("shownames") == "0" then state.showNames = false end
  if getSetting("simplenames") == "1" then state.simpleNames = true end

  -- A root without a scale, or the other way round, would light nothing.
  if not (state.root and state.scale) then state.root, state.scale = nil, nil end

  -- A scale saved in the project wins over the last one used anywhere, so
  -- reopening a project puts its own key back on screen.
  currentProject = activeProject()
  local root, scale = projectScale(currentProject)
  if root then state.root, state.scale = root, scale end

  refreshActive()
end

-- Following the project the user is looking at: switching tab, or opening
-- another project, brings that project's scale with it. A project that has
-- never had one is left showing whatever is already up rather than blanking.
local function followProjectChange()
  local project = activeProject()
  if not project or project == currentProject then return false end

  currentProject = project

  local root, scale = projectScale(project)
  if not root then return false end
  if root == state.root and scale == state.scale then return false end

  state.root, state.scale = root, scale
  refreshActive()
  if heldCount > 0 then chordName = detectChord() end
  return true
end

local function saveWindowState()
  local dock, x, y, w, h = gfx.dock(-1, 0, 0, 0, 0)
  reaper.SetExtState(EXT_SECTION, "wnd", table.concat({dock, x, y, w, h}, " "), true)
end

local function loadWindowState()
  local dock, x, y, w, h = getSetting("wnd"):match(
    "(-?%d+) (-?%d+) (-?%d+) (-?%d+) (-?%d+)")
  if not dock then return 0, nil, nil, DEFAULT_W, DEFAULT_H end
  w, h = tonumber(w), tonumber(h)
  if w < 60 then w = DEFAULT_W end
  if h < 40 then h = DEFAULT_H end
  return tonumber(dock), tonumber(x), tonumber(y), w, h
end

------------------------------------------------------------------------------
-- Layout - everything is derived from the current window size so the icon
-- stays correct if it is resized or docked.
------------------------------------------------------------------------------

local function layout()
  local aspect = DEFAULT_W / DEFAULT_H

  -- The icon keeps its 2:1 proportions inside whatever window it is given and
  -- is centred in it, so a wide docker doesn't smear the circles across the
  -- full width of the dock.
  local boxW = math.min(gfx.w, gfx.h * aspect)
  local boxH = math.min(gfx.h, gfx.w / aspect)
  local originX = (gfx.w - boxW) / 2
  local originY = (gfx.h - boxH) / 2

  local step   = boxW / 7                              -- one white-key slot
  local labelH = boxH * 0.20
  local radius = math.min(step * 0.40, (boxH - labelH) * 0.20)

  return {
    originX = originX,
    boxW    = boxW,
    step    = step,
    radius  = radius,
    topY    = originY + (boxH - labelH) * 0.33,
    botY    = originY + (boxH - labelH) * 0.76,
    labelY  = originY + boxH - labelH,
    labelH  = labelH,
  }
end

------------------------------------------------------------------------------
-- Chord detection
--
-- The held notes give a set of pitch classes and a bass - the lowest note
-- actually sounding, which is found separately from the root. Every pitch
-- class is then tried as a root: the notes above it are read as a third, a
-- fifth and a seventh, and whatever is left over is described as an extension.
-- Each reading is costed, the cheapest wins, and a root that is not in the
-- bass pays for the slash it will need. That is what separates Bsus2 from
-- F#sus4 and keeps C E A as Amin/C.
------------------------------------------------------------------------------

--[[ A chord is named from the same vocabulary the scale list offers: the
     eighteen spellings in ROOTS. Those are exactly the roots real keys are
     built on, which is what makes a chord in Gb major read Gb rather than F#,
     and one in Cb major read Cb.

     Anything outside that vocabulary falls back to its plain name, leaning the
     way the key does. That covers the double accidentals a key like Gb minor
     blues produces - the circles rightly read Bbb and Dbb, but the chord is
     Amin/C, not Bbbmin/Dbb - and the theoretical spellings no one writes a
     chord on: B#, E# and Fb. In C# major a chord on B# D# E# reads Cmin add11,
     the way it would be written. ]]
local CHORD_ROOT_NAMES = {}
for _, root in ipairs(ROOTS) do CHORD_ROOT_NAMES[root.name] = true end

local function chordNoteName(pc)
  local name = noteName(pc)
  if CHORD_ROOT_NAMES[name] then return name end
  return (keyUsesFlats and FLAT_NAMES or SHARP_NAMES)[pc + 1]
end

local function heldPitchClasses()
  local classes, bass = {}, nil

  for note in pairs(held) do
    classes[note % 12] = true
    if not bass or note < bass then bass = note end
  end

  return classes, bass and bass % 12 or nil
end

--[[  Reading the chord.

    Every note being held is tried as the root and the cheapest reading wins.
    The cost is the whole of the judgement: how unusual the quality is, what
    its extensions cost, and whether the root had to be named after a slash.
    That is what keeps a complete triad in an inversion ahead of a rooted
    chord with a hole in it - C E A is Amin/C, not a C6 missing its fifth.

    Where two readings cost exactly the same the selected scale settles it: a
    root that is a degree of the scale is preferred, then a reading whose
    notes sit in it. With no scale selected `active` is empty and the commoner
    quality decides instead, so the naming never depends on a scale being
    chosen - and a chord from outside the key is still named for what it is
    rather than bent to fit. ]]
function detectChord()
  local classes, bass = heldPitchClasses()
  if not bass then return nil end

  local count = 0
  for _ in pairs(classes) do count = count + 1 end
  if count == 1 then return chordNoteName(bass) end

  local function spellOut()
    local spelled = {}
    for pc = 0, 11 do
      if classes[pc] then spelled[#spelled + 1] = chordNoteName(pc) end
    end
    return table.concat(spelled, " ")
  end

  -- Two notes are an interval rather than a chord, and only the bare fifth
  -- has a name of its own.
  if count == 2 then
    for root = 0, 11 do
      if classes[root] and classes[(root + 7) % 12] then
        local name = chordNoteName(root) .. "5"
        if root ~= bass then name = name .. "/" .. chordNoteName(bass) end
        return name
      end
    end
    return spellOut()
  end

  -- Past a certain thickness there is no chord left to find, only a cluster.
  if count > 7 then return spellOut() end

  local best
  for root = 0, 11 do
    if classes[root] then
      local has = {}
      for pc = 0, 11 do
        if classes[pc] then has[(pc - root) % 12] = true end
      end

      local name, cost, rank = analyse(has, root, bass)

      local key = (state.root and state.scale) and active or ASSUMED_KEY
      local fit = key[root] and 100 or 0
      for pc = 0, 11 do
        if classes[pc] and key[pc] then fit = fit + 1 end
      end

      if not best or cost < best.cost
         or (cost == best.cost and fit > best.fit)
         or (cost == best.cost and fit == best.fit and rank < best.rank) then
        best = {root = root, name = name, cost = cost, rank = rank, fit = fit}
      end
    end
  end

  local name = chordNoteName(best.root) .. best.name
  if best.root ~= bass then name = name .. "/" .. chordNoteName(bass) end
  return name
end

------------------------------------------------------------------------------
-- Live MIDI input
--
-- MIDI_GetRecentInputEvent reads REAPER's global input history: idx 0 is the
-- most recent event and must be asked for first, since it latches the list.
-- Each event carries a sequence number, so walking back until we meet the one
-- we finished on last time gives exactly the events we have not seen yet.
------------------------------------------------------------------------------

local MAX_EVENTS_PER_POLL = 64   -- a generous ceiling at 30 polls a second

local function applyEvent(message)
  if #message < 3 then return end

  local status   = message:byte(1)
  local command  = status & 0xF0
  local note     = message:byte(2)
  local velocity = message:byte(3)

  if command == 0x90 and velocity > 0 then
    if not held[note] then
      held[note] = true
      heldCount = heldCount + 1
    end
  elseif command == 0x80 or (command == 0x90 and velocity == 0) then
    if held[note] then
      held[note] = nil
      heldCount = heldCount - 1
    end
  elseif command == 0xB0 and (note == 120 or note == 123) then
    held, heldCount = {}, 0       -- all sound off / all notes off
  end
end

local function pollMidiInput()
  if midiFailed then return false end

  local fresh, newestSeq = {}, nil

  for index = 0, MAX_EVENTS_PER_POLL - 1 do
    local ok, sequence, message = pcall(reaper.MIDI_GetRecentInputEvent, index)

    if not ok or type(sequence) ~= "number" or type(message) ~= "string" then
      -- Either the API is missing or it does not return what we expect. Say
      -- so once rather than throwing in the defer loop on every frame.
      midiFailed = true
      return false
    end

    if sequence == 0 or sequence == lastEventSeq then break end
    if index == 0 then newestSeq = sequence end

    fresh[#fresh + 1] = message
  end

  if #fresh == 0 then return false end

  -- The history runs newest first, so apply it backwards to keep note-ons and
  -- note-offs in the order they were played.
  for i = #fresh, 1, -1 do applyEvent(fresh[i]) end

  lastEventSeq = newestSeq or lastEventSeq

  local detected = heldCount > 0 and detectChord() or nil
  if detected ~= chordName then
    chordName = detected
    return true
  end
  return false
end

------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------

-- A note being played is ringed, whether or not it is in the scale.
local function drawHeldRing(x, y, r, pc)
  for _, note in ipairs({pc, pc + 12, pc + 24, pc + 36, pc + 48, pc + 60,
                         pc + 72, pc + 84, pc + 96, pc + 108, pc + 120}) do
    if held[note] then
      setColor(COLOR_HELD)
      gfx.circle(x, y, r + 1.5, false, true)
      gfx.circle(x, y, r + 2.5, false, true)
      return
    end
  end
end

local function drawCircle(x, y, r, pc)
  local on = active[pc] == true
  local fill = on and highlightColor() or COLOR_OFF
  setColor(fill)
  gfx.circle(x, y, r, true, true)

  if state.showNames and r >= 7 then
    local name = noteName(pc)
    -- "Bbb" needs to fit the same circle as "B".
    local fit = ({0.95, 0.80, 0.62})[#name] or 0.55
    gfx.setfont(2, "Arial", math.max(7, math.floor(r * fit)))
    local tw, th = gfx.measurestr(name)
    setColor(on and COLOR_TEXT_ON or COLOR_TEXT_OFF)
    gfx.x, gfx.y = x - tw / 2, y - th / 2
    gfx.drawstr(name)
  end

  drawHeldRing(x, y, r, pc)
end

local function draw()
  setColor(COLOR_BG)
  gfx.rect(0, 0, gfx.w, gfx.h, true)

  local L = layout()

  -- Top row: the five black keys, sitting over the gaps between white keys.
  for i, pc in ipairs(BLACK_PCS) do
    drawCircle(L.originX + BLACK_SLOTS[i] * L.step, L.topY, L.radius, pc)
  end

  -- Bottom row: the seven white keys.
  for i, pc in ipairs(WHITE_PCS) do
    drawCircle(L.originX + (i - 0.5) * L.step, L.botY, L.radius, pc)
  end

  -- Current scale name.
  if L.labelH > 6 then
    gfx.setfont(1, "Arial", math.max(9, math.floor(L.labelH * 0.62)))
    local text, isChord = displayLabel()
    local tw, th = gfx.measurestr(text)
    setColor(isChord and COLOR_CHORD or COLOR_LABEL)
    gfx.x = math.max(2, L.originX + (L.boxW - tw) / 2)
    gfx.y = L.labelY + (L.labelH - th) / 2
    gfx.drawstr(text)
  end
end

------------------------------------------------------------------------------
-- Menus
--
-- gfx.showmenu() returns the 1-based index of the chosen item counting only
-- *selectable* items: separators and submenu headers are in the menu string
-- but are not counted. The action table is therefore keyed by a separate
-- counter that only advances for selectable items, so the indices line up
-- whatever gets added to the menu later.
------------------------------------------------------------------------------

local function newMenu()
  return {fields = {}, actions = {}, selectableCount = 0}
end

local function addField(menu, field)
  menu.fields[#menu.fields + 1] = field
end

-- opts.checked draws a tick, opts.last closes the submenu the item is in.
local function addItem(menu, label, action, opts)
  opts = opts or {}
  local prefix = (opts.last and "<" or "") .. (opts.checked and "!" or "")
  addField(menu, prefix .. label)
  menu.selectableCount = menu.selectableCount + 1
  menu.actions[menu.selectableCount] = action
end

local function addSeparator(menu)
  addField(menu, "")
end

local function addSubmenu(menu, label)
  addField(menu, ">" .. label)
end

local function showMenu(menu)
  gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
  local choice = gfx.showmenu(table.concat(menu.fields, "|"))
  local action = menu.actions[choice]
  if action then action() end

  -- showmenu() is modal, and the click that picked an item is reported to the
  -- window once the menu closes - sometimes a frame or two later. Left alone
  -- it reads as a fresh click and opens a menu nobody asked for.
  settlingMouse = true
  menuClosedAt  = reaper.time_precise()
end

local function selectScale(root, scaleIdx)
  state.root, state.scale = root, scaleIdx
  refreshActive()
  saveProjectScale()
  -- The chord is spelled for the key, so it has to be renamed when the key
  -- changes: the same notes read Gb in one key and F# in another.
  if heldCount > 0 then chordName = detectChord() end
  saveState()
  needRedraw = true
end

local function clearScale()
  selectScale(nil, nil)
end

-- Picks a scale at random, never the one already showing.
local function randomScale()
  local root, scale
  repeat
    root  = math.random(#ROOTS)
    scale = math.random(#SCALES)
  until root ~= state.root or scale ~= state.scale
  selectScale(root, scale)
end

local function scaleMenu()
  local menu = newMenu()

  addItem(menu, "Clear scale", clearScale, {checked = state.scale == nil})
  addSeparator(menu)

  for scaleIdx, scale in ipairs(SCALES) do
    addSubmenu(menu, scale.name)
    for rootIdx, root in ipairs(ROOTS) do
      addItem(menu, root.name .. " " .. scale.name,
        function() selectScale(rootIdx, scaleIdx) end,
        {
          last    = rootIdx == #ROOTS,
          checked = state.root == rootIdx and state.scale == scaleIdx,
        })
    end
  end

  showMenu(menu)
end

-- The dock state is a bitfield: bit 0 says whether the window is docked, and
-- the second byte holds the docker index, which is kept even while undocked.
-- So flip the bit rather than setting 0 or 1 - otherwise an undocked window
-- that still remembers a docker reads as non-zero and never docks again.
local function isDocked()
  return gfx.dock(-1) & 1 == 1
end

local function toggleDock()
  local dock = gfx.dock(-1)
  gfx.dock(dock & 1 == 1 and dock & ~1 or dock | 1)
  saveWindowState()
  needRedraw = true
end

local function optionsMenu()
  local menu = newMenu()

  addItem(menu, "Random Scale", randomScale)
  addSeparator(menu)

  addItem(menu, "Show Note Names", function()
    state.showNames = not state.showNames
    saveState()
    needRedraw = true
  end, {checked = state.showNames})

  addItem(menu, "Simplify Note Names", function()
    state.simpleNames = not state.simpleNames
    -- The chord is spelled from the note names, so it has to be renamed too.
    if heldCount > 0 then chordName = detectChord() end
    saveState()
    needRedraw = true
  end, {checked = state.simpleNames})

  addSubmenu(menu, "Highlight Colour")
  for i, entry in ipairs(HIGHLIGHTS) do
    addItem(menu, entry.name, function()
      state.highlight = i
      saveState()
      needRedraw = true
    end, {last = i == #HIGHLIGHTS, checked = state.highlight == i})
  end

  addSeparator(menu)
  addItem(menu, "Dock Window", toggleDock, {checked = isDocked()})
  addSeparator(menu)
  addItem(menu, "Close", function() gfx.quit() end)

  showMenu(menu)
end

------------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------------

-- Which menu a click opens depends on where it is, not which button was used:
-- the circles are the scale list, everything else is the options. That means
-- there is no wrong menu to open by mistake.
local function isOverCircle(x, y)
  local L = layout()
  local reach = L.radius + 2      -- a little forgiveness around the edge

  for i, _ in ipairs(BLACK_PCS) do
    local cx = L.originX + BLACK_SLOTS[i] * L.step
    local dx, dy = x - cx, y - L.topY
    if dx * dx + dy * dy <= reach * reach then return true end
  end

  for i, _ in ipairs(WHITE_PCS) do
    local cx = L.originX + (i - 0.5) * L.step
    local dx, dy = x - cx, y - L.botY
    if dx * dx + dy * dy <= reach * reach then return true end
  end

  return false
end

local function handleMouse()
  local cap = gfx.mouse_cap
  local buttons = cap & MOUSE_BUTTONS

  -- After a menu closes, ignore the mouse until nothing is held AND a moment
  -- has passed. Whatever it did while the menu was up belongs to the menu.
  if settlingMouse then
    if buttons == 0 and reaper.time_precise() - menuClosedAt >= MENU_SETTLE_SECONDS then
      settlingMouse = false
    end
    prevMouseCap, pressActive = cap, false
    return
  end

  local wasDown = prevMouseCap & MOUSE_BUTTONS ~= 0

  if not wasDown and buttons ~= 0 then
    -- A press. Remember where it started: a click belongs where it began, so
    -- pressing on a circle and drifting off still opens the scale list.
    pressActive = true
    pressX, pressY = gfx.mouse_x, gfx.mouse_y
  elseif wasDown and buttons == 0 and pressActive then
    -- A release, so the click is finished. Firing here rather than on the
    -- press means dragging the window by its edge does not open a menu.
    pressActive = false
    if isOverCircle(pressX, pressY) then scaleMenu() else optionsMenu() end
  end

  prevMouseCap = cap
end

-- Returns false when the script should stop.
local function handleKeys()
  local char = gfx.getchar()
  if char < 0 or char == 27 then return false end        -- window closed / Esc
  if char == 100 or char == 68 then toggleDock() end     -- d / D
  return true
end

------------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------------

local function main()
  if followProjectChange() then needRedraw = true end
  if pollMidiInput() then needRedraw = true end

  handleMouse()

  if not handleKeys() then
    saveWindowState()
    gfx.quit()
    return
  end

  local dock = gfx.dock(-1)
  if needRedraw or gfx.w ~= lastW or gfx.h ~= lastH or dock ~= lastDock then
    lastW, lastH, lastDock = gfx.w, gfx.h, dock
    needRedraw = false
    draw()
    gfx.update()
  end

  reaper.defer(main)
end

local function init()
  --[[  Tell REAPER the script is on, so a toolbar button bound to it lights up,
      and that re-running the action should stop this instance rather than
      start a second one - which makes the same button toggle it off.
      REAPER 7+; harmless to skip on anything older.  ]]
  if reaper.set_action_options then reaper.set_action_options(1 | 4) end

  math.randomseed(os.time() + math.floor(reaper.time_precise() * 1000))
  loadState()
  local dock, x, y, w, h = loadWindowState()
  if x and y then
    gfx.init(SCRIPT_NAME, w, h, dock, x, y)
  else
    gfx.init(SCRIPT_NAME, w, h, dock)
  end
  gfx.setfont(1, "Arial", 12)
  main()
end

reaper.atexit(function()
  saveState()
  if reaper.set_action_options then reaper.set_action_options(8) end   -- toggle off
  gfx.quit()
end)

init()
