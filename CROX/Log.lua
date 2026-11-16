-- cro/x — session log, fight review (/x flag) and export (/x export). Second alpha.
-- Everything stays on this computer, in the addon's saved file. Nothing is sent anywhere: a player who wants to
-- help can paste the export into Discord, a form or an email. Other players' names are replaced by their class.

local ADDON, ns = ...
local W = ns.W
local Log = {}
ns.Log = Log

local MAX_SESSIONS, MAX_FIGHTS, MAX_EVENTS = 3, 60, 400
local TEST_MAX_FIGHTS, TEST_MAX_EVENTS = 150, 1500      -- testing mode keeps more
local session, fight
local looseStart

local function on() return ns.cdb and ns.cdb.logging end
local function clock(sec) sec = math.floor(sec or 0) return ("%d:%02d"):format(sec / 60, sec % 60) end

function Log.init()
  local cdb = ns.cdb
  cdb.log = cdb.log or {sessions = {}}
  local s = cdb.log.sessions
  session = {start = ns.wall(), version = ns.VERSION, fights = {}, loose = {}}
  table.insert(s, session)
  while #s > MAX_SESSIONS do table.remove(s, 1) end
  looseStart = ns.now()
end

local function testing() return ns.cdb and ns.cdb.testing == true end
-- while the simulator is playing a fake user, nothing is logged
local function muted() return ns.simActor ~= nil and not ns.simActor.user end

