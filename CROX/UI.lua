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
local CHOICES = {{"temperament", "Temperament"}, {"homeland", "Homeland"}, {"upbringing", "Upbringing"},
  {"drive", "What drives them"}, {"pronouns", "Pronouns"}}
ns.CHOICES = CHOICES

local SPLASH_HINTS = {pronouns = "Used in emotes"}

-- The first section, and the first thing you see: who the character is and how they speak. It replaces the old
-- Character tab and the splash page. The poster sits behind it, whole, fitted inside the area.
local function buildHome(parent)
  local s = CreateFrame("Frame", nil, parent)
  posterBG(s)
  local dim = s:CreateTexture(nil, "BACKGROUND", nil, 0)
  dim:SetAllPoints()
  dim:SetColorTexture(0, 0, 0, 0.3)

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
  s.who = W.text(s, "", "GameFontHighlight")
  s.who:SetPoint("TOP", card, "BOTTOM", 0, -6)

  local function dark(f)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(0, 0, 0, 0.62)
  end

  -- who are you: the five choices, each with a line of flavor, then an example line
  local plate = CreateFrame("Frame", nil, s)
  plate:SetPoint("TOP", s.who, "BOTTOM", 0, -12)
  plate:SetPoint("LEFT", s, "LEFT", 8, 0)
  plate:SetPoint("RIGHT", s, "RIGHT", -8, 0)
  plate:SetHeight(40 + #CHOICES * 34 + 44)
  dark(plate)
  local head = W.heading(plate, "Who are you?")
  head:SetPoint("TOP", plate, "TOP", 0, -10)
  local grp = CreateFrame("Frame", nil, plate)
  grp:SetSize(560, #CHOICES * 34)
  grp:SetPoint("TOP", plate, "TOP", 0, -34)
  s.grp = grp
  s.dds, s.hints = {}, {}
  for i, ch in ipairs(CHOICES) do
    local kind = ch[1]
    local y = -(i - 1) * 34
    local label = W.text(grp, ch[2], "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, y - 6)
    local dd = W.dropdown(grp, 170, function() return choiceItems(kind) end, function() return cdb()[kind] end,
      function(v) cdb()[kind] = v s:refreshChoices(kind) end)
    dd:SetPoint("TOPLEFT", 100, y + 2)
    local hint = W.text(grp, "", "GameFontHighlightSmall")
    hint:SetPoint("LEFT", dd, "RIGHT", -2, 2)
    hint:SetPoint("RIGHT", grp, "RIGHT", 0, 0)
    hint:SetHeight(30)
    hint:SetWordWrap(true)
    hint:SetJustifyV("MIDDLE")
    s.dds[kind] = dd
    s.hints[kind] = hint
  end
  local ex = W.text(plate, "", "GameFontHighlight")
  ex:SetPoint("TOPLEFT", grp, "BOTTOMLEFT", 0, -8)
  ex:SetPoint("RIGHT", grp, "RIGHT", -84, 0)
  ex:SetHeight(32)
  ex:SetWordWrap(true)
  ex:SetJustifyV("TOP")
  s.example = ex
  local another = W.button(plate, "Another", 76, function() s:rollExample() end)
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
  local chattyDD, _, chattyHint = speakRow(1, "How chatty", "", ns.chattyItems, function() return cdb().chatty end,
    function(v) cdb().chatty = v s:refreshChoices() end,
    "How many lines a minute to expect in a fight. These are rough: the real rate depends on how fast you press. In a party the shared party pace still applies.")
  s.chattyDD, s.chattyHint = chattyDD, chattyHint
  local raidDD, _, raidHint = speakRow(2, "In a raid", "", ns.chattyItems, function() return cdb().raidChatty or 2 end,
    function(v) cdb().raidChatty = v s:refreshChoices() end,
    "How chatty in a raid, with the same five levels. Raids are noisy already, so this starts at Quiet.")
  s.raidDD, s.raidHint = raidDD, raidHint
  s.askDD = speakRow(3, "Ask for help", "How often you call for aid", CR_LEVELS, function() return cdb().crAsk or 4 end,
    function(v) cdb().crAsk = v end,
    "How often your character calls for help (a debuff, low health, an enemy on you) when a cro/x partymate could answer. Always means every time it fits.")
  s.giveDD = speakRow(4, "Answer a call", "How often you speak when helping", CR_LEVELS, function() return cdb().crGive or 4 end,
    function(v) cdb().crGive = v end,
    "How often your character says something when they answer a call. They still help either way; Rarely just means they usually do it quietly.")
  local trollDD, trollL, trollH = speakRow(5, "Troll voice", "Accent or plain",
    function() return {{"accent", "Accent"}, {"plain", "Plain"}} end, function() return cdb().troll end,
    function(v) cdb().troll = v s:refreshChoices() end,
    "Trolls speak with the accent from the first alpha's converter. Emotes and your own lines stay as written.")
  s.trollDD, s.trollL, s.trollH = trollDD, trollL, trollH
  local SWITCHES = {
    {"emotes", "Emotes", "Emotes stay a rare accent either way."},
    {"yell", "Allow /yell", "With this off, everything goes to /say, even calls to faraway allies."},
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
    grp2:SetHeight(gh)
    plate2:SetHeight(34 + gh + 10)
  end

  -- read from the game: professions and how deep the spec lines have unlocked
  local plate3 = CreateFrame("Frame", nil, s)
  plate3:SetPoint("TOP", plate2, "BOTTOM", 0, -8)
  plate3:SetPoint("LEFT", s, "LEFT", 8, 0)
  plate3:SetPoint("RIGHT", s, "RIGHT", -8, 0)
  plate3:SetHeight(92)
  dark(plate3)
  local head3 = W.heading(plate3, "Read from the game")
  head3:SetPoint("TOPLEFT", 14, -10)
  s.facts = W.text(plate3, "", "GameFontHighlight")
  s.facts:SetPoint("TOPLEFT", head3, "BOTTOMLEFT", 0, -4)
  s.facts:SetPoint("RIGHT", plate3, "RIGHT", -14, 0)
  s.facts:SetJustifyH("LEFT")
  s.spec = W.text(plate3, "", "GameFontHighlightSmall")
  s.spec:SetPoint("TOPLEFT", s.facts, "BOTTOMLEFT", 0, -6)
  s.spec:SetPoint("RIGHT", plate3, "RIGHT", -14, 0)
  s.spec:SetJustifyH("LEFT")
  local sh = W.hint(plate3, "Spec lines unlock as you spend talent points deeper in a tree.")
  sh:SetPoint("TOPLEFT", s.spec, "BOTTOMLEFT", 0, -3)

  -- the foot: done, choose lines, show at login
  local tip = W.hint(s, "Type /x any time to come back here  ·  /x flag to review a fight")
  tip:SetPoint("TOP", plate3, "BOTTOM", 0, -8)
  local foot = CreateFrame("Frame", nil, s)
  foot:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", -4, -8)
  foot:SetPoint("RIGHT", s, "RIGHT", -8, 0)
  foot:SetHeight(30)
  local ver = W.hint(foot, ns.BUILD)
  ver:SetPoint("LEFT", 6, 0)
  local done = W.button(foot, "Done", 90, function() s:finish(false) end)
  done:SetPoint("RIGHT", 0, 0)
  local lines = W.button(foot, "Choose lines", 110, function() s:finish(true) end)
  lines:SetPoint("RIGHT", done, "LEFT", -6, 0)
  W.tooltip(lines, "Choose lines", "Go and pick which lines your character says, or add some of your own.")
  local show = W.check(foot, "Open to this page at login", function(_, on) cdb().splash = on and true or false end)
  show:SetPoint("RIGHT", lines, "LEFT", -150, 0)
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
    self.chattyHint:SetText(est(c.chatty or 3))
    self.raidHint:SetText(est(c.raidChatty or 2))
    self:layoutSpeak()
    local pf = ns.profile
    self.who:SetText(("%s · %s %s"):format(pf.name or "", pf.race or "", cap((pf.class or ""):lower())))
    self.facts:SetText("Professions: " .. profText())
    self.spec:SetText("Spec lines unlocked: " .. specText())
    self.show:SetChecked(c.splash ~= false)
  end
  function s:refresh() self:refreshChoices() end
  function s:layout(w)
    self.grp:SetWidth(math.max(380, math.min(640, w - 40)))
    local h = 6 + 54 + 6 + 18 + 12 + plate:GetHeight() + 8 + plate2:GetHeight() + 8 + plate3:GetHeight() + 8 + 14 + 8 + 30 + 16
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
  check("profLines", "Profession lines", "Lines and emotes about your professions (cooking, mining, and so on), when you use food, potions or gather. Off: your professions are never mentioned.")
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
    function(v) cdb().textScale = v if ns.relayout then ns.relayout() end end, function(v) return ("%d%%"):format(v * 100 + 0.5) end)
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
    local src = k:find("^prof:") and ("Profession · " .. k:gsub("^prof:", "")) or ("Tag · " .. k:gsub(":", ": "))
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
local function canSay(o)
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
  if id:find("^tag:class:") then return id:find("^tag:class:" .. (pf.class or "") .. "|") ~= nil end
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
    if o.cls ~= pf.class then return false end
    return ((pf.spec or {})[o.tree] or 0) >= (o.band or 1)
  end
  if id:find("^summon:") then return pf.class == "WARLOCK" end
  return true
end

-- which kind of source a line comes from, for the source checkboxes
local SOURCE_LIST = {
  {"base", "Baseline"}, {"drive", "Tag: drive"}, {"up", "Tag: upbringing"}, {"home", "Tag: homeland"},
  {"class", "Tag: class"}, {"spec", "Spec lines"}, {"prof", "Professions"}, {"cr", "Call and response"},
  {"dmg", "Damage types"}, {"profemote", "Profession emotes"}, {"own", "My own lines"},
}
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

local function countKeys(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local function buildLines(parent)
  local s = CreateFrame("Frame", nil, parent)
  -- empty moments / sources = everything; ticking some narrows to just those, in any combination
  local state = {moments = {}, sources = {}, search = "", limit = 100, open = false}
  local momentItems = {}
  for _, l in ipairs({ARCH_LIST, MOMENT_LIST, EXTRA_LIST}) do for _, it in ipairs(l) do momentItems[#momentItems + 1] = it end end
  local function changed() state.limit = 100 s:refresh() if ns.relayout then ns.relayout() end end

  -- the set chooser
  local toggle = W.button(s, "", 250, function()
    local pn = s.picker
    if pn:IsShown() then pn:Hide()
    else
      state.open = true
      pn:ClearAllPoints()
      -- open where the mouse pointer is (the screen keeps it fully visible); under the button if that can't be read
      local cx, cy = 0, 0
      if GetCursorPosition then cx, cy = GetCursorPosition() end
      local sc = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
      if cx and cy and cx > 0 and cy > 0 and sc > 0 then
        pn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / sc - 16, cy / sc + 14)
      else
        pn:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -4)
      end
      pn:Show()
    end
  end)
  toggle:SetPoint("TOPLEFT", 4, 0)
  W.tooltip(toggle, "Choose sets of lines", "Opens checkboxes for moments (opener, kill, potions...) and sources (baseline, class, drive, spec...). " ..
    "Tick as many as you like, in any combination. With nothing ticked, every line shows.")
  local search = W.edit(s, 170)
  search:SetPoint("LEFT", toggle, "RIGHT", 14, 0)
  local ph = W.hint(search, "Search lines")
  ph:SetPoint("LEFT", 2, 0)
  search:SetScript("OnTextChanged", function(self)
    state.search = (self:GetText() or ""):lower()
    ph:SetShown(state.search == "")
    changed()
  end)
  -- the chooser is its own window that pops out at the pointer; it can be resized, and the checkboxes flow into
  -- as many columns as fit (two by default)
  local ROWH, COLW = 24, 172
  local saved = ns.db and ns.db.pickerSize
  local panel = W.panel("CROX2LinesPicker", "Choose sets of lines",
    saved and saved[1] or 2 * COLW + 56, saved and saved[2] or 470)
  panel:SetResizable(true)
  if panel.SetResizeBounds then panel:SetResizeBounds(2 * 100 + 56, 240, 1000, 900)
  elseif panel.SetMinResize then panel:SetMinResize(256, 240) panel:SetMaxResize(1000, 900) end
  local sf, content = W.scroll(panel)
  sf:SetPoint("TOPLEFT", 10, -30)
  sf:SetPoint("BOTTOMRIGHT", -30, 74)
  panel.mBoxes, panel.sBoxes = {}, {}
  local mHead = W.heading(content, "Moments")
  for _, it in ipairs(momentItems) do
    local key = it[1]
    panel.mBoxes[#panel.mBoxes + 1] = W.check(content, it[2], function(_, on) state.moments[key] = on or nil changed() end)
  end
  local sHead = W.heading(content, "Sources and tags")
  for _, it in ipairs(SOURCE_LIST) do
    local key = it[1]
    panel.sBoxes[#panel.sBoxes + 1] = W.check(content, it[2], function(_, on) state.sources[key] = on or nil changed() end)
  end
  local function flow()
    local w = panel:GetWidth() or (2 * COLW + 56)
    local cols = math.max(1, math.floor((w - 52) / COLW))
    local y = -2
    local function place(head, boxes)
      head:ClearAllPoints() head:SetPoint("TOPLEFT", 4, y)
      y = y - 24
      for i, c in ipairs(boxes) do
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", ((i - 1) % cols) * COLW, y - math.floor((i - 1) / cols) * ROWH)
      end
      y = y - math.ceil(#boxes / cols) * ROWH - 10
    end
    place(mHead, panel.mBoxes)
    place(sHead, panel.sBoxes)
    content:SetHeight(-y + 8)
  end
  panel:SetScript("OnSizeChanged", function() flow() end)
  flow()
  local grip = CreateFrame("Button", nil, panel)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -4, 4)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() panel:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    panel:StopMovingOrSizing()
    flow()
    if ns.db then ns.db.pickerSize = {math.floor(panel:GetWidth() + 0.5), math.floor(panel:GetHeight() + 0.5)} end
  end)
  panel.note = W.hint(panel, "Nothing ticked shows every line.")
  panel.note:SetPoint("BOTTOMLEFT", 14, 48)
  panel.clear = W.button(panel, "Clear ticks", 120, function()
    state.moments, state.sources = {}, {}
    for _, c in ipairs(panel.mBoxes) do c:SetChecked(false) end
    for _, c in ipairs(panel.sBoxes) do c:SetChecked(false) end
    changed()
  end)
  panel.clear:SetPoint("BOTTOMLEFT", 12, 14)
  panel.done = W.button(panel, "Done", 90, function() panel:Hide() end)
  panel.done:SetPoint("BOTTOMRIGHT", -28, 14)
  panel:HookScript("OnHide", function() state.open = false end)
  s:SetScript("OnHide", function() panel:Hide() end)
  s.picker = panel

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
    toggle:SetText(("Sets: %s · %s"):format(
      next(state.moments) and (countKeys(state.moments) .. " moment" .. (countKeys(state.moments) == 1 and "" or "s")) or "all moments",
      next(state.sources) and (countKeys(state.sources) .. " source" .. (countKeys(state.sources) == 1 and "" or "s")) or "all sources"))
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
    local shown = {}
    for _, o in ipairs(gather()) do
      local okSrc = not next(state.sources) or state.sources[sourceKind(o)]
      local okSearch = state.search == "" or o.line.t:lower():find(state.search, 1, true)
      if okSrc and okSearch and canSay(o) then shown[#shown + 1] = o end
    end
    self.count:SetText(("%d line%s your character can say"):format(#shown, #shown == 1 and "" or "s"))
    self.count:ClearAllPoints()
    self.count:SetPoint("TOPLEFT", 8, -32)
    for _, r in ipairs(self.rows) do r:Hide() end
    local y = -56
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
      r.txt:SetText(off and ("|cff808080" .. text .. "|r") or text)
      local tags = {}
      local ml = table.concat(o.mlist or {}, ", ")
      if ml ~= "" then tags[#tags + 1] = ml end
      if o.line.o then tags[#tags + 1] = o.line.o .. " only" end
      if o.line.r then tags[#tags + 1] = "rating " .. o.line.r end
      local n = cdb().said[o.id] or 0
      r.sub:SetText(("%s%s · %s"):format(o.src, #tags > 0 and (" · " .. table.concat(tags, ", ")) or "",
        off and "switched off" or ("said " .. n .. " time" .. (n == 1 and "" or "s"))))
      local tshort, tfull = trigger(o)
      if o.own then tshort, tfull = "", "" end
      r.trig:SetText(tshort ~= "" and ("Can trigger on: " .. tshort) or "")
      r.trigFull = tfull
      r.check:SetChecked(not off)
      r.check:SetScript("OnClick", function(self)
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
    return self.height or 200
  end
  s._state = state
  return s
end

------------------------------------------------------------------------
-- Section: Credits
------------------------------------------------------------------------
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
  {"phrases", "My phrases", buildPhrases}, {"lines", "Lines", buildLines}, {"credits", "Credits", buildCredits}}

local hordePage, alliancePage, scrollFrame, scrollChild, listFrame

local function showSection(key)
  current = key
  for k, s in pairs(sections) do s:SetShown(k == key) end
  for k, b in pairs(sectionButtons) do
    if k == key then b:LockHighlight() b.text:SetFontObject("GameFontHighlight") else b:UnlockHighlight() b.text:SetFontObject("GameFontNormal") end
  end
  if sections[key].refresh then sections[key]:refresh() end
  W.sound("click")
  if ns.relayout then ns.relayout() end
end

local function relayout()
  if not main then return end
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
  local cw = scrollFrame:GetWidth()
  if not cw or cw < 50 then cw = narrow and (bw - 40) or (bw - LIST_W - 40) end
  scrollChild:SetWidth(cw)
  local s = sections[current]
  if s then
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    s:SetWidth(cw)
    local h = s.layout and s:layout(cw) or 400
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
  p("/x - open the window · /x flag - review a fight · /x export - copy your log · /x setup - redo setup")
  p("/x reset - start over · /x probe - what this client offers")
  p("/x bug - report a problem · /x test - why was that press quiet?")
  p("/x on · /x off · /x help")
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
  -- first run always opens it (that's where the choices are made); after that, only if "Open to this page at login" is on
  if ns.cdb.splash or not ns.cdb.setupDone then
    C_Timer.After(1.5, function() pcall(ns.showSplash) end)
  end
end)

