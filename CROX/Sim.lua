-- cro/x — combat simulator. A small window that looks like a chat frame and plays pretend fights through the
-- real line-picking logic, so a player can see (and the log can capture) how their character would talk without
-- needing an enemy. Nothing is sent to chat: lines appear only in this window, and the "said recently" memory is
-- put back when the test stops.

local ADDON, ns = ...
local W = ns.W
local Sim = {}
ns.Sim = Sim

local SCENARIOS = {
  {1, "One pull (30 seconds)", pulls = 1, dur = 30},
  {2, "Boss fight (3 minutes)", pulls = 1, dur = 180},
  {3, "Five pulls in a row", pulls = 5, dur = 30},
}
local FOES = {"Razormane Scout", "Venture Co. Laborer", "Bristleback Hunter", "Kolkar Raider",
  "Burning Blade Cultist", "Gnoll Brute", "Dustwind Harpy", "Defias Pillager"}
local REST = 6          -- seconds between pulls

local frame, msgs, run, snapshot, ticker
local details = false

local function say(text, r, g, b) if msgs then msgs:AddMessage(text, r or 1, g or 1, b or 1) end end

-- lines as the default chat window writes them
local function chatLine(channel, text)
  local name = ns.profile and ns.profile.name or "You"
  if channel == "YELL" then say(("%s yells: %s"):format(name, text), 1, 0.25, 0.25)
  elseif channel == "EMOTE" then say(("%s %s"):format(name, text), 1, 0.5, 0.25)
  else say(("%s says: %s"):format(name, text), 1, 1, 1) end
end

local function byArch()
  local cls = CROX2_ABILITIES and CROX2_ABILITIES[ns.profile and ns.profile.class or ""] or {}
  local by = {}
  for name, a in pairs(cls) do
    if not a.quiet and a.arch then by[a.arch] = by[a.arch] or {}; table.insert(by[a.arch], name) end
  end
  for _, l in pairs(by) do table.sort(l) end
  return by
end

local function foeTarget(r)
  return {exists = true, name = r.foe, enemy = true, friend = false, self = false, player = false, ctype = "humanoid",
    hp = r.foeHp, dead = r.foeHp <= 0, casting = r.casting, guid = "sim-" .. r.pull}
end
local function selfTarget(r)
  return {exists = true, name = ns.profile and ns.profile.name, enemy = false, friend = false, self = true, player = true,
    hp = r.hp, dead = false, casting = false, guid = "sim-self"}
end

