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
 *                 "Simplify Note Names" in the options menu turns that off
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

local SCRIPT_NAME  = "ScaleView Pattern"
local EXT_SECTION  = "ScaleViewPattern"

-- This script is new, so it supersedes nothing and has no legacy section to
-- read. It keeps its own settings, which is what lets it run alongside Pro.
local EXT_LEGACY   = {}

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

--[[  Chord detection, pattern-based.

  This is a port of Long Kelvin's Pattern-Based Interval Matching algorithm
  from the MIDI Chord Detector plugin, and it is what makes this script
  different from ScaleView Pro. Pro reads a chord - it matches only the third,
  fifth and seventh and describes everything above them. This matches the whole
  chord against a database of 62 patterns, scores every (root, pattern) pair,
  and takes the highest.

  Ported from Source/chord_detection/detector/{ChordPatterns,ChordScoring,
  ChordDetector,VoicingAnalyzer}.cpp, which carry:

      MIT License. Copyright (c) 2026 Long Kelvin

      Permission is hereby granted, free of charge, to any person obtaining a
      copy of this software and associated documentation files (the
      "Software"), to deal in the Software without restriction, including
      without limitation the rights to use, copy, modify, merge, publish,
      distribute, sublicense, and/or sell copies of the Software, and to permit
      persons to whom the Software is furnished to do so, subject to the
      following conditions:

      The above copyright notice and this permission notice shall be included
      in all copies or substantial portions of the Software.

      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
      IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
      CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
      TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
      SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

  The constants below are taken from the source, not from that repository's
  documentation, which disagrees with it in several places: the root-position
  bonus is 25 and not 15, the penalty for an extra interval is 4 and not 8, and
  the confidence weights are .35/.25/.15/.25 and not .4/.4/.1/.1.

  Two things are deliberately NOT ported, so that a comparison against Pro
  measures the detection and nothing else:

    - note spelling. Chord roots and basses go through this script's own
      chordNoteName, so Gb major still reads Gbmaj7 here.
    - the chord history / context option, which is off in the original too.

  One thing IS changed in the ported data: 27 of the display templates spell
  their accidentals with the musical symbols U+266D and U+266F rather than with
  b and #. They are rewritten to ASCII, because gfx.drawstr has no guarantee of
  a glyph for either, and because leaving them would make every altered chord
  differ from Pro on typography rather than on detection. The chord vocabulary
  itself is untouched - m7b5 stays m7b5 and is not renamed to Pro's min7b5.
]]
-- Generated from ChordPatterns.cpp (MIT, (c) 2026 Long Kelvin).
local PATTERNS = {
  {name = "major",               intervals = {0, 4, 7},                 base = 100,
   required = {0, 4, 7},             optional = {},              important = {4, 7},          display = "{root}"},
  {name = "minor",               intervals = {0, 3, 7},                 base = 100,
   required = {0, 3, 7},             optional = {},              important = {3, 7},          display = "{root}m"},
  {name = "diminished",          intervals = {0, 3, 6},                 base = 100,
   required = {0, 3, 6},             optional = {},              important = {3, 6},          display = "{root}dim"},
  {name = "augmented",           intervals = {0, 4, 8},                 base = 100,
   required = {0, 4, 8},             optional = {},              important = {4, 8},          display = "{root}aug"},
  {name = "sus2",                intervals = {0, 2, 7},                 base =  95,
   required = {0, 2, 7},             optional = {},              important = {2, 7},          display = "{root}sus2"},
  {name = "sus4",                intervals = {0, 5, 7},                 base =  95,
   required = {0, 5, 7},             optional = {},              important = {5, 7},          display = "{root}sus4"},
  {name = "power5",              intervals = {0, 7},                    base =  80,
   required = {0, 7},                optional = {},              important = {7},             display = "{root}5"},
  {name = "major7",              intervals = {0, 4, 7, 11},             base = 115,
   required = {0, 4, 11},            optional = {7},             important = {4, 11},         display = "{root}maj7"},
  {name = "minor7",              intervals = {0, 3, 7, 10},             base = 115,
   required = {0, 3, 10},            optional = {7},             important = {3, 10},         display = "{root}m7"},
  {name = "dominant7",           intervals = {0, 4, 7, 10},             base = 115,
   required = {0, 4, 10},            optional = {7},             important = {4, 10},         display = "{root}7"},
  {name = "diminished7",         intervals = {0, 3, 6, 9},              base = 115,
   required = {0, 3, 6, 9},          optional = {},              important = {3, 6, 9},       display = "{root}dim7"},
  {name = "half-diminished7",    intervals = {0, 3, 6, 10},             base = 115,
   required = {0, 3, 6, 10},         optional = {},              important = {3, 6, 10},      display = "{root}m7b5"},
  {name = "augmented7",          intervals = {0, 4, 8, 10},             base = 110,
   required = {0, 4, 8, 10},         optional = {},              important = {4, 8, 10},      display = "{root}aug7"},
  {name = "augmented-major7",    intervals = {0, 4, 8, 11},             base = 110,
   required = {0, 4, 8, 11},         optional = {},              important = {4, 8, 11},      display = "{root}+maj7"},
  {name = "minor-major7",        intervals = {0, 3, 7, 11},             base = 110,
   required = {0, 3, 11},            optional = {7},             important = {3, 11},         display = "{root}m(maj7)"},
  {name = "7sus4",               intervals = {0, 5, 7, 10},             base = 108,
   required = {0, 5, 10},            optional = {7},             important = {5, 10},         display = "{root}7sus4"},
  {name = "major6",              intervals = {0, 4, 7, 9},              base = 105,
   required = {0, 4, 9},             optional = {7},             important = {4, 9},          display = "{root}6"},
  {name = "minor6",              intervals = {0, 3, 7, 9},              base = 105,
   required = {0, 3, 9},             optional = {7},             important = {3, 9},          display = "{root}m6"},
  {name = "6/9",                 intervals = {0, 4, 7, 9, 14},          base = 110,
   required = {0, 4, 9, 14},         optional = {7},             important = {4, 9, 14},      display = "{root}6/9"},
  {name = "minor6/9",            intervals = {0, 3, 7, 9, 14},          base = 110,
   required = {0, 3, 9, 14},         optional = {7},             important = {3, 9, 14},      display = "{root}m6/9"},
  {name = "major9",              intervals = {0, 4, 7, 11, 14},         base = 125,
   required = {0, 4, 11, 14},        optional = {7},             important = {4, 11, 14},     display = "{root}maj9"},
  {name = "minor9",              intervals = {0, 3, 7, 10, 14},         base = 125,
   required = {0, 3, 10, 14},        optional = {7},             important = {3, 10, 14},     display = "{root}m9"},
  {name = "dominant9",           intervals = {0, 4, 7, 10, 14},         base = 125,
   required = {0, 4, 10, 14},        optional = {7},             important = {4, 10, 14},     display = "{root}9"},
  {name = "dominant7b9",         intervals = {0, 4, 7, 10, 13},         base = 120,
   required = {0, 4, 10, 13},        optional = {7},             important = {4, 10, 13},     display = "{root}7b9"},
  {name = "dominant7#9",         intervals = {0, 4, 7, 10, 15},         base = 120,
   required = {0, 4, 10, 15},        optional = {7},             important = {4, 10, 15},     display = "{root}7#9"},
  {name = "minor-major9",        intervals = {0, 3, 7, 11, 14},         base = 120,
   required = {0, 3, 11, 14},        optional = {7},             important = {3, 11, 14},     display = "{root}m(maj9)"},
  {name = "major11",             intervals = {0, 4, 7, 11, 14, 17},     base = 130,
   required = {0, 4, 11, 14, 17},    optional = {7},             important = {4, 11, 14, 17}, display = "{root}maj11"},
  {name = "minor11",             intervals = {0, 3, 7, 10, 14, 17},     base = 130,
   required = {0, 3, 10, 14, 17},    optional = {7},             important = {3, 10, 14, 17}, display = "{root}m11"},
  {name = "dominant11",          intervals = {0, 4, 7, 10, 14, 17},     base = 130,
   required = {0, 4, 10, 14, 17},    optional = {7},             important = {4, 10, 14, 17}, display = "{root}11"},
  {name = "dominant7#11",        intervals = {0, 4, 7, 10, 18},         base = 125,
   required = {0, 4, 10, 18},        optional = {7},             important = {4, 10, 18},     display = "{root}7#11"},
  {name = "major7#11",           intervals = {0, 4, 7, 11, 18},         base = 125,
   required = {0, 4, 11, 18},        optional = {7},             important = {4, 11, 18},     display = "{root}maj7#11"},
  {name = "major9#11",           intervals = {0, 4, 7, 11, 14, 18},     base = 130,
   required = {0, 4, 11, 14, 18},    optional = {7},             important = {4, 11, 14, 18}, display = "{root}maj9#11"},
  {name = "minor11b5",           intervals = {0, 3, 6, 10, 14, 17},     base = 125,
   required = {0, 3, 6, 10, 14, 17}, optional = {},              important = {3, 6, 10, 14, 17}, display = "{root}m11b5"},
  {name = "major13",             intervals = {0, 4, 7, 11, 14, 21},     base = 135,
   required = {0, 4, 11, 21},        optional = {7, 14},         important = {4, 11, 21},     display = "{root}maj13"},
  {name = "minor13",             intervals = {0, 3, 7, 10, 14, 21},     base = 135,
   required = {0, 3, 10, 21},        optional = {7, 14},         important = {3, 10, 21},     display = "{root}m13"},
  {name = "dominant13",          intervals = {0, 4, 7, 10, 14, 21},     base = 135,
   required = {0, 4, 10, 21},        optional = {7, 14},         important = {4, 10, 21},     display = "{root}13"},
  {name = "dominant13#11",       intervals = {0, 4, 7, 10, 18, 21},     base = 135,
   required = {0, 4, 10, 18, 21},    optional = {7},             important = {4, 10, 18, 21}, display = "{root}13#11"},
  {name = "dominant7b13",        intervals = {0, 4, 7, 10, 20},         base = 125,
   required = {0, 4, 10, 20},        optional = {7},             important = {4, 10, 20},     display = "{root}7b13"},
  {name = "dominant13b9",        intervals = {0, 4, 7, 10, 13, 21},     base = 130,
   required = {0, 4, 10, 13, 21},    optional = {7},             important = {4, 10, 13, 21}, display = "{root}13b9"},
  {name = "dominant13#9",        intervals = {0, 4, 7, 10, 15, 21},     base = 130,
   required = {0, 4, 10, 15, 21},    optional = {7},             important = {4, 10, 15, 21}, display = "{root}13#9"},
  {name = "dominant7b5",         intervals = {0, 4, 6, 10},             base = 118,
   required = {0, 4, 6, 10},         optional = {},              important = {4, 6, 10},      display = "{root}7b5"},
  {name = "dominant7#5",         intervals = {0, 4, 8, 10},             base = 118,
   required = {0, 4, 8, 10},         optional = {},              important = {4, 8, 10},      display = "{root}7#5"},
  {name = "dominant7b5b9",       intervals = {0, 4, 6, 10, 13},         base = 122,
   required = {0, 4, 6, 10, 13},     optional = {},              important = {4, 6, 10, 13},  display = "{root}7b5b9"},
  {name = "dominant7#5b9",       intervals = {0, 4, 8, 10, 13},         base = 122,
   required = {0, 4, 8, 10, 13},     optional = {},              important = {4, 8, 10, 13},  display = "{root}7#5b9"},
  {name = "dominant7b5#9",       intervals = {0, 4, 6, 10, 15},         base = 122,
   required = {0, 4, 6, 10, 15},     optional = {},              important = {4, 6, 10, 15},  display = "{root}7b5#9"},
  {name = "dominant7#5#9",       intervals = {0, 4, 8, 10, 15},         base = 122,
   required = {0, 4, 8, 10, 15},     optional = {},              important = {4, 8, 10, 15},  display = "{root}7#5#9"},
  {name = "altered",             intervals = {0, 4, 6, 10, 13},         base = 120,
   required = {0, 4, 10},            optional = {6, 8, 13, 15},  important = {4, 10},         display = "{root}7alt"},
  {name = "dominant7#5#9b13",    intervals = {0, 4, 8, 10, 15, 20},     base = 128,
   required = {0, 4, 8, 10, 15, 20}, optional = {},              important = {4, 8, 10, 15, 20}, display = "{root}7#5#9b13"},
  {name = "dominant9#11",        intervals = {0, 4, 7, 10, 14, 18},     base = 130,
   required = {0, 4, 10, 14, 18},    optional = {7},             important = {4, 10, 14, 18}, display = "{root}9#11"},
  {name = "dominant9b13",        intervals = {0, 4, 7, 10, 14, 20},     base = 130,
   required = {0, 4, 10, 14, 20},    optional = {7},             important = {4, 10, 14, 20}, display = "{root}9b13"},
  {name = "dominant7#9#11",      intervals = {0, 4, 7, 10, 15, 18},     base = 128,
   required = {0, 4, 10, 15, 18},    optional = {7},             important = {4, 10, 15, 18}, display = "{root}7#9#11"},
  {name = "dominant7b9#11",      intervals = {0, 4, 7, 10, 13, 18},     base = 128,
   required = {0, 4, 10, 13, 18},    optional = {7},             important = {4, 10, 13, 18}, display = "{root}7b9#11"},
  {name = "dominant7b9b13",      intervals = {0, 4, 7, 10, 13, 20},     base = 128,
   required = {0, 4, 10, 13, 20},    optional = {7},             important = {4, 10, 13, 20}, display = "{root}7b9b13"},
  {name = "dominant7#9b13",      intervals = {0, 4, 7, 10, 15, 20},     base = 128,
   required = {0, 4, 10, 15, 20},    optional = {7},             important = {4, 10, 15, 20}, display = "{root}7#9b13"},
  {name = "add9",                intervals = {0, 4, 7, 14},             base = 105,
   required = {0, 4, 7, 14},         optional = {},              important = {4, 7, 14},      display = "{root}add9"},
  {name = "minor-add9",          intervals = {0, 3, 7, 14},             base = 105,
   required = {0, 3, 7, 14},         optional = {},              important = {3, 7, 14},      display = "{root}m(add9)"},
  {name = "add11",               intervals = {0, 4, 7, 17},             base = 100,
   required = {0, 4, 7, 17},         optional = {},              important = {4, 7, 17},      display = "{root}add11"},
  {name = "add#11",              intervals = {0, 4, 7, 18},             base = 100,
   required = {0, 4, 7, 18},         optional = {},              important = {4, 7, 18},      display = "{root}add#11"},
  {name = "major7#5",            intervals = {0, 4, 8, 11},             base = 115,
   required = {0, 4, 8, 11},         optional = {},              important = {4, 8, 11},      display = "{root}maj7#5"},
  {name = "minor7b5",            intervals = {0, 3, 6, 10},             base = 115,
   required = {0, 3, 6, 10},         optional = {},              important = {3, 6, 10},      display = "{root}m7b5"},
  {name = "quartal",             intervals = {0, 5, 10},                base =  90,
   required = {0, 5, 10},            optional = {},              important = {5, 10},         display = "{root}quartal"},
  {name = "quartal-7",           intervals = {0, 5, 10, 15},            base =  95,
   required = {0, 5, 10, 15},        optional = {},              important = {5, 10, 15},     display = "{root}quartal7"},
}

