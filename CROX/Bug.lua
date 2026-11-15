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
  parts[#parts + 1] = ("cro/x bug report · v%s · game %s (%s)"):format(ns.VERSION or "?", gv, gb)
  parts[#parts + 1] = "what: " .. reasonLabel(reason)
  if note and note ~= "" then parts[#parts + 1] = "note: " .. cut(note, 220) end
  parts[#parts + 1] = ("character: %s %s · %s · homeland %s · drive %s · chatty %s · filter %s · %s"):format(
    pf.race or "?", (pf.class or "?"):lower(), cdb.temperament or "?",
    (cdb.homeland or "none"):gsub("^home:", ""), cdb.drive or "?", tostring(cdb.chatty or 2),
    cdb.filter and "on" or "off", cdb.on == false and "OFF" or "on")
  parts[#parts + 1] = "hook: " .. ((ns.hookOK and ns.hookOK()) and "ok" or "NOT WORKING") ..
    " · errors this session: " .. Bug.errorCount()
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
