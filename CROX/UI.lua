-- cro/x — the window (second alpha). Blizzard's own panel, tabs, checkboxes, dropdowns, sliders, scroll bars,
-- fonts, tooltips and sounds. Horde tab: Character, Options, My phrases, Lines. Alliance tab: LOK'TAR OGAR.
-- The layout rebuilds whenever the window changes size; text scales with the window (within readable limits),
-- times the player's text-scale setting.

local ADDON, ns = ...
local W = ns.W
local p = ns.p

local BASE_W, BASE_H = 660, 500
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
local function allianceArt(parent, withCheckbox)
  local f = CreateFrame("Frame", nil, parent)
  local bg = f:CreateTexture(nil, "BACKGROUND", nil, -2)
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.95)
  -- Fixed Alliance background (Blizzard art, see Credits). Independent of the art picker.
  -- The image sits in the top part of a 1024 square, so the texture coordinates cover only that part
  -- and crop to the frame's shape without stretching.
  local poster = f:CreateTexture(nil, "BACKGROUND", nil, -1)
  poster:SetAllPoints()
  poster:SetTexture("Interface\\AddOns\\CROX\\Art\\AllianceBG")
  local IMG_ASPECT, IMG_H = 1024 / 786, 786 / 1024
  local function fit()
    local w, h = f:GetWidth(), f:GetHeight()
    if not w or not h or w < 1 or h < 1 then return end
    local frameAspect = w / h
    local u0, u1, v0, v1 = 0, 1, 0, IMG_H
    if frameAspect > IMG_ASPECT then          -- frame is wider: trim top and bottom
      local keep = IMG_ASPECT / frameAspect
      v0 = IMG_H * (1 - keep) / 2; v1 = IMG_H - v0
    else                                      -- frame is taller: trim left (keep the orc on the right)
      local keep = frameAspect / IMG_ASPECT
      u0 = 1 - keep
    end
    poster:SetTexCoord(u0, u1, v0, v1)
  end
  f:SetScript("OnSizeChanged", fit)
  fit()
  local shade = f:CreateTexture(nil, "BACKGROUND", nil, 0)
  shade:SetPoint("BOTTOMLEFT"); shade:SetPoint("BOTTOMRIGHT"); shade:SetHeight(110)
  shade:SetColorTexture(0, 0, 0, 0.45)
  local title = f:CreateFontString(nil, "OVERLAY")
  if not pcall(title.SetFont, title, "Fonts\\MORPHEUS.TTF", 46, "THICKOUTLINE") then title:SetFontObject("GameFontNormalHuge") end
  title:SetTextColor(0.85, 0.08, 0.05)
  title:SetText("LOK'TAR OGAR")
  title:SetPoint("BOTTOM", 0, 52)
  f.poster, f.title = poster, title
  if withCheckbox then
    local c = W.check(f, "Disable addon and reroll Horde", function(_, on)
      if on then
        cdb().alliance.disabled = true
        cdb().on = false
        p("off for this character. For the Horde!")
        parent:Hide()
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

local function buildCharacter(parent)
  local s = CreateFrame("Frame", nil, parent)
  ns.paintArea(s, "charBg", 0.6)
  local h1 = W.heading(s, "Read from the game")
  h1:SetPoint("TOPLEFT", 4, -4)
  s.facts = W.text(s, "", "GameFontHighlight")
  s.facts:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -6)
  local h2 = W.heading(s, "Your choices")
  h2:SetPoint("TOPLEFT", 4, -50)
  -- a fixed grid: every row is the same height, labels in one column, dropdowns lined up in the next,
  -- the sample line beside the dropdown (beneath it when the window is narrow)
  local ROW_H, LABEL_W, DD_W = 50, 130, 150
  s.rows = {}
  for i, ch in ipairs(CHOICES) do
    local kind = ch[1]
    local y = -76 - (i - 1) * ROW_H
    local label = W.text(s, ch[2], "GameFontNormal")
    label:SetPoint("TOPLEFT", 8, y - 7)
    label:SetWidth(LABEL_W - 8)
    -- the dropdown template has about 16 px of empty space on its left; pull it back so the box sits on the grid
    local dd = W.dropdown(s, DD_W, function() return choiceItems(kind) end, function() return cdb()[kind] end,
      function(v) cdb()[kind] = v s:refresh() end)
    dd:SetPoint("TOPLEFT", LABEL_W - 16, y)
    local sample = W.text(s, "", "GameFontDisableSmall")
    sample:SetWordWrap(true)
    s.rows[kind] = {label = label, dd = dd, sample = sample, y = y}
  end
  local gridBottom = -76 - #CHOICES * ROW_H
  local h3 = W.heading(s, "Spec lines unlocked")
  h3:SetPoint("TOPLEFT", 4, gridBottom - 10)
  s.spec = W.text(s, "", "GameFontHighlightSmall")
  s.spec:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -6)
  local hint = W.hint(s, "Spec lines unlock as you spend talent points deeper in a tree.")
  hint:SetPoint("TOPLEFT", s.spec, "BOTTOMLEFT", 0, -4)
  s.LABEL_W, s.DD_W = LABEL_W, DD_W
  local hear = W.button(s, "Hear a sample", 130, function()
    local line = ns.sample("any")
    p(line and ("|cffffffff\"" .. line .. "\"|r  (only you see this)") or "no sample available.")
  end)
  hear:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
  W.tooltip(hear, "Hear a sample", "Prints a line in your character's voice to your own chat window. Nobody else sees it.")
  local redo = W.button(s, "Redo setup", 110, function() if ns.openSetup then ns.openSetup() end end)
  redo:SetPoint("LEFT", hear, "RIGHT", 8, 0)
  s.bottom = hear

  function s:refresh()
    local pf = ns.profile
    self.facts:SetText(("%s · %s · %s"):format(pf.race or "?", cap((pf.class or "?"):lower()), profText()))
    for kind, r in pairs(self.rows) do
      r.dd.refresh()
      local line = ns.sample(kind)
      r.sample:SetText(line and ("\"" .. line .. "\"") or "")
    end
    self.spec:SetText(specText())
  end
  function s:layout(w)
    self.facts:SetWidth(w - 10)
    self.spec:SetWidth(w - 10)
    local besideX = self.LABEL_W + self.DD_W + 24
    local beside = w - besideX >= 160
    for _, r in pairs(self.rows) do
      r.sample:ClearAllPoints()
      if beside then
        r.sample:SetPoint("TOPLEFT", besideX, r.y - 4)
        r.sample:SetWidth(w - besideX - 8)
        r.sample:SetHeight(32)
        r.sample:SetJustifyV("MIDDLE")
      else
        r.sample:SetPoint("TOPLEFT", self.LABEL_W, r.y - 30)
        r.sample:SetWidth(w - self.LABEL_W - 8)
        r.sample:SetHeight(14)
        r.sample:SetJustifyV("TOP")
      end
    end
    return 520
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
  local function dropdown(label, tip, items, get, set)
    local l = W.text(s, label, "GameFontHighlight")
    l:SetPoint("TOPLEFT", 14, y - 6)
    l:SetWidth(170)
    local dd = W.dropdown(s, 120, items, get, set)
    dd:SetPoint("TOPLEFT", 170, y)
    W.tooltip(l, label, tip)
    y = y - 32
    return dd, l
  end

  head("Speaking")
  check("on", "cro/x on for this character", "The master switch for this character.")
  s.chatty = dropdown("How chatty", "Quiet is about 1-2 lines a minute, Normal about 2-4, Lively about 4-6. In a party the shared party pace still applies.",
    function() return {{1, "Quiet"}, {2, "Normal"}, {3, "Lively"}} end, function() return cdb().chatty end,
    function(v) cdb().chatty = v end)
  check("emotes", "Emotes", "Emotes stay a rare accent either way.")
  check("yell", "Allow /yell", "With this off, everything goes to /say, even calls to faraway allies.")
  head("Group")
  check("cr", "Call and response", "Your character calls for help and answers other cro/x users in your group.")
  check("turns", "Take turns with the party", "cro/x users in a party take turns instead of talking over each other. Turning it off only affects you.")
  head("Content")
  check("filter", "Profanity filter", "Real-world swear words are swapped for clean versions. Your own lines are never changed.")
  s.troll, s.trollL = dropdown("Troll voice", "Trolls speak with the accent from the first alpha's converter. Emotes and your own lines stay as written.",
    function() return {{"accent", "Accent"}, {"plain", "Plain"}} end, function() return cdb().troll end,
    function(v) cdb().troll = v end)
  s.trollY = y + 32
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
  check("splash", "Show the splash page at login", "A short welcome when you log in. It closes by itself after a few seconds.")
  local artBtn = W.button(s, "Choose art...", 130, function() ns.openArtPicker() end)
  artBtn:SetPoint("TOPLEFT", 12, y - 2)
  W.tooltip(artBtn, "Choose art", "The Horde crest, the splash page background, the page behind setup and Credits, and the Character backdrop, all from the game's own art. Same as /x art.")
  y = y - 32
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
  y = y - 34
  local ver = W.hint(s, ("cro/x v%s alpha 2 · built %s · /x help for commands"):format(ns.VERSION, ns.BUILD_DATE))
  ver:SetPoint("TOPLEFT", 12, y - 4)
  local height = -y + 30

  function s:refresh()
    for key, c in pairs(checks) do c:SetChecked(cdb()[key] and true or false) end
    self.chatty.refresh()
    self.troll.refresh()
    local troll = ns.isTroll()
    self.troll:SetShown(troll)
    self.trollL:SetShown(troll)
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