-- Scoring weights, from ChordScoring.cpp.
local SCORE_EXACT      = 150  -- the whole interval set matches the pattern
local SCORE_REQUIRED   =  30  -- per required interval present
local SCORE_OPTIONAL   =  10  -- per optional interval present
local SCORE_IMPORTANT  =  30  -- per quality-defining interval (3rd, 7th)
local SCORE_ROOT_POS   =  25  -- the bass is the candidate root
local SCORE_RATIO      =  80  -- scaled by how much of the pattern was matched
--  RAISED FROM THE ORIGINAL'S 4. This is the one weight worth retuning: at 4
--  a pattern can win while leaving notes unexplained, which is how C F# G came
--  out F#5/C with the G abandoned. Swept over all 17,688 voicings of three to
--  seven notes, 4 scores 22.08% on the objective test, 15 scores 22.62%, 30
--  scores 23.52%, and 60 scores 23.64% but gives up on 3,420 voicings instead
--  of 312. 30 is the most that buys accuracy without the engine falling silent.
local PENALTY_EXTRA    =  30  -- per played interval the pattern does not hold
local SCORE_ROOTLESS   =  10  -- voicing bonuses
local SCORE_CLOSE      =   5
local PENALTY_NO_ROOT  =  40  -- root absent and not read as a rootless voicing
local PENALTY_NO_THIRD =  25  -- nothing at 2, 3, 4 or 5 to give it a quality
local MIN_SCORE        =  80  -- below this a candidate is not offered at all
local MAX_INTERVAL     =  24  -- extended intervals stop at the second octave

