-- cro/x — the window (second alpha). Blizzard's own panel, tabs, checkboxes, dropdowns, sliders, scroll bars,
-- fonts, tooltips and sounds. Horde tab: Character, Options, My phrases, Lines. Alliance tab: LOK'TAR OGAR.
-- The layout rebuilds whenever the window changes size; text scales with the window (within readable limits),
-- times the player's text-scale setting.

local ADDON, ns = ...
local W = ns.W
local p = ns.p

local BASE_W, BASE_H = 780, 720
local LIST_W = 140
local main, body, sections, current
local sectionButtons = {}

local function cdb() return ns.cdb end

------------------------------------------------------------------------
-- Names for things
------------------------------------------------------------------------
local ARCH_LIST = {
  {"opener", "Opener"}, {"filler", "Filler"}, {"heavy", "Heavy hitter"}, {"area", "Area"}, {"upkeep", "Upkeep"},
  {"reactive", "Reactive"}, {"finisher", "Finisher"}, {"interrupt", "Interrupt"}, {"lockdown", "Lockdown"},
  {"snare", "Snare"}, {"weaken", "Weaken"}, {"taunt", "Taunt"}, {"guard", "Guard"}, {"laststand", "Last stand"},
  {"escape", "Escape"}, {"sneak", "Sneak"}, {"heal", "Heal"}, {"ward", "Ward and renew"}, {"groupheal", "Group heal"},
  {"clutch", "Clutch save"}, {"cleanse", "Cleanse"}, {"raise", "Raise"}, {"rally", "Rally"}, {"powerup", "Power-up"},
  {"bless", "Bless an ally"}, {"summon", "Summon (warlock)"},
}
local MOMENT_LIST = {
  {"kill", "After a kill"},
  {"debuff:poisoned", "Poisoned"}, {"debuff:cursed", "Cursed"}, {"debuff:diseased", "Diseased"},
  {"debuff:magic", "Magic debuff"}, {"debuff:physical", "Physical debuff"}, {"debuff:cc", "Crowd control"},
  {"item:potion", "Any potion"}, {"item:healing", "Healing potion"}, {"item:mana", "Mana potion"},
  {"item:rage", "Rage potion"}, {"item:bandage", "Bandage"}, {"item:food", "Food"}, {"item:drink", "Drink"},
  {"item:elixir", "Elixir"}, {"item:flask", "Flask"}, {"item:scroll", "Scroll"}, {"item:explosives", "Explosive"},
}
local EXTRA_LIST = {
  {"x:cr", "Call and response"}, {"x:dmg", "Damage types"}, {"x:profemote", "Profession emotes"},
}
local function momentLabel(key)
  for _, l in ipairs({ARCH_LIST, MOMENT_LIST, EXTRA_LIST}) do
    for _, it in ipairs(l) do if it[1] == key then return it[2] end end
  end
  return key
end
ns.momentLabel = momentLabel

local function cap(s) return s and (s:sub(1, 1):upper() .. s:sub(2)) or "" end

------------------------------------------------------------------------
-- Alliance screen
------------------------------------------------------------------------
-- The fixed Blizzard-poster background used by the Alliance screen and the Horde splash (see Credits).
-- The whole picture is always shown: it is fitted inside the frame at its own
-- 4:3 shape (never cropped or stretched), and any spare room stays dark. The image sits in the top three
-- quarters of a 1024 square texture. onSize(w, h) lets a screen resize its own parts when the frame changes.
-- The Horde army poster behind the Setup page and the Alliance screen. The picture is portrait (about 3:4);
-- it fills the frame and the overflow is cropped evenly at the sides or a little more from the bottom.
local POSTER_ASPECT, POSTER_U = 1974 / 2576, 785 / 1024     -- width / height of the art, and how much of the texture it fills
local function posterBG(f, onSize)
  local poster = f:CreateTexture(nil, "BACKGROUND", nil, -1)
  poster:SetTexture("Interface\\AddOns\\CROX\\Art\\HordeBG")
  poster:SetAllPoints()
  local function fit()
    local w, h = f:GetWidth(), f:GetHeight()
    if not w or not h or w < 1 or h < 1 then return end
    if w / h >= POSTER_ASPECT then
      local vf = math.min(1, h * POSTER_ASPECT / w)         -- the part of the height that shows
      local v0 = (1 - vf) * 0.35
      poster:SetTexCoord(0, POSTER_U, v0, v0 + vf)
    else
      local uf = math.min(1, (w / h) / POSTER_ASPECT)       -- the part of the width that shows
      local u0 = (1 - uf) / 2 * POSTER_U
      poster:SetTexCoord(u0, u0 + uf * POSTER_U, 0, 1)
    end
    if onSize then onSize(w, h) end
  end
  f:SetScript("OnSizeChanged", fit)
  fit()
  return poster
end

local function allianceArt(parent, withCheckbox)
  local f = CreateFrame("Frame", nil, parent)
  local bg = f:CreateTexture(nil, "BACKGROUND", nil, -2)
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.95)
  -- the Horde battleground timer logo, locked in and enlarged behind the words
  local logo = f:CreateTexture(nil, "ARTWORK")
  W.crest(logo, 2)
  logo:SetPoint("CENTER", 0, 4)
  logo:SetAlpha(0.7)
  local function resize(w, h) local d = math.min(w, h) * 0.8 logo:SetSize(d, d) end
  local poster = posterBG(f, resize)
  resize(f:GetWidth() or 400, f:GetHeight() or 300)
  local title = f:CreateFontString(nil, "OVERLAY")
  if not pcall(title.SetFont, title, "Fonts\\MORPHEUS.TTF", 46, "THICKOUTLINE") then title:SetFontObject("GameFontNormalHuge") end
  title:SetTextColor(0.85, 0.08, 0.05)
  title:SetText("LOK'TAR OGAR")
  title:SetPoint("CENTER", 0, 18)
  local sub = f:CreateFontString(nil, "OVERLAY")
  if not pcall(sub.SetFont, sub, "Fonts\\MORPHEUS.TTF", 20, "THICKOUTLINE") then sub:SetFontObject("GameFontNormalLarge") end
  sub:SetTextColor(0.96, 0.92, 0.82)
  sub:SetText("You have chosen your faction poorly.")
  sub:SetPoint("TOP", title, "BOTTOM", 0, -8)
  f.poster, f.logo, f.title, f.sub = poster, logo, title, sub
  if withCheckbox then
    local c = W.check(f, "Disable addon and reroll Horde", function(_, on)
      if on then
        cdb().alliance.disabled = true
        cdb().on = false
        p("off for this character. For the Horde! Type /x and untick the box to bring it back.")
        parent:Hide()
      else
        cdb().alliance.disabled = false
        cdb().on = true
        p("back on for this character. The screen will show at login.")
      end
    end)
    c:SetPoint("BOTTOM", -100, 20)
    f.check = c
  end
  return f
end

local alliancePanel
function ns.showAlliance()
  if not alliancePanel then
    alliancePanel = W.panel("CROX2AllianceFrame", "cro/x", 520, 420)
    local art = allianceArt(alliancePanel, true)
    art:SetPoint("TOPLEFT", 8, -26)
    art:SetPoint("BOTTOMRIGHT", -8, 8)
    alliancePanel.art = art
  end
  alliancePanel.art.check:SetChecked(cdb().alliance.disabled)
  alliancePanel:Show()
end