local function buildLines(parent)
  local s = CreateFrame("Frame", nil, parent)
  local state = {moment = "opener", source = "all", search = "", onlyMine = true}
  local momentItems = {}
  for _, l in ipairs({ARCH_LIST, MOMENT_LIST, EXTRA_LIST}) do for _, it in ipairs(l) do momentItems[#momentItems + 1] = it end end
  local mdd = W.dropdown(s, 150, function() return momentItems end, function() return state.moment end,
    function(v) state.moment = v s:refresh() if ns.relayout then ns.relayout() end end)
  mdd:SetPoint("TOPLEFT", -12, 0)
  local sdd = W.dropdown(s, 110, function() return {{"all", "All sources"}, {"base", "Baseline"}, {"tag", "Tags and spec"},
    {"prof", "Professions"}, {"own", "My phrases"}} end, function() return state.source end,
    function(v) state.source = v s:refresh() if ns.relayout then ns.relayout() end end)
  sdd:SetPoint("LEFT", mdd, "RIGHT", -24, 0)
  local search = W.edit(s, 150)
  search:SetPoint("LEFT", sdd, "RIGHT", -4, 2)
  local ph = W.hint(search, "Search lines")
  ph:SetPoint("LEFT", 2, 0)
  search:SetScript("OnTextChanged", function(self)
    state.search = (self:GetText() or ""):lower()
    ph:SetShown(state.search == "")
    s:refresh()
    if ns.relayout then ns.relayout() end
  end)
  local only = W.check(s, "Only lines this character can say", function(_, on) state.onlyMine = on s:refresh() if ns.relayout then ns.relayout() end end)
  only:SetPoint("TOPLEFT", 6, -32)
  only:SetChecked(true)
  W.tooltip(only, "Only lines this character can say", "Hides lines your temperament, race, class or tags rule out. Untick to see everything.")
  s.count = W.heading(s, "")
  s.count:SetPoint("TOPLEFT", 8, -62)
  s.rows = {}
  local allOn = W.button(s, "Turn all back on", 140, function()
    for k in pairs(cdb().off) do cdb().off[k] = nil end
    s:refresh()
  end)
  W.tooltip(allOn, "Turn all back on", "Every line you switched off for this character comes back.")
  s.allOn = allOn

  local function rowFor(i)
    if s.rows[i] then return s.rows[i] end
    local r = CreateFrame("Frame", nil, s)
    r:SetHeight(34)
    r.check = W.check(r, "")
    r.check:SetPoint("LEFT", 0, 0)
    r.txt = W.text(r, "", "GameFontHighlight")
    r.txt:SetPoint("TOPLEFT", 28, -3)
    r.txt:SetWordWrap(false)
    r.sub = W.hint(r, "")
    r.sub:SetPoint("TOPLEFT", r.txt, "BOTTOMLEFT", 0, -2)
    r.hear = W.button(r, "Hear", 54)
    r.hear:SetPoint("RIGHT", 0, 0)
    W.tooltip(r.hear, "Hear", "Prints the line to your own chat window only.")
    s.rows[i] = r
    return r
  end

  local MAX_ROWS = 120
  function s:refresh()
    mdd.refresh() sdd.refresh()
    local list = linesFor(state.moment)
    local shown = {}
    for _, o in ipairs(list) do
      local src = o.src
      local okSrc = state.source == "all" or (state.source == "base" and (src:find("^Baseline") or src:find("^Call") or src:find("^Damage")))
        or (state.source == "tag" and (src:find("^Tag") or src:find("^Spec"))) or (state.source == "prof" and src:find("^Profession"))
        or (state.source == "own" and o.own)
      local okSearch = state.search == "" or o.line.t:lower():find(state.search, 1, true)
      if okSrc and okSearch and (not state.onlyMine or canSay(o)) then shown[#shown + 1] = o end
    end
    self.count:SetText(("%s · %d line%s%s"):format(momentLabel(state.moment), #shown, #shown == 1 and "" or "s",
      state.onlyMine and " your character can say" or ""))
    for _, r in ipairs(self.rows) do r:Hide() end
    local y = -84
    for i = 1, math.min(#shown, MAX_ROWS) do
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
      if o.line.o then tags[#tags + 1] = o.line.o .. " only" end
      if o.line.r then tags[#tags + 1] = "rating " .. o.line.r end
      local n = cdb().said[o.id] or 0
      r.sub:SetText(("%s%s · %s"):format(o.src, #tags > 0 and (" · " .. table.concat(tags, ", ")) or "",
        off and "switched off" or ("said " .. n .. " time" .. (n == 1 and "" or "s"))))
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
      y = y - 38
    end
    if #shown > MAX_ROWS then
      self.more = self.more or W.hint(self, "")
      self.more:SetText(("%d more - search or pick a source to narrow it down."):format(#shown - MAX_ROWS))
      self.more:ClearAllPoints()
      self.more:SetPoint("TOPLEFT", 8, y)
      self.more:Show()
      y = y - 20
    elseif self.more then self.more:Hide() end
    self.allOn:ClearAllPoints()
    self.allOn:SetPoint("TOPLEFT", 8, y - 8)
    self.height = -y + 44
  end
  function s:layout(w)
    for _, r in ipairs(self.rows) do r.txt:SetWidth(w - 100) r.sub:SetWidth(w - 100) end
    return self.height or 200
  end
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
local SECTIONS = {{"character", "Character", buildCharacter}, {"options", "Options", buildOptions},
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
  main = W.panel("CROX2MainFrame", "cro/x - Combat Roleplay Options /x", BASE_W, BASE_H)
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
  if wdb and wdb.w then
    main:SetSize(wdb.w, wdb.h)
    main:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", wdb.x, wdb.y)
  else
    main:SetSize(BASE_W, BASE_H)
    main:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
  end
  main:HookScript("OnShow", function()
    if sections[current or "character"] then showSection(current or "character") end
  end)
  current = "character"
  selectTab(1)
end

function ns.toggleMain()
  if ns.isAlliance() then ns.showAlliance() return end
  if not main then buildMain() end
  if main:IsShown() then main:Hide() else main:Show() end
end

function ns.refreshUI()
  if main and main:IsShown() and current and sections[current] and sections[current].refresh then
    sections[current]:refresh()
    relayout()
  end
end

------------------------------------------------------------------------
-- First-login setup: the five choices one at a time
------------------------------------------------------------------------
local setup
function ns.openSetup()
  if ns.isAlliance() then return end
  if not setup then
    setup = W.panel("CROX2SetupFrame", "cro/x - who is your character?", 460, 260)
    local page = CreateFrame("Frame", nil, setup)
    page:SetPoint("TOPLEFT", 8, -26)
    page:SetPoint("BOTTOMRIGHT", -8, 8)
    ns.paintArea(page, "page", 0.55)
    local step = 1
    local q = W.heading(setup, "")
    q:SetPoint("TOPLEFT", 20, -40)
    local hint = W.hint(setup, "")
    hint:SetPoint("TOPLEFT", q, "BOTTOMLEFT", 0, -4)
    hint:SetWidth(420)
    local dd = W.dropdown(setup, 200, function() return choiceItems(CHOICES[step][1]) end,
      function() return cdb()[CHOICES[step][1]] end,
      function(v) cdb()[CHOICES[step][1]] = v setup:fill() end)
    dd:SetPoint("TOPLEFT", 4, -96)
    local sample = W.text(setup, "", "GameFontHighlight")
    sample:SetPoint("TOPLEFT", 20, -136)
    sample:SetWidth(420)
    local HINTS = {
      temperament = "How your character talks in a fight. Colors every line.",
      homeland = "Where they're from. Lines name it, in their own people's words.",
      upbringing = "How they were raised.",
      drive = "What they fight for.",
      pronouns = "Used in emotes, like \"tightens [their] grip\".",
    }
    local back = W.button(setup, "Back", 80, function() step = math.max(1, step - 1) setup:fill() end)
    back:SetPoint("BOTTOMLEFT", 16, 14)
    local skip = W.button(setup, "Skip", 80, function() cdb().setupDone = true setup:Hide() end)
    skip:SetPoint("LEFT", back, "RIGHT", 6, 0)
    W.tooltip(skip, "Skip", "Keeps the defaults. You can change everything in the Character section, or redo setup.")
    local nxt = W.button(setup, "Next", 100, function()
      if step < #CHOICES then step = step + 1 setup:fill()
      else
        cdb().setupDone = true
        setup:Hide()
        p("all set. Type /x any time to change things.")
        if ns.refreshUI then ns.refreshUI() end
      end
    end)
    nxt:SetPoint("BOTTOMRIGHT", -16, 14)
    function setup:fill()
      local kind = CHOICES[step][1]
      if kind == "homeland" and not cdb().homeland then
        local list = ns.homelands()
        if list[1] then cdb().homeland = list[1][1] end
      end
      q:SetText(("%d of %d · %s"):format(step, #CHOICES, CHOICES[step][2]))
      hint:SetText(HINTS[kind] or "")
      dd.refresh()
      local line = ns.sample(kind)
      sample:SetText(line and ("|cffffd100Sounds like:|r \"" .. line .. "\"") or "")
      back:SetEnabled(step > 1)
      nxt:SetText(step == #CHOICES and "Done" or "Next")
    end
    setup.reset = function() step = 1 end
    setup:SetScript("OnShow", function() setup:fill() end)
  end
  setup.reset()
  if setup:IsShown() then setup:fill() else setup:Show() end
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
  p("/x art - pick the crest art · /x splash - show the splash page")
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
  elseif msg == "art" then ns.openArtPicker()
  elseif msg == "splash" then ns.showSplash()
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
-- Art browser (/x art): the game's own crests, painted backgrounds and book pages, side by side
------------------------------------------------------------------------
-- painted areas that follow the player's choices: {frame, key, holder, dim}
local painted = {}
local ART_KEYS = {
  bg = {list = function() return W.BACKGROUNDS end, label = "Splash and Alliance screen background"},
  page = {list = function() return W.PAGES end, label = "Setup and Credits page"},
  charBg = {list = function() return {W.BACKGROUNDS[1], W.BACKGROUNDS[4]} end, label = "Character section backdrop"},
}
local function entryFor(key)
  local list = ART_KEYS[key].list()
  return list[(ns.db and ns.db[key]) or 1] or list[1]
end
-- paint a frame with the chosen art for key; dim = how dark (0 none .. 1 black)
function ns.paintArea(frame, key, dim)
  local rec = {frame = frame, key = key, dim = dim or 0.5}
  painted[#painted + 1] = rec
  rec.shade = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  rec.shade:SetAllPoints(frame)
  local function apply()
    local e = entryFor(key)
    rec.holder = W.paint(frame, e, rec.holder)
    rec.holder:SetFrameLevel(math.max(0, frame:GetFrameLevel() or 0))
    for _, t in ipairs(rec.holder.tex or {}) do t:SetDrawLayer("BACKGROUND", -1) end
    rec.shade:SetColorTexture(0, 0, 0, e.none and 0 or rec.dim)
  end
  rec.apply = apply
  apply()
  return rec
end
function ns.applyArt()
  W.applyArt()
  for _, rec in ipairs(painted) do pcall(rec.apply) end
end

local browserFrame
function ns.openArtPicker()
  if not browserFrame then
    local f = W.panel("CROX2ArtFrame", "cro/x - art from the game", 600, 470)
    browserFrame = f
    local cat = "art"
    local CATS = {{"art", "Horde crest"}, {"bg", ART_KEYS.bg.label}, {"page", ART_KEYS.page.label},
      {"charBg", ART_KEYS.charBg.label}}
    local hint = W.hint(f, "Click the one that looks best. Blank squares are art this game client doesn't have.")
    hint:SetPoint("TOPLEFT", 16, -62)
    local dd = W.dropdown(f, 240, function() return CATS end, function() return cat end, function(v) cat = v f:fill() end)
    dd:SetPoint("TOPLEFT", 0, -28)
    f.cells = {}
    local function cell(i)
      if f.cells[i] then return f.cells[i] end
      local b = CreateFrame("Button", nil, f)
      b:SetSize(130, 150)
      local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
      b:SetPoint("TOPLEFT", 20 + col * 142, -84 - row * 166)
      b.art = CreateFrame("Frame", nil, b)
      b.art:SetSize(120, 110)
      b.art:SetPoint("TOP", 0, -4)
      b.crest = b.art:CreateTexture(nil, "ARTWORK")
      b.crest:SetAllPoints()
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
      hl:SetBlendMode("ADD")
      hl:SetAllPoints()
      b.sel = b:CreateTexture(nil, "BACKGROUND")
      b.sel:SetAllPoints()
      b.sel:SetColorTexture(1, 0.82, 0, 0.15)
      b.label = W.text(b, "", "GameFontHighlightSmall")
      b.label:SetPoint("TOP", b.art, "BOTTOM", 0, -4)
      b.label:SetWidth(126)
      b.label:SetJustifyH("CENTER")
      f.cells[i] = b
      return b
    end
    function f:fill()
      dd.refresh()
      for _, b in ipairs(self.cells) do b:Hide() end
      local list
      if cat == "art" then list = {} for i, a in ipairs(W.CREST_ART) do list[i] = {label = a[6], crest = i} end
      else list = ART_KEYS[cat].list() end
      for i, e in ipairs(list) do
        local b = cell(i)
        b.crest:SetShown(e.crest ~= nil)
        if e.crest then W.crest(b.crest, e.crest) end
        b.painted = W.paint(b.art, (not e.crest) and e or {none = true}, b.painted)
        if e.none and not e.crest then
          b.dark = b.dark or b.art:CreateTexture(nil, "BACKGROUND")
          b.dark:SetAllPoints()
          b.dark:SetColorTexture(0.05, 0.05, 0.05, 1)
          b.dark:Show()
        elseif b.dark then b.dark:Hide() end
        b.label:SetText(i .. ". " .. e.label)
        b.sel:SetShown(((ns.db[cat]) or 1) == i)
        b:SetScript("OnClick", function()
          ns.db[cat] = i
          ns.applyArt()
          W.sound("click")
          f:fill()
          p(("%s: %s."):format(cat == "art" and "Horde crest" or ART_KEYS[cat].label, e.label))
        end)
        b:Show()
      end
    end
    f:SetScript("OnShow", function() f:fill() end)
  end
  browserFrame:Show()
end

------------------------------------------------------------------------
-- Splash page at login
------------------------------------------------------------------------
local splash
local SPLASH_SECONDS = 8

function ns.showSplash(onDone)
  if not splash then
    splash = W.make("Frame", UIParent, {"BackdropTemplate"}, "CROX2SplashFrame")
    splash:SetSize(420, 330)
    splash:SetPoint("CENTER", 0, 80)
    splash:SetFrameStrata("DIALOG")
    splash:EnableMouse(true)
    if splash.SetBackdrop then
      splash:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}})
    end
    local inner = CreateFrame("Frame", nil, splash)
    inner:SetPoint("TOPLEFT", 12, -12)
    inner:SetPoint("BOTTOMRIGHT", -12, 12)
    ns.paintArea(inner, "bg", 0.55)
    local crest = splash:CreateTexture(nil, "ARTWORK")
    crest:SetSize(150, 150)
    crest:SetPoint("TOP", 0, -18)
    W.crest(crest)
    local title = splash:CreateFontString(nil, "OVERLAY")
    if not pcall(title.SetFont, title, "Fonts\\MORPHEUS.TTF", 40, "OUTLINE") then title:SetFontObject("GameFontNormalHuge") end
    title:SetTextColor(1, 0.82, 0)
    title:SetText("cro/x")
    title:SetPoint("TOP", crest, "BOTTOM", 0, -2)
    local sub = W.text(splash, "Combat Roleplay Options /x", "GameFontHighlightLarge")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -2)
    splash.who = W.text(splash, "", "GameFontHighlight")
    splash.who:SetPoint("TOP", sub, "BOTTOM", 0, -10)
    local hint = W.hint(splash, "Type /x to open  ·  /x flag to review a fight")
    hint:SetPoint("TOP", splash.who, "BOTTOM", 0, -6)
    local ver = W.hint(splash, ("v%s · alpha 2"):format(ns.VERSION))
    ver:SetPoint("BOTTOMLEFT", 18, 16)
    local close = W.button(splash, "Close", 80, function() splash:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -16, 14)
    local open = W.button(splash, "Open cro/x", 110, function() splash:Hide() if ns.toggleMain then ns.toggleMain() end end)
    open:SetPoint("RIGHT", close, "LEFT", -6, 0)
    splash:SetScript("OnUpdate", function(self, el)
      if self:IsMouseOver() then self.left = SPLASH_SECONDS return end
      self.left = (self.left or SPLASH_SECONDS) - (el or 0)
      if self.left <= 0 then self:Hide() end
    end)
    splash:SetScript("OnHide", function(self)
      W.sound("close")
      local cb = self.onDone
      self.onDone = nil
      if cb then cb() end
    end)
  end
  local c = cdb()
  local home
  for _, h in ipairs(ns.homelands()) do if h[1] == c.homeland then home = h[2] end end
  splash.who:SetText(c.setupDone and ("%s · %s · %s · %s · %s"):format(ns.profile.name or "", c.temperament or "",
    home or "no homeland", c.upbringing or "", c.drive or "") or (ns.profile.name or "") .. " - let's meet your character.")
  splash.left = SPLASH_SECONDS
  splash.onDone = onDone
  splash:Show()
  if UIFrameFadeIn then pcall(UIFrameFadeIn, splash, 0.6, 0, 1) end
  W.sound("open")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  pcall(ns.updateMinimap)
  pcall(ns.applyArt)
  if not ns.cdb or ns.isAlliance() or not ns.cdb.on then return end
  local function setupIfNeeded() if not ns.cdb.setupDone then pcall(ns.openSetup) end end
  if ns.cdb.splash then
    C_Timer.After(1.5, function() pcall(ns.showSplash, setupIfNeeded) end)
  else
    C_Timer.After(2, setupIfNeeded)
  end
end)