--[[  The scale, as an accuracy term. THIS IS NOT IN THE ORIGINAL.

    Pro uses the selected scale only to break an exact tie, and CLAUDE.md
    records that measuring it as anything stronger bought nothing: in C E G A
    over E both candidate roots are in C major, so being diatonic does not
    separate them. That was measured on Pro, whose costs are fine-grained.

    This engine's scores are coarse - whole multiples of 10 and 30 - so exact
    ties and near-ties are far commoner, and a scale term has room to act. It
    is kept as two named weights rather than folded into the pattern scores so
    that its effect can be measured by setting them to zero.
]]
local SCORE_ROOT_IN_KEY = 18  -- candidate root is a degree of the scale
local SCORE_TONE_IN_KEY =  4  -- per chord tone that sits in the scale

--[[  MEASURED, so that nobody has to take the idea on trust. Over all 17,688
    voicings the scale term moves the objective score from 22.07% to 22.08% -
    one hundredth of a point, which is nothing. That is the same null result
    CLAUDE.md records for Pro, now reproduced on a completely different
    engine, and it is worth more than either measurement alone: being diatonic
    does not separate candidate roots, because the competing roots are usually
    both in the key.

    What it does do is change WHICH name wins in 1,485 voicings, 8.4% of them,
    without making any of them more correct. So it is a preference lever, not
    an accuracy one. Kept because that is still useful when judging names by
    ear against Scaler; set both weights to 0 to take it out. ]]

