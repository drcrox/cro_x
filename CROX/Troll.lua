-- cro/x — troll voice (carried over from the first alpha, v0.30; unchanged rules)
-- Trolls in WoW speak with an accent. For a troll character, voice lines (say / yell) are turned into troll
-- speech: a hand-written version from CROX_TROLL_FIX if the line has one, otherwise the converter below.
-- Emotes stay plain English. Placeholders like [target] are never touched. Your own lines stay exactly as
-- typed unless you mark them Troll voice.
--
-- Rules (approved 2026-11-14), taken from Blizzard's own troll dialogue (Darkspear, Vol'jin, Zul'jin, NPCs):
--  * Grammar first: is / are / am -> be ("Dat be da plan"); you're -> ya ("Ya leakin'"); questions drop
--    do / are / is ("What ya want?", "Dat all ya got?!"); isn't / aren't -> ain't; going to -> gonna,
--    want to -> wanna, have / has / got to -> gotta.
--  * Spelling: the -> da before a consonant sound, de before a vowel ("da Horde", "de elves");
--    this / that / these / those / them / they / there / then / than -> dis / dat / dese / dose / dem / dey /
--    dere / den / dan; with -> wit; to -> ta; about -> 'bout; and -> an' / of -> o' before a consonant
--    (kept before a vowel); -ing -> -in'; mother / brother -> mudder / bruddah; you / your -> ya.
--    Kept as is: think, thing, their.
--  * "mon" only on lines said (never yelled), about 1 in 5, fixed per line.
--  * Verbs losing their -s ("Corruption end here!") only in hand fixes.

-- Hand fixes: original line (exactly as in the library) = troll version. Filled from the audit checklists.
CROX_TROLL_FIX = {
  ["The Light finds you wanting!"] = "Da Light find ya wantin'!",
  ["Corruption ends here!"] = "Corruption end here!",
  ["Here I go killing again!"] = "Oh loa, here I go killin' again!",
}

-- one word -> troll word (lowercase keys). Articles, and, of are decided later by the next word's sound.
local WORDS = {
  ["this"] = "dis", ["that"] = "dat", ["these"] = "dese", ["those"] = "dose",
  ["them"] = "dem", ["they"] = "dey", ["there"] = "dere", ["then"] = "den", ["than"] = "dan",
  ["themselves"] = "demselves", ["themself"] = "demself",
  ["with"] = "wit", ["without"] = "widout", ["to"] = "ta", ["about"] = "'bout",
  ["mother"] = "mudder", ["brother"] = "bruddah", ["brothers"] = "bruddahs",
  ["nothing"] = "nuttin'", ["something"] = "somethin'", ["everything"] = "everytin'", ["anything"] = "anytin'",
  ["man"] = "mon", ["yes"] = "ya", ["yeah"] = "ya",
  ["you"] = "ya", ["your"] = "ya", ["yourself"] = "yaself", ["yourselves"] = "yaselves",
  ["is"] = "be", ["are"] = "be", ["am"] = "be",
  ["isn't"] = "ain't", ["aren't"] = "ain't",
  -- contractions
  ["you're"] = "ya", ["you've"] = "ya", ["you'll"] = "ya gonna", ["you'd"] = "ya'd",
  ["i'm"] = "I be", ["we're"] = "we be", ["they're"] = "dey be", ["it's"] = "it be", ["that's"] = "dat be",
  ["there's"] = "dere be", ["here's"] = "here be", ["what's"] = "what be", ["who's"] = "who be",
  ["he's"] = "he be", ["she's"] = "she be", ["where's"] = "where be",
  ["that'll"] = "dat'll", ["they'll"] = "dey gonna", ["there'll"] = "dere'll", ["they've"] = "dey",
}

-- two-word phrases (checked before single words)
local PHRASES = {
  ["you are"] = "ya", ["you will"] = "ya gonna",
  ["is not"] = "ain't", ["are not"] = "ain't", ["am not"] = "ain't",
  ["want to"] = "wanna", ["wants to"] = "wanna", ["have to"] = "gotta", ["has to"] = "gotta", ["got to"] = "gotta",
}

