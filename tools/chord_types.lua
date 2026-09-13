--[[ Dumps the closed half of Pro's chord vocabulary: every third/fifth/seventh
     combination `core()` can reach, and the symbol `coreName()` prints for it.

     It loads the shipped script under the test suite's mocks and asks the real
     functions, so it cannot drift from what REAPER shows. Everything ABOVE the
     core - sixths, ninths, elevenths, thirteenths - is described rather than
     matched and so has no list; see tools/CHORD_TYPES.md.

       lua5.4 tools/chord_types.lua "reascripts/ScaleView Pro.lua"
]]
local SCRIPT = arg[1] or "reascripts/ScaleView Pro.lua"

local deferred
reaper = {
  SetExtState = function() end, GetExtState = function() return "" end,
  defer = function(f) deferred = f end, atexit = function() end,
  time_precise = function() return 0 end,
  EnumProjects = function() return nil end,
  SetProjExtState = function() return 1 end,
  GetProjExtState = function() return 0, "" end,
  set_action_options = function() end,
  MIDI_GetRecentInputEvent = function() return 0, "", 0, 0, -1, 0 end,
}
gfx = {
  w = 200, h = 100, x = 0, y = 0, mouse_x = 0, mouse_y = 0, mouse_cap = 0,
  init = function() end, quit = function() end, update = function() end,
  rect = function() end, setfont = function() end,
  measurestr = function(s) return #s * 6, 12 end,
  set = function() end, circle = function() end, drawstr = function() end,
  dock = function(_, a) if a then return 0, 0, 0, 200, 100 end return 0 end,
  getchar = function() return 0 end, showmenu = function() return 0 end,
}

--  The script keeps core(), coreName() and rankOf() local, so read the source
--  and append one line that hands them out. File-scope locals are visible to
--  code added at the end of the same chunk.
local src = assert(io.open(SCRIPT)):read("a")
assert(load(src .. "\n_G.__SV = {core=core, coreName=coreName, rankOf=rankOf}\n",
            "@" .. SCRIPT))()
local SV = assert(_G.__SV, "could not reach the engine's internals")

local SEMI = {maj = 4, min = 3, sus4 = 5, sus2 = 2,
              P = 7, b = 6, ["#"] = 8, b7 = 10, maj7 = 11, bb7 = 9}

--  Every reachable quality, found by running core() over every possible set of
--  intervals rather than by listing what we think it can do.
local best = {}
for mask = 0, 4095 do
  local has = {[0] = true}
  for i = 1, 11 do if (mask >> i) & 1 == 1 then has[i] = true end end

  local third, fifth, seventh = SV.core(has)
  local sym  = SV.coreName(third, fifth, seventh)
  local rank = SV.rankOf(third, fifth, seventh)

  --  A missing fifth is silent, so it prints the same symbol; a missing third
  --  is said out loud, so it is a different one. analyse() appends that, not
  --  coreName(), so do the same here.
  local shown = sym
  if third == "none" then shown = (sym == "" and "5" or sym .. "(no3)") end

  --  Keep the most complete spelling of each symbol.
  local score = (third ~= "none" and 2 or 0) + (fifth ~= "none" and 1 or 0)
  local cur = best[shown]
  if not cur or score > cur.score or (score == cur.score and rank < cur.rank) then
    best[shown] = {third = third, fifth = fifth, seventh = seventh,
                   rank = rank, sym = shown, score = score}
  end
end

local rows = {}
for _, v in pairs(best) do rows[#rows + 1] = v end
table.sort(rows, function(a, b)
  if a.rank ~= b.rank then return a.rank < b.rank end
  return a.sym < b.sym
end)

print(string.format("%-14s  %-22s  %s", "symbol", "semitones from root", "rank"))
print(string.rep("-", 52))
for _, r in ipairs(rows) do
  local iv = {"0"}
  for _, part in ipairs({r.third, r.fifth, r.seventh}) do
    if part ~= "none" then iv[#iv + 1] = tostring(SEMI[part]) end
  end
  print(string.format("%-14s  %-22s  %d",
        r.sym == "" and "(major)" or r.sym, table.concat(iv, " "), r.rank))
end
print(string.format("\n%d core qualities.", #rows))
