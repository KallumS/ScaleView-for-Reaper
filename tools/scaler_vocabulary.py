#!/usr/bin/env python3
"""Every chord shape of two to four notes over C, as Scaler Detector names it,
beside what ScaleView Pro printed for the same notes.

Collected 1 November 2026 in REAPER 7.84 by playing each chord live, one at a
time, and reading both plugins off the screen. Every note was released between
chords. C was always the lowest note (MIDI 48), with the other notes in close
position in the octave above it (49-59). That is every 2-, 3- and 4-note
pitch-class set that contains C, 11 + 55 + 165 = 231 chords. Scaler had no
scale selected. ScaleView Pro was set to C Minor (Natural), so it spells black
keys as flats.

Scaler Detector is Scaler's detection plugin, not Scaler 3 itself. On three
earlier rows of scaler_cases.py it gave Scaler 3's names.

Each row of VOCAB is: the intervals above C, Scaler's name exactly as printed,
whether that name has a slash, the root Scaler named (its own text, e.g.
"C#/Db"; None where it printed "?"), and ScaleView Pro's name. A name with no
slash and root C is a shape Scaler names from its bass, i.e. one on its list of
chord names. See CLAUDE.md, *Where Pro and Scaler 3 disagree*.

TRANSPOSED holds three shapes that Scaler does not name from the bass, played
over all twelve bass notes plus a few octave repeats. They show that Scaler's
choice of the other root depends on the absolute pitch class, not only on the
shape. Only Scaler was read for these.

The 5-, 6- and 7-note continuation (in progress) lives in
scaler_vocabulary_5to7/.

Run it to print the summary; nothing here needs Lua.
"""
import re, collections

