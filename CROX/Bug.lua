-- cro/x — bug reporting for the beta: /x bug (a short report to paste), an error catcher that points testers
-- at it, and /x test (tells you, in your own chat, why a button press stayed quiet).
-- Nothing is sent anywhere. The report is text the player copies and pastes into Discord or GitHub themselves.
-- The error catcher only listens: it passes every error on to whatever handler was already in place.

local ADDON, ns = ...
local W = ns.W
local Bug = {}
ns.Bug = Bug

local p = ns.p
local LIMIT = 1900          -- Discord stops at 2,000 characters; leave a little room
local MAX_ERRORS = 5
local errors = {}           -- this session's errors: {msg, count}
local lastTold = -1000

local REASONS = {
  {"error", "Something went wrong (an error)"},
  {"wording", "A line was awkward or wrong"},
  {"silent", "It stayed quiet when it shouldn't"},
  {"chatty", "It spoke too much"},
  {"window", "The window looks or acts wrong"},
  {"other", "Something else"},
}
local function reasonLabel(v)
  for _, r in ipairs(REASONS) do if r[1] == v then return r[2] end end
  return "Something else"
end
Bug.REASONS = REASONS

------------------------------------------------------------------------
-- Error catcher
------------------------------------------------------------------------
local function clean(msg)
  msg = tostring(msg or "unknown error")
  msg = msg:gsub("[\r\n]+", " ")
  msg = msg:gsub("Interface[/\\]AddOns[/\\]", "")
  msg = msg:gsub("|", "||")
  if #msg > 350 then msg = msg:sub(1, 347) .. "..." end
  return msg
end

