--[[ Names the same chords with ScaleView Pro and ScaleView Pattern side by
     side, so the two can be judged against a third opinion - Scaler, or your
     ear. Reads MIDI note numbers on stdin, one chord per line, and writes
     notes, Pro's name, Pattern's name, and whether they agree.

       printf '60 64 67 69\n' | lua5.4 tools/compare_engines.lua
       lua5.4 tools/compare_engines.lua "Gb Major" < chords.txt

     An argument selects a scale in both first. With --differ only the
     disagreements are printed, which is usually what you want.
]]
local SCALE, ONLY_DIFF
for i = 1, #arg do
  if arg[i] == "--differ" then ONLY_DIFF = true else SCALE = arg[i] end
end

local HERE = (arg[0] or ""):match("^(.*)[/\\]") or "."
local RUNNER = HERE .. "/runner.lua"

local chords = {}
for line in io.lines() do
  if line:match("%d") then chords[#chords + 1] = line end
end

local function nameWith(script)
  local tmp = os.tmpname()
  local f = assert(io.open(tmp, "w"))
  f:write(table.concat(chords, "\n"), "\n")
  f:close()
  local cmd = string.format('lua5.4 %q %q %s < %q',
                            RUNNER, HERE .. "/../reascripts/" .. script,
                            SCALE and string.format("%q", SCALE) or "", tmp)
  local pipe = assert(io.popen(cmd))
  local out = {}
  for line in pipe:lines() do out[#out + 1] = line:match("\t(.*)$") end
  pipe:close()
  os.remove(tmp)
  return out
end

local pro     = nameWith("ScaleView Pro.lua")
local pattern = nameWith("ScaleView Pattern.lua")

local agree = 0
print(string.format("%-24s %-22s %-22s", "notes", "Pro", "Pattern"))
print(string.rep("-", 70))
for i, notes in ipairs(chords) do
  local a, b = pro[i] or "?", pattern[i] or "?"
  local same = (a == b)
  if same then agree = agree + 1 end
  if not (ONLY_DIFF and same) then
    print(string.format("%-24s %-22s %-22s%s", notes, a, b, same and "" or "  <>"))
  end
end
print(string.format("\n%d chords, %d identical, %d differ%s",
      #chords, agree, #chords - agree, SCALE and (" (in " .. SCALE .. ")") or ""))