-- Close, open or a drop voicing, from VoicingAnalyzer.cpp. A rootless voicing
-- is not decided here - it is decided per candidate, when the root is absent.
local function classifyVoicing(sorted)
  if #sorted < 2 then return "unknown" end
  local span = sorted[#sorted] - sorted[1]
  if span <= 12 then return "close" end
  if #sorted >= 4 then
    if sorted[2] - sorted[1] > 7 then return "drop2" end
    if sorted[3] - sorted[2] > 7 then return "drop3" end
  end
  return "open"
end

local function contains(list, want)
  for _, v in ipairs(list) do if v == want then return true end end
  return false
end

--[[  Score one (root, pattern) pair. A missing required interval disqualifies
    the pattern outright; everything else is additive. ]]
local function computeScore(intervals, pattern, bass, root, voicing, key)
  for _, req in ipairs(pattern.required) do
    if not contains(intervals, req) then return 0 end
  end

  local score = pattern.base

  local held = {}
  for _, iv in ipairs(intervals) do held[iv] = true end
  local inPattern = {}
  for _, iv in ipairs(pattern.intervals) do inPattern[iv] = true end

  -- Exact match: every interval played is in the pattern and vice versa.
  local exact = true
  for _, iv in ipairs(pattern.intervals) do
    if not held[iv] then exact = false break end
  end
  if exact then
    for _, iv in ipairs(intervals) do
      if not inPattern[iv] then exact = false break end
    end
  end
  if exact then score = score + SCORE_EXACT end

  local matched = 0
  for _, iv in ipairs(intervals) do
    if contains(pattern.required,  iv) then score = score + SCORE_REQUIRED  end
    if contains(pattern.optional,  iv) then score = score + SCORE_OPTIONAL  end
    if contains(pattern.important, iv) then score = score + SCORE_IMPORTANT end
    if inPattern[iv] then matched = matched + 1
    elseif not contains(pattern.optional, iv) then
      score = score - PENALTY_EXTRA
    end
  end

  if bass == root then score = score + SCORE_ROOT_POS end

  if #pattern.intervals > 0 then
    score = score + (matched / #pattern.intervals) * SCORE_RATIO
  end

  if     voicing == "rootless" then score = score + SCORE_ROOTLESS
  elseif voicing == "close"    then score = score + SCORE_CLOSE end

  if not held[0] and voicing ~= "rootless" then
    score = score - PENALTY_NO_ROOT
  end

  if not (held[2] or held[3] or held[4] or held[5]) then
    score = score - PENALTY_NO_THIRD
  end

  --  The scale term. `key` is nil when the weights are zeroed for measurement.
  if key then
    if key[root] then score = score + SCORE_ROOT_IN_KEY end
    for _, iv in ipairs(intervals) do
      if iv < 12 and key[(root + iv) % 12] then
        score = score + SCORE_TONE_IN_KEY
      end
    end
  end

  return score
end

-- From ChordScoring.cpp. Reported rather than displayed - see the note in
-- detectChord about what the number is and is not good for.
local function computeConfidence(best, second, noteCount, exact)
  local margin   = math.min((best - second) / 100, 1)
  local absolute = math.min(best / 250, 1)
  local notes    = math.min(noteCount / 6, 1)
  return 0.35 * margin + 0.25 * absolute + 0.15 * notes + 0.25 * (exact and 1 or 0.5)
end

--[[  The original's hardcoded disambiguation, kept as it is. Every one of its
    three cases asks the same question - is this candidate's root the bass -
    which is the rule Pro applies to everything rather than to three pairs. ]]
local function resolveAmbiguity(sorted, bass)
  if #sorted < 2 then return sorted[1] end
  local top, second = sorted[1], sorted[2]
  if top.score - second.score > 40 then return top end

  local a, b = top.type, second.type

  if (a == "major6" and b == "minor7") or (a == "minor7" and b == "major6") then
    if top.root    == bass then return top end
    if second.root == bass then return second end
    return (a == "major6") and top or second
  end

  if a == "diminished7" and b == "diminished7" then
    if top.root    == bass then return top end
    if second.root == bass then return second end
    return top
  end

  if (a == "minor6" and b == "minor") or (a == "minor" and b == "minor6") then
    local m6 = (a == "minor6") and top or second
    if m6.root == bass then return m6 end
    return top
  end

  return top
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
--  How far the winning candidate outscored the rest. Computed because the
--  original computes it; deliberately never drawn - see detectChord.
local chordConfidence = nil

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

--[[  Reading the chord, by pattern.

    Every pitch class present is tried as a root, and then - because jazz
    voicings routinely leave the root out - every pitch class absent is tried
    as a virtual one. Each candidate root is scored against all 62 patterns and
    the highest score wins, with three hardcoded pairs disambiguated after.

    Two of Pro's guards are kept, because they are about what a chord IS rather
    than about how it is named: two notes are an interval, and past seven pitch
    classes there is no chord left to find. The original has no thickness
    guard, so without it an eight-note cluster comes back confidently named.

    The confidence number is computed and can be read by the tools, but is not
    drawn. It measures agreement between this engine's own candidates, not
    whether the answer is right, so putting it on the icon would dress up a
    guess as a measurement. ]]
function detectChord()
  local classes, bass = heldPitchClasses()
  if not bass then return nil end

  local pcs = {}
  for pc = 0, 11 do if classes[pc] then pcs[#pcs + 1] = pc end end
  local count = #pcs

  local function spellOut()
    local spelled = {}
    for _, pc in ipairs(pcs) do spelled[#spelled + 1] = chordNoteName(pc) end
    return table.concat(spelled, " ")
  end

  if count == 1 then return chordNoteName(bass) end
  if count == 2 then
    for _, root in ipairs(pcs) do
      if classes[(root + 7) % 12] then
        local name = chordNoteName(root) .. "5"
        if root ~= bass then name = name .. "/" .. chordNoteName(bass) end
        return name
      end
    end
    return spellOut()
  end
  if count > 7 then return spellOut() end

  local sorted = {}
  for note in pairs(held) do sorted[#sorted + 1] = note end
  table.sort(sorted)

  local key     = (state.root and state.scale) and active or ASSUMED_KEY
  local voicing = classifyVoicing(sorted)
  local extend  = #sorted > 3

  local candidates, order = {}, 0

  local function tryRoot(root, rootless)
    local seen, intervals = {}, {}
    local function add(iv)
      if iv <= MAX_INTERVAL and not seen[iv] then
        seen[iv] = true
        intervals[#intervals + 1] = iv
      end
    end
    for _, pc in ipairs(pcs) do
      local iv = (pc - root) % 12
      add(iv)
      -- The root is not doubled an octave up; that would inflate every score.
      if extend and iv ~= 0 then add(iv + 12) end
    end
    table.sort(intervals)

    local how = rootless and "rootless" or voicing
    for _, pattern in ipairs(PATTERNS) do
      local score = computeScore(intervals, pattern, bass, root, how, key)
      if score > MIN_SCORE then
        order = order + 1
        candidates[#candidates + 1] = {
          root = root, type = pattern.name, display = pattern.display,
          score = score, intervals = intervals, pattern = pattern.intervals,
          order = order,
        }
      end
    end
  end

  for _, root in ipairs(pcs) do tryRoot(root, false) end
  for root = 0, 11 do
    if not classes[root] then tryRoot(root, true) end
  end

  if #candidates == 0 then return spellOut() end

  --  Sorted by score, and by discovery order when scores tie, so the answer
  --  is reproducible. The original leaves ties to std::sort, which does not
  --  promise an order.
  table.sort(candidates, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.order < b.order
  end)

  local best   = candidates[1]
  local second = candidates[2] and candidates[2].score or 0

  local inPattern, exact = {}, true
  for _, iv in ipairs(best.pattern) do inPattern[iv] = true end
  for _, iv in ipairs(best.intervals) do
    if not inPattern[iv] then exact = false break end
  end
  if exact then
    local held2 = {}
    for _, iv in ipairs(best.intervals) do held2[iv] = true end
    for _, iv in ipairs(best.pattern) do
      if not held2[iv] then exact = false break end
    end
  end

  chordConfidence = computeConfidence(best.score, second, #sorted, exact)

  local top = {}
  for i = 1, math.min(3, #candidates) do top[i] = candidates[i] end
  best = resolveAmbiguity(top, bass)

  local name = best.display:gsub("{root}", chordNoteName(best.root))
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

  addItem(menu, "Clear Scale", clearScale, {checked = state.scale == nil})
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