function Log.fightStart(sim)
  if not session or muted() then return end
  fight = {start = ns.now(), wall = ns.wall(), events = {}, flags = {}, sim = sim and true or nil,
    test = testing() or nil, pace = ns.chattyNow and ns.chattyNow() or nil,
    party = ns.simParty and #ns.simParty or nil}
  table.insert(session.fights, fight)
  local cap = testing() and TEST_MAX_FIGHTS or MAX_FIGHTS
  while #session.fights > cap do table.remove(session.fights, 1) end
end

function Log.fightEnd()
  if muted() then return end
  if fight then
    fight.dur = ns.now() - fight.start
    -- name the fight after the first enemy it involved
    for _, e in ipairs(fight.events) do
      if e.target and not e.onAlly and not e.onSelf then fight.foe = e.target fight.foePlayer = e.tgtPlayer break end
    end
  end
  fight = nil
end

local function add(e)
  if not on() or not session or muted() then return end
  local list = fight and fight.events or session.loose
  e.t = ns.now() - (fight and fight.start or looseStart)
  e.wall = ns.wall()
  if testing() then      -- testing mode: remember the pace situation behind each event
    e.budget = ns.getBudget and math.floor(ns.getBudget() * 10 + 0.5) / 10 or nil
    e.pace = ns.chattyNow and ns.chattyNow() or nil
    if ns._lastChance then e.chance = math.floor(ns._lastChance * 10 + 0.5) / 10 end
    if ns.sim then e.sim = true end
  end
  if #list < (testing() and TEST_MAX_EVENTS or MAX_EVENTS) then list[#list + 1] = e end
end

function Log.said(e) add(e) end
function Log.event(e) add(e) end
-- the last few quiet presses, kept in memory only, for /x test and /x bug (even outside combat)
local recentQuiet = {}
function Log.quiet(ctx, moment, why)
  if ns.simQuiet then ns.simQuiet(ctx, moment, why) end
  if muted() then return end
  recentQuiet[#recentQuiet + 1] = {at = ns.now(), moment = moment, ability = ctx and ctx.ability,
    item = ctx and ctx.itemName, why = why}
  while #recentQuiet > 8 do table.remove(recentQuiet, 1) end
  if not ns.inCombat then return end
  add({kind = "quiet", moment = moment, ability = ctx and ctx.ability, item = ctx and ctx.itemName, why = why})
end

function Log.recentQuiet(n)
  local out = {}
  for i = math.max(1, #recentQuiet - (n or 4) + 1), #recentQuiet do out[#out + 1] = recentQuiet[i] end
  return out
end

------------------------------------------------------------------------
-- Plain words: "Warhorn said "..." when he used Mortal Strike on a Razormane Hunter."
------------------------------------------------------------------------
local MOMENT_WORDS = {
  ["debuff:poisoned"] = "was poisoned", ["debuff:cursed"] = "was cursed", ["debuff:diseased"] = "caught a disease",
  ["debuff:magic"] = "was hit by a spell", ["debuff:physical"] = "was hit by a debuff",
  ["debuff:cc"] = "was stunned or held", ["debuff:frost"] = "was chilled",
}

local function subject()
  local pr = ns.PRON[ns.cdb.pronouns] or ns.PRON.they
  return ns.profile.name or "You", pr.they, pr.plural
end

function Log.describe(e, forExport)
  local who, they, plural = subject()
  local text = e.text or ""
  if forExport and e.ally then
    local a, b = text:find(e.ally, 1, true)
    while a do
      local rep = "[" .. (e.allyClass or "ally"):lower() .. "]"
      text = text:sub(1, a - 1) .. rep .. text:sub(b + 1)
      a, b = text:find(e.ally, a + #rep, true)
    end
  end
  if forExport and e.own and not ns.cdb.includeOwn then text = "(one of your own lines)" end
  local verb = e.channel == "EMOTE" and "emoted" or (e.channel == "YELL" and "yelled" or "said")
  if e.held then verb = verb .. " (a yell held back: " .. e.held .. ")" end
  local quote = e.channel == "EMOTE" and ("\"" .. who .. " " .. text .. "\"") or ("\"" .. text .. "\"")
  local target = e.target
  if forExport and e.tgtPlayer then target = "an enemy player" end
  local ally = e.ally
  if forExport and ally then ally = "a " .. ((e.allyClass or "group member"):lower()) end
  local was = plural and "were" or "was"
  local when
  local m = e.moment or ""
  if e.kind == "call" then when = "when " .. they .. " called on " .. (ally or "a group member") .. " for help"
  elseif e.kind == "reply" then when = "when " .. they .. " answered " .. (ally or "a group member")
  elseif m == "kill" then when = "after " .. they .. " killed " .. (target or "the enemy")
  elseif MOMENT_WORDS[m] then when = "when " .. they .. " " .. MOMENT_WORDS[m]:gsub("^was", was)
  elseif m:find("^item:") then when = "when " .. they .. " used " .. (e.item or "an item")
  elseif m:find("^gather:") then when = "while gathering"
  elseif m:find("^craft:") then when = "after crafting"
  elseif e.ability then
    when = "when " .. they .. " used " .. e.ability
    if target and not e.onSelf then when = when .. " on " .. target end
  else when = "" end
  local line = ("%s %s %s %s."):format(who, verb, quote, when)
  return (line:gsub(" %.$", "."))
end

-- fights with at least one line said, newest first
function Log.recentFights(n)
  local out = {}
  local sessions = ns.cdb and ns.cdb.log and ns.cdb.log.sessions or {}
  for si = #sessions, 1, -1 do
    local fs = sessions[si].fights
    for fi = #fs, 1, -1 do
      local f = fs[fi]
      if f ~= fight then
        for _, e in ipairs(f.events) do
          if e.text then out[#out + 1] = f break end
        end
      end
      if #out >= n then return out end
    end
  end
  return out
end

------------------------------------------------------------------------
-- Review a fight (/x flag)
------------------------------------------------------------------------
local REASONS = {{"fit", "Didn't fit"}, {"often", "Too often"}, {"wording", "Awkward wording"}, {"other", "Other"}}
local review

local function buildReview()
  local f = W.panel("CROX2ReviewFrame", "cro/x - review a fight", 560, 440)
  review = f
  local which = 1
  local fights = {}
  local hint = W.hint(f, "Tick anything that felt wrong. A reason and a note are optional.")
  hint:SetPoint("TOPLEFT", 16, -60)
  local dd = W.dropdown(f, 260, function()
    local items = {}
    for i, fg in ipairs(fights) do
      items[#items + 1] = {i, ("%s · %s%s"):format(i == 1 and "Last fight" or (i .. " fights ago"),
        (fg.foe and (fg.foePlayer and "an enemy player" or fg.foe) or "unknown"),
        fg.dur and (", " .. clock(fg.dur)) or "")}
    end
    return items
  end, function() return which end, function(v) which = v f:fill() end)
  dd:SetPoint("TOPLEFT", 0, -28)
  local sf, content = W.scroll(f)
  sf:SetPoint("TOPLEFT", 14, -80)
  sf:SetPoint("BOTTOMRIGHT", -32, 44)
  local rows = {}
  local empty = W.hint(content, "No fights with lines yet. Fight something, then try again.")
  empty:SetPoint("TOPLEFT", 4, -4)

  local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, content)
    r.check = W.check(r, "")
    r.check:SetPoint("TOPLEFT", 0, 0)
    r.txt = W.text(r, "", "GameFontHighlightSmall")
    r.txt:SetPoint("TOPLEFT", 28, -5)
    r.txt:SetWordWrap(true)
    r.reason = W.dropdown(r, 130, function() return REASONS end,
      function() local fl = r.fight and r.fight.flags[r.idx] return fl and fl.reason or "fit" end,
      function(v) local fl = r.fight.flags[r.idx] if fl then fl.reason = v end end)
    r.note = W.edit(r, 220, 120)
    r.note:SetScript("OnTextChanged", function(self)
      local fl = r.fight and r.fight.flags[r.idx]
      if fl then fl.note = self:GetText() end
    end)
    r.check:SetScript("OnClick", function(self)
      W.sound(self:GetChecked() and "check" or "uncheck")
      if self:GetChecked() then r.fight.flags[r.idx] = r.fight.flags[r.idx] or {reason = "fit"}
      else r.fight.flags[r.idx] = nil end
      f:fill()
    end)
    rows[i] = r
    return r
  end

  function f:fill()
    fights = Log.recentFights(5)
    if which > #fights then which = 1 end
    dd.refresh()
    local fg = fights[which]
    for _, r in ipairs(rows) do r:Hide() end
    empty:SetShown(not fg)
    if not fg then return end
    local y, n = 0, 0
    local w = math.max(200, sf:GetWidth() - 8)
    for idx, e in ipairs(fg.events) do
      if e.text then
        n = n + 1
        local r = row(n)
        r.fight, r.idx = fg, idx
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r:SetWidth(w)
        r.txt:SetWidth(w - 32)
        r.txt:SetText("|cff999999" .. clock(e.t) .. "|r  " .. Log.describe(e))
        local flagged = fg.flags[idx] ~= nil
        r.check:SetChecked(flagged)
        local h = math.max(24, r.txt:GetStringHeight() + 10)
        r.reason:ClearAllPoints()
        r.note:ClearAllPoints()
        if flagged then
          r.reason:SetPoint("TOPLEFT", 12, -h + 2)
          r.reason.refresh()
          r.note:SetPoint("TOPLEFT", 190, -h - 2)
          r.note:SetText(fg.flags[idx].note or "")
          h = h + 32
        end
        r.reason:SetShown(flagged)
        r.note:SetShown(flagged)
        r:SetHeight(h)
        r:Show()
        y = y + h + 4
      end
    end
    content:SetHeight(math.max(10, y))
  end

  local save = W.button(f, "Save flags", 120, function()
    for _, fg in ipairs(fights) do
      local any = false
      for _ in pairs(fg.flags) do any = true break end
      fg.flagged = any or nil
    end
    ns.p("flags saved. They go out with /x export.")
    f:Hide()
  end)
  save:SetPoint("BOTTOMRIGHT", -16, 12)
  local close = W.button(f, "Close", 90, function() f:Hide() end)
  close:SetPoint("RIGHT", save, "LEFT", -6, 0)
  f:SetScript("OnShow", function() f:fill() end)
end

function Log.openReview()
  if not review then buildReview() end
  if review:IsShown() then review:fill() else review:Show() end
end

------------------------------------------------------------------------
-- Export (/x export)
------------------------------------------------------------------------
function Log.exportText()
  local cdb, pf = ns.cdb, ns.profile
  local out = {}
  local function add(s) out[#out + 1] = s end
  add(("cro/x export · %s · %s"):format(ns.BUILD, date and date("%Y-%m-%d %H:%M") or ""))
  add(("character: %s %s · temperament %s · homeland %s · origin %s · motivation %s · chatty %d · filter %s"):format(
    pf.race or "?", (pf.class or "?"):lower(), cdb.temperament or "?", (cdb.homeland or "none"):gsub("^home:", ""),
    cdb.upbringing or "?", cdb.drive or "?", cdb.chatty or 2, cdb.filter and "on" or "off"))
  local profs = {}
  for k in pairs(pf.profs or {}) do profs[#profs + 1] = k end
  local spec = {}
  for k, v in pairs(pf.spec or {}) do spec[#spec + 1] = k .. " " .. v end
  add("professions: " .. (#profs > 0 and table.concat(profs, ", ") or "none") .. " · spec bands: " ..
    (#spec > 0 and table.concat(spec, ", ") or "none"))
  for si, s in ipairs(cdb.log and cdb.log.sessions or {}) do
    add("")
    add(("== session %d · %s · v%s"):format(si, date and date("%Y-%m-%d %H:%M", s.start) or "", s.version or "?"))
    for fi, fg in ipairs(s.fights) do
      local said, quiet = 0, 0
      for _, e in ipairs(fg.events) do if e.text then said = said + 1 elseif e.kind == "quiet" then quiet = quiet + 1 end end
      add(("-- fight %d · %s · vs %s · %d said, %d quiet%s"):format(fi, clock(fg.dur), fg.foePlayer and "an enemy player"
        or (fg.foe or "?"), said, quiet, fg.flagged and " · FLAGGED" or ""))
      for idx, e in ipairs(fg.events) do
        if e.text then
          local fl = fg.flags and fg.flags[idx]
          local reason
          if fl then for _, r in ipairs(REASONS) do if r[1] == fl.reason then reason = r[2] end end end
          add(("  %s %s | %s%s"):format(clock(e.t), Log.describe(e, true), e.moment or "", fl and
            (" | FLAG: " .. (reason or "?") .. ((fl.note and fl.note ~= "") and (" - " .. fl.note) or "")) or ""))
        elseif e.kind == "quiet" then
          add(("  %s quiet | %s | %s | %s"):format(clock(e.t), e.moment or "-", e.ability or e.item or "-", e.why or "-"))
        elseif e.kind == "kill" then
          add(("  %s kill"):format(clock(e.t)))
        end
      end
    end
    if #s.loose > 0 then
      add("-- out of combat")
      for _, e in ipairs(s.loose) do if e.text then add("  " .. Log.describe(e, true) .. " | " .. (e.moment or "")) end end
    end
  end
  return table.concat(out, "\n")
end

-- the last n things said in the newest fight, written like the export (other players become classes); quiet
-- presses are left out unless asked for, since a report already lists the recent ones
function Log.recentLines(n, withQuiet)
  local sessions = ns.cdb and ns.cdb.log and ns.cdb.log.sessions or {}
  local s = sessions[#sessions]
  if not s then return {} end
  local fg
  for i = #s.fights, 1, -1 do if #s.fights[i].events > 0 then fg = s.fights[i] break end end
  if not fg then return {} end
  local lines = {}
  for _, e in ipairs(fg.events) do
    if e.text then lines[#lines + 1] = ("%s %s"):format(clock(e.t), Log.describe(e, true))
    elseif withQuiet and e.kind == "quiet" then lines[#lines + 1] = ("%s quiet | %s | %s | %s"):format(clock(e.t), e.moment or "-", e.ability or e.item or "-", e.why or "-") end
  end
  local out = {}
  for i = math.max(1, #lines - n + 1), #lines do out[#out + 1] = lines[i] end
  return out
end

local exportFrame
function Log.openExport()
  if not exportFrame then
    local f = W.panel("CROX2ExportFrame", "cro/x - export", 600, 460)
    exportFrame = f
    local hint = W.hint(f, "Everything below is selected. Copy it (Ctrl+C) and paste it into Discord, a form or an email.")
    hint:SetPoint("TOPLEFT", 16, -32)
    hint:SetPoint("RIGHT", -16, 0)
    local sf = W.make("ScrollFrame", f, {"UIPanelScrollFrameTemplate"}, "CROX2ExportScroll")
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
  exportFrame:Show()
  exportFrame.eb:SetText(Log.exportText())
  exportFrame.eb:SetFocus()
  exportFrame.eb:HighlightText()
end

------------------------------------------------------------------------
-- Testing mode: the data it collected, with a summary, ready to copy
------------------------------------------------------------------------
local function round1(x) return math.floor(x * 10 + 0.5) / 10 end

function Log.testFights()
  local out = {}
  for _, s in ipairs(ns.cdb and ns.cdb.log and ns.cdb.log.sessions or {}) do
    for _, fg in ipairs(s.fights) do if fg.test then out[#out + 1] = {s = s, f = fg} end end
  end
  return out
end

function Log.clearTest()
  for _, s in ipairs(ns.cdb and ns.cdb.log and ns.cdb.log.sessions or {}) do
    for i = #s.fights, 1, -1 do if s.fights[i].test then table.remove(s.fights, i) end end
  end
end

function Log.testReport()
  local cdb, pf = ns.cdb, ns.profile
  local out = {}
  local function add(x) out[#out + 1] = x end
  local gv, gb = "?", "?"
  if GetBuildInfo then local a, b = GetBuildInfo() gv, gb = a or "?", b or "?" end
  add(("cro/x TEST DATA · %s · game %s (%s) · %s"):format(ns.BUILD, gv, gb, date and date("%Y-%m-%d %H:%M") or ""))
  add(("character: %s %s · %s · homeland %s · origin %s · motivation %s"):format(pf.race or "?", (pf.class or "?"):lower(),
    cdb.temperament or "?", (cdb.homeland or "none"):gsub("^home:", ""), cdb.upbringing or "?", cdb.drive or "?"))
  local ch, rc = ns.CHATTY[cdb.chatty or 3], ns.CHATTY[cdb.raidChatty or 3]
  add(("pace: on your own %s (%s) · in a group %s (%s) · emotes %s · yell %s · call and response %s · ask %s · answer %s · take turns %s · profession lines %s"):format(
    ch and ch.name or "?", ch and ch.est or "?", rc and rc.name or "?", rc and rc.est or "?", tostring(cdb.emotes), tostring(cdb.yell),
    tostring(cdb.cr), tostring(cdb.crAsk), tostring(cdb.crGive), tostring(cdb.turns), tostring(cdb.profLines ~= false)))
  add(("errors this session: %d%s"):format(ns.Bug and ns.Bug.errorCount() or 0,
    (ns.Bug and ns.Bug.lastError()) and (" · last: " .. ns.Bug.lastError().msg) or ""))
  local list = Log.testFights()
  if #list == 0 then
    add("")
    add("No fights were captured. Turn testing mode on (Options > Testing), fight something or run the combat simulator, then copy again.")
    return table.concat(out, "\n")
  end
  -- totals over every captured fight
  local totalDur, totalSaid = 0, 0
  local reasons, moments, gaps = {}, {}, {}
  for _, it in ipairs(list) do
    local fg = it.f
    local prev
    totalDur = totalDur + (fg.dur or 0)
    for _, e in ipairs(fg.events) do
      if e.text then
        totalSaid = totalSaid + 1
        moments[e.moment or "?"] = (moments[e.moment or "?"] or 0) + 1
        if prev then gaps[#gaps + 1] = e.t - prev end
        prev = e.t
      elseif e.kind == "quiet" then
        local w = (e.why or "?"):gsub("%d+", "#")
        reasons[w] = (reasons[w] or 0) + 1
      end
    end
  end
  table.sort(gaps)
  local function pctile(q) if #gaps == 0 then return 0 end return gaps[math.max(1, math.ceil(#gaps * q))] end
  add("")
  add(("SUMMARY · %d fights · %s of combat · %d lines · about %s a minute"):format(#list, clock(totalDur), totalSaid,
    totalDur > 0 and round1(totalSaid / (totalDur / 60)) or "0"))
  add(("gaps between lines: shortest %ss · median %ss · 90%% under %ss · longest %ss"):format(
    #gaps > 0 and round1(gaps[1]) or "-", round1(pctile(0.5)), round1(pctile(0.9)), #gaps > 0 and round1(gaps[#gaps]) or "-"))
  local function top(t, n)
    local arr = {}
    for k, v in pairs(t) do arr[#arr + 1] = {k, v} end
    table.sort(arr, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    local o = {}
    for i = 1, math.min(n, #arr) do o[#o + 1] = ("%s x%d"):format(arr[i][1], arr[i][2]) end
    return table.concat(o, ", ")
  end
  add("said most on: " .. top(moments, 8))
  add("quiet because: " .. top(reasons, 8))
  add("")
  for i, it in ipairs(list) do
    local fg = it.f
    local said, quiet, prev, longest = 0, 0, 0, 0
    for _, e in ipairs(fg.events) do
      if e.text then said = said + 1 longest = math.max(longest, e.t - prev) prev = e.t
      elseif e.kind == "quiet" then quiet = quiet + 1 end
    end
    longest = math.max(longest, (fg.dur or 0) - prev)
    add(("-- fight %d%s · %s · vs %s · pace %s · %d said, %d quiet · longest silence %ss%s"):format(i, fg.sim and " (SIMULATED)" or "",
      clock(fg.dur), fg.foePlayer and "an enemy player" or (fg.foe or "?"), tostring(fg.pace or "?"), said, quiet, round1(longest),
      fg.flagged and " · FLAGGED" or ""))
    for idx, e in ipairs(fg.events) do
      if e.text then
        local fl = fg.flags and fg.flags[idx]
        add(("  %s SAID %s | %s | pace %s budget %s chance %s%%%s"):format(clock(e.t), Log.describe(e, true), e.moment or "", tostring(e.pace or "?"),
          tostring(e.budget or "?"), tostring(e.chance or "?"), fl and (" | FLAG: " .. (fl.reason or "?") .. ((fl.note and fl.note ~= "") and (" - " .. fl.note) or "")) or ""))
      elseif e.kind == "quiet" then
        add(("  %s quiet | %s | %s | %s | budget %s chance %s%%"):format(clock(e.t), e.moment or "-", e.ability or e.item or "-", e.why or "-",
          tostring(e.budget or "?"), tostring(e.chance or "?")))
      elseif e.kind == "kill" then
        add(("  %s kill"):format(clock(e.t)))
      end
    end
  end
  return table.concat(out, "\n")
end

local testFrame
function Log.openTestData()
  if not testFrame then
    local f = W.panel("CROX2TestDataFrame", "cro/x - test data", 640, 520)
    testFrame = f
    local how = W.text(f, "|cffffd100How to send this|r\n" ..
      "1. Leave testing mode on and play as you normally would, or run the combat simulator (/x sim).\n" ..
      "2. When you have a few fights, open this window (/x testdata, or Options > Testing > Copy test data).\n" ..
      "3. Click in the box, press Ctrl+A then Ctrl+C to copy everything.\n" ..
      "4. Paste it into the beta Discord (use a file or a code block for long text) or a GitHub issue, with a note on what felt wrong.\n" ..
      "Nothing is sent for you. Other players show only as their class, and the report has no account or email information.", "GameFontHighlightSmall")
    how:SetPoint("TOPLEFT", 16, -34)
    how:SetPoint("RIGHT", -16, 0)
    how:SetJustifyH("LEFT")
    how:SetWordWrap(true)
    local sf = W.make("ScrollFrame", f, {"UIPanelScrollFrameTemplate"}, "CROX2TestDataScroll")
    sf:SetPoint("TOPLEFT", 14, -130)
    sf:SetPoint("BOTTOMRIGHT", -32, 44)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetWidth(580)
    eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    sf:SetScrollChild(eb)
    f.eb = eb
    local sel = W.button(f, "Select all", 110, function() eb:SetFocus() eb:HighlightText() end)
    sel:SetPoint("BOTTOMRIGHT", -16, 12)
    local clear = W.button(f, "Clear test data", 130, function() Log.clearTest() eb:SetText(Log.testReport()) end)
    clear:SetPoint("RIGHT", sel, "LEFT", -6, 0)
    local close = W.button(f, "Close", 90, function() f:Hide() end)
    close:SetPoint("RIGHT", clear, "LEFT", -6, 0)
  end
  testFrame:Show()
  testFrame.eb:SetText(Log.testReport())
  testFrame.eb:SetFocus()
  testFrame.eb:HighlightText()
end