function Bug.capture(err)
  local msg = clean(err)
  local seen
  for _, e in ipairs(errors) do if e.msg == msg then e.count = e.count + 1 seen = true break end end
  if not seen then
    errors[#errors + 1] = {msg = msg, count = 1}
    while #errors > MAX_ERRORS do table.remove(errors, 1) end
  end
  -- one short line, and not again for five minutes
  local t = ns.now and ns.now() or 0
  if t - lastTold > 300 then
    lastTold = t
    if p then p("hit a snag. Type /x bug to report it.") end
  end
end

function Bug.lastError() return errors[#errors] end
function Bug.errorCount()
  local n = 0
  for _, e in ipairs(errors) do n = n + e.count end
  return n
end

local function install()
  if Bug.installed or not (geterrorhandler and seterrorhandler) then return end
  local prev = geterrorhandler()
  seterrorhandler(function(e)
    pcall(function()
      if tostring(e):find("AddOns[/\\]CROX[/\\]") then Bug.capture(e) end
    end)
    if prev then return prev(e) end
  end)
  Bug.installed = true
end
install()

------------------------------------------------------------------------
-- The report: most useful things first, cut off cleanly at the limit
------------------------------------------------------------------------
local function cut(s, n) s = tostring(s or "") if #s > n then return s:sub(1, n - 3) .. "..." end return s end

function Bug.report(reason, note, withFight)
  local cdb, pf = ns.cdb or {}, ns.profile or {}
  local gv, gb = "?", "?"
  if GetBuildInfo then local a, b = GetBuildInfo() gv, gb = a or "?", b or "?" end
  local parts = {}
  parts[#parts + 1] = ("cro/x bug report · %s · game %s (%s)"):format(ns.BUILD or "?", gv, gb)
  parts[#parts + 1] = "what: " .. reasonLabel(reason)
  if note and note ~= "" then parts[#parts + 1] = "note: " .. cut(note, 220) end
  parts[#parts + 1] = ("character: %s %s · %s · homeland %s · drive %s · chatty %s · filter %s · %s"):format(
    pf.race or "?", (pf.class or "?"):lower(), cdb.temperament or "?",
    (cdb.homeland or "none"):gsub("^home:", ""), cdb.drive or "?", tostring(cdb.chatty or 2),
    cdb.filter and "on" or "off", cdb.on == false and "OFF" or "on")
  parts[#parts + 1] = "hook: " .. ((ns.hookOK and ns.hookOK()) and "ok" or "NOT WORKING") ..
    " · errors this session: " .. Bug.errorCount()
  if ns.G and ns.G.exchanges and #ns.G.exchanges > 0 then
    local xs, G = {}, ns.G
    for i = math.max(1, #G.exchanges - 2), #G.exchanges do
      local x = G.exchanges[i]
      local who = {}
      for _, n in ipairs(x.slots or {}) do who[#who + 1] = (G.members[n] and G.members[n].class) or "me/?" end
      xs[#xs + 1] = ("%s x%d (%s)"):format(x.moment or "?", #(x.slots or {}), table.concat(who, ","))
    end
    parts[#parts + 1] = ("group: protocol %s · recent exchanges (other players shown as class): %s"):format(tostring(G.PROTO), table.concat(xs, " | "))
  end
  local le = Bug.lastError()
  if le then parts[#parts + 1] = "last error" .. (le.count > 1 and (" (x" .. le.count .. ")") or "") .. ": " .. le.msg end
  if ns.Log then
    local q = ns.Log.recentQuiet and ns.Log.recentQuiet(4) or {}
    if #q > 0 then
      local qs = {}
      for _, e in ipairs(q) do qs[#qs + 1] = ("%s/%s: %s"):format(e.moment or "-", e.ability or e.item or "-", e.why or "-") end
      parts[#parts + 1] = "recent quiet: " .. table.concat(qs, " | ")
    end
    if withFight then
      local lines = ns.Log.recentLines and ns.Log.recentLines(8) or {}
      if #lines > 0 then
        parts[#parts + 1] = "last fight (other players shown as their class):"
        for _, l in ipairs(lines) do parts[#parts + 1] = cut(l, 150) end
      end
    end
  end
  local out, total = {}, 0
  for _, s in ipairs(parts) do
    if total + #s + 1 > LIMIT then out[#out + 1] = "..." break end
    out[#out + 1] = s
    total = total + #s + 1
  end
  return table.concat(out, "\n")
end

------------------------------------------------------------------------
-- /x probe: what this game client offers for reading professions and talents
------------------------------------------------------------------------
local function show(v)
  if ns.secret(v) then return "<secret>" end
  if v == nil then return "nil" end
  if type(v) == "table" then
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    return "table(" .. n .. ")"
  end
  return tostring(v)
end
local function call(fn, ...)
  if type(fn) ~= "function" then return "missing" end
  local r = {pcall(fn, ...)}
  if not r[1] then return "error" end
  local out = {}
  for i = 2, math.max(2, #r) do out[#out + 1] = show(r[i]) if #out >= 8 then break end end
  return table.concat(out, ", ")
end

function Bug.probeText()
  local L = {}
  local function add(s) L[#L + 1] = s end
  local gv, gb, gd, toc = "?", "?", "?", "?"
  if GetBuildInfo then gv, gb, gd, toc = GetBuildInfo() end
  add(("cro/x probe · %s · game %s (%s) · interface %s"):format(ns.BUILD or "?", show(gv), show(gb), show(toc)))
  local _, cls
  if UnitClass then local ok, a1, a2 = pcall(UnitClass, "player") if ok then cls = a2 end end
  add("class: " .. show(cls) .. " · level: " .. call(UnitLevel, "player"))
  add("")
  add("PROFESSIONS")
  add("classic skill list: GetNumSkillLines = " .. call(GetNumSkillLines))
  if type(GetNumSkillLines) == "function" then
    local names = {}
    for i = 1, math.min(40, tonumber((select(2, pcall(GetNumSkillLines)))) or 0) do
      local r = {pcall(GetSkillLineInfo, i)}
      if r[1] and not r[3] then names[#names + 1] = show(r[2]) end
    end
    add("  skills (non-header): " .. table.concat(names, ", "))
  end
  add("modern list: GetProfessions = " .. call(GetProfessions))
  if type(GetProfessions) == "function" then
    local r = {pcall(GetProfessions)}
    for i = 2, 7 do
      if type(r[i]) == "number" then add("  index " .. r[i] .. " = " .. call(GetProfessionInfo, r[i])) end
    end
  end
  local TS = C_TradeSkillUI
  add("C_TradeSkillUI.GetAllProfessionTradeSkillLines = " .. call(TS and TS.GetAllProfessionTradeSkillLines))
  add("cro/x read: " .. (function() local t = {} for k in pairs(ns.profile.profs or {}) do t[#t + 1] = k end table.sort(t) return #t > 0 and table.concat(t, ", ") or "nothing" end)())
  add("")
  add("TALENTS AND SPEC")
  add("classic trees: GetNumTalentTabs = " .. call(GetNumTalentTabs))
  add("  GetTalentTabInfo(1) = " .. call(GetTalentTabInfo, 1))
  add("  GetNumTalents(1) = " .. call(GetNumTalents, 1))
  add("  GetTalentInfo(1, 1) = " .. call(GetTalentInfo, 1, 1))
  add("modern spec: GetSpecialization = " .. call(GetSpecialization))
  add("  GetSpecializationInfo(1) = " .. call(GetSpecializationInfo, 1))
  local SI = C_SpecializationInfo
  add("  C_SpecializationInfo.GetSpecialization = " .. call(SI and SI.GetSpecialization))
  add("  C_SpecializationInfo.GetSpecializationInfo(1) = " .. call(SI and SI.GetSpecializationInfo, 1))
  local CT = C_ClassTalents
  add("  C_ClassTalents.GetActiveConfigID = " .. call(CT and CT.GetActiveConfigID))
  add("  GetNumTalentGroups = " .. call(GetNumTalentGroups))
  add("spell tabs: GetNumSpellTabs = " .. call(GetNumSpellTabs))
  local SB = C_SpellBook
  add("  C_SpellBook.GetNumSpellBookSkillLines = " .. call(SB and SB.GetNumSpellBookSkillLines))
  local n = tonumber((select(2, pcall(GetNumSpellTabs or function() return 0 end)))) or 0
  for i = 1, math.min(n, 8) do add("  tab " .. i .. " = " .. call(GetSpellTabInfo, i)) end
  if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo then
    local m = tonumber((select(2, pcall(SB.GetNumSpellBookSkillLines)))) or 0
    for i = 1, math.min(m, 8) do
      local r = {pcall(SB.GetSpellBookSkillLineInfo, i)}
      add("  skill line " .. i .. " = " .. (type(r[2]) == "table" and show(r[2].name) or show(r[2])))
    end
  end
  add("cro/x read: " .. (function() local t = {} for k, v in pairs(ns.profile.spec or {}) do t[#t + 1] = k .. " " .. v end table.sort(t) return #t > 0 and table.concat(t, ", ") or "nothing" end)())
  return table.concat(L, "\n")
end

local probeFrame
function Bug.probe()
  if not probeFrame then
    local f = W.panel("CROX2ProbeFrame", "cro/x - what this client offers", 600, 460)
    probeFrame = f
    local hint = W.hint(f, "Everything below is selected. Copy it (Ctrl+C) and paste it into the chat with Claude.")
    hint:SetPoint("TOPLEFT", 16, -32)
    hint:SetPoint("RIGHT", -16, 0)
    local sf = W.make("ScrollFrame", f, {"UIPanelScrollFrameTemplate"}, "CROX2ProbeScroll")
    sf:SetPoint("TOPLEFT", 14, -54)
    sf:SetPoint("BOTTOMRIGHT", -32, 44)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetWidth(540)
    eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    sf:SetScrollChild(eb)
    f.eb = eb
    local sel = W.button(f, "Select all", 110, function() eb:SetFocus() eb:HighlightText() end)
    sel:SetPoint("BOTTOMRIGHT", -16, 12)
    local close = W.button(f, "Close", 90, function() f:Hide() end)
    close:SetPoint("RIGHT", sel, "LEFT", -6, 0)
  end
  if ns.refreshProfile then pcall(ns.refreshProfile) end
  probeFrame:Show()
  probeFrame.eb:SetText(Bug.probeText())
  probeFrame.eb:SetFocus()
  probeFrame.eb:HighlightText()
end

------------------------------------------------------------------------
-- The window (/x bug)
------------------------------------------------------------------------
local frame
function Bug.open(reason)
  if not frame then
    local f = W.panel("CROX2BugFrame", "cro/x - report a problem", 540, 480)
    frame = f
    f.reason, f.note, f.withFight = "error", "", true

    local h1 = W.heading(f, "What happened?")
    h1:SetPoint("TOPLEFT", 18, -34)
    local dd = W.dropdown(f, 300, function() return REASONS end, function() return f.reason end,
      function(v) f.reason = v f:update() end)
    dd:SetPoint("TOPLEFT", 0, -50)
    dd.refresh()
    f.dd = dd

    local h2 = W.heading(f, "A few words about it (optional)")
    h2:SetPoint("TOPLEFT", 18, -88)
    local nb = W.make("EditBox", f, {"InputBoxTemplate"})
    nb:SetSize(480, 22)
    nb:SetPoint("TOPLEFT", 24, -108)
    nb:SetAutoFocus(false)
    nb:SetMaxLetters(220)
    nb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nb:SetScript("OnTextChanged", function(self) f.note = self:GetText() or "" f:update() end)
    f.nb = nb

    local ck = W.check(f, "Include my last fight (other players' names become their class)", function(_, v)
      f.withFight = v f:update() end)
    ck:SetPoint("TOPLEFT", 14, -134)
    ck:SetChecked(true)

    local hint = W.hint(f, "Copy the report below (Ctrl+C) and paste it into the beta Discord, or into a new issue at github.com/drcrox/cro_x. Nothing is sent for you.")
    hint:SetPoint("TOPLEFT", 18, -166)
    hint:SetPoint("RIGHT", -18, 0)
    hint:SetJustifyH("LEFT")

    local sf = W.make("ScrollFrame", f, {"UIPanelScrollFrameTemplate"}, "CROX2BugScroll")
    sf:SetPoint("TOPLEFT", 14, -196)
    sf:SetPoint("BOTTOMRIGHT", -32, 44)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetWidth(480)
    eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(eb)
    f.eb = eb

    f.count = W.hint(f, "")
    f.count:SetPoint("BOTTOMLEFT", 18, 18)
    local sel = W.button(f, "Select all", 110, function() eb:SetFocus() eb:HighlightText() end)
    sel:SetPoint("BOTTOMRIGHT", -16, 12)
    local close = W.button(f, "Close", 90, function() f:Hide() end)
    close:SetPoint("RIGHT", sel, "LEFT", -6, 0)

    function f:update()
      local text = Bug.report(self.reason, self.note, self.withFight)
      self.eb:SetText(text)
      self.count:SetText(("%d / 2000 characters"):format(#text))
    end
  end
  if reason then frame.reason = reason end
  frame.dd.refresh()
  frame:Show()
  frame:update()
  frame.nb:SetFocus()
end

------------------------------------------------------------------------
-- /x test: why a press stayed quiet, in plain words, in your own chat only
------------------------------------------------------------------------
local PLAIN = {
  ["pace: quiet gap"] = "it was too soon after my last line for your Chatty level",
  ["party: holding after someone spoke"] = "someone in your group had just spoken",
  ["party: pace for the whole party"] = "your party had already spoken enough this minute",
  ["party: letting someone else talk"] = "I'd been the last to speak, so I let someone else go",
  ["chance roll"] = "the dice said not this time (not every press speaks)",
  ["no true line"] = "no line fit what's true right now",
  ["raise outside combat"] = "resurrections only speak in combat",
  ["button not ready"] = "the button wasn't ready, so it never fired",
  ["interrupt with nothing to interrupt"] = "there was nothing to interrupt",
}
local function plain(why)
  why = why or "?"
  local n = why:match("^pace: (%d+)s between lines")
  if n then return "I'd spoken less than " .. n .. " seconds ago (the always-on gap)" end
  n = why:match("^pace: (%d+) lines a minute")
  if n then return "I'd already said " .. n .. " lines this minute (your Chatty level's limit)" end
  return PLAIN[why] or why
end

function Bug.test()
  local cdb = ns.cdb or {}
  p("test - why cro/x might be quiet:")
  if cdb.on == false then p("  It's switched off. Type /x on.") end
  if ns.hookOK and not ns.hookOK() then p("  This client won't let me see your button presses (the hook failed). That would be a bug - /x bug.") end
  if not ns.inCombat then p("  You're not in combat; most lines only happen in a fight.") end
  local ch = ns.CHATTY and ns.CHATTY[cdb.chatty or 2]
  if ch then
    p(("  Chatty %s: at least %ds between lines, at most %d a minute."):format(tostring(cdb.chatty or 2), ch.gap, ch.perMin))
  end
  if ns.sinceSpoke then
    local s = ns.sinceSpoke()
    if s < 3600 then p(("  Last spoke %d seconds ago."):format(math.floor(s))) else p("  Hasn't spoken this session.") end
  end
  local q = ns.Log and ns.Log.recentQuiet and ns.Log.recentQuiet(6) or {}
  if #q == 0 then
    p("  No quiet presses yet. Press an ability, then type /x test again.")
  else
    p("  Recent quiet presses, newest first:")
    for i = #q, 1, -1 do
      local e = q[i]
      p(("    %ds ago - %s: %s"):format(math.floor(ns.now() - (e.at or ns.now())), e.ability or e.item or e.moment or "a press", plain(e.why)))
    end
  end
  if Bug.errorCount() > 0 then p("  There were errors this session. /x bug will include them.") end
end