#  intervals, Scaler's name, slash?, Scaler's root, ScaleView Pro's name
VOCAB = [
    ('0 1'        , 'C min second'                , False, 'C'     , 'C Db'),
    ('0 2'        , 'C maj second'                , False, 'C'     , 'C D'),
    ('0 3'        , 'C min(no5)'                  , False, 'C'     , 'Cmin(no5)'),
    ('0 4'        , 'C maj(no5)'                  , False, 'C'     , 'Cmaj(no5)'),
    ('0 5'        , 'F 5'                         , False, 'F'     , 'F5/C'),
    ('0 6'        , 'C tritone'                   , False, 'C'     , 'C Gb'),
    ('0 7'        , 'C 5'                         , False, 'C'     , 'C5'),
    ('0 8'        , 'G#/Ab maj(no5)'              , False, 'G#/Ab' , 'Abmaj(no5)/C'),
    ('0 9'        , 'A min(no5)'                  , False, 'A'     , 'Amin(no5)/C'),
    ('0 10'       , 'C min seventh'               , False, 'C'     , 'C Bb'),
    ('0 11'       , 'C maj seventh'               , False, 'C'     , 'C B'),
    ('0 1 2'      , 'C ?'                         , False, None    , 'Csus2b9'),
    ('0 1 3'      , 'C min b9'                    , False, 'C'     , 'Dbmaj7sus2/C'),
    ('0 1 4'      , 'C maj b9'                    , False, 'C'     , 'DbminMaj7/C'),
    ('0 1 5'      , 'C#/Db maj7 / C'              , True , 'C#/Db' , 'Dbmaj7/C'),
    ('0 1 6'      , 'C#/Db maj7(sus4) / C'        , True , 'C#/Db' , 'Gbadd#11(no3)/C'),
    ('0 1 7'      , 'C#/Db maj7(no3 b5) / C'      , True , 'C#/Db' , 'Caddb9(no3)'),
    ('0 1 8'      , 'C#/Db maj7(no3) / C'         , True , 'C#/Db' , 'Abadd11/C'),
    ('0 1 9'      , 'C#/Db maj7(no3 #5) / C'      , True , 'C#/Db' , 'Aadd#9/C'),
    ('0 1 10'     , 'A#/Bb min(no5) add 9 / C'    , True , 'A#/Bb' , 'BbminAdd9/C'),
    ('0 1 11'     , 'C ?'                         , False, None    , 'Bsus2b9/C'),
    ('0 2 3'      , 'C min(no5) add 9'            , False, 'C'     , 'CminAdd9'),
    ('0 2 4'      , 'C maj(no5) 9'                , False, 'C'     , 'Cadd9'),
    ('0 2 5'      , 'D min7 / C'                  , True , 'D'     , 'Dmin7/C'),
    ('0 2 6'      , 'C sus2(b5)'                  , False, 'C'     , 'D7/C'),
    ('0 2 7'      , 'C sus2'                      , False, 'C'     , 'Csus2'),
    ('0 2 8'      , 'G#/Ab maj(b5) / C'           , True , 'G#/Ab' , 'Ab(b5)/C'),
    ('0 2 9'      , 'C 6(sus2)'                   , False, 'C'     , 'AminAdd11/C'),
    ('0 2 10'     , 'C 7(sus2)'                   , False, 'C'     , 'Bbadd9/C'),
    ('0 2 11'     , 'C maj7(sus2)'                , False, 'C'     , 'Cmaj7sus2'),
    ('0 3 4'      , 'C maj #9'                    , False, 'C'     , 'Cadd#9'),
    ('0 3 5'      , 'C min add 11'                , False, 'C'     , 'CminAdd11'),
    ('0 3 6'      , 'C dim'                       , False, 'C'     , 'Cdim'),
    ('0 3 7'      , 'C min'                       , False, 'C'     , 'Cmin'),
    ('0 3 8'      , 'G#/Ab maj / C'               , True , 'G#/Ab' , 'Ab/C'),
    ('0 3 9'      , 'C min6'                      , False, 'C'     , 'Adim/C'),
    ('0 3 10'     , 'C min7'                      , False, 'C'     , 'Cmin7'),
    ('0 3 11'     , 'C min(no5) maj7'             , False, 'C'     , 'CminMaj7'),
    ('0 4 5'      , 'C maj add 11'                , False, 'C'     , 'Cadd11'),
    ('0 4 6'      , 'C maj(b5)'                   , False, 'C'     , 'C(b5)'),
    ('0 4 7'      , 'C maj'                       , False, 'C'     , 'C'),
    ('0 4 8'      , 'C aug'                       , False, 'C'     , 'Caug'),
    ('0 4 9'      , 'A min / C'                   , True , 'A'     , 'Amin/C'),
    ('0 4 10'     , 'C 7'                         , False, 'C'     , 'C7'),
    ('0 4 11'     , 'C maj7'                      , False, 'C'     , 'Cmaj7'),
    ('0 5 6'      , 'F#/Gb maj7(no3 b5) / C'      , True , 'F#/Gb' , 'Gbmaj7b5(no3)/C'),
    ('0 5 7'      , 'C sus4'                      , False, 'C'     , 'Csus4'),
    ('0 5 8'      , 'F min / C'                   , True , 'F'     , 'Fmin/C'),
    ('0 5 9'      , 'F maj / C'                   , True , 'F'     , 'F/C'),
    ('0 5 10'     , 'C 7(sus4)'                   , False, 'C'     , 'C7sus4'),
    ('0 5 11'     , 'C maj7(sus4)'                , False, 'C'     , 'Fadd#11(no3)/C'),
    ('0 6 7'      , 'C 5 #11'                     , False, 'C'     , 'Cadd#11(no3)'),
    ('0 6 8'      , 'F#/Gb sus2(b5) / C'          , True , 'F#/Gb' , 'Ab7/C'),
    ('0 6 9'      , 'F#/Gb dim / C'               , True , 'F#/Gb' , 'Gbdim/C'),
    ('0 6 10'     , 'F#/Gb maj(b5) / C'           , True , 'F#/Gb' , 'Gb(b5)/C'),
    ('0 6 11'     , 'C maj7(no3 b5)'              , False, 'C'     , 'Cmaj7b5(no3)'),
    ('0 7 8'      , 'G#/Ab maj7 / C'              , True , 'G#/Ab' , 'Abmaj7/C'),
    ('0 7 9'      , 'A min7 / C'                  , True , 'A'     , 'Amin7/C'),
    ('0 7 10'     , 'C 7(no3)'                    , False, 'C'     , 'C7(no3)'),
    ('0 7 11'     , 'C maj7(no3)'                 , False, 'C'     , 'Cmaj7(no3)'),
    ('0 8 9'      , 'G#/Ab maj b9 / C'            , True , 'G#/Ab' , 'AminMaj7/C'),
    ('0 8 10'     , 'G#/Ab maj(no5) 9 / C'        , True , 'G#/Ab' , 'Abadd9/C'),
    ('0 8 11'     , 'C maj7(no3 #5)'              , False, 'C'     , 'Abadd#9/C'),
    ('0 9 10'     , 'A min b9 / C'                , True , 'A'     , 'C7(13)(no3)'),
    ('0 9 11'     , 'A min(no5) add 9 / C'        , True , 'A'     , 'Cmaj7(13)(no3)'),
    ('0 10 11'    , 'C ?'                         , False, None    , 'Bbsus2b9/C'),
    ('0 1 2 3'    , 'C ?'                         , False, None    , 'CminAdd9b9'),
    ('0 1 2 4'    , 'C#/Db min maj7 b9 / C'       , True , 'C#/Db' , 'Cadd9b9'),
    ('0 1 2 5'    , 'C#/Db maj7 b9 / C'           , True , 'C#/Db' , 'Dmin7(maj7)/C'),
    ('0 1 2 6'    , 'C#/Db maj7(sus4) b9 / C'     , True , 'C#/Db' , 'D7(maj7)/C'),
    ('0 1 2 7'    , 'C ?'                         , False, None    , 'Gsus4#11/C'),
    ('0 1 2 8'    , 'G#/Ab maj(b5) 11 / C'        , True , 'G#/Ab' , 'Ab(b5)Add11/C'),
    ('0 1 2 9'    , 'C 6(sus2) b9'                , False, 'C'     , 'Aadd11#9/C'),
    ('0 1 2 10'   , 'C ?'                         , False, None    , 'C7sus2b9'),
    ('0 1 2 11'   , 'C ?'                         , False, None    , 'Cmaj7sus2b9'),
    ('0 1 3 4'    , 'C maj b9 #9'                 , False, 'C'     , 'DbminMaj9/C'),
    ('0 1 3 5'    , 'C#/Db maj9 / C'              , True , 'C#/Db' , 'Dbmaj9/C'),
    ('0 1 3 6'    , 'C dim b9'                    , False, 'C'     , 'Ebmin7(13)/C'),
    ('0 1 3 7'    , 'C min b9'                    , False, 'C'     , 'Cminb9'),
    ('0 1 3 8'    , 'C#/Db maj7(sus2) / C'        , True , 'C#/Db' , 'Abadd11/C'),
    ('0 1 3 9'    , 'C min6 b9'                   , False, 'C'     , 'Cmin6b9'),
    ('0 1 3 10'   , 'C min7 b9'                   , False, 'C'     , 'Cmin7b9'),
    ('0 1 3 11'   , 'C min maj7 b9'               , False, 'C'     , 'CminMaj7b9'),
    ('0 1 4 5'    , 'C#/Db maj7 #9 / C'           , True , 'C#/Db' , 'Dbmaj7#9/C'),
    ('0 1 4 6'    , 'C maj(b5) b9'                , False, 'C'     , 'DbminMaj7(11)/C'),
    ('0 1 4 7'    , 'C maj b9'                    , False, 'C'     , 'DbminMaj7b5/C'),
    ('0 1 4 8'    , 'C#/Db min maj7 / C'          , True , 'C#/Db' , 'DbminMaj7/C'),
    ('0 1 4 9'    , 'A maj #9 / C'                , True , 'A'     , 'Aadd#9/C'),
    ('0 1 4 10'   , 'C 7 b9'                      , False, 'C'     , 'C7b9'),
    ('0 1 4 11'   , 'C maj7 b9'                   , False, 'C'     , 'Cmaj7b9'),
    ('0 1 5 6'    , 'C#/Db maj7 11 / C'           , True , 'C#/Db' , 'Dbmaj7(11)/C'),
    ('0 1 5 7'    , 'C#/Db maj7(b5) / C'          , True , 'C#/Db' , 'Dbmaj7b5/C'),
    ('0 1 5 8'    , 'C#/Db maj7 / C'              , True , 'C#/Db' , 'Dbmaj7/C'),
    ('0 1 5 9'    , 'C#/Db maj7(#5) / C'          , True , 'C#/Db' , 'Dbmaj7#5/C'),
    ('0 1 5 10'   , 'C 7(sus4) b9'                , False, 'C'     , 'BbminAdd9/C'),
    ('0 1 5 11'   , 'C maj7(sus4) b9'             , False, 'C'     , 'Db7(maj7)/C'),
    ('0 1 6 7'    , 'C ?'                         , False, None    , 'Caddb9#11(no3)'),
    ('0 1 6 8'    , 'C#/Db maj7(sus4) / C'        , True , 'C#/Db' , 'Dbmaj7sus4/C'),
    ('0 1 6 9'    , 'F#/Gb min #11 / C'           , True , 'F#/Gb' , 'Gbmin#11/C'),
    ('0 1 6 10'   , 'C#/Db maj13(sus4) / C'       , True , 'C#/Db' , 'Gbadd#11/C'),
    ('0 1 6 11'   , 'C ?'                         , False, None    , 'Gbsus4#11/C'),
    ('0 1 7 8'    , 'C#/Db 5 maj7 #11 / C'        , True , 'C#/Db' , 'Abmaj7(11)/C'),
    ('0 1 7 9'    , 'A 7 #9 / C'                  , True , 'A'     , 'A7#9/C'),
    ('0 1 7 10'   , 'A#/Bb min6 9 / C'            , True , 'A#/Bb' , 'GdimAdd11/C'),
    ('0 1 7 11'   , 'G maj(b5) 11 / C'            , True , 'G'     , 'G(b5)Add11/C'),
    ('0 1 8 9'    , 'A maj7 #9 / C'               , True , 'A'     , 'Amaj7#9/C'),
    ('0 1 8 10'   , 'G#/Ab maj add 9 11 / C'      , True , 'G#/Ab' , 'Abadd9Add11/C'),
    ('0 1 8 11'   , 'B 6(sus2) b9 / C'            , True , 'B'     , 'Abadd11#9/C'),
    ('0 1 9 10'   , 'A maj b9 #9 / C'             , True , 'A'     , 'BbminMaj9/C'),
    ('0 1 9 11'   , 'C ?'                         , False, None    , 'Cmaj13b9(no3)'),
    ('0 1 10 11'  , 'C ?'                         , False, None    , 'BbminAdd9b9/C'),
    ('0 2 3 4'    , 'C ?'                         , False, None    , 'Cadd9#9'),
    ('0 2 3 5'    , 'C min add 9 11'              , False, 'C'     , 'CminAdd9Add11'),
    ('0 2 3 6'    , 'C dim add 9'                 , False, 'C'     , 'CdimAdd9'),
    ('0 2 3 7'    , 'C min add 9'                 , False, 'C'     , 'CminAdd9'),
    ('0 2 3 8'    , 'D#/Eb maj13(sus4) / C'       , True , 'D#/Eb' , 'Abadd#11/C'),
    ('0 2 3 9'    , 'C min6 9'                    , False, 'C'     , 'AdimAdd11/C'),
    ('0 2 3 10'   , 'C min9'                      , False, 'C'     , 'Bbadd9Add11/C'),
    ('0 2 3 11'   , 'C min maj9'                  , False, 'C'     , 'CminMaj9'),
    ('0 2 4 5'    , 'C maj add 9 11'              , False, 'C'     , 'Cadd9Add11'),
    ('0 2 4 6'    , 'D 9 / C'                     , True , 'D'     , 'D9/C'),
    ('0 2 4 7'    , 'C maj add 9'                 , False, 'C'     , 'Cadd9'),
    ('0 2 4 8'    , 'C aug add 9'                 , False, 'C'     , 'Eaug7/C'),
    ('0 2 4 9'    , 'C 6 9'                       , False, 'C'     , 'AminAdd11/C'),
    ('0 2 4 10'   , 'C 9'                         , False, 'C'     , 'C9'),
    ('0 2 4 11'   , 'C maj9'                      , False, 'C'     , 'Cmaj9'),
    ('0 2 5 6'    , 'D 7 #9 / C'                  , True , 'D'     , 'D7#9/C'),
    ('0 2 5 7'    , 'D min11 / C'                 , True , 'D'     , 'Dmin7(11)/C'),
    ('0 2 5 8'    , 'D min7(b5) / C'              , True , 'D'     , 'Dmin7b5/C'),
    ('0 2 5 9'    , 'D min7 / C'                  , True , 'D'     , 'Dmin7/C'),
    ('0 2 5 10'   , 'C 9(sus4)'                   , False, 'C'     , 'Bbadd9/C'),
    ('0 2 5 11'   , 'C maj9(sus4)'                , False, 'C'     , 'Dmin7(13)/C'),
    ('0 2 6 7'    , 'D 7 11 / C'                  , True , 'D'     , 'Gmaj7sus4/C'),
    ('0 2 6 8'    , 'D 7(b5) / C'                 , True , 'D'     , 'D7b5/C'),
    ('0 2 6 9'    , 'C 6(sus2 b5)'                , False, 'C'     , 'D7/C'),
    ('0 2 6 10'   , 'C 7(sus2 b5)'                , False, 'C'     , 'Daug7/C'),
    ('0 2 6 11'   , 'D 7 13 / C'                  , True , 'D'     , 'Bminb9/C'),
    ('0 2 7 8'    , 'G#/Ab maj7(b5) / C'          , True , 'G#/Ab' , 'Abmaj7b5/C'),
    ('0 2 7 9'    , 'C 6(sus2)'                   , False, 'C'     , 'Amin7(11)/C'),
    ('0 2 7 10'   , 'C 7(sus2)'                   , False, 'C'     , 'C7sus2'),
    ('0 2 7 11'   , 'C maj7(sus2)'                , False, 'C'     , 'Gadd11/C'),
    ('0 2 8 9'    , 'G#/Ab maj(b5) b9 / C'        , True , 'G#/Ab' , 'AminMaj7(11)/C'),
    ('0 2 8 10'   , 'A#/Bb 9 / C'                 , True , 'A#/Bb' , 'Bb9/C'),
    ('0 2 8 11'   , 'G#/Ab maj(b5) #9 / C'        , True , 'G#/Ab' , 'Ab(b5)#9/C'),
    ('0 2 9 10'   , 'A#/Bb maj9 / C'              , True , 'A#/Bb' , 'Bbmaj9/C'),
    ('0 2 9 11'   , 'C maj7(sus2) 13'             , False, 'C'     , 'Cmaj7sus2(13)'),
    ('0 2 10 11'  , 'B min maj7 b9 / C'           , True , 'B'     , 'BminMaj7b9/C'),
    ('0 3 4 5'    , 'D#/Eb 6(sus2) b9 / C'        , True , 'D#/Eb' , 'Cadd11#9'),
    ('0 3 4 6'    , 'C maj(b5) #9'                , False, 'C'     , 'C(b5)#9'),
    ('0 3 4 7'    , 'C maj #9'                    , False, 'C'     , 'Cadd#9'),
    ('0 3 4 8'    , 'E maj7(#5) / C'              , True , 'E'     , 'Emaj7#5/C'),
    ('0 3 4 9'    , 'C 6 #9'                      , False, 'C'     , 'Amin#11/C'),
    ('0 3 4 10'   , 'C 7 #9'                      , False, 'C'     , 'C7#9'),
    ('0 3 4 11'   , 'C maj7 #9'                   , False, 'C'     , 'Cmaj7#9'),
    ('0 3 5 6'    , 'D#/Eb min6 9 / C'            , True , 'D#/Eb' , 'CdimAdd11'),
    ('0 3 5 7'    , 'C min add 11'                , False, 'C'     , 'CminAdd11'),
    ('0 3 5 8'    , 'F min7 / C'                  , True , 'F'     , 'Fmin7/C'),
    ('0 3 5 9'    , 'C min6 11'                   , False, 'C'     , 'F7/C'),
    ('0 3 5 10'   , 'C min11'                     , False, 'C'     , 'Cmin7(11)'),
    ('0 3 5 11'   , 'B maj(b5) b9 / C'            , True , 'B'     , 'CminMaj7(11)'),
    ('0 3 6 7'    , 'C min #11'                   , False, 'C'     , 'Cmin#11'),
    ('0 3 6 8'    , 'C dim #5'                    , False, 'C'     , 'Ab7/C'),
    ('0 3 6 9'    , 'C dim7'                      , False, 'C'     , 'Cdim7'),
    ('0 3 6 10'   , 'C min7(b5)'                  , False, 'C'     , 'Cmin7b5'),
    ('0 3 6 11'   , 'B maj b9 / C'                , True , 'B'     , 'CminMaj7b5'),
    ('0 3 7 8'    , 'G#/Ab maj7 / C'              , True , 'G#/Ab' , 'Abmaj7/C'),
    ('0 3 7 9'    , 'C min6'                      , False, 'C'     , 'Cmin6'),
    ('0 3 7 10'   , 'C min7'                      , False, 'C'     , 'Cmin7'),
    ('0 3 7 11'   , 'C min maj7'                  , False, 'C'     , 'CminMaj7'),
    ('0 3 8 9'    , 'G#/Ab maj b9 / C'            , True , 'G#/Ab' , 'AminMaj7b5/C'),
    ('0 3 8 10'   , 'D#/Eb 6(sus4) / C'           , True , 'D#/Eb' , 'Abadd9/C'),
    ('0 3 8 11'   , 'G#/Ab maj #9 / C'            , True , 'G#/Ab' , 'Abadd#9/C'),
    ('0 3 9 10'   , 'C min7 13'                   , False, 'C'     , 'Cmin7(13)'),
    ('0 3 9 11'   , 'A dim add 9 / C'             , True , 'A'     , 'CminMaj7(13)'),
    ('0 3 10 11'  , 'B maj7 b9 / C'               , True , 'B'     , 'Cmin7(maj7)'),
    ('0 4 5 6'    , 'C maj(b5) 11'                , False, 'C'     , 'C(b5)Add11'),
    ('0 4 5 7'    , 'C maj add 11'                , False, 'C'     , 'Cadd11'),
    ('0 4 5 8'    , 'C aug add 11'                , False, 'C'     , 'FminMaj7/C'),
    ('0 4 5 9'    , 'F maj7 / C'                  , True , 'F'     , 'Fmaj7/C'),
    ('0 4 5 10'   , 'C 7 11'                      , False, 'C'     , 'Fmaj7sus4/C'),
    ('0 4 5 11'   , 'C maj7 11'                   , False, 'C'     , 'Cmaj7(11)'),
    ('0 4 6 7'    , 'C maj #11'                   , False, 'C'     , 'Cadd#11'),
    ('0 4 6 8'    , 'E aug add 9 / C'             , True , 'E'     , 'Abaug7/C'),
    ('0 4 6 9'    , 'F#/Gb min7(b5) / C'          , True , 'F#/Gb' , 'Gbmin7b5/C'),
    ('0 4 6 10'   , 'C 7(b5)'                     , False, 'C'     , 'C7b5'),
    ('0 4 6 11'   , 'C maj7(b5)'                  , False, 'C'     , 'Cmaj7b5'),
    ('0 4 7 8'    , 'G#/Ab maj7(#5) / C'          , True , 'G#/Ab' , 'Abmaj7#5/C'),
    ('0 4 7 9'    , 'C maj add 13'                , False, 'C'     , 'C6'),
    ('0 4 7 10'   , 'C 7'                         , False, 'C'     , 'C7'),
    ('0 4 7 11'   , 'C maj7'                      , False, 'C'     , 'Cmaj7'),
    ('0 4 8 9'    , 'C aug add 13'                , False, 'C'     , 'AminMaj7/C'),
    ('0 4 8 10'   , 'C 7(#5)'                     , False, 'C'     , 'Caug7'),
    ('0 4 8 11'   , 'C maj7(#5)'                  , False, 'C'     , 'Cmaj7#5'),
    ('0 4 9 10'   , 'C 7 13'                      , False, 'C'     , 'C7(13)'),
    ('0 4 9 11'   , 'C maj7 13'                   , False, 'C'     , 'AminAdd9/C'),
    ('0 4 10 11'  , 'C 7 maj7'                    , False, 'C'     , 'C7(maj7)'),
    ('0 5 6 7'    , 'C ?'                         , False, None    , 'Csus4#11'),
    ('0 5 6 8'    , 'F min b9 / C'                , True , 'F'     , 'Fminb9/C'),
    ('0 5 6 9'    , 'F maj b9 / C'                , True , 'F'     , 'GbminMaj7b5/C'),
    ('0 5 6 10'   , 'F#/Gb maj7(b5) / C'          , True , 'F#/Gb' , 'Gbmaj7b5/C'),
    ('0 5 6 11'   , 'C ?'                         , False, None    , 'Faddb9#11(no3)/C'),
    ('0 5 7 8'    , 'F min add 9 / C'             , True , 'F'     , 'FminAdd9/C'),
    ('0 5 7 9'    , 'C 6(sus4)'                   , False, 'C'     , 'Fadd9/C'),
    ('0 5 7 10'   , 'C 7(sus4)'                   , False, 'C'     , 'C7sus4'),
    ('0 5 7 11'   , 'C maj7(sus4)'                , False, 'C'     , 'Cmaj7sus4'),
    ('0 5 8 9'    , 'F maj #9 / C'                , True , 'F'     , 'Fadd#9/C'),
    ('0 5 8 10'   , 'F min add 11 / C'            , True , 'F'     , 'FminAdd11/C'),
    ('0 5 8 11'   , 'F min #11 / C'               , True , 'F'     , 'Fmin#11/C'),
    ('0 5 9 10'   , 'F maj add 11 / C'            , True , 'F'     , 'Fadd11/C'),
    ('0 5 9 11'   , 'C maj13(sus4)'               , False, 'C'     , 'Fadd#11/C'),
    ('0 5 10 11'  , 'C ?'                         , False, None    , 'Fsus4#11/C'),
    ('0 6 7 8'    , 'G maj7(sus4) b9 / C'         , True , 'G'     , 'Ab7(maj7)/C'),
    ('0 6 7 9'    , 'F#/Gb dim b9 / C'            , True , 'F#/Gb' , 'Amin7(13)/C'),
    ('0 6 7 10'   , 'F#/Gb maj(b5) b9 / C'        , True , 'F#/Gb' , 'GminMaj7(11)/C'),
    ('0 6 7 11'   , 'C 5 maj7 #11'                , False, 'C'     , 'Gmaj7(11)/C'),
    ('0 6 8 9'    , 'F#/Gb dim add 9 / C'         , True , 'F#/Gb' , 'GbdimAdd9/C'),
    ('0 6 8 10'   , 'G#/Ab 9 / C'                 , True , 'G#/Ab' , 'Ab9/C'),
    ('0 6 8 11'   , 'G#/Ab 7 #9 / C'              , True , 'G#/Ab' , 'Ab7#9/C'),
    ('0 6 9 10'   , 'F#/Gb maj(b5) #9 / C'        , True , 'F#/Gb' , 'C7b5(13)(no3)'),
    ('0 6 9 11'   , 'A min6 9 / C'                , True , 'A'     , 'GbdimAdd11/C'),
    ('0 6 10 11'  , 'F#/Gb maj(b5) 11 / C'        , True , 'F#/Gb' , 'Gb(b5)Add11/C'),
    ('0 7 8 9'    , 'G#/Ab maj7 b9 / C'           , True , 'G#/Ab' , 'Amin7(maj7)/C'),
    ('0 7 8 10'   , 'G#/Ab maj9 / C'              , True , 'G#/Ab' , 'Abmaj9/C'),
    ('0 7 8 11'   , 'G#/Ab maj7 #9 / C'           , True , 'G#/Ab' , 'Abmaj7#9/C'),
    ('0 7 9 10'   , 'G min add 9 11 / C'          , True , 'G'     , 'C7(13)(no3)'),
    ('0 7 9 11'   , 'G maj add 9 11 / C'          , True , 'G'     , 'Gadd9Add11/C'),
    ('0 7 10 11'  , 'A#/Bb 6(sus2) b9 / C'        , True , 'A#/Bb' , 'C7(maj7)(no3)'),
    ('0 8 9 10'   , 'A min maj7 b9 / C'           , True , 'A'     , 'AminMaj7b9/C'),
    ('0 8 9 11'   , 'G#/Ab maj b9 #9 / C'         , True , 'G#/Ab' , 'AminMaj9/C'),
    ('0 8 10 11'  , 'C ?'                         , False, None    , 'Abadd9#9/C'),
    ('0 9 10 11'  , 'C ?'                         , False, None    , 'C7(13)(maj7)(no3)'),
]