-- a believable button to press right now: mostly fillers and heavy hits, finishers when the foe is low, a heal when you are
function Sim.pickAbility(r)
  local by = r.by
  local cands, total = {}, 0
  local function add(arch, w, selfCast)
    local list = by[arch]
    if not list then return end
    for _, name in ipairs(list) do
      local each = w / #list
      cands[#cands + 1] = {name = name, w = each, selfCast = selfCast}
      total = total + each
    end
  end
  add("filler", 40) add("heavy", 20) add("upkeep", 8) add("area", 6) add("reactive", 8)
  add("snare", 3) add("lockdown", 3) add("weaken", 3) add("taunt", 3)
  if r.foeHp < 25 then add("finisher", 30) end
  if r.casting then add("interrupt", 25) end
  add("heal", r.hp < 60 and 12 or 2, true) add("ward", 3, true) add("guard", 3, true)
  if r.hp < 35 then add("clutch", 25, true) add("laststand", 20, true) end
  add("powerup", 1.5, true)
  if total <= 0 then return nil end
  local x = math.random() * total
  for _, c in ipairs(cands) do
    x = x - c.w
    if x <= 0 then return c end
  end
  return cands[#cands]
end

local function setStatus(text) if frame and frame.status then frame.status:SetText(text) end end

local function startPull(t)
  run.pull = run.pull + 1
  run.foe = FOES[math.random(#FOES)]
  run.foeHp, run.hp, run.casting, run.killed = 100, 100, false, false
  run.start = t
  run.nextPress = t + 0.8
  run.nextHurt = t + 5 + math.random() * 6
  run.phase = "fight"
  ns.sim = {tgt = foeTarget(run), hp = run.hp, hurt = false}
  ns.simFight(true)
  say(("-- Pull %d: %s --"):format(run.pull, run.foe), 0.7, 0.7, 0.7)
end

local function endPull(t)
  ns.simFight(false)
  ns.sim = {tgt = {exists = false}, hp = 100, hurt = false}
  if run.pull >= run.scen.pulls then Sim.stop(true) return end
  run.phase = "rest"
  run.nextAt = t + REST
end

local function press(t)
  local c = Sim.pickAbility(run)
  if not c then return end
  ns.sim.tgt = c.selfCast and selfTarget(run) or foeTarget(run)
  ns.sim.hp = run.hp
  ns.sim.hurt = (t - (run.hurtAt or -100)) < 3
  if details then say("   > " .. c.name, 0.45, 0.6, 0.9) end
  local ok, err = pcall(ns.simPress, c.name)
  if not ok and ns.Bug then ns.Bug.capture(err) end
end

-- advance the pretend fight; the ticker calls this a few times a second
function Sim.tick()
  if not run then return end
  local t = ns.now()
  if run.phase == "rest" then
    setStatus(("Resting · next pull in %ds"):format(math.max(0, math.ceil(run.nextAt - t))))
    if t >= run.nextAt then startPull(t) end
    return
  end
  local elapsed = t - run.start
  run.foeHp = math.max(0, 100 - 100 * elapsed / run.scen.dur + (math.random() - 0.5) * 3)
  if run.killed then run.foeHp = 0 end
  if t >= run.nextHurt then
    run.hp = math.max(8, run.hp - (15 + math.random() * 25))
    run.hurtAt = t
    ns.simHurt()
    run.nextHurt = t + 6 + math.random() * 8
  elseif run.hp < 100 then
    run.hp = math.min(100, run.hp + 0.4)
  end
  run.casting = math.random() < 0.08
  if not run.killed and elapsed >= run.scen.dur then
    run.killed = true
    run.foeHp = 0
    ns.simKill(run.foe)
    run.nextPress = t + 1.0
  end
  if t >= run.nextPress then
    press(t)
    run.nextPress = t + 1.4 + math.random() * 0.5
    if run.killed then endPull(t) return end
  end
  setStatus(("Pull %d of %d · %d:%02d · budget %.1f"):format(run.pull, run.scen.pulls, math.floor(elapsed / 60), math.floor(elapsed % 60),
    ns.getBudget and ns.getBudget() or 0))
end

function Sim.running() return run ~= nil end

function Sim.start(scenario)
  if run then return end
  if not ns.cdb or not ns.cdb.on then say("cro/x is switched off for this character. Turn it on first (/x on).", 1, 0.5, 0.5) return end
  if ns.isAlliance and ns.isAlliance() then return end
  if InCombatLockdown and InCombatLockdown() then say("You are in a real fight. Try again when it's over.", 1, 0.5, 0.5) return end
  local scen = SCENARIOS[scenario or (frame and frame.scenario) or 1] or SCENARIOS[1]
  snapshot = ns.simSnapshot()
  run = {scen = scen, pull = 0, by = byArch(), phase = "rest", nextAt = ns.now(), foeHp = 100, hp = 100, casting = false}
  ns.sim = {tgt = {exists = false}, hp = 100, hurt = false}
  ns.simOut = chatLine
  ns.simQuiet = function(ctx, moment, why)
    if details then say(("   (quiet: %s - %s)"):format(ctx and ctx.ability or moment or "?", why or "?"), 0.55, 0.55, 0.55) end
  end
  say(("-- Simulating: %s as %s --"):format(scen[2], ns.profile and ns.profile.name or "you"), 0.7, 0.7, 0.7)
  if C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(0.25, function() Sim.tick() end) end
  if frame and frame.go then frame.go:SetText("Stop") end
  Sim.tick()
end

function Sim.stop(finished)
  if not run then return end
  if ticker and ticker.Cancel then ticker:Cancel() end
  ticker = nil
  if ns.inCombat and ns.sim then ns.simFight(false) end
  run = nil
  ns.sim, ns.simOut, ns.simQuiet = nil, nil, nil
  ns.simRestore(snapshot)
  snapshot = nil
  say(finished and "-- Done. Your test data is in /x testdata if testing mode was on. --" or "-- Stopped. --", 0.7, 0.7, 0.7)
  setStatus("Idle")
  if frame and frame.go then frame.go:SetText("Start") end
end

function Sim.open()
  if ns.isAlliance and ns.isAlliance() then return end
  if not frame then
    local f = W.panel("CROX2SimFrame", "cro/x - combat simulator", 520, 340)
    frame = f
    f.scenario = 1
    -- the chat-style area
    local chat = CreateFrame("Frame", nil, f)
    chat:SetPoint("TOPLEFT", 12, -52)
    chat:SetPoint("BOTTOMRIGHT", -12, 76)
    local bg = chat:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    -- a chat tab on top, like the default window's
    local tab = CreateFrame("Frame", nil, f)
    tab:SetSize(110, 20)
    tab:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", 0, 0)
    local tb = tab:CreateTexture(nil, "BACKGROUND")
    tb:SetAllPoints()
    tb:SetColorTexture(0, 0, 0, 0.7)
    local tt = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tt:SetPoint("CENTER")
    tt:SetText("Combat sim")
    msgs = CreateFrame("ScrollingMessageFrame", nil, chat)
    msgs:SetPoint("TOPLEFT", 6, -6)
    msgs:SetPoint("BOTTOMRIGHT", -6, 6)
    msgs:SetFontObject("ChatFontNormal")
    msgs:SetJustifyH("LEFT")
    msgs:SetMaxLines(300)
    msgs:SetFading(false)
    msgs:EnableMouseWheel(true)
    msgs:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
    f.msgs = msgs
    -- controls
    local dd = W.dropdown(f, 190, function()
      local t = {}
      for i, s in ipairs(SCENARIOS) do t[i] = {s[1], s[2]} end
      return t
    end, function() return f.scenario end, function(v) f.scenario = v end)
    dd:SetPoint("BOTTOMLEFT", 12, 44)
    f.dd = dd
    local go = W.button(f, "Start", 80, function() if run then Sim.stop() else Sim.start(f.scenario) end end)
    go:SetPoint("LEFT", dd, "RIGHT", 6, 0)
    f.go = go
    local clear = W.button(f, "Clear", 70, function() msgs:Clear() end)
    clear:SetPoint("LEFT", go, "RIGHT", 6, 0)
    local det = W.check(f, "Show presses and why it stayed quiet", function(_, on) details = on and true or false end)
    det:SetPoint("BOTTOMLEFT", 12, 14)
    f.det = det
    f.status = W.hint(f, "Idle")
    f.status:SetPoint("BOTTOMRIGHT", -14, 20)
    f:HookScript("OnHide", function() Sim.stop() end)
  end
  frame:Show()
  frame.dd.refresh()
  if not frame.welcomed then
    frame.welcomed = true
    say("Pretend fights run through your character's real lines. Nothing here goes to chat.", 0.7, 0.7, 0.7)
    say("Pick a fight and press Start. Turn on testing mode in Options to keep the data.", 0.7, 0.7, 0.7)
  end
end
