-- cro/x — group play: party pacing and call and response (second alpha).
-- The addons talk to each other with small hidden addon messages (prefix CROX). Everything the characters say
-- is public, in /say, /yell or emotes. Nothing personal is sent: names, classes, "I just spoke", what help is ready.

local ADDON, ns = ...
local p, secret, safe, str, num, now = ns.p, ns.secret, ns.safe, ns.str, ns.num, ns.now

local PREFIX = "CROX"
local G = {}
ns.G = G

local members = {}           -- [name] = {class, ver, flags, flagsT, seen}
G.members = members
local partyTimes = {}        -- times of party lines (last minute)
local lastPartySpoke, lastPartySpeaker = -1000, nil
local pendingReply           -- {kind, caller, t, dtype}
local pendingThanks          -- {helper, t}
local lastCall = {}          -- [kind] = time
local REPLY_WINDOW = 6
local PARTY_HOLD = 5
local PARTY_CAP = {[1] = 3, [2] = 5, [3] = 6}

-- Multi-speaker groundwork (see docs/Raid and Multi-Speaker (proposal).md).
-- A moment that several characters can answer is an "exchange": an id, the moment, who started it, and a list
-- of speaker slots. Nobody negotiates: every addon sees the same roster and the same id, so each works out the
-- same speakers with the same ranking function. PROTO goes out with HI so builds with different rules can mix.
G.PROTO = 1
local SLOTS = {rally = 1, kill = 1}      -- answerers wanted per moment; raids will raise these
local exCounter = 0
local exchanges = {}                      -- the last few exchanges, newest last: {id, moment, from, slots, t}
G.exchanges = exchanges

local function hashName(s)             -- exact in double precision, so every machine gets the same numbers
  local h = 12345
  for i = 1, #s do h = ((h + s:byte(i)) * 48271) % 2147483647 end
  for _ = 1, 3 do h = (h * 48271) % 2147483647 end
  return h
end

-- the same order on every machine for a given exchange id
function G.rank(xid, names)
  local out = {}
  for i, n in ipairs(names) do out[i] = n end
  local key = {}
  for _, n in ipairs(out) do key[n] = hashName(tostring(xid) .. "|" .. n) end
  table.sort(out, function(a, b) if key[a] ~= key[b] then return key[a] < key[b] end return a < b end)
  return out
end