------------------------------------------------------------------------
-- Section: Character
------------------------------------------------------------------------
local function specText()
  local parts = {}
  local names = {"early", "middle", "deep"}
  for tree, band in pairs(ns.profile.spec or {}) do
    local got = {}
    for b = 1, band do got[#got + 1] = names[b] end
    parts[#parts + 1] = tree .. ": " .. (#got > 0 and table.concat(got, ", ") or "none yet")
  end
  table.sort(parts)
  return #parts > 0 and table.concat(parts, "  ·  ") or "No talents spent yet."
end

local function profText()
  local out = {}
  local names = {first_aid = "First Aid"}
  for k in pairs(ns.profile.profs or {}) do out[#out + 1] = names[k] or cap(k) end
  table.sort(out)
  return #out > 0 and table.concat(out, ", ") or "no professions"
end

local function choiceItems(kind)
  if kind == "temperament" then
    local t = {} for _, v in ipairs(ns.TEMPERAMENTS) do t[#t + 1] = {v, cap(v)} end return t
  elseif kind == "upbringing" then
    local t = {} for _, v in ipairs(ns.UPBRINGINGS) do t[#t + 1] = {v, cap(v)} end return t
  elseif kind == "drive" then
    local t = {} for _, v in ipairs(ns.DRIVES) do t[#t + 1] = {v, cap(v)} end return t
  elseif kind == "homeland" then
    local t = {}
    for _, h in ipairs(ns.homelands()) do t[#t + 1] = {h[1], h[2]} end
    if #t == 0 then t[1] = {nil, "None for this race yet"} end
    return t
  elseif kind == "pronouns" then
    return {{"he", "he / him"}, {"she", "she / her"}, {"they", "they / them"}}
  end
end
ns.choiceItems = choiceItems
local CHOICES = {{"temperament", "Temperament"}, {"homeland", "Homeland"}, {"upbringing", "Origin"},
  {"drive", "Motivation"}, {"pronouns", "Pronouns"}}
ns.CHOICES = CHOICES

local SPLASH_HINTS = {pronouns = "Used in emotes"}

-- The first section, and the first thing you see: who the character is and how they speak. It replaces the old
-- Character tab and the splash page. The poster sits behind it, whole, fitted inside the area.
local function buildHome(parent)
  local s = CreateFrame("Frame", nil, parent)
  s.fill = true       -- the poster behind every page is drawn once, behind the whole page (see createMain)
  -- a frame around the page, so it is clear where the Setup screen begins and ends
  do
    local function edge(a1, a2, w, h)
      local t = s:CreateTexture(nil, "OVERLAY", nil, 7)
      t:SetColorTexture(0.72, 0.56, 0.16, 1)
      t:SetPoint(a1, s, a1, 0, 0)
      t:SetPoint(a2, s, a2, 0, 0)
      if w then t:SetWidth(w) else t:SetHeight(h) end
      return t
    end
    s.edges = {edge("TOPLEFT", "TOPRIGHT", nil, 2), edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2),
      edge("TOPLEFT", "BOTTOMLEFT", 2), edge("TOPRIGHT", "BOTTOMRIGHT", 2)}
  end

  -- the title card
  local card = CreateFrame("Frame", nil, s)
  card:SetPoint("TOPLEFT", 4, -6)
  card:SetPoint("TOPRIGHT", -4, -6)
  card:SetHeight(54)
  local ct = card:CreateTexture(nil, "BACKGROUND")
  ct:SetAllPoints()
  ct:SetColorTexture(0, 0, 0, 0.5)
  for _, edge in ipairs({"TOP", "BOTTOM"}) do
    local ln = card:CreateTexture(nil, "ARTWORK")
    ln:SetPoint(edge .. "LEFT", 20, 0) ln:SetPoint(edge .. "RIGHT", -20, 0) ln:SetHeight(2)
    ln:SetColorTexture(0.78, 0.6, 0.15, 0.9)
  end
  local title = card:CreateFontString(nil, "OVERLAY")
  if not pcall(title.SetFont, title, "Fonts\\MORPHEUS.TTF", 34, "THICKOUTLINE") then title:SetFontObject("GameFontNormalHuge") end
  title:SetTextColor(1, 0.82, 0)
  title:SetText("Combat Roleplay Options")
  title:SetPoint("CENTER", 0, 0)
  s.title = title
  -- the character's name, in a box like the other headers, in the class colour
  local whoBox = CreateFrame("Frame", nil, s)
  whoBox:SetPoint("TOP", card, "BOTTOM", 0, -6)
  whoBox:SetPoint("LEFT", s, "LEFT", 8, 0)
  whoBox:SetPoint("RIGHT", s, "RIGHT", -8, 0)
  whoBox:SetHeight(34)
  local wbg = whoBox:CreateTexture(nil, "BACKGROUND")
  wbg:SetAllPoints()
  wbg:SetColorTexture(0, 0, 0, 0.62)
  for _, edge in ipairs({"TOP", "BOTTOM"}) do
    local ln = whoBox:CreateTexture(nil, "ARTWORK")
    ln:SetPoint(edge .. "LEFT", 20, 0) ln:SetPoint(edge .. "RIGHT", -20, 0) ln:SetHeight(1)
    ln:SetColorTexture(0.78, 0.6, 0.15, 0.9)
  end
  s.whoBox = whoBox
  s.who = W.text(whoBox, "", "GameFontNormalLarge")
  s.who:SetPoint("CENTER", 0, 0)

  local function dark(f)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(0, 0, 0, 0.62)
  end

  -- who are you: the five choices, each with a line of flavor, then an example line
  local plate = CreateFrame("Frame", nil, s)
  plate:SetPoint("TOP", whoBox, "BOTTOM", 0, -8)
  plate:SetPoint("LEFT", s, "LEFT", 8, 0)
  plate:SetPoint("RIGHT", s, "RIGHT", -8, 0)
  local ROW = 54          -- a choice's row: the dropdown, with its line of flavor text underneath
  plate:SetHeight(40 + #CHOICES * ROW + 44)
  dark(plate)
  local head = W.heading(plate, "Who are you?")
  head:SetPoint("TOP", plate, "TOP", 0, -10)
  local grp = CreateFrame("Frame", nil, plate)
  grp:SetSize(560, #CHOICES * ROW)
  grp:SetPoint("TOP", plate, "TOP", 0, -34)
  s.grp = grp
  s.dds, s.hints = {}, {}
  for i, ch in ipairs(CHOICES) do
    local kind = ch[1]
    local y = -(i - 1) * ROW
    local label = W.text(grp, ch[2], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y - 6)
    local dd = W.dropdown(grp, 170, function() return choiceItems(kind) end, function() return cdb()[kind] end,
      function(v) cdb()[kind] = v s:refreshChoices(kind) end)
    dd:SetPoint("TOPLEFT", 100, y + 2)
    local hint = W.text(grp, "", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 20, 2)
    hint:SetPoint("RIGHT", grp, "RIGHT", 0, 0)
    hint:SetHeight(24)
    hint:SetWordWrap(true)
    hint:SetJustifyV("TOP")
    hint:SetJustifyH("LEFT")
    s.dds[kind] = dd
    s.hints[kind] = hint
  end
  local ex = W.text(plate, "", "GameFontHighlight")
  ex:SetPoint("TOPLEFT", grp, "BOTTOMLEFT", 0, -8)
  ex:SetPoint("RIGHT", grp, "RIGHT", -108, 0)
  ex:SetHeight(32)
  ex:SetWordWrap(true)
  ex:SetJustifyV("TOP")
  s.example = ex
  local another = W.button(plate, "Another One", 100, function() s:rollExample() end)
  another:SetPoint("TOPRIGHT", grp, "BOTTOMRIGHT", 0, -6)
  W.tooltip(another, "Another example", "Another line in your character's voice. Only you see this.")
  function s:rollExample(kind)
    local pick = kind
    if not pick or pick == "pronouns" then
      local kinds = {"temperament", "homeland", "upbringing", "drive"}
      pick = kinds[math.random(#kinds)]
    end
    local line = ns.sample(pick)
    self.example:SetText(line and ("|cffffd100Example:|r \"" .. line .. "\"") or "")
  end

  -- how do you speak: pace, call and response, content, sounds
  local plate2 = CreateFrame("Frame", nil, s)
  plate2:SetPoint("TOP", plate, "BOTTOM", 0, -8)
  plate2:SetPoint("LEFT", s, "LEFT", 8, 0)
  plate2:SetPoint("RIGHT", s, "RIGHT", -8, 0)
  plate2:SetHeight(300)
  dark(plate2)
  local head2 = W.heading(plate2, "How do you speak?")
  head2:SetPoint("TOP", plate2, "TOP", 0, -10)
  local grp2 = CreateFrame("Frame", nil, plate2)
  grp2:SetSize(440, 200)
  grp2:SetPoint("TOP", plate2, "TOP", 0, -34)
  local CR_LEVELS = function() return {{1, "Rarely"}, {2, "Sometimes"}, {3, "Often"}, {4, "Always"}} end
  local function speakRow(i, text, hint, items, get, set, tip)
    local label = W.text(grp2, text, "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, -(i - 1) * 34 - 6)
    local dd = W.dropdown(grp2, 170, items, get, set)
    dd:SetPoint("TOPLEFT", 100, -(i - 1) * 34 + 2)
    local h = W.text(grp2, hint, "GameFontDisableSmall")
    h:SetPoint("LEFT", dd, "RIGHT", -6, 2)
    if tip then W.tooltip(label, text, tip) end
    return dd, label, h
  end
  local chattyDD, _, chattyHint = speakRow(1, "On your own", "", function() return ns.chattyItems(false) end, function() return cdb().chatty end,
    function(v) cdb().chatty = v s:refreshChoices() end,
    "How many lines a minute to expect in a fight when you are on your own. These are rough: the real rate depends on how fast you press.")
  s.chattyDD, s.chattyHint = chattyDD, chattyHint
  local raidDD, _, raidHint = speakRow(2, "In a group", "", function() return ns.chattyItems(true) end, function() return cdb().raidChatty or 3 end,
    function(v) cdb().raidChatty = v s:refreshChoices() end,
    "How talkative you are whenever you are in a party or a raid. The group shares one pace, set by its loudest member. Windbag and Deafening are only here, and they can fill other people's chat, so please be considerate.")
  s.raidDD, s.raidHint = raidDD, raidHint
  local askL, askH
  s.askDD, askL, askH = speakRow(3, "Ask for help", "", CR_LEVELS, function() return cdb().crAsk or 4 end,
    function(v) cdb().crAsk = v s:refreshChoices() end,
    "How often your character calls for help (a debuff, low health, an enemy on you) when a cro/x partymate could answer. Always means every time it fits.")
  local giveL, giveH
  s.giveDD, giveL, giveH = speakRow(4, "Answer a call", "", CR_LEVELS, function() return cdb().crGive or 4 end,
    function(v) cdb().crGive = v s:refreshChoices() end,
    "How often your character says something when they answer a call. They still help either way; Rarely just means they usually do it quietly.")
  s.askHint, s.giveHint = askH, giveH
  local trollDD, trollL, trollH = speakRow(5, "Troll voice", "Accent or plain",
    function() return {{"accent", "Accent"}, {"plain", "Plain"}} end, function() return cdb().troll end,
    function(v) cdb().troll = v s:refreshChoices() end,
    "Trolls speak with the accent from the first alpha's converter. Emotes and your own lines stay as written.")
  s.trollDD, s.trollL, s.trollH = trollDD, trollL, trollH
  local SWITCHES = {
    {"emotes", "Emotes", "Emotes stay a rare accent either way."},
    {"yell", "Allow /yell", "With this off, everything goes to /say, even calls to faraway allies. With it on, yells are still saved for big moments: low health, a boss or elite, or a long fight, with a rest between yells that is shorter at louder paces, and only one yell at a time in a party."},
    {"cr", "Call and response", "Your character calls for help and answers other cro/x users in your group."},
    {"turns", "Take turns with the party", "cro/x users in a party take turns instead of talking over each other. Turning it off only affects you."},
    {"filter", "Profanity filter", "Real-world swear words are swapped for clean versions. Your own lines are never changed."},
    {"sound", "Window sounds", "The small clicks and chimes when cro/x windows open and close."},
  }
  s.switches = {}
  for i, sw in ipairs(SWITCHES) do
    local key = sw[1]
    local c = W.check(grp2, sw[2], function(_, on) cdb()[key] = on and true or false end)
    W.tooltip(c, sw[2], sw[3])
    s.switches[key] = c
    c._index = i
  end
  -- the troll row only exists for a troll; everything below moves up when it isn't there
  -- a note for the two loudest levels, so nobody picks them without thinking of the people around them
  local warn = W.text(grp2, "", "GameFontNormalSmall")
  warn:SetTextColor(1, 0.55, 0.2)
  warn:SetWordWrap(true)
  warn:SetJustifyH("LEFT")
  warn:SetJustifyV("TOP")
  warn:SetWidth(430)
  warn:SetHeight(54)
  s.paceWarn = warn
  local PACE_WARNING = "Please be considerate of how this addon could affect other people's game when you choose how often you speak. "
    .. "At this level your character talks a lot, and in a group everyone else's chat fills up with it."
  function s:layoutSpeak()
    local troll = ns.isTroll()
    trollDD:SetShown(troll) trollL:SetShown(troll) trollH:SetShown(troll)
    local top = (troll and 5 or 4) * 34 + 4
    for key, c in pairs(self.switches) do
      local i = c._index
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", ((i - 1) % 2) * 220, -top - math.floor((i - 1) / 2) * 26)
      c:SetChecked(cdb()[key] == true)
    end
    local gh = top + 3 * 26 + 4
    local loud = (cdb().raidChatty or 3) >= 6 or (cdb().chatty or 3) >= 6
    warn:ClearAllPoints()
    warn:SetPoint("TOPLEFT", 0, -gh - 2)
    warn:SetText(loud and PACE_WARNING or "")
    warn:SetShown(loud)
    if loud then gh = gh + 62 end
    grp2:SetHeight(gh)
    plate2:SetHeight(34 + gh + 10)
  end

  -- character tags: every tag there is, in tabs; a box marks the ones this character has
  local plate3 = CreateFrame("Frame", nil, s)
  plate3:SetPoint("TOP", plate2, "BOTTOM", 0, -8)
  plate3:SetPoint("LEFT", s, "LEFT", 8, 0)
  plate3:SetPoint("RIGHT", s, "RIGHT", -8, 0)
  plate3:SetHeight(140)
  dark(plate3)
  local head3 = W.heading(plate3, "Character tags")
  head3:SetPoint("TOP", plate3, "TOP", 0, -10)
  local TAG_TABS = {{"race", "Race"}, {"class", "Class"}, {"temperament", "Temperament"}, {"homeland", "Homeland"},
    {"upbringing", "Origin"}, {"drive", "Motivation"}, {"profs", "Professions"}, {"spec", "Spec"}}
  local CLASSES = {"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}
  local PROFS_ALL = {"alchemy", "blacksmithing", "cooking", "enchanting", "engineering", "first_aid", "fishing",
    "herbalism", "leatherworking", "mining", "skinning", "tailoring"}
  local HOME_ORDER = {"Orc", "Troll", "Tauren", "Scourge", "Skyborne"}
  local HOME_RACE = {Scourge = "Forsaken"}
  local function describe(kind, key) local d = CROX2_DESCRIBE and CROX2_DESCRIBE[kind] return d and d[key] end
  -- every tag in a tab: {key, label, own, tip}
  local function tagList(kind)
    local out, pf, c = {}, ns.profile or {}, cdb()
    if kind == "race" then
      for _, r in ipairs(ns.Sim and ns.Sim.RACES or {"Orc", "Tauren", "Troll", "Forsaken", "Skyborne"}) do
        out[#out + 1] = {r, r, pf.race == r}
      end
    elseif kind == "class" then
      for _, k in ipairs(CLASSES) do out[#out + 1] = {k, cap(k:lower()), pf.class == k} end
    elseif kind == "temperament" then
      for _, v in ipairs(ns.TEMPERAMENTS) do out[#out + 1] = {v, cap(v), c.temperament == v, describe("temperament", v)} end
    elseif kind == "upbringing" then
      for _, v in ipairs(ns.UPBRINGINGS) do out[#out + 1] = {v, cap(v), c.upbringing == v, describe("upbringing", v)} end
    elseif kind == "drive" then
      for _, v in ipairs(ns.DRIVES) do out[#out + 1] = {v, cap(v), c.drive == v, describe("drive", v)} end
    elseif kind == "homeland" then
      for _, rk in ipairs(HOME_ORDER) do
        for _, h in ipairs(CROX2_HOMELANDS and CROX2_HOMELANDS[rk] or {}) do
          out[#out + 1] = {h[1], h[2], c.homeland == h[1], (HOME_RACE[rk] or rk) .. " homeland"}
        end
      end
    elseif kind == "profs" then
      for _, k in ipairs(PROFS_ALL) do out[#out + 1] = {k, k == "first_aid" and "First Aid" or cap(k), pf.profs and pf.profs[k] and true or false} end
    elseif kind == "spec" then
      local depth = {"early", "middle", "deep"}
      for _, tree in ipairs((ns.SPEC_ORDER or {})[pf.class or ""] or {}) do
        local band = (pf.spec or {})[tree] or 0
        out[#out + 1] = {tree, band > 0 and (tree .. " · " .. depth[math.min(3, band)]) or tree, band > 0,
          band > 0 and "Spec lines unlock as you spend talent points deeper in a tree." or nil}
      end
    end
    return out
  end
  s.tagTab = "race"
  s.tagTabs, s.tagChips = {}, {}
  local function tagTabBtn()
    local b = CreateFrame("Button", nil, plate3)
    b:SetHeight(22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.top = b:CreateTexture(nil, "ARTWORK")
    b.top:SetPoint("TOPLEFT", 0, 0) b.top:SetPoint("TOPRIGHT", 0, 0) b.top:SetHeight(2)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("CENTER", 0, -1)
    function b:setLabel(t) self.label:SetText(t) self:SetWidth(math.max(40, (self.label:GetStringWidth() or 40) + 20)) end
    function b:setActive(on)
      if on then
        self.bg:SetColorTexture(0.18, 0.14, 0.06, 0.95) self.top:SetColorTexture(0.9, 0.72, 0.2, 1) self.label:SetTextColor(1, 0.82, 0)
      else
        self.bg:SetColorTexture(0, 0, 0, 0.55) self.top:SetColorTexture(0.35, 0.3, 0.2, 0.8) self.label:SetTextColor(0.75, 0.75, 0.75)
      end
    end
    return b
  end
  local function chipFrame()
    local b = CreateFrame("Frame", nil, plate3)
    b:SetHeight(24)
    b:EnableMouse(true)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER", 0, 0)
    b.edges = {}
    for _, e in ipairs({{"TOPLEFT", "TOPRIGHT", nil, 2}, {"BOTTOMLEFT", "BOTTOMRIGHT", nil, 2}, {"TOPLEFT", "BOTTOMLEFT", 2}, {"TOPRIGHT", "BOTTOMRIGHT", 2}}) do
      local t = b:CreateTexture(nil, "BORDER")
      t:SetColorTexture(0.9, 0.72, 0.2, 1)
      t:SetPoint(e[1], b, e[1]) t:SetPoint(e[2], b, e[2])
      if e[3] then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
      b.edges[#b.edges + 1] = t
    end
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b:SetScript("OnEnter", function(self)
      if not self.tip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.name or "", 1, 0.82, 0)
      GameTooltip:AddLine(self.tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  local tagHint = W.hint(plate3, "A box marks what your character has. Race, class, professions and talents are read from the game; the rest you choose above.")
  tagHint:SetWordWrap(true)
  s.tagHint = tagHint
  -- place the tabs and the tags for the width given; sets the height of the plate
  function s:layoutTags(w)
    local pw = (w or 600) - 16
    local x, row, y = 10, 0, -34
    for i, t in ipairs(TAG_TABS) do
      local b = self.tagTabs[i]
      if not b then
        b = tagTabBtn()
        self.tagTabs[i] = b
        b:SetScript("OnClick", function() W.sound("click") s.tagTab = TAG_TABS[i][1] s:layoutTags(s.w) if ns.relayout then ns.relayout() end end)
      end
      b:setLabel(t[2])
      b:setActive(self.tagTab == t[1])
      if x + b:GetWidth() > pw - 6 and x > 10 then x = 10 row = row + 1 end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", plate3, "TOPLEFT", x, y - row * 25)
      b:Show()
      x = x + b:GetWidth() + 3
    end
    y = y - (row + 1) * 25 - 10
    local list = tagList(self.tagTab)
    local cx, crow = 10, 0
    for i, t in ipairs(list) do
      local c = self.tagChips[i]
      if not c then c = chipFrame() self.tagChips[i] = c end
      c.name, c.tip = t[2], t[4]
      c.label:SetText(t[2])
      c.label:SetTextColor(t[3] and 1 or 0.62, t[3] and 0.82 or 0.62, t[3] and 0 or 0.62)
      for _, e in ipairs(c.edges) do e:SetShown(t[3] and true or false) end
      c.fill:SetColorTexture(t[3] and 0.2 or 0, t[3] and 0.15 or 0, t[3] and 0.04 or 0, t[3] and 0.8 or 0.35)
      c:SetWidth((c.label:GetStringWidth() or 40) + 22)
      if cx + c:GetWidth() > pw - 6 and cx > 10 then cx = 10 crow = crow + 1 end
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", plate3, "TOPLEFT", cx, y - crow * 30)
      c:Show()
      cx = cx + c:GetWidth() + 6
    end
    for i = #list + 1, #self.tagChips do self.tagChips[i]:Hide() end
    y = y - (crow + 1) * 30 - 6
    tagHint:ClearAllPoints()
    tagHint:SetPoint("TOPLEFT", plate3, "TOPLEFT", 12, y)
    tagHint:SetWidth(pw - 24)
    plate3:SetHeight(-y + 30)
  end
  function s:refreshTags() self:layoutTags(self.w) end

  -- the foot: done, choose lines, show at login
  local tip = W.hint(s, "Type /x any time to come back here  ·  /x flag to review a fight")
  tip:SetPoint("TOP", plate3, "BOTTOM", 0, -8)
  local foot = CreateFrame("Frame", nil, s)
  foot:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", -4, -8)
  foot:SetPoint("RIGHT", s, "RIGHT", -8, 0)
  foot:SetHeight(30)
  local ver = W.hint(s, ns.BUILD)       -- the bottom corner of the picture (the artist's signature is bottom right)
  ver:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 8, 6)
  local done = W.button(foot, "Done", 90, function() s:finish(false) end)
  done:SetPoint("RIGHT", 0, 0)
  local lines = W.button(foot, "Choose lines", 110, function() s:finish(true) end)
  lines:SetPoint("RIGHT", done, "LEFT", -6, 0)
  W.tooltip(lines, "Choose lines", "Go and pick which lines your character says, or add some of your own.")
  -- the login switch lives in the bottom left corner of the window (it is moved there when the window is built)
  local show = W.check(s, "Open to this page at login", function(_, on) cdb().splash = on and true or false end)
  W.tooltip(show, "Open to this page at login", "When on, this Setup page opens by itself each time you log in. Off: it opens only when you type /x.")
  s.show = show
  -- first time through: finishing marks setup done and offers the lines
  function s:finish(toLines)
    local first = not cdb().setupDone
    cdb().setupDone = true
    if first then p("all set. Type /x any time to change things.") end
    if toLines then
      if ns.openSection then ns.openSection("lines") end
    else
      if ns.closeMain then ns.closeMain() end
      if first and ns.showNextStep then pcall(ns.showNextStep) end
    end
  end

  function s:refreshChoices(changed)
    local c = cdb()
    if not c.homeland then
      local list = ns.homelands()
      if list[1] then c.homeland = list[1][1] end
    end
    for _, dd in pairs(self.dds) do dd.refresh() end
    for kind, hint in pairs(self.hints) do
      local d = CROX2_DESCRIBE and CROX2_DESCRIBE[kind]
      hint:SetText((d and c[kind] and d[c[kind]]) or SPLASH_HINTS[kind] or "")
    end
    if changed or not self.example:GetText() or self.example:GetText() == "" then self:rollExample(changed) end
    self.chattyDD.refresh() self.raidDD.refresh() self.askDD.refresh() self.giveDD.refresh() self.trollDD.refresh()
    local function est(level) local ch = ns.CHATTY[level] return ch and ("About " .. ch.est) or "" end
    local CR_EST = {[1] = "About 1 time in 4", [2] = "About every other time", [3] = "About 4 times in 5", [4] = "Every time it fits"}
    self.askHint:SetText(CR_EST[c.crAsk or 4] or "")
    self.giveHint:SetText(CR_EST[c.crGive or 4] or "")
    self.chattyHint:SetText(est(c.chatty or 3))
    self.raidHint:SetText(est(c.raidChatty or 3))
    self:layoutSpeak()
    local pf = ns.profile
    local nm = ns.fullName and ns.fullName() or pf.name or ""
    local r, g, b
    if ns.classColor then r, g, b = ns.classColor(pf.class) end
    local hex = r and ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) or "|cffffd100"
    self.who:SetText(("%s%s|r  |cffbbbbbb· %s %s|r"):format(hex, nm, pf.race or "", cap((pf.class or ""):lower())))
    self:refreshTags()
    self.show:SetChecked(c.splash ~= false)
    if ns.relayout then ns.relayout() end      -- the page grows by a note at the loudest levels
  end
  function s:refresh() self:refreshChoices() end
  function s:layout(w)
    self.w = w
    self.grp:SetWidth(math.max(380, math.min(640, w - 40)))
    self:layoutTags(w)
    local h = 6 + 54 + 6 + 34 + 8 + plate:GetHeight() + 8 + plate2:GetHeight() + 8 + plate3:GetHeight() + 8 + 14 + 8 + 30 + 16
    self.height = h
    return h
  end
  return s
end

------------------------------------------------------------------------
-- Section: Options
------------------------------------------------------------------------
local function buildOptions(parent)
  local s = CreateFrame("Frame", nil, parent)
  local y = -4
  local function head(t)
    local h = W.heading(s, t)
    h:SetPoint("TOPLEFT", 4, y)
    y = y - 20
  end
  local checks = {}
  local function check(key, label, tip, onSet)
    local c = W.check(s, label, function(_, on)
      cdb()[key] = on
      if onSet then onSet(on) end
    end)
    c:SetPoint("TOPLEFT", 8, y)
    W.tooltip(c, label, tip)
    checks[key] = c
    y = y - 26
    return c
  end
  local function dropdown(label, tip, items, get, set, width)
    local l = W.text(s, label, "GameFontHighlight")
    l:SetPoint("TOPLEFT", 14, y - 6)
    l:SetWidth(170)
    local dd = W.dropdown(s, width or 120, items, get, set)
    dd:SetPoint("TOPLEFT", 170, y)
    W.tooltip(l, label, tip)
    y = y - 32
    return dd, l
  end

  head("General")
  check("on", "cro/x on for this character", "The master switch for this character. Everything about how it speaks is on the Setup page.")
  head("Content")
  check("profLines", "Profession combat lines", "Lines about your professions that come up in a fight or when you use items (cooking on food, alchemy on potions, engineering on explosives, blacksmithing on heavy hits and so on), plus the emotes for gathering and crafting. Off: your professions are never mentioned.")
  local profBtn = W.button(s, "Sample profession lines...", 190, function() ns.openProfSamples() end)
  profBtn:SetPoint("TOPLEFT", 36, y + 2)
  W.tooltip(profBtn, "Sample profession lines", "Shows a few examples for the professions this character has, and what each would trigger on.")
  y = y - 28
  local media = W.check(s, "Media references (a later build)", function(self)
    self:SetChecked(false)
    p("media references come in a later build.")
  end)
  media:SetPoint("TOPLEFT", 8, y)
  media.label:SetFontObject("GameFontDisable")
  W.tooltip(media, "Media references", "Movie and TV lines and catchphrases, as a separate category you can switch on. Coming in a later build.")
  y = y - 26
  head("Log")
  check("logging", "Keep a session log", "Records what was said and why lines stayed quiet, on this computer only. Used by /x flag and /x export.")
  check("includeOwn", "Include my own lines in exports", "Off: your own lines show as \"one of your own lines\" in /x export.")
  head("Testing")
  check("testing", "Testing mode (collects extra data)", "Off by default. While on, cro/x keeps more detail about every fight (what it said, why it stayed quiet, the pace and speech budget at the time), on this computer only. Copy it from Copy test data and paste it where the testers gather. Nothing is sent for you.",
    function(on) p(on and "testing mode is ON. Play as normal, then /x testdata to copy what it collected." or "testing mode is off.") end)
  local dataBtn = W.button(s, "Copy test data...", 150, function() ns.Log.openTestData() end)
  dataBtn:SetPoint("TOPLEFT", 12, y - 2)
  W.tooltip(dataBtn, "Copy test data", "Opens the collected testing data with instructions on how to copy and send it. Same as /x testdata.")
  local simBtn = W.button(s, "Combat simulator...", 150, function() ns.Sim.open() end)
  simBtn:SetPoint("LEFT", dataBtn, "RIGHT", 8, 0)
  W.tooltip(simBtn, "Combat simulator", "A small chat-style window that plays pretend fights through your character's real lines. Same as /x sim.")
  y = y - 32
  head("Beta testing")
  local bugBtn = W.button(s, "Report a problem...", 150, function() ns.Bug.open() end)
  bugBtn:SetPoint("TOPLEFT", 12, y - 2)
  W.tooltip(bugBtn, "Report a problem", "Builds a short report to copy and paste into the beta Discord or GitHub. Nothing is sent for you. Same as /x bug.")
  local testBtn = W.button(s, "Why was it quiet?", 150, function() ns.Bug.test() end)
  testBtn:SetPoint("LEFT", bugBtn, "RIGHT", 8, 0)
  W.tooltip(testBtn, "Why was it quiet?", "Prints, in your own chat only, the reasons your last few button presses stayed quiet. Same as /x test.")
  y = y - 32
  head("Window")
  local slider = W.slider(s, "Text scale", 0.8, 1.4, 0.05, function() return cdb().textScale or 1 end,
    function(v)
      cdb().textScale = v
      if ns.relayout then ns.relayout() end
      if C_Timer and C_Timer.After then C_Timer.After(0.1, function() if ns.relayout then ns.relayout() end end) end   -- once more when the frames have settled
    end, function(v) return ("%d%%"):format(v * 100 + 0.5) end, true)
  slider:SetPoint("TOPLEFT", 18, y - 12)
  y = y - 44
  check("minimap", "Minimap button", "/x always opens this window.", function(on) if ns.updateMinimap then ns.updateMinimap() end end)
  local reset = W.button(s, "Reset window", 120, function()
    cdb().window = nil
    cdb().textScale = 1
    slider:SetValue(1)
    if ns.resetWindow then ns.resetWindow() end
  end)
  reset:SetPoint("TOPLEFT", 12, y - 4)
  local resetAll = W.button(s, "Reset cro/x...", 130, function() ns.confirmReset() end)
  resetAll:SetPoint("LEFT", reset, "RIGHT", 8, 0)
  W.tooltip(resetAll, "Reset cro/x", "Puts every option and your character's choices back to the defaults and brings the Setup page back so you can set up again. Your own phrases are kept. Same as /x reset.")
  y = y - 34
  local ver = W.hint(s, ("cro_x %s · built %s · /x help for commands"):format(ns.BUILD, ns.BUILD_DATE))
  ver:SetPoint("TOPLEFT", 12, y - 4)
  local height = -y + 30

  function s:refresh()
    for key, c in pairs(checks) do c:SetChecked(cdb()[key] and true or false) end
  end
  function s:layout() return height end
  return s
end

------------------------------------------------------------------------
-- Section: My phrases
------------------------------------------------------------------------
local OWN_MOMENTS = {}
for _, it in ipairs(ARCH_LIST) do OWN_MOMENTS[#OWN_MOMENTS + 1] = it end
for _, it in ipairs(MOMENT_LIST) do OWN_MOMENTS[#OWN_MOMENTS + 1] = it end

local function buildPhrases(parent)
  local s = CreateFrame("Frame", nil, parent)
  local h = W.heading(s, "Your lines")
  h:SetPoint("TOPLEFT", 4, -4)
  s.empty = W.hint(s, "None yet. Write one below.")
  s.empty:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 4, -8)
  s.rows = {}
  local editing          -- the entry being edited (nil = new)
  local draft = {as = "auto", moments = {}, freq = 2, scope = "char"}

  local formTop = CreateFrame("Frame", nil, s)
  formTop:SetSize(10, 10)
  local h2 = W.heading(formTop, "New line")
  h2:SetPoint("TOPLEFT", 0, 0)
  s.formHead = h2
  local eb = W.edit(formTop, 400, 255)
  eb:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 6, -8)
  local slots = W.hint(formTop, "Slots: [target] [they] [them] [their] · 255 characters max · emotes start with your name")
  slots:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", -6, -4)

  local function row(label, y, w)
    local l = W.text(formTop, label, "GameFontHighlight")
    l:SetPoint("TOPLEFT", 0, y)
    l:SetWidth(90)
    return l
  end
  row("As", -78)
  local asDD = W.dropdown(formTop, 110, function()
    return {{"auto", "Auto"}, {"say", "Say"}, {"yell", "Yell"}, {"emote", "Emote"}} end,
    function() return draft.as end, function(v) draft.as = v end)
  asDD:SetPoint("TOPLEFT", 80, -72)
  W.tooltip(asDD, "As", "Auto picks /say or /yell the way built-in lines do. Emotes start with your character's name automatically.")
  row("When", -110)
  local whenDD = W.make("Frame", formTop, {"UIDropDownMenuTemplate"}, "CROX2WhenDD")
  whenDD:SetPoint("TOPLEFT", 80, -104)
  local function whenText()
    local n, first = 0, nil
    for _, it in ipairs(OWN_MOMENTS) do if draft.moments[it[1]] then n = n + 1 first = first or it[2] end end
    if n == 0 then return "Pick moments" end
    return n == 1 and first or (first .. " +" .. (n - 1))
  end
  if UIDropDownMenu_Initialize then
    UIDropDownMenu_SetWidth(whenDD, 200)
    UIDropDownMenu_Initialize(whenDD, function(_, level)
      for _, it in ipairs(OWN_MOMENTS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text, info.isNotRadio, info.keepShownOnClick = it[2], true, true
        info.checked = draft.moments[it[1]] and true or false
        info.func = function(_, _, _, checked)
          draft.moments[it[1]] = (not draft.moments[it[1]]) or nil
          UIDropDownMenu_SetText(whenDD, whenText())
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end
  row("How often", -142)
  local freqDD = W.dropdown(formTop, 110, function() return {{1, "Rarely"}, {2, "Sometimes"}, {3, "Often"}} end,
    function() return draft.freq end, function(v) draft.freq = v end)
  freqDD:SetPoint("TOPLEFT", 80, -136)
  W.tooltip(freqDD, "How often", "Rarely weighs the same as one built-in line, Sometimes about three times as much, Often about half of all picks for that moment.")
  row("For", -174)
  local scopeDD = W.dropdown(formTop, 110, function() return {{"char", "This character"}, {"account", "All characters"}} end,
    function() return draft.scope end, function(v) draft.scope = v end)
  scopeDD:SetPoint("TOPLEFT", 80, -168)
  local err = W.text(formTop, "", "GameFontRedSmall")
  err:SetPoint("TOPLEFT", 0, -204)
  local preview = W.button(formTop, "Preview", 90, function()
    local t = eb:GetText()
    if t == "" then err:SetText("Write a line first.") return end
    p("|cffffffff" .. (draft.as == "emote" and ((ns.profile.name or "You") .. " " .. t) or ("\"" .. t .. "\"")) .. "|r  (only you see this)")
  end)
  preview:SetPoint("TOPLEFT", 0, -222)
  local save = W.button(formTop, "Save line", 100)
  save:SetPoint("LEFT", preview, "RIGHT", 6, 0)
  local cancel = W.button(formTop, "New", 70)
  cancel:SetPoint("LEFT", save, "RIGHT", 6, 0)
  eb:SetScript("OnTextChanged", function() err:SetText("") end)

  local function loadDraft(entry)
    editing = entry
    draft = {as = "auto", moments = {}, freq = 2, scope = "char"}
    if entry then
      draft.as, draft.freq, draft.scope = entry.c.as or "auto", entry.c.freq or 2, entry.scope
      for k, v in pairs(entry.c.moments or {}) do draft.moments[k] = v end
      eb:SetText(entry.c.text or "")
      h2:SetText("Edit line")
    else
      eb:SetText("")
      h2:SetText("New line")
    end
    asDD.refresh() freqDD.refresh() scopeDD.refresh()
    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(whenDD, whenText()) end
    err:SetText("")
  end

  save:SetScript("OnClick", function()
    local t = (eb:GetText() or ""):gsub("[\r\n|]", " "):match("^%s*(.-)%s*$")
    if t == "" then err:SetText("Write a line first.") return end
    if not next(draft.moments) then err:SetText("Pick at least one moment under When.") return end
    if draft.as == "emote" then t = t:gsub("^/e%s+", ""):gsub("^/emote%s+", "") end
    local entry = {text = t, as = draft.as, moments = draft.moments, freq = draft.freq, on = true}
    if editing then
      local list = editing.scope == "account" and ns.db.custom or cdb().custom
      table.remove(list, editing.index)
      entry.on = editing.c.on
    end
    local list = draft.scope == "account" and ns.db.custom or cdb().custom
    if #list >= 200 then err:SetText("That's the limit of 200 lines here.") return end
    list[#list + 1] = entry
    loadDraft(nil)
    s:refresh()
    if ns.relayout then ns.relayout() end
  end)
  cancel:SetScript("OnClick", function() loadDraft(nil) end)

  local function rowFor(i)
    if s.rows[i] then return s.rows[i] end
    local r = CreateFrame("Button", nil, s)
    r:SetHeight(34)
    r.check = W.check(r, "")
    r.check:SetPoint("LEFT", 0, 0)
    r.txt = W.text(r, "", "GameFontHighlight")
    r.txt:SetPoint("TOPLEFT", 28, -3)
    r.txt:SetWordWrap(false)
    r.sub = W.hint(r, "")
    r.sub:SetPoint("TOPLEFT", r.txt, "BOTTOMLEFT", 0, -2)
    r.del = W.make("Button", r, {"UIPanelCloseButton"})
    r.del:SetSize(24, 24)
    r.del:SetPoint("RIGHT", 0, 0)
    W.tooltip(r.del, "Delete this line")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    W.tooltip(r, "Click to edit")
    s.rows[i] = r
    return r
  end

  function s:refresh()
    local entries = {}
    for i, c in ipairs(cdb().custom) do entries[#entries + 1] = {c = c, scope = "char", index = i} end
    for i, c in ipairs(ns.db.custom) do entries[#entries + 1] = {c = c, scope = "account", index = i} end
    for _, r in ipairs(self.rows) do r:Hide() end
    self.empty:SetShown(#entries == 0)
    local y = -26
    for i, e in ipairs(entries) do
      local r = rowFor(i)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 4, y)
      r:SetPoint("RIGHT", self, "RIGHT", -4, 0)
      r.txt:SetText(e.c.as == "emote" and ((ns.profile.name or "") .. " " .. e.c.text) or e.c.text)
      local ms = {}
      for _, it in ipairs(OWN_MOMENTS) do if e.c.moments and e.c.moments[it[1]] then ms[#ms + 1] = it[2] end end
      r.sub:SetText(("%s · %s · %s · %s"):format(cap(e.c.as or "auto"), table.concat(ms, ", "),
        ({"Rarely", "Sometimes", "Often"})[e.c.freq or 2], e.scope == "account" and "All characters" or "This character"))
      r.check:SetChecked(e.c.on ~= false)
      r.check:SetScript("OnClick", function(self) e.c.on = self:GetChecked() and true or false W.sound(e.c.on and "check" or "uncheck") end)
      r:SetScript("OnClick", function() loadDraft(e) end)
      r.del:SetScript("OnClick", function()
        local list = e.scope == "account" and ns.db.custom or cdb().custom
        table.remove(list, e.index)
        if editing and editing.c == e.c then loadDraft(nil) end
        s:refresh()
        if ns.relayout then ns.relayout() end
      end)
      r:Show()
      y = y - 38
    end
    if #entries == 0 then y = y - 14 end
    formTop:ClearAllPoints()
    formTop:SetPoint("TOPLEFT", 4, y - 14)
    formTop:SetPoint("RIGHT", self, "RIGHT", -4, 0)
    self.formY = -y + 14
  end
  function s:layout(w)
    eb:SetWidth(math.max(200, math.min(440, w - 30)))
    for _, r in ipairs(self.rows) do r.txt:SetWidth(w - 70) end
    return (self.formY or 40) + 260
  end
  loadDraft(nil)
  return s
end

------------------------------------------------------------------------
-- Section: Lines
------------------------------------------------------------------------
local function linesFor(moment)
  -- returns {{id, line, src}, ...}
  local out = {}
  local function addList(pool, lines, src, filter, extra)
    for _, line in ipairs(lines or {}) do
      if not filter or filter(line) then
        local o = {id = ns.lineId(pool, line), line = line, src = src}
        for k, v in pairs(extra or {}) do o[k] = v end
        out[#out + 1] = o
      end
    end
  end
  local function fits(line)
    if not line.a then return false end
    for _, a in ipairs(line.a) do if a == moment then return true end end
    return false
  end
  if moment == "x:cr" then
    local keys = {}
    for k in pairs(CROX2_POOLS) do if k:find("^cr:") then keys[#keys + 1] = k end end
    table.sort(keys)
    for _, k in ipairs(keys) do addList(k, CROX2_POOLS[k], "Call and response · " .. k:gsub("^cr:", ""):gsub(":", " ")) end
    return out
  end
  if moment == "x:dmg" then
    local keys = {}
    for k in pairs(CROX2_DMG or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do addList("dmg:" .. k, CROX2_DMG[k], "Damage type · " .. k) end
    return out
  end
  if moment == "x:profemote" then
    local keys = {}
    for k in pairs(CROX2_PROF_EMOTES or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do addList("profemote:" .. k, CROX2_PROF_EMOTES[k], "Profession emote · " .. k:gsub(":", " ")) end
    return out
  end
  local base = moment:find(":") and moment or (moment == "kill" and "kill" or ("arch:" .. moment))
  if moment == "summon" then
    for k in pairs(CROX2_POOLS) do if k:find("^summon:") then addList(k, CROX2_POOLS[k], "Baseline · " .. k:gsub("^summon:", "")) end end
  else
    addList(base, CROX2_POOLS[base], "Baseline")
  end
  local tkeys = {}
  for k in pairs(CROX2_TAGS) do tkeys[#tkeys + 1] = k end
  table.sort(tkeys)
  for _, k in ipairs(tkeys) do
    local src = k:find("^prof:") and ("Profession · " .. k:gsub("^prof:", "")) or ("Tag · " .. k:gsub("^up:", "origin:"):gsub("^drive:", "motivation:"):gsub(":", ": "))
    addList("tag:" .. k, CROX2_TAGS[k], src, fits)
  end
  for cls, trees in pairs(CROX2_SPEC or {}) do
    for tree, bands in pairs(trees) do
      for b, lines in pairs(bands) do
        addList("spec:" .. tree .. ":" .. b, lines, ("Spec · %s %s (%s)"):format(cap(cls:lower()), tree,
          ({"early", "middle", "deep"})[b]), fits, {cls = cls, tree = tree, band = b})
      end
    end
  end
  for _, list in ipairs({cdb().custom, ns.db.custom}) do
    for _, c in ipairs(list) do
      if c.moments and c.moments[moment] then
        out[#out + 1] = {id = "own|" .. c.text, line = {t = c.text, e = c.as == "emote"}, src = "My phrase", own = c}
      end
    end
  end
  return out
end

-- can this character ever say the line? (temperament, race, class and tags; situational facts ignored)
local function canSay(o, ignore)   -- ignore: "spec" = pretend the spec band is unlocked, "other" = pretend it is this class
  local line = o.line
  if o.own then return o.own.on ~= false end
  if line.o and line.o ~= cdb().temperament then return false end
  for _, tok in ipairs(line.m or {}) do
    if tok == "nt:" .. (cdb().temperament or "") then return false end
    if tok:find("^race:") or tok:find("^!race:") then
      if not ns.lineOK({m = {tok}}, ns.makeCtx(nil, nil)) then return false end
    end
  end
  local id = o.id
  local pf = ns.profile
  if id:find("^tag:class:") then
    if ignore == "other" then return true end
    return id:find("^tag:class:" .. (pf.class or "") .. "|") ~= nil
  end
  if id:find("^tag:drive:") then return id:find("^tag:drive:" .. (cdb().drive or "") .. "|") ~= nil end
  if id:find("^tag:up:") then return id:find("^tag:up:" .. (cdb().upbringing or "") .. "|") ~= nil end
  if id:find("^tag:home:") then
    if id:find("^tag:home:skyborne_all|") then return pf.race == "Skyborne" end
    return cdb().homeland ~= nil and id:find("^tag:" .. cdb().homeland:gsub("%p", "%%%0") .. "|") ~= nil
  end
  if id:find("^tag:prof:") then
    local k = id:match("^tag:prof:([^|]+)")
    return pf.profs and pf.profs[k] and true or false
  end
  if o.cls then
    if ignore == "other" then return true end
    if o.cls ~= pf.class then return false end
    if ignore == "spec" then return true end
    return ((pf.spec or {})[o.tree] or 0) >= (o.band or 1)
  end
  if id:find("^summon:") then return pf.class == "WARLOCK" end
  return true
end

-- which kind of source a line comes from, for the source checkboxes
local SOURCE_LIST = {
  {"base", "Baseline"}, {"drive", "Tag: motivation"}, {"up", "Tag: origin"}, {"home", "Tag: homeland"},
  {"class", "Tag: class"}, {"spec", "Spec lines"}, {"prof", "Professions"}, {"cr", "Call and response"},
  {"dmg", "Damage types"}, {"profemote", "Profession emotes"}, {"own", "My own lines"},
}
local CHIP_LABEL = {base = "Baseline", drive = "Motivation", up = "Origin", home = "Homeland", class = "Class",
  spec = "Spec", prof = "Professions", cr = "Call and response", dmg = "Damage types", profemote = "Profession emotes", own = "My lines"}
local function sourceKind(o)
  if o.own then return "own" end
  if o.cls then return "spec" end
  local id = o.id
  if id:find("^tag:drive:") then return "drive" end
  if id:find("^tag:up:") then return "up" end
  if id:find("^tag:home:") then return "home" end
  if id:find("^tag:class:") then return "class" end
  if id:find("^tag:prof:") then return "prof" end
  if id:find("^cr:") then return "cr" end
  if id:find("^dmg:") then return "dmg" end
  if id:find("^profemote:") then return "profemote" end
  return "base"
end

-- what makes a moment fire, in plain words, for moments that aren't an ability
local TRIGGER_TEXT = {
  kill = "killing an enemy",
  ["debuff:poisoned"] = "being poisoned", ["debuff:cursed"] = "being cursed", ["debuff:diseased"] = "catching a disease",
  ["debuff:magic"] = "a harmful magic effect on you", ["debuff:physical"] = "a harmful physical effect on you (bleeds and the like)",
  ["debuff:cc"] = "being stunned, feared or otherwise controlled",
  ["x:cr"] = "a party or raid call you answer", ["x:dmg"] = "damage of that type landing", ["x:profemote"] = "using that profession",
}
-- Does this character know the spell? true / false, or nil when the client can't say.
local function spellKnown(name)
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
  local id = type(info) == "table" and info.spellID
  if not id and GetSpellInfo then id = select(7, GetSpellInfo(name)) end
  if not id then return nil end
  if IsPlayerSpell then return IsPlayerSpell(id) and true or false end
  if IsSpellKnown then return IsSpellKnown(id) and true or false end
  return nil
end
-- abilities (this class, plus racials the character knows) that fire a moment; plain-words text for the rest
local function triggersFor(moment)
  if TRIGGER_TEXT[moment] then return nil, TRIGGER_TEXT[moment] end
  if moment:find("^item:") then return nil, "using " .. (momentLabel(moment):lower():gsub("^any ", "a ")) end
  local names = {}
  local cls = CROX2_ABILITIES and CROX2_ABILITIES[ns.profile.class or ""] or {}
  for name, a in pairs(cls) do
    if not a.quiet and (a.arch == moment or a.friend == moment) and spellKnown(name) ~= false then names[#names + 1] = name end
  end
  for name, a in pairs((CROX2_ABILITIES or {}).ANY or {}) do
    if not a.quiet and (a.arch == moment or a.friend == moment) and spellKnown(name) == true then names[#names + 1] = name end
  end
  table.sort(names)
  return names
end

------------------------------------------------------------------------
-- Profession line samples: examples for the professions the character has, and what each would trigger on
------------------------------------------------------------------------
local PROF_NAME = {first_aid = "First Aid"}
local function profLabel(k) return PROF_NAME[k] or cap(k) end
local function shuffle(t)
  for i = #t, 2, -1 do local j = math.random(i) t[i], t[j] = t[j], t[i] end
  return t
end
-- plain words for what sets a profession line off
local function profTrigger(line)
  local parts, items, arch = {}, {}, {}
  for _, m in ipairs(line.a or {}) do
    if m:find("^item:") then items[#items + 1] = (momentLabel(m):lower():gsub("^any ", "a "))
    else arch[#arch + 1] = m end
  end
  if #items > 0 then parts[#parts + 1] = "using " .. table.concat(items, ", ") .. " (about half the time you do, if you have the profession)" end
  for _, m in ipairs(arch) do
    local names = triggersFor(m)
    if names and #names > 0 then
      local shown = {}
      for i = 1, math.min(5, #names) do shown[i] = names[i] end
      parts[#parts + 1] = ("%s abilities: %s%s - now and then, mixed in with your other lines for that moment"):format(
        momentLabel(m):lower(), table.concat(shown, ", "), #names > 5 and (" +" .. (#names - 5) .. " more") or "")
    else
      parts[#parts + 1] = momentLabel(m):lower() .. " moments (none of your current abilities set this off)"
    end
  end
  if #parts == 0 then parts[1] = "any moment, now and then, mixed in with your other lines" end
  local when = {}
  for _, tok in ipairs(line.m or {}) do
    if tok == "recipe" then when[#when + 1] = "only for an item you can make yourself"
    elseif tok == "fish" then when[#when + 1] = "only for fish"
    elseif tok == "recipe:weapon" then when[#when + 1] = "only while you wield something you made"
    elseif tok == "recipe:armor" then when[#when + 1] = "only while you wear something you made" end
  end
  if line.rare then when[#when + 1] = "rarely" end
  return table.concat(parts, "; ") .. (#when > 0 and (" (" .. table.concat(when, ", ") .. ")") or "")
end

function ns.profSampleText(perProf)
  perProf = perProf or 3
  local pf = ns.profile or {}
  local keys = {}
  for k in pairs(pf.profs or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {}
  if cdb().profLines == false then
    out[#out + 1] = "|cffcc9933Profession combat lines are switched off in Options.|r These are what would be said if you switched them on.\n"
  end
  if #keys == 0 then
    out[#out + 1] = "cro/x does not see any professions on this character. It reads them from your skills when you log in or when your skills change."
    return table.concat(out, "\n"), 0
  end
  local n = 0
  for _, k in ipairs(keys) do
    local pool = {}
    for _, line in ipairs(CROX2_TAGS["prof:" .. k] or {}) do
      if canSay({id = "tag:prof:" .. k .. "|" .. line.t, line = line}) then pool[#pool + 1] = line end
    end
    shuffle(pool)
    out[#out + 1] = "|cffffd100" .. profLabel(k) .. "|r"
    if #pool == 0 and not (CROX2_PROF_EMOTES and (CROX2_PROF_EMOTES["gather:" .. k] or CROX2_PROF_EMOTES["craft:" .. k])) then
      out[#out + 1] = "  |cff999999No lines for this profession yet.|r"
    end
    for i = 1, math.min(perProf, #pool) do
      local line = pool[i]
      out[#out + 1] = "  \"" .. line.t .. "\""
      out[#out + 1] = "    |cff999999Triggers on: " .. profTrigger(line) .. "|r"
      n = n + 1
    end
    for _, kind in ipairs({"gather", "craft"}) do
      local list = CROX2_PROF_EMOTES and CROX2_PROF_EMOTES[kind .. ":" .. k]
      if list and #list > 0 then
        local e = list[math.random(#list)]
        local pr = (ns.PRON or {})[cdb().pronouns] or (ns.PRON or {}).they or {}
        local et = e.t:gsub("%[(%a+)%]", function(w) return pr[w:lower()] or ("[" .. w .. "]") end)
        out[#out + 1] = "  " .. (pf.name or "Your character") .. " " .. et
        out[#out + 1] = "    |cff999999Triggers on: " .. (kind == "gather"
          and (k == "fishing" and "looting a catch" or ("gathering with " .. profLabel(k)))
          or ("crafting something with " .. profLabel(k))) .. " - a profession emote, about 1 time in 10, at most once every 5 minutes, only out of combat|r"
        n = n + 1
      end
    end
    out[#out + 1] = ""
  end
  return table.concat(out, "\n"), n
end

local profSampleFrame
function ns.openProfSamples()
  if not profSampleFrame then
    local f = W.panel("CROX2ProfSamples", "cro/x - profession line samples", 640, 520)
    profSampleFrame = f
    local intro = W.hint(f, "A few examples from the profession lines your character could say, with what would set each one off. Only you see this.")
    intro:SetPoint("TOPLEFT", 16, -34)
    intro:SetPoint("RIGHT", -16, 0)
    intro:SetWordWrap(true)
    local sf, content = W.scroll(f)
    sf:SetPoint("TOPLEFT", 14, -62)
    sf:SetPoint("BOTTOMRIGHT", -32, 44)
    local txt = W.text(content, "", "GameFontHighlight")
    txt:SetPoint("TOPLEFT", 4, -4)
    txt:SetWidth(560)
    txt:SetWordWrap(true)
    f.txt, f.content = txt, content
    function f:fill()
      local text = ns.profSampleText(3)
      self.txt:SetText(text)
      self.content:SetHeight(math.max(10, (self.txt:GetStringHeight() or 300) + 12))
    end
    local more = W.button(f, "Another sample", 130, function() f:fill() end)
    more:SetPoint("BOTTOMRIGHT", -16, 12)
    local close = W.button(f, "Close", 90, function() f:Hide() end)
    close:SetPoint("RIGHT", more, "LEFT", -6, 0)
  end
  profSampleFrame:Show()
  profSampleFrame:fill()
end

local function countKeys(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local function buildLines(parent)
  local s = CreateFrame("Frame", nil, parent)
  -- empty moments / sources = everything; ticking some narrows to just those, in any combination
  local state = {moments = {}, sources = {}, search = "", limit = 100, open = false, view = "mine"}
  local momentItems = {}
  for _, l in ipairs({ARCH_LIST, MOMENT_LIST, EXTRA_LIST}) do for _, it in ipairs(l) do momentItems[#momentItems + 1] = it end end
  local function changed() state.limit = 100 s:refresh() if ns.relayout then ns.relayout() end end

  -- folio tabs: a row of group tabs, and under it a row of tabs for the moments (or classes) inside the group
  local GROUPS = {
    {"all", "All"},
    {"attacks", "Attacks", {"opener", "filler", "heavy", "area", "upkeep", "reactive", "finisher"}},
    {"control", "Control", {"interrupt", "lockdown", "snare", "weaken", "taunt"}},
    {"defense", "Defense & healing", {"guard", "laststand", "escape", "heal", "ward", "groupheal", "clutch", "cleanse", "raise"}},
    {"support", "Support", {"rally", "powerup", "bless", "summon", "sneak"}},
    {"kill", "After a kill", {"kill"}},
    {"debuffs", "Debuffs", {"debuff:poisoned", "debuff:cursed", "debuff:diseased", "debuff:magic", "debuff:physical", "debuff:cc"}},
    {"items", "Items", {"item:potion", "item:healing", "item:mana", "item:rage", "item:bandage", "item:food", "item:drink",
      "item:elixir", "item:flask", "item:scroll", "item:explosives"}},
    {"extras", "Group & extras", {"x:cr", "x:dmg", "x:profemote"}},
    {"others", "Other classes"},
  }
  state.group, state.sub, state.cls = "all", nil, nil
  local function groupDef(k) for _, g in ipairs(GROUPS) do if g[1] == k then return g end end end
  local function classList()
    local l = {}
    for cls in pairs(CROX2_SPEC or {}) do if cls ~= (ns.profile and ns.profile.class) then l[#l + 1] = cls end end
    table.sort(l)
    return l
  end
  -- what the current tabs mean for the line filters
  local function applyTabs()
    state.moments, state.sources = {}, {}
    state.view = state.group == "others" and "others" or "mine"
    local g = groupDef(state.group)
    if g and g[3] then
      if state.sub then state.moments[state.sub] = true
      else for _, k in ipairs(g[3]) do state.moments[k] = true end end
    end
  end

  local function folioTab(small)
    local b = CreateFrame("Button", nil, s)
    b:SetHeight(small and 20 or 26)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.top = b:CreateTexture(nil, "ARTWORK")
    b.top:SetPoint("TOPLEFT", 0, 0)
    b.top:SetPoint("TOPRIGHT", 0, 0)
    b.top:SetHeight(2)
    b.label = b:CreateFontString(nil, "OVERLAY", small and "GameFontHighlightSmall" or "GameFontNormalSmall")
    b.label:SetPoint("CENTER", 0, -1)
    function b:setLabel(t) self.label:SetText(t) self:SetWidth(math.max(40, (self.label:GetStringWidth() or 40) + 22)) end
    function b:setActive(on)
      self.active = on
      if on then
        self.bg:SetColorTexture(0.18, 0.14, 0.06, 0.95)
        self.top:SetColorTexture(0.9, 0.72, 0.2, 1)
        self.label:SetTextColor(1, 0.82, 0)
      else
        self.bg:SetColorTexture(0, 0, 0, 0.55)
        self.top:SetColorTexture(0.35, 0.3, 0.2, 0.8)
        self.label:SetTextColor(0.75, 0.75, 0.75)
      end
    end
    b:SetScript("OnEnter", function(self) if not self.active then self.bg:SetColorTexture(0.12, 0.1, 0.06, 0.8) end end)
    b:SetScript("OnLeave", function(self) self:setActive(self.active) end)
    return b
  end
  s.tabs, s.subs = {}, {}
  local function flowTabs(pool, specs, activeKey, y, w, small)
    local x, rowH = 4, small and 22 or 28
    local rows = 1
    for i, sp in ipairs(specs) do
      local b = pool[i]
      if not b then b = folioTab(small) pool[i] = b end
      b:setLabel(sp[2])
      b:setActive(sp[1] == activeKey)
      b:SetScript("OnClick", function() W.sound("click") sp.pick() end)
      local bw = b:GetWidth()
      if x + bw > w - 6 and x > 4 then x = 4 rows = rows + 1 end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", x, y - (rows - 1) * rowH)
      b:Show()
      x = x + bw + 3
    end
    for i = #specs + 1, #pool do pool[i]:Hide() end
    return y - rows * rowH
  end
  -- places both rows for the width given and returns how tall the header is
  function s:flowHeader(w)
    local gspecs = {}
    for _, g in ipairs(GROUPS) do
      gspecs[#gspecs + 1] = {g[1], g[2], pick = function()
        state.group, state.sub, state.cls = g[1], nil, nil
        applyTabs() state.limit = 100 s:refresh() if ns.relayout then ns.relayout() end
      end}
    end
    local y = flowTabs(self.tabs, gspecs, state.group, 0, w, false)
    local sspecs = {}
    local g = groupDef(state.group)
    local active
    if state.group == "others" then
      sspecs[1] = {"*", "All classes", pick = function() state.cls = nil state.limit = 100 s:refresh() if ns.relayout then ns.relayout() end end}
      for _, cls in ipairs(classList()) do
        sspecs[#sspecs + 1] = {cls, cap(cls:lower()), pick = function() state.cls = cls state.limit = 100 s:refresh() if ns.relayout then ns.relayout() end end}
      end
      active = state.cls or "*"
    elseif g and g[3] and #g[3] > 1 then
      sspecs[1] = {"*", "All " .. g[2]:lower(), pick = function() state.sub = nil applyTabs() state.limit = 100 s:refresh() if ns.relayout then ns.relayout() end end}
      for _, k in ipairs(g[3]) do
        sspecs[#sspecs + 1] = {k, momentLabel(k), pick = function() state.sub = k applyTabs() state.limit = 100 s:refresh() if ns.relayout then ns.relayout() end end}
      end
      active = state.sub or "*"
    end
    if #sspecs > 0 then y = flowTabs(self.subs, sspecs, active, y - 2, w, true)
    else for _, b in ipairs(self.subs) do b:Hide() end end
    return -y + 4
  end
  local search = W.edit(s, 190)
  local ph = W.hint(search, "Search lines")
  ph:SetPoint("LEFT", 2, 0)
  search:SetScript("OnTextChanged", function(self)
    state.search = (self:GetText() or ""):lower()
    ph:SetShown(state.search == "")
    changed()
  end)
  s.search = search
  applyTabs()
  -- open a tab by name (the tabs call this; the tests do too)
  function s:pickTab(group, sub)
    state.group, state.sub, state.cls = group, sub, nil
    applyTabs()
    state.limit = 100
    self:refresh()
  end

  s.count = W.heading(s, "")
  s.rows = {}
  local allOn = W.button(s, "Turn all back on", 140, function()
    for k in pairs(cdb().off) do cdb().off[k] = nil end
    s:refresh()
  end)
  W.tooltip(allOn, "Turn all back on", "Every line you switched off for this character comes back.")
  s.allOn = allOn
  local moreBtn = W.button(s, "Show 100 more", 140, function() state.limit = state.limit + 100 s:refresh() if ns.relayout then ns.relayout() end end)
  s.moreBtn = moreBtn

  local function rowFor(i)
    if s.rows[i] then return s.rows[i] end
    local r = CreateFrame("Frame", nil, s)
    r:SetHeight(46)
    r.check = W.check(r, "")
    r.check:SetPoint("LEFT", 0, 0)
    r.txt = W.text(r, "", "GameFontHighlight")
    r.txt:SetPoint("TOPLEFT", 28, -3)
    r.txt:SetWordWrap(false)
    r.sub = W.hint(r, "")
    r.sub:SetPoint("TOPLEFT", r.txt, "BOTTOMLEFT", 0, -2)
    r.sub:SetWordWrap(false)
    r.trig = W.hint(r, "")
    r.trig:SetPoint("TOPLEFT", r.sub, "BOTTOMLEFT", 0, -2)
    r.trig:SetWordWrap(false)
    r.hear = W.button(r, "Hear", 54)
    r.hear:SetPoint("RIGHT", 0, 0)
    W.tooltip(r.hear, "Hear", "Prints the line to your own chat window only.")
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
      if not self.trigFull or self.trigFull == "" then return end
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:SetText("Can trigger on", 1, 0.82, 0)
      GameTooltip:AddLine(self.trigFull, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    s.rows[i] = r
    return r
  end

  -- every line for the ticked moments (all of them when none are ticked), each line once
  local function gather()
    local keys, any = {}, next(state.moments) ~= nil
    for _, it in ipairs(momentItems) do if not any or state.moments[it[1]] then keys[#keys + 1] = it[1] end end
    local out, seen = {}, {}
    for _, m in ipairs(keys) do
      for _, o in ipairs(linesFor(m)) do
        local prior = seen[o.id]
        if prior then
          prior.mlist[#prior.mlist + 1] = momentLabel(m)
          prior.mkeys[#prior.mkeys + 1] = m
        else
          o.mlist = {m:find("^x:") and "" or momentLabel(m)}
          o.mkeys = {m}
          seen[o.id] = o
          out[#out + 1] = o
        end
      end
    end
    return out
  end

  function s:refresh()
    local hdr = self:flowHeader(self.w or 600)
    self.search:ClearAllPoints()
    self.search:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -(hdr + 4))
    local trigCache = {}
    local function trigger(o)
      local names, seen, plain = {}, {}, {}
      for _, m in ipairs(o.mkeys or {}) do
        local t = trigCache[m]
        if not t then
          local ab, text = triggersFor(m)
          t = {ab = ab, text = text}
          trigCache[m] = t
        end
        for _, n in ipairs(t.ab or {}) do if not seen[n] then seen[n] = true names[#names + 1] = n end end
        if t.text and not seen[t.text] then seen[t.text] = true plain[#plain + 1] = t.text end
      end
      table.sort(names)
      local parts = {}
      if #names > 0 then parts[#parts + 1] = table.concat(names, ", ") end
      for _, t in ipairs(plain) do parts[#parts + 1] = t end
      local full = table.concat(parts, "; ")
      local short = full
      if #names > 6 then
        local first = {}
        for i = 1, 6 do first[i] = names[i] end
        short = table.concat(first, ", ") .. (" +%d more"):format(#names - 6)
        if #plain > 0 then short = short .. "; " .. table.concat(plain, "; ") end
      end
      return short, full
    end
    local shown, locked = {}, {}
    local hide = cdb().lineHide
    if not hide then hide = {} cdb().lineHide = hide end
    local kindCount, hiddenN = {}, 0
    for _, o in ipairs(gather()) do
      o.locked, o.other = nil, nil
      local okSrc = not next(state.sources) or state.sources[sourceKind(o)]
      local okSearch = state.search == "" or o.line.t:lower():find(state.search, 1, true)
      if okSrc and okSearch then
        local list
        if state.view == "others" then
          -- another class's tag or spec lines (anything else that is blocked stays hidden)
          local cls = o.cls or o.id:match("^tag:class:([^|]+)")
          if cls and cls ~= ns.profile.class and (not state.cls or cls == state.cls) and canSay(o, "other") then o.locked, o.other = true, cls list = shown end
        elseif canSay(o) then list = shown
        elseif o.cls and o.cls == ns.profile.class and canSay(o, "spec") then o.locked = true list = locked end    -- a spec line you could unlock
        if list then
          local k = sourceKind(o)
          kindCount[k] = (kindCount[k] or 0) + 1
          if hide[k] then hiddenN = hiddenN + 1 else list[#list + 1] = o end
        end
      end
    end
    -- tag chips: one per kind of line in this tab; click one to hide those lines, click again to bring them back
    local chipKinds = {}
    for _, it in ipairs(SOURCE_LIST) do if kindCount[it[1]] or hide[it[1]] then chipKinds[#chipKinds + 1] = it[1] end end
    local chipBottom = 0
    self.chips = self.chips or {}
    if #chipKinds > 1 or next(hide) then
      if not self.chipLabel then self.chipLabel = W.hint(self, "Show lines tagged:") end
      self.chipLabel:ClearAllPoints()
      self.chipLabel:SetPoint("TOPLEFT", 8, -(hdr + 34))
      self.chipLabel:Show()
      local x, row, w = 110, 0, self.w or 600
      for i, k in ipairs(chipKinds) do
        local b = self.chips[i]
        if not b then
          b = CreateFrame("Button", nil, self)
          b:SetHeight(20)
          b.bg = b:CreateTexture(nil, "BACKGROUND")
          b.bg:SetAllPoints()
          b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          b.label:SetPoint("CENTER")
          self.chips[i] = b
        end
        local off = hide[k] == true
        b.kind = k
        b.label:SetText(("%s (%d)"):format(CHIP_LABEL[k] or k, kindCount[k] or 0))
        b.label:SetTextColor(off and 0.5 or 1, off and 0.5 or 0.82, off and 0.5 or 0.2)
        b.bg:SetColorTexture(off and 0 or 0.18, off and 0 or 0.14, off and 0 or 0.06, off and 0.45 or 0.9)
        b.off = off
        b:SetWidth((b.label:GetStringWidth() or 40) + 16)
        if x + b:GetWidth() > w - 6 and x > 110 then x = 110 row = row + 1 end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, -(hdr + 31 + row * 24))
        x = x + b:GetWidth() + 4
        b:SetScript("OnClick", function(self)
          W.sound(hide[self.kind] and "check" or "uncheck")
          hide[self.kind] = (not hide[self.kind]) or nil
          state.limit = 100
          s:refresh() if ns.relayout then ns.relayout() end
        end)
        b:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText(CHIP_LABEL[self.kind] or self.kind, 1, 0.82, 0)
          GameTooltip:AddLine(self.off and "Hidden from this list. Click to show them again. This only changes what you see here, not what the character says."
            or "Click to hide these lines from the list while you look for something. This only changes what you see here, not what the character says.", 1, 1, 1, true)
          GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Show()
      end
      for i = #chipKinds + 1, #self.chips do self.chips[i]:Hide() end
      chipBottom = 3 + (row + 1) * 24
    else
      if self.chipLabel then self.chipLabel:Hide() end
      for _, b in ipairs(self.chips) do b:Hide() end
    end
    local sayable = state.view == "others" and 0 or #shown
    for _, o in ipairs(locked) do shown[#shown + 1] = o end      -- locked ones come last
    if state.view == "others" then
      self.count:SetText(("%d line%s from other classes (to look at only)"):format(#shown, #shown == 1 and "" or "s"))
    else
      self.count:SetText(("%d line%s your character can say%s"):format(sayable, sayable == 1 and "" or "s",
        #locked > 0 and (" · " .. #locked .. " more to unlock") or "")
        .. (hiddenN > 0 and (" · " .. hiddenN .. " hidden by tags") or ""))
    end
    self.count:ClearAllPoints()
    self.count:SetPoint("TOPLEFT", 8, -(hdr + 8))
    for _, r in ipairs(self.rows) do r:Hide() end
    local y = -(hdr + 32 + chipBottom)
    local limit = math.min(#shown, state.limit)
    for i = 1, limit do
      local o = shown[i]
      local r = rowFor(i)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 4, y)
      r:SetPoint("RIGHT", self, "RIGHT", -4, 0)
      local off = cdb().off[o.id] == true
      local text = o.line.e and ((ns.profile.name or "") .. " " .. o.line.t) or o.line.t
      if cdb().filter and o.line.c then text = o.line.c end
      r.txt:SetText((off or o.locked) and ("|cff808080" .. text .. "|r") or text)
      local tags = {}
      local ml = table.concat(o.mlist or {}, ", ")
      if ml ~= "" then tags[#tags + 1] = ml end
      if o.line.o then tags[#tags + 1] = o.line.o .. " only" end
      if o.line.r then tags[#tags + 1] = "rating " .. o.line.r end
      local n = cdb().said[o.id] or 0
      r.sub:SetText(("%s%s · %s"):format(o.src, #tags > 0 and (" · " .. table.concat(tags, ", ")) or "",
        o.other and ("|cff999999" .. cap(o.other:lower()) .. " only|r - not available to this character")
          or o.locked and ("|cffcc9933locked|r - " .. (off and "stays off" or "switches on by itself") .. " once you spend more talent points in " .. (o.tree or "this tree"))
          or (off and "switched off" or ("said " .. n .. " time" .. (n == 1 and "" or "s")))))
      local tshort, tfull = trigger(o)
      if o.own then tshort, tfull = "", "" end
      r.trig:SetText(tshort ~= "" and ("Can trigger on: " .. tshort) or "")
      r.trigFull = tfull
      r.check:SetChecked(not off and not o.other)
      if r.check.SetEnabled then r.check:SetEnabled(not o.locked) end
      r.check:SetScript("OnClick", function(self)
        if o.locked then self:SetChecked(false) return end      -- a locked line can be seen, never switched on
        if o.own then o.own.on = self:GetChecked() and true or false
        else cdb().off[o.id] = (not self:GetChecked()) or nil end
        W.sound(self:GetChecked() and "check" or "uncheck")
        s:refresh()
      end)
      r.hear:SetScript("OnClick", function()
        p("|cffffffff" .. (o.line.e and text or ("\"" .. text .. "\"")) .. "|r  (only you see this)")
      end)
      r:Show()
      y = y - 50
    end
    if #shown > limit then
      self.moreBtn:SetText(("Show %d more (%d left)"):format(math.min(100, #shown - limit), #shown - limit))
      self.moreBtn:SetWidth(200)
      self.moreBtn:ClearAllPoints()
      self.moreBtn:SetPoint("TOPLEFT", 8, y - 4)
      self.moreBtn:Show()
      y = y - 30
    else self.moreBtn:Hide() end
    self.allOn:ClearAllPoints()
    self.allOn:SetPoint("TOPLEFT", 8, y - 8)
    self.height = -y + 44
  end
  function s:layout(w)
    for _, r in ipairs(self.rows) do r.txt:SetWidth(w - 100) r.sub:SetWidth(w - 100) r.trig:SetWidth(w - 100) end
    if self.w ~= w then self.w = w self:refresh() end          -- the tabs wrap to the width
    return self.height or 200
  end
  s._state = state
  return s
end

------------------------------------------------------------------------
-- Section: Credits
------------------------------------------------------------------------
-- Every slash command, in one place: the Commands section and /x help both read this list
local COMMANDS = {
  {"/x", "Open or close this window."},
  {"/x setup", "Go to the Setup page."},
  {"/x flag", "Review your recent fights and flag lines that felt wrong."},
  {"/x export", "Copy your session log to paste into Discord, a form or an email."},
  {"/x testdata", "Copy the data testing mode collected, with how to send it."},
  {"/x sim", "Open the combat simulator."},
  {"/x test", "Say why your last button presses stayed quiet."},
  {"/x bug", "Build a short bug report to copy and send."},
  {"/x probe", "Show what this game client lets cro/x read (talents, professions)."},
  {"/x on  ·  /x off", "Turn cro/x on or off for this character."},
  {"/x reset", "Put every option back to the defaults (it asks first)."},
  {"/x debug", "Show or hide error messages in chat."},
  {"/x help", "List these commands in chat."},
  {"/crox", "The same as /x, if another addon already uses /x."},
}

local function buildCommands(parent)
  local s = CreateFrame("Frame", nil, parent)
  ns.paintArea(s, "page", 0.55)
  s.rows = {}
  local intro = W.hint(s, "Type these in chat. Key binding: Key Bindings > AddOns > cro/x > Review a fight.")
  intro:SetPoint("TOPLEFT", 4, -4)
  for i, c in ipairs(COMMANDS) do
    local cmd = W.text(s, c[1], "GameFontNormal")
    local desc = W.text(s, c[2], "GameFontHighlightSmall")
    desc:SetWordWrap(true)
    s.rows[i] = {cmd = cmd, desc = desc}
  end
  function s:layout(w)
    local y = -28
    local dw = math.max(120, w - 190)
    for _, r in ipairs(self.rows) do
      r.cmd:ClearAllPoints()
      r.cmd:SetPoint("TOPLEFT", 8, y)
      r.desc:ClearAllPoints()
      r.desc:SetPoint("TOPLEFT", 160, y - 1)
      r.desc:SetWidth(dw)
      local h = math.max(18, (r.desc:GetStringHeight() or 14) + 6)
      y = y - h
    end
    return -y + 16
  end
  return s
end

local function buildCredits(parent)
  local s = CreateFrame("Frame", nil, parent)
  ns.paintArea(s, "page", 0.55)
  s.items = {}
  local intro = W.hint(s, "Where every asset and source in cro/x comes from.")
  intro:SetPoint("TOPLEFT", 4, -4)
  s.intro = intro
  for _, group in ipairs(CROX2_CREDITS or {}) do
    s.items[#s.items + 1] = {head = W.heading(s, group.heading)}
    for _, it in ipairs(group.items) do
      local fs = W.text(s, "", "GameFontHighlightSmall")
      fs:SetWordWrap(true)
      local lines = {"|cffffffff" .. it.what .. "|r"}
      if it.by then lines[#lines + 1] = "By " .. it.by end
      if it.source then lines[#lines + 1] = "Source: " .. it.source end
      if it.url then lines[#lines + 1] = "|cff999999" .. it.url .. "|r" end
      if it.license then lines[#lines + 1] = "License: " .. it.license end
      if it.used then lines[#lines + 1] = "Used for: " .. it.used end
      fs:SetText(table.concat(lines, "\n"))
      s.items[#s.items + 1] = {text = fs}
    end
  end
  function s:layout(w)
    local y = -24
    for _, it in ipairs(self.items) do
      local r = it.head or it.text
      r:ClearAllPoints()
      if it.head then
        y = y - 6
        r:SetPoint("TOPLEFT", 4, y)
        y = y - 20
      else
        r:SetPoint("TOPLEFT", 12, y)
        r:SetWidth(w - 20)
        y = y - (r:GetStringHeight() or 60) - 10
      end
    end
    return -y + 20
  end
  return s
end

------------------------------------------------------------------------
-- The main window
------------------------------------------------------------------------
local SECTIONS = {{"home", "Setup", buildHome}, {"options", "Options", buildOptions},
  {"phrases", "My phrases", buildPhrases}, {"lines", "Lines", buildLines}, {"commands", "Commands", buildCommands}, {"credits", "Credits", buildCredits}}

local hordePage, alliancePage, scrollFrame, scrollChild, listFrame

local function showSection(key)
  current = key
  for k, s in pairs(sections) do s:SetShown(k == key) end
  if sections.home and sections.home.show then sections.home.show:SetShown(key == "home") end
  if hordePage and hordePage.dim then hordePage.dim:SetAlpha(key == "home" and 0.3 or 0.66) end
  for k, b in pairs(sectionButtons) do
    if k == key then b:LockHighlight() b.text:SetFontObject("GameFontHighlight") else b:UnlockHighlight() b.text:SetFontObject("GameFontNormal") end
  end
  if sections[key].refresh then sections[key]:refresh() end
  W.sound("click")
  if ns.relayout then ns.relayout() end
end

local function relayout()
  if not main or not listFrame or not scrollFrame or not sections then return end    -- the window is still being built
  local fw, fh = main:GetWidth(), main:GetHeight()
  local auto = math.max(0.85, math.min(1.15, fw / BASE_W))
  local scale = auto * (cdb().textScale or 1)
  body:SetScale(scale)
  local bw, bh = (fw - 16) / scale, (fh - 60) / scale
  body:SetSize(bw, bh)
  -- narrower than about twice the section list: the list moves on top
  local narrow = bw < LIST_W * 2 + 240
  listFrame:ClearAllPoints()
  scrollFrame:ClearAllPoints()
  local prev
  for i, sd in ipairs(SECTIONS) do
    local b = sectionButtons[sd[1]]
    b:ClearAllPoints()
    if narrow then
      b:SetSize((bw - 16) / #SECTIONS, 22)
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -4) end
    else
      b:SetSize(LIST_W - 8, 22)
      if prev then b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2) else b:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -4) end
    end
    prev = b
  end
  if narrow then
    listFrame:SetPoint("TOPLEFT", hordePage, "TOPLEFT", 0, 0)
    listFrame:SetPoint("TOPRIGHT", hordePage, "TOPRIGHT", 0, 0)
    listFrame:SetHeight(30)
    scrollFrame:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 6, -4)
  else
    listFrame:SetPoint("TOPLEFT", hordePage, "TOPLEFT", 0, 0)
    listFrame:SetPoint("BOTTOMLEFT", hordePage, "BOTTOMLEFT", 0, 0)
    listFrame:SetWidth(LIST_W)
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 8, -4)
  end
  scrollFrame:SetPoint("BOTTOMRIGHT", hordePage, "BOTTOMRIGHT", -26, 4)
  -- worked out from the window's own size, not read back from the scroll frame: right after a scale change the frame
  -- still reports its old width for a moment, and the text would wrap to it
  local cw = narrow and (bw - 32) or (bw - LIST_W - 34)
  scrollChild:SetWidth(cw)
  local s = sections[current]
  if s then
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    s:SetWidth(cw)
    local h = s.layout and s:layout(cw) or 400
    if s.fill then h = math.max(h, scrollFrame:GetHeight() or 0) end   -- a picture section runs to the bottom of the window
    s:SetHeight(h)
    scrollChild:SetHeight(h)
  end
end
ns.relayout = relayout

local function saveWindow()
  local l, t = main:GetLeft(), main:GetTop()
  if not l then return end
  cdb().window = {w = main:GetWidth(), h = main:GetHeight(), x = l, y = t}
end

function ns.resetWindow()
  if not main then return end
  main:ClearAllPoints()
  main:SetSize(BASE_W, BASE_H)
  -- bottom right, like the first alpha
  main:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
  relayout()
end

local function selectTab(id)
  if PanelTemplates_SetTab then pcall(PanelTemplates_SetTab, main, id) end
  hordePage:SetShown(id == 1)
  alliancePage:SetShown(id == 2)
  W.sound("tab")
  relayout()
end

local function buildMain()
  main = W.panel("CROX2MainFrame", "Combat Roleplay Options - cro/x", BASE_W, BASE_H)
  main.onMoved = saveWindow
  -- the Horde crest beside the title
  local crest = main:CreateTexture(nil, "OVERLAY")
  crest:SetTexture(W.HORDE_CREST)
  crest:SetTexCoord(0, 0.62, 0, 0.62)
  crest:SetSize(20, 20)
  crest:SetPoint("TOPLEFT", 6, -2)

  -- resizing: the grip in the bottom-right corner
  main:SetResizable(true)
  if main.SetResizeBounds then main:SetResizeBounds(420, 360, 1100, 860)
  elseif main.SetMinResize then main:SetMinResize(420, 360) main:SetMaxResize(1100, 860) end
  local grip = CreateFrame("Button", nil, main)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -4, 4)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() main:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function() main:StopMovingOrSizing() saveWindow() relayout() end)
  main:SetScript("OnSizeChanged", function() relayout() end)

  body = CreateFrame("Frame", nil, main)
  body:SetPoint("TOPLEFT", 8, -28)

  hordePage = CreateFrame("Frame", nil, body)
  hordePage:SetAllPoints()
  -- the Horde poster sits behind every page, fixed in place while the page scrolls over it; the page is dimmed
  -- more on the text-heavy pages (Setup keeps the picture bright)
  local pageBG = CreateFrame("Frame", nil, hordePage)
  pageBG:SetAllPoints()
  posterBG(pageBG)
  hordePage.dim = pageBG:CreateTexture(nil, "BACKGROUND", nil, 0)
  hordePage.dim:SetAllPoints()
  hordePage.dim:SetColorTexture(0, 0, 0, 1)
  hordePage.dim:SetAlpha(0.3)
  alliancePage = CreateFrame("Frame", nil, body)
  alliancePage:SetAllPoints()
  alliancePage.art = allianceArt(alliancePage, false)
  alliancePage.art:SetAllPoints()
  local note = W.hint(alliancePage.art, "What Alliance characters see when they type /x.")
  note:SetPoint("BOTTOM", 0, 14)

  listFrame = CreateFrame("Frame", nil, hordePage)
  for _, sd in ipairs(SECTIONS) do
    local b = CreateFrame("Button", nil, listFrame)
    b.text = W.text(b, sd[2], "GameFontNormal")
    b.text:SetPoint("LEFT", 8, 0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    b:SetScript("OnClick", function() showSection(sd[1]) end)
    sectionButtons[sd[1]] = b
  end
  scrollFrame, scrollChild = W.scroll(hordePage)
  sections = {}
  ns._sections = sections
  for _, sd in ipairs(SECTIONS) do
    local s = sd[3](scrollChild)
    s:Hide()
    sections[sd[1]] = s
  end

  -- the Setup page's login switch sits in the window's bottom left corner, under the section list
  if sections.home and sections.home.show then
    local sh = sections.home.show
    sh:SetParent(hordePage)
    sh:ClearAllPoints()
    sh:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 12, 5)
    sh:SetShown(current == "home")
  end

  -- tabs along the bottom edge, as on the character sheet
  local tabs = {}
  for i, label in ipairs({"Horde", "Alliance"}) do
    local t = W.make("Button", main, {"CharacterFrameTabButtonTemplate", "PanelTabButtonTemplate", "TabButtonTemplate"}, "CROX2MainFrameTab" .. i)
    t:SetID(i)
    t:SetText(label)
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, t, 0) end
    if i == 1 then t:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 12, 2) else t:SetPoint("LEFT", tabs[i - 1], "RIGHT", -16, 0) end
    t:SetScript("OnClick", function() selectTab(i) end)
    tabs[i] = t
  end
  main.Tabs = tabs
  main.numTabs = 2
  if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, main, 2) end

  -- size and place: remembered, or bottom right
  local wdb = cdb().window
  main:ClearAllPoints()
  if wdb and wdb.w and wdb.w >= 700 and wdb.h >= 560 then
    main:SetSize(wdb.w, wdb.h)
    main:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", wdb.x, wdb.y)
  else
    main:SetSize(BASE_W, BASE_H)
    main:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
  end
  main:HookScript("OnShow", function()
    if sections[current or "home"] then showSection(current or "home") end
  end)
  -- closing the window the first time (without pressing Done) still finishes setup and offers the lines
  main:HookScript("OnHide", function()
    if cdb() and not cdb().setupDone and not ns.isAlliance() then
      cdb().setupDone = true
      p("all set. Type /x any time to change things.")
      if ns.showNextStep then pcall(ns.showNextStep) end
    end
  end)
  current = "home"
  selectTab(1)
end

function ns.closeMain() if main and main:IsShown() then main:Hide() end end

function ns.toggleMain()
  if ns.isAlliance() then ns.showAlliance() return end
  if not main then buildMain() end
  if main:IsShown() then main:Hide() else main:Show() end
end

-- Reset: back to defaults, then the splash again so setup starts over
local resetDlg
function ns.doReset()
  if main then main:Hide() end
  ns.resetAll()
  if ns.resetWindow then pcall(ns.resetWindow) end
  pcall(ns.updateMinimap)
  p("reset to the defaults.")
  ns.showSplash()
end
function ns.confirmReset()
  if ns.isAlliance() then return end
  if not resetDlg then
    resetDlg = W.panel("CROX2ResetFrame", "cro/x - reset everything?", 440, 220)
    local page = CreateFrame("Frame", nil, resetDlg)
    page:SetPoint("TOPLEFT", 8, -26)
    page:SetPoint("BOTTOMRIGHT", -8, 8)
    ns.paintArea(page, "page", 0.55)
    local t = W.text(resetDlg, "This puts every cro/x option and your character's choices back to the defaults, " ..
      "turns all lines back on, and brings the Setup page back so you can set up again.", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 24, -44)
    t:SetWidth(392)
    t:SetWordWrap(true)
    local keep = W.hint(resetDlg, "Your own phrases are kept.")
    keep:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10)
    local go = W.button(resetDlg, "Reset everything", 140, function() resetDlg:Hide() ns.doReset() end)
    go:SetPoint("BOTTOMLEFT", 24, 22)
    local no = W.button(resetDlg, "Cancel", 90, function() resetDlg:Hide() end)
    no:SetPoint("BOTTOMRIGHT", -24, 22)
  end
  resetDlg:Show()
end

-- open the main window on one section (home, options, phrases, lines, credits)
function ns.openSection(key)
  if ns.isAlliance() then ns.showAlliance() return end
  if not main then buildMain() end
  main:Show()
  selectTab(1)
  if sections[key] then showSection(key) end
end

function ns.refreshUI()
  if main and main:IsShown() and current and sections[current] and sections[current].refresh then
    sections[current]:refresh()
    relayout()
  end
end

------------------------------------------------------------------------
-- Minimap button (off by default)
------------------------------------------------------------------------
local mm
function ns.updateMinimap()
  if not cdb() then return end
  if not cdb().minimap then if mm then mm:Hide() end return end
  if not mm and Minimap then
    mm = CreateFrame("Button", "CROX2MinimapButton", Minimap)
    mm:SetSize(31, 31)
    mm:SetFrameLevel(8)
    mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = mm:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(W.HORDE_CREST)
    icon:SetTexCoord(0, 0.62, 0, 0.62)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    local border = mm:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    local function place()
      local a = math.rad(ns.db.minimap.angle or 200)
      mm:ClearAllPoints()
      mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
    end
    mm:RegisterForDrag("LeftButton")
    mm:SetScript("OnDragStart", function(self)
      self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local sc = Minimap:GetEffectiveScale()
        ns.db.minimap.angle = math.deg(math.atan2(cy / sc - my, cx / sc - mx))
        place()
      end)
    end)
    mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mm:SetScript("OnClick", function() ns.toggleMain() end)
    W.tooltip(mm, "cro/x", "Click to open. Drag to move.")
    place()
  end
  if mm then mm:Show() end
end

------------------------------------------------------------------------
-- Slash commands: /x, with /crox as a second command that always works
------------------------------------------------------------------------
local function help()
  for _, c in ipairs(COMMANDS) do p(c[1] .. " - " .. c[2]) end
end

SLASH_CROX1 = "/x"
SLASH_CROX2 = "/crox"
SlashCmdList["CROX"] = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if not ns.cdb then return end
  if ns.isAlliance() then ns.showAlliance() return end
  if msg == "" then ns.toggleMain()
  elseif msg == "flag" then ns.Log.openReview()
  elseif msg == "export" then ns.Log.openExport()
  elseif msg == "setup" then ns.openSetup()
  elseif msg == "splash" then ns.showSplash()   -- the old name
  elseif msg == "reset" then ns.confirmReset()
  elseif msg == "probe" then ns.Bug.probe()
  elseif msg == "bug" or msg == "report" then ns.Bug.open()
  elseif msg == "testdata" then ns.Log.openTestData()
  elseif msg == "sim" then ns.Sim.open()
  elseif msg == "test" then ns.Bug.test()
  elseif msg == "on" then ns.cdb.on = true p("on.")
  elseif msg == "off" then ns.cdb.on = false p("off.")
  elseif msg == "debug" then ns.debug = not ns.debug p("debug " .. (ns.debug and "on" or "off"))
  else help() end
end

-- key binding (Key Bindings > AddOns > cro/x)
BINDING_HEADER_CROX2 = "cro/x"
BINDING_NAME_CROX2_FLAG = "Review a fight"
function CROX2_FlagBinding() if ns.Log then ns.Log.openReview() end end

------------------------------------------------------------------------
-- Painted areas: the art is fixed (plain dark behind setup, Credits and the Character section); players don't choose it
------------------------------------------------------------------------
-- paint a frame; dim = how dark (0 none .. 1 black)
function ns.paintArea(frame, key, dim)
  local rec = {frame = frame, key = key, dim = dim or 0.5}
  rec.shade = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  rec.shade:SetAllPoints(frame)
  local e = key == "charBg" and W.BACKGROUNDS[1] or W.PAGES[1]
  rec.holder = W.paint(frame, e, rec.holder)
  rec.holder:SetFrameLevel(math.max(0, frame:GetFrameLevel() or 0))
  for _, t in ipairs(rec.holder.tex or {}) do t:SetDrawLayer("BACKGROUND", -1) end
  rec.shade:SetColorTexture(0, 0, 0, e.none and 0 or rec.dim)
  return rec
end

------------------------------------------------------------------------
-- Splash page at login
------------------------------------------------------------------------

-- Shown once, right after setup is finished for the first time: look through the lines or add your own
local nextStep
local function showNextStep()
  if not nextStep then
    nextStep = W.panel("CROX2NextFrame", "cro/x - you're all set", 440, 210)
    local page = CreateFrame("Frame", nil, nextStep)
    page:SetPoint("TOPLEFT", 8, -26)
    page:SetPoint("BOTTOMRIGHT", -8, 8)
    ns.paintArea(page, "page", 0.55)
    local t = W.text(nextStep, "Your character's choices are saved. Want to go into the addon now to pick which lines " ..
      "they say, or add some of your own?", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 24, -44)
    t:SetWidth(392)
    t:SetWordWrap(true)
    local h = W.hint(nextStep, "You can do either at any time: type /x, then Lines or My phrases.")
    h:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10)
    h:SetWidth(392)
    local browse = W.button(nextStep, "Choose lines", 120, function() nextStep:Hide() ns.openSection("lines") end)
    browse:SetPoint("BOTTOMLEFT", 24, 22)
    local mine = W.button(nextStep, "Add my own lines", 140, function() nextStep:Hide() ns.openSection("phrases") end)
    mine:SetPoint("LEFT", browse, "RIGHT", 8, 0)
    local later = W.button(nextStep, "Not now", 90, function() nextStep:Hide() end)
    later:SetPoint("BOTTOMRIGHT", -24, 22)
  end
  nextStep:Show()
end
ns.showNextStep = showNextStep

-- The setup page is the first section of the main window; these keep the old names working
-- (/x setup, /x splash, "Redo setup", reset, and the login page).
function ns.showSplash()
  if ns.isAlliance() then return end
  ns.openSection("home")
end
function ns.openSetup() ns.showSplash() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  pcall(ns.updateMinimap)
  if not ns.cdb or ns.isAlliance() or not ns.cdb.on then return end
  if ns.cdb.testing then p("testing mode is ON (collecting extra data). /x testdata to copy it, /x sim for the combat simulator.") end
  -- first run always opens it (that's where the choices are made); after that, only if "Open to this page at login" is on
  if ns.cdb.splash or not ns.cdb.setupDone then
    C_Timer.After(1.5, function() pcall(ns.showSplash) end)
  end
end)