local KEEP_ING = {
  bring = true, string = true, spring = true, sling = true, swing = true, sting = true, cling = true,
  fling = true, king = true, ring = true, wing = true, sing = true, ding = true, ping = true, wring = true,
  during = true, ceiling = true, thing = true, things = true,
}
local AUX = {is = true, are = true, ["do"] = true, does = true, did = true}
local SUBJ = {you = true, we = true, they = true, it = true, that = true, this = true, these = true, those = true,
  he = true, she = true, i = true, the = true, your = true, my = true, our = true, a = true, an = true}
local PRON_TAG = {it = true, you = true, they = true, we = true, he = true, she = true, i = true}
local WH = {what = true, where = true, why = true, how = true, who = true, when = true}
local DET = {the = true, a = true, an = true, my = true, your = true, our = true, his = true, her = true,
  their = true, this = true, that = true, these = true, those = true, ["da"] = true, ["de"] = true}

local function matchCase(orig, rep)
  if #orig > 1 and orig == orig:upper() and orig:match("%a") then return rep:upper() end
  if orig:sub(1, 1):match("%u") then return rep:sub(1, 1):upper() .. rep:sub(2) end
  return rep
end

local function ing(w)
  local lw = w:lower()
  local stem = lw:match("^(%a+)ing$")
  if stem and #lw >= 5 and stem:match("[aeiouy]") and not KEEP_ING[lw] then
    return matchCase(w, lw:sub(1, #lw - 3) .. "in'")
  end
  return w
end

-- does this word start with a vowel sound? (hour/honor yes; one/use/unit no)
local function vowelSound(w)
  if not w then return false end
  local lw = w:lower()
  if lw:match("^hour") or lw:match("^honou?r") or lw:match("^honest") or lw:match("^heir") then return true end
  if lw:match("^one") or lw:match("^once") or lw:match("^use") or lw:match("^uni") or lw:match("^eu") then return false end
  return lw:match("^[aeiou]") ~= nil
end

-- split text into tokens: words, placeholders ([target]) and everything else
local function tokenize(s)
  local t, pos = {}, 1
  while pos <= #s do
    local a, b = s:find("%b[]", pos)
    local w1, w2 = s:find("[%a][%a']*", pos)
    if a and (not w1 or a < w1) then
      if a > pos then t[#t + 1] = {s = s:sub(pos, a - 1)} end
      t[#t + 1] = {s = s:sub(a, b), ph = true}
      pos = b + 1
    elseif w1 then
      if w1 > pos then t[#t + 1] = {s = s:sub(pos, w1 - 1)} end
      local w = s:sub(w1, w2)
      local core, q = w:match("^(.-)('*)$")             -- a trailing quote mark isn't part of the word...
      if core:lower():match("in$") and q ~= "" then core, q = w, "" end   -- ...unless it's goin'
      t[#t + 1] = {s = core, w = core:lower()}
      if q ~= "" then t[#t + 1] = {s = q} end
      pos = w2 + 1
    else
      t[#t + 1] = {s = s:sub(pos)}
      pos = #s + 1
    end
  end
  return t
end

local function nextWord(t, i)
  for j = i + 1, #t do
    if t[j].w then return j end
    if t[j].ph then return nil end
    if t[j].s:find("[%.!%?;:]") then return nil end
  end
end
local function sentenceStart(t, i)
  for j = i - 1, 1, -1 do
    if t[j].w or t[j].ph then return false end
    if t[j].s:find("[%.!%?]") then return true end
  end
  return true
end
local function isQuestion(t, i)
  for j = i + 1, #t do
    if not t[j].w and not t[j].ph then
      if t[j].s:find("%?") then return true end
      if t[j].s:find("[%.!]") then return false end
    end
  end
  return false
end

local function drop(t, i)      -- remove word i (and the space after it), passing its capital on
  local cap = t[i].s:match("^%u")
  table.remove(t, i)
  if t[i] and not t[i].w and t[i].s:match("^%s+$") then table.remove(t, i) end
  if cap then
    local j = nextWord(t, i - 1) or i
    if t[j] and t[j].w then t[j].cap = true end
  end
end

local function convert(s)
  local t = tokenize(s)
  -- 1) questions drop their helper verb: "Is that all...?" -> "That all...?", "What do you want?" -> "What you want?"
  local i = 1
  while i <= #t do
    local tk = t[i]
    if tk.w and AUX[tk.w] and isQuestion(t, i) then
      local n = nextWord(t, i)
      local prev
      for j = i - 1, 1, -1 do if t[j].w then prev = t[j].w break end if t[j].ph or t[j].s:find("[%.!%?]") then break end end
      if n and SUBJ[t[n].w] and (sentenceStart(t, i) or (prev and WH[prev])) then drop(t, i) i = i - 1 end
    end
    i = i + 1
  end
  -- 2) phrases and "going to <verb>" -> gonna
  i = 1
  while i <= #t do
    local tk = t[i]
    local n = tk.w and nextWord(t, i)
    if n and n == i + 2 and t[i + 1].s:match("^%s+$") then
      local key = tk.w .. " " .. t[n].w
      local rep = PHRASES[key]
      if tk.w == "going" and t[n].w == "to" then
        local after = nextWord(t, n)
        if after and not DET[t[after].w] then rep = "gonna" end
      end
      if rep then
        t[i] = {s = matchCase(tk.s, rep), w = "\0"}
        table.remove(t, i + 1) table.remove(t, i + 1)
      end
    end
    i = i + 1
  end
  -- 3) words; the / and / of by the sound of the next word
  for k, tk in ipairs(t) do
    if tk.w and tk.w ~= "\0" then
      local lw, out = tk.w, nil
      local n = nextWord(t, k)
      local nw = n and t[n].s
      if lw == "the" then out = vowelSound(nw) and "de" or "da"
      elseif lw == "and" then out = (nw and not vowelSound(nw)) and "an'" or nil
      elseif lw == "of" then out = (nw and not vowelSound(nw)) and "o'" or nil
      elseif (lw == "is" or lw == "are") and n and PRON_TAG[t[n].w] and not nextWord(t, n) and isQuestion(t, n) then
        out = nil                                            -- tag question stays: "..., is it?"
      else out = WORDS[lw] end
      if out then tk.s = matchCase(tk.s, out) else tk.s = ing(tk.s) end
      if tk.cap then tk.s = tk.s:sub(1, 1):upper() .. tk.s:sub(2) end
    elseif tk.cap then
      tk.s = tk.s:sub(1, 1):upper() .. tk.s:sub(2)
    end
  end
  local out = {}
  for _, tk in ipairs(t) do out[#out + 1] = tk.s end
  local r = table.concat(out)
  r = r:gsub("%f[%a]([Bb])e not%f[%A]", function(b) return b == "B" and "Ain't" or "ain't" end)
  r = r:gsub("(%a+) be gonna", "%1 gonna"):gsub("%f[%a]be still%f[%A]", "still be")   -- "We gonna", "I still be"
  return r
end

-- one word, for pronoun placeholders filled later ("they" -> "dey")
function CROX_TrollWord(w) return WORDS[w:lower()] and matchCase(w, WORDS[w:lower()]) or w end

-- ", mon" on about one said line in five (fixed per line); never on a yell
local function addMon(orig, s)
  if s:lower():find("%f[%a]mon%f[%A]") or s == s:upper() then return s end
  local h = 0
  for i = 1, #orig do h = (h * 31 + orig:byte(i)) % 1000003 end
  if h % 5 ~= 0 then return s end
  local body, punct = s:match("^(.-)([!%?%.]+)$")
  if not body or body == "" or body:match("[%]%)\"]$") or body:match(",$") then return s end
  return body .. ", mon" .. punct
end

-- the whole line: hand fix if there is one, otherwise the converter. yell = true when it will be yelled.
function CROX_Trollify(line, yell)
  if not line then return line end
  local s = CROX_TROLL_FIX[line] or convert(line)
  if not yell then s = addMon(line, s) end
  return s
end