-- the first n of the ranked candidates, leaving out anyone in `skip`
function G.speakers(xid, candidates, n, skip)
  local list = {}
  for _, name in ipairs(candidates) do if not (skip and skip[name]) then list[#list + 1] = name end end
  local ranked, out = G.rank(xid, list), {}
  for i = 1, math.min(n or 1, #ranked) do out[i] = ranked[i] end
  return out
end

local function noteExchange(xid, moment, from, slots)
  exchanges[#exchanges + 1] = {id = xid, moment = moment, from = from, slots = slots, t = now()}
  while #exchanges > 10 do table.remove(exchanges, 1) end
end

local function newExchangeId()
  exCounter = exCounter + 1
  return (ns.profile.name or "?") .. "-" .. exCounter
end

local function me() return ns.profile.name or str(safe(UnitName, "player")) end
local function short(n) if type(n) ~= "string" or secret(n) then return nil end return n:match("^[^-]+") or n end
local function grouped() return safe(IsInGroup) and true or false end

-- my raid subgroup (0 in a party)
local function mySubgroup()
  if not safe(IsInRaid) then return 0 end
  for i = 1, (num(safe(GetNumGroupMembers)) or 0) do
    local name, _, sub = safe(GetRaidRosterInfo, i)
    if short(str(name)) == me() then return num(sub) or 0 end
  end
  return 0
end

local function channel()
  if safe(IsInRaid) then return "RAID" end
  if grouped() then return "PARTY" end
end

local function send(kind, ...)
  local ch = channel()
  if not ch then return end
  local parts = {"V2", kind, tostring(mySubgroup())}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  local f = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
  if f then pcall(f, PREFIX, table.concat(parts, "|"), ch) end
end

do
  local reg = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
  if reg then pcall(reg, PREFIX) end
end

-- the unit token for a group member's name
local function unitFor(name)
  if not name then return nil end
  if name == me() then return "player" end
  local raid = safe(IsInRaid)
  for i = 1, (num(safe(GetNumGroupMembers)) or 0) do
    local u = raid and ("raid" .. i) or ("party" .. i)
    if short(str(safe(UnitName, u))) == name then return u end
  end
end

-- other cro/x users in my party (fresh in the last few minutes)
local function others()
  local out = {}
  local t = now()
  for name, m in pairs(members) do
    if name ~= me() and t - (m.seen or 0) < 300 and unitFor(name) then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end
G.others = others

------------------------------------------------------------------------
-- What help I can give right now
------------------------------------------------------------------------
local CURE = {
  poison = {"Cure Poison", "Abolish Poison", "Purify", "Cleanse", "Poison Cleansing Totem"},
  disease = {"Cure Disease", "Abolish Disease", "Purify", "Cleanse", "Disease Cleansing Totem"},
  curse = {"Remove Curse", "Remove Lesser Curse"},
  magic = {"Dispel Magic", "Cleanse"},
}
local HEALS = {"Lesser Heal", "Heal", "Flash Heal", "Greater Heal", "Renew", "Healing Wave", "Lesser Healing Wave",
  "Holy Light", "Flash of Light", "Healing Touch", "Regrowth", "Rejuvenation", "Holy Shock", "Penance", "Riptide",
  "Swiftmend", "Lay on Hands"}
local TAUNTS = {"Taunt", "Mocking Blow", "Challenging Shout", "Growl", "Challenging Roar", "Stoneclaw Totem"}
local TANK_FORMS = {["Defensive Stance"] = true, ["Bear Form"] = true, ["Dire Bear Form"] = true}
local FLAG_OF = {poison = "P", disease = "D", curse = "C", magic = "M"}

local function spellReady(name)
  local known = safe(GetSpellInfo, name)
  if not known or secret(known) then return false end
  local usable = safe(IsUsableSpell, name)
  if secret(usable) or not usable then return false end
  local start, dur = safe(GetSpellCooldown, name)
  if type(start) == "table" then start, dur = start.startTime, start.duration end
  if secret(start) or secret(dur) then return false end
  if num(dur) and dur > 1.6 then return false end
  return true
end

local function anyReady(list)
  for _, n in ipairs(list) do if spellReady(n) then return true end end
  return false
end

local function myFlags()
  local f = ""
  for kind, list in pairs(CURE) do if anyReady(list) then f = f .. FLAG_OF[kind] end end
  if anyReady(HEALS) then f = f .. "H" end
  if anyReady(TAUNTS) then f = f .. "T" end
  local form = ns.activeForm and ns.activeForm()
  if form and TANK_FORMS[form] then f = f .. "K" end
  return f
end

-- a cro/x member who can help with what (fresh status only)
local function helperFor(flagLetter)
  local t = now()
  local best
  for _, name in ipairs(others()) do
    local m = members[name]
    if m.flags and t - (m.flagsT or 0) < 8 and m.flags:find(flagLetter, 1, true) then
      if flagLetter == "T" and m.flags:find("K", 1, true) then return name end   -- a tank first
      best = best or name
    end
  end
  return best
end

------------------------------------------------------------------------
-- Party pacing
------------------------------------------------------------------------
function G.paceBlock(t)
  local cdb = ns.cdb
  if not cdb.turns or not grouped() or #others() == 0 then return nil end
  if t - lastPartySpoke < PARTY_HOLD then return "party: holding after someone spoke" end
  local n = 0
  for i = #partyTimes, 1, -1 do if t - partyTimes[i] < 60 then n = n + 1 else break end end
  if n >= (PARTY_CAP[ns.chattyNow()] or 5) then return "party: pace for the whole party" end
  if lastPartySpeaker == me() and t - lastPartySpoke < 20 then return "party: letting someone else talk" end
end

local function notePartyLine(who)
  local t = now()
  lastPartySpoke, lastPartySpeaker = t, who
  partyTimes[#partyTimes + 1] = t
  while #partyTimes > 20 do table.remove(partyTimes, 1) end
end

-- Core calls this after any line goes out. kind: "said" | "call" | "reply"
function G.noteSpoke(kind)
  if kind == "call" then return end          -- a call counts only once answered (the reply counts the pair)
  notePartyLine(me())
  send("SP", kind == "reply" and 1 or 0)
end

------------------------------------------------------------------------
-- Saying calls and replies
------------------------------------------------------------------------
local function distanceChannel(name)
  local u = unitFor(name)
  local close = u and safe(CheckInteractDistance, u, 4)
  if secret(close) then close = nil end
  if close then return "SAY" end
  return ns.cdb.yell and "YELL" or "SAY"
end

local function sayCR(pool, kind, other, ctx)
  ctx = ctx or ns.makeCtx(nil, nil)
  local c = ns.choose("cr", {pool}, ctx, {noTags = true})
  if not c then return false end
  local m = members[other]
  return ns.deliver(c, ctx, pool, {ally = other, allyClass = m and m.class},
    {channel = distanceChannel(other), kind = kind, noBroadcast = kind == "call"})
end

-- B: the reply, when the caller's need is actually met
local function reply(kind, caller, ctx)
  local ok = sayCR("cr:" .. kind .. ":reply", "reply", caller, ctx)
  pendingReply = nil
  return ok
end

-- called by Core for every ready ability press (after the archetype is known). true = this press spoke.
function G.onAbility(arch, ctx)
  if not ns.cdb.cr or not grouped() then return false end
  local tname = ctx.tgt and ctx.tgt.name
  -- a save: healing an ally who was nearly dead, or raising them
  if tname and ctx.onAlly and members[tname] and (arch == "raise" or ((arch == "heal" or arch == "clutch" or arch == "ward")
      and ctx.tgt.hp and ctx.tgt.hp < 35)) then
    send("SAVED", tname)
  end
  local pr = pendingReply
  if not pr or now() - pr.t > REPLY_WINDOW then pendingReply = nil return false end
  if pr.kind == "debuffhelp" and arch == "cleanse" and tname == pr.caller then return reply("debuffhelp", pr.caller, ctx) end
  if pr.kind == "lowhealth" and (arch == "heal" or arch == "clutch" or arch == "ward") and tname == pr.caller then
    return reply("lowhealth", pr.caller, ctx)
  end
  if pr.kind == "getoff" and arch == "taunt" then return reply("getoff", pr.caller, ctx) end
  return false
end

local function cooled(kind, secs)
  local t = now()
  if lastCall[kind] and t - lastCall[kind] < secs then return false end
  return true
end

-- called by Core first on every press. true = this press spoke.
function G.onPress(info, t)
  if not grouped() then return false end
  -- replies any press can carry: rally, kill, "don't mention it"
  local pr = pendingReply
  if pr and t - pr.t <= REPLY_WINDOW and (pr.kind == "rally" or pr.kind == "kill" or pr.kind == "thanks") then
    return reply(pr.kind, pr.caller)
  end
  if pr and t - pr.t > REPLY_WINDOW then pendingReply = nil end
  -- thanks for the save
  local pt = pendingThanks
  if pt and t - pt.t <= REPLY_WINDOW then
    pendingThanks = nil
    if sayCR("cr:thanks:call", "call", pt.helper) then send("THANKS", pt.helper) return true end
  elseif pt then pendingThanks = nil end

  if not ns.inCombat or #others() == 0 then return false end

  -- debuff help: replaces the debuff callout
  local q = ns.debuffQueue
  local d = q[1]
  if d and FLAG_OF[d.kind or ""] and d.kind ~= "magic" and cooled("debuffhelp", 20) then
    local helper = helperFor(FLAG_OF[d.kind])
    if helper then
      table.remove(q, 1)
      local ctx = ns.makeCtx(nil, nil)
      ctx.debuffName, ctx.debuffType = d.name, d.kind
      if sayCR("cr:debuffhelp:call", "call", helper, ctx) then
        lastCall.debuffhelp = t
        local x = newExchangeId()
        noteExchange(x, "debuffhelp", me(), {helper})
        send("CALL", "debuffhelp", helper, d.kind, x)
        return true
      end
    end
  end

  -- low health
  local hp = ns.pct("player")
  if hp and hp < 35 and cooled("lowhealth", 30) then
    local helper = helperFor("H")
    if helper then
      if sayCR("cr:lowhealth:call", "call", helper) then
        lastCall.lowhealth = t
        local x = newExchangeId()
        noteExchange(x, "lowhealth", me(), {helper})
        send("CALL", "lowhealth", helper, "", x)
        return true
      end
    end
  end

  -- get it off me: an enemy really on me, and I'm not the tank
  local form = ns.activeForm and ns.activeForm()
  if not (form and TANK_FORMS[form]) and cooled("getoff", 30) then
    local can = safe(UnitCanAttack, "player", "target")
    local onMe = not secret(can) and can and safe(UnitIsUnit, "targettarget", "player")
    if secret(onMe) then onMe = nil end
    if onMe then
      local helper = helperFor("T")
      if helper and sayCR("cr:getoff:call", "call", helper) then
        lastCall.getoff = t
        local x = newExchangeId()
        noteExchange(x, "getoff", me(), {helper})
        send("CALL", "getoff", helper, "", x)
        return true
      end
    end
  end
  return false
end

-- Core tells us when it said a rally or kill line: one other member answers
function G.onRallySpoken() local x = newExchangeId() noteExchange(x, "rally", me(), {}) send("RALLY", x) end
function G.onKillSpoken() local x = newExchangeId() noteExchange(x, "kill", me(), {}) send("KILL", x) end

------------------------------------------------------------------------
-- Receiving
------------------------------------------------------------------------
-- the members who answer a rally or a kill: the same ranked pick on every machine, never the caller
local function answerers(caller, xid, n)
  local list = others()
  list[#list + 1] = me()
  return G.speakers(xid, list, n, {[caller] = true})
end
local function iAmAnAnswerer(list)
  for _, name in ipairs(list) do if name == me() then return true end end
  return false
end

local function onAddon(prefix, msg, ch, sender)
  if secret(prefix) or prefix ~= PREFIX or secret(msg) or type(msg) ~= "string" then return end
  local from = short(str(sender))
  if not from or from == me() then return end
  local parts = {}
  for x in (msg .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = x end
  if parts[1] ~= "V2" then return end
  local kind, sub = parts[2], tonumber(parts[3]) or 0
  if safe(IsInRaid) and sub ~= mySubgroup() then return end
  local m = members[from] or {}
  members[from] = m
  m.seen = now()
  local t = now()
  if kind == "HI" then
    local isNew = not m.ver
    m.ver, m.class, m.proto = parts[4], parts[5], tonumber(parts[6])
    if isNew then send("HI", ns.VERSION, ns.profile.class or "", G.PROTO) end
  elseif kind == "ST" then
    m.flags, m.flagsT = parts[4] or "", t
  elseif kind == "SP" then
    notePartyLine(from)
  elseif kind == "CALL" then
    local xid = (parts[7] and parts[7] ~= "") and parts[7] or (from .. "-" .. math.floor(t))
    noteExchange(xid, parts[4], from, {parts[5]})
    if parts[5] == me() then pendingReply = {kind = parts[4], caller = from, t = t, dtype = parts[6], xid = xid} end
  elseif kind == "RALLY" or kind == "KILL" then
    local moment = kind == "RALLY" and "rally" or "kill"
    local xid = (parts[4] and parts[4] ~= "") and parts[4] or (from .. "-" .. math.floor(t))
    local who = answerers(from, xid, SLOTS[moment])
    noteExchange(xid, moment, from, who)
    if ns.cdb.cr and iAmAnAnswerer(who) then pendingReply = {kind = moment, caller = from, t = t, xid = xid} end
  elseif kind == "SAVED" then
    if parts[4] == me() and ns.cdb.cr then pendingThanks = {helper = from, t = t} end
  elseif kind == "THANKS" then
    if parts[4] == me() and ns.cdb.cr then pendingReply = {kind = "thanks", caller = from, t = t} end
  end
end

------------------------------------------------------------------------
-- Status every few seconds in combat; hello on joining
------------------------------------------------------------------------
local acc, lastFlags, lastSent = 0, nil, 0
local f = CreateFrame("Frame")
f:SetScript("OnUpdate", function(_, el)
  acc = acc + (el or 0)
  if acc < 1 then return end
  acc = 0
  if not ns.cdb or not ns.cdb.on or not ns.cdb.cr or not grouped() or not ns.inCombat then return end
  local fl = myFlags()
  local t = now()
  if fl ~= lastFlags or t - lastSent >= 4 then
    lastFlags, lastSent = fl, t
    send("ST", fl)
  end
end)

local ev = CreateFrame("Frame")
for _, e in ipairs({"CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "CHAT_MSG_ADDON" then pcall(onAddon, ...) return end
  if not ns.cdb or not ns.cdb.on then return end
  if event == "PLAYER_REGEN_DISABLED" then
    lastFlags = nil
    return
  end
  if grouped() then send("HI", ns.VERSION, ns.profile.class or "", G.PROTO) end
end)

G._test = {answerers = answerers, exchanges = exchanges, onAddon = onAddon, members = members, setPending = function(v) pendingReply = v end,
  setThanks = function(v) pendingThanks = v end, myFlags = myFlags, helperFor = helperFor}