#  shape (intervals above the bass), bass, Scaler's name. Each block is one
#  shape over the twelve bass notes; the "+12"/"-12" rows repeat a voicing an
#  octave up or down and always gave the same name.
TRANSPOSED = [
    ("0 4 6 9", "C",  "F#/Gb min7(b5) / C"), ("0 4 6 9", "C#", "G min7(b5) / C#"),
    ("0 4 6 9", "D",  "G#/Ab min7(b5) / D"), ("0 4 6 9", "D#", "C min6 / D#"),
    ("0 4 6 9", "E",  "C#/Db min6 / E"),     ("0 4 6 9", "F",  "D min6 / F"),
    ("0 4 6 9", "F#", "D#/Eb min6 / F#"),    ("0 4 6 9", "G",  "E min6 / G"),
    ("0 4 6 9", "G#", "F min6 / G#"),        ("0 4 6 9", "A",  "F#/Gb min6 / A"),
    ("0 4 6 9", "A#", "G min6 / A#"),        ("0 4 6 9", "B",  "G#/Ab min6 / B"),
    ("0 4 6 9", "C+12", "F#/Gb min7(b5) / C"),

    ("0 3 5 8", "C",  "F min7 / C"),         ("0 3 5 8", "C#", "F#/Gb min7 / C#"),
    ("0 3 5 8", "D",  "G min7 / D"),         ("0 3 5 8", "D#", "G#/Ab min7 / D#"),
    ("0 3 5 8", "E",  "C maj add 13 / E"),   ("0 3 5 8", "F",  "C#/Db maj add 13 / F"),
    ("0 3 5 8", "F#", "D maj add 13 / F#"),  ("0 3 5 8", "G",  "D#/Eb maj add 13 / G"),
    ("0 3 5 8", "G#", "E maj add 13 / G#"),  ("0 3 5 8", "A",  "F maj add 13 / A"),
    ("0 3 5 8", "A#", "F#/Gb maj add 13 / A#"), ("0 3 5 8", "B", "G maj add 13 / B"),
    ("0 3 5 8", "C+12", "F min7 / C"),       ("0 3 5 8", "C-12", "F min7 / C"),
    ("0 3 5 8", "E+12", "C maj add 13 / E"), ("0 3 5 8", "E-12", "C maj add 13 / E"),
    ("0 3 5 8", "D#+12", "G#/Ab min7 / D#"),

    ("0 2 5 9", "C",  "D min7 / C"),         ("0 2 5 9", "C#", "D#/Eb min7 / C#"),
    ("0 2 5 9", "D",  "E min7 / D"),         ("0 2 5 9", "D#", "F min7 / D#"),
    ("0 2 5 9", "E",  "F#/Gb min7 / E"),     ("0 2 5 9", "F",  "G min7 / F"),
    ("0 2 5 9", "F#", "G#/Ab min7 / F#"),    ("0 2 5 9", "G",  "A min7 / G"),
    ("0 2 5 9", "G#", "A#/Bb min7 / G#"),    ("0 2 5 9", "A",  "B min7 / A"),
    ("0 2 5 9", "A#", "D#/Eb maj add 13 / A#"), ("0 2 5 9", "B", "E maj add 13 / B"),
    ("0 2 5 9", "A+12", "B min7 / A"),       ("0 2 5 9", "A-12", "B min7 / A"),
    ("0 2 5 9", "A#-12", "D#/Eb maj add 13 / A#"),
]

PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
      "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def quality(name):
    """Scaler's name with the root and any slash taken off."""
    head = name.split(" / ")[0]
    return re.sub(r"^[A-G][#b]?(?:/[A-G][#b]?)?\s*", "", head)


def pro_root(name):
    m = re.match(r"([A-G][#b]?)", name)
    return PC[m.group(1)] if m and " " not in name else None


def main():
    named = {frozenset(map(int, iv.split())): quality(sc)
             for iv, sc, slash, root, _ in VOCAB if root == "C" and not slash}
    by_size = collections.defaultdict(list)
    for iv, sc, slash, root, _ in VOCAB:
        if root == "C" and not slash:
            by_size[len(iv.split())].append(f"{iv:10} {quality(sc)}")
    for size in sorted(by_size):
        print(f"{size}-note shapes Scaler names from the bass: {len(by_size[size])}")
        for line in by_size[size]:
            print("   ", line)
    print("\nRefused (named from another root, with a slash):")
    for iv, sc, slash, root, _ in VOCAB:
        if slash:
            r = PC[root.split("/")[0]]
            pcs = set(map(int, iv.split()))
            rot = frozenset((p - r) % 12 for p in pcs)
            print(f"    {iv:10} {sc:28} same shape from its bass: {named.get(rot, '-')}")
    print("\nNamed '?':", ", ".join(iv for iv, _, _, root, _ in VOCAB if root is None))
    agree = sum(1 for iv, sc, s, root, pro in VOCAB
                if root and pro_root(pro) == PC[root.split("/")[0]])
    total = sum(1 for row in VOCAB if row[3])
    print(f"\nScaleView Pro names Scaler's root on {agree} of the {total} chords Scaler names")


if __name__ == "__main__":
    main()
