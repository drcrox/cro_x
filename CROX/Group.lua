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
local lastPartyYell = -1000                      -- when anyone in the party last yelled (a line, not a call across distance)
local PARTY_YELL_GAP = 20
local lastCallAny = -1000                       -- when anyone in the party last called for help (one call at a time)
local EXCH_GAP_MIN, EXCH_GAP_MAX = 15, 60
local lineTimes = {}                             -- when the party's recent lines went out (any kind), for the crowding limit
local pendingReply           -- {kind, caller, t, dtype}
local pendingThanks          -- {helper, t}
local lastCall = {}          -- [kind] = time
local REPLY_WINDOW = 6
local PARTY_HOLD = 3           -- seconds after anyone in the party speaks before the next voice
local PARTY_BUDGET_CAP = 2.5   -- the party shares a speech budget, set by its loudest member

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
local function grouped() return ns.simParty ~= nil or (safe(IsInGroup) and true or false) end

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
  if ns.simParty then return "PARTY" end
  if safe(IsInRaid) then return "RAID" end
  if grouped() then return "PARTY" end
end

local function send(kind, ...)
  local ch = channel()
  if not ch then return end
  local parts = {"V2", kind, tostring(mySubgroup())}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  if ns.simParty then       -- the simulator: queue it for the other simulated players, as the game would deliver it
    G.simInbox[#G.simInbox + 1] = {from = ns.simActor, msg = table.concat(parts, "|")}
    return
  end
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
  if ns.simParty then return "simparty" end
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
-- Nearby cro/x users outside my group. When someone near me speaks, I send them one silent addon whisper (a hello). A player
-- who runs cro/x answers, and from then on we swap the same "I just spoke" notices a party does, so we pace, take turns and
-- keep yells apart without being grouped. Players without cro/x never see anything: an addon whisper nobody listens for is
-- dropped by the game. Calls for help and replies stay a party thing. The "nearby" switch turns all of this off.
------------------------------------------------------------------------
local near = {}              -- [name] = {seen, level}: cro/x users who answered, near me and not in my group
G.near = near
local probed = {}            -- [name] = when I last sent them a hello
local lastProbe = -1000
local NEAR_FRESH = 180       -- a nearby cro/x user counts for this many seconds after I last heard from them
local PROBE_NEW, PROBE_KNOWN = 900, 60

local function nearOn() return ns.cdb ~= nil and ns.cdb.on and ns.cdb.nearby ~= false and not ns.simParty end
local function nearPeers()
  local out = {}
  if not nearOn() then return out end
  local t = now()
  for name, m in pairs(near) do
    if t - (m.seen or 0) < NEAR_FRESH and not unitFor(name) then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end
G.nearPeers = nearPeers
local function whisper(to, msg)
  local f = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
  if f then pcall(f, PREFIX, msg, "WHISPER", to) end
end
local function sendNear(kind, ...)
  local peers = nearPeers()
  if #peers == 0 then return end
  local parts = {"V2", kind, "0"}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  local msg = table.concat(parts, "|")
  for i = 1, math.min(#peers, 8) do whisper(peers[i], msg) end
end
local function helloMsg() return table.concat({"V2", "HI", "0", ns.VERSION, ns.profile.class or "", G.PROTO, ns.chattyNow()}, "|") end
-- someone near me spoke (say, yell or emote): say hello once in a while
local function probe(sender)
  if not nearOn() or secret(sender) or type(sender) ~= "string" then return end
  local who = short(sender)
  if not who or who == me() then return end
  if unitFor(who) then return end                       -- in my group: the party channel already covers them
  local t = now()
  local gap = near[who] and PROBE_KNOWN or PROBE_NEW
  if probed[who] and t - probed[who] < gap then return end
  if t - lastProbe < 3 then return end                  -- never a burst of hellos
  local n = 0 for _ in pairs(probed) do n = n + 1 end
  if n > 200 then probed = {} end
  probed[who], lastProbe = t, t
  whisper(sender, helloMsg())
end
G.probe = probe

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
local pBudget, pBudgetT = 1.0, 0
-- the loudest pace level in the group (levels ride along on HI and SP messages)
local function loudest()
  local lv = ns.chattyNow()
  for _, name in ipairs(others()) do
    local m = members[name]
    if m and m.level and m.level > lv then lv = m.level end
  end
  for _, name in ipairs(nearPeers()) do
    local m = near[name]
    if m and m.level and m.level > lv then lv = m.level end
  end
  return lv
end
local function refillParty(t)
  local ch = ns.CHATTY[loudest()] or ns.CHATTY[3]
  if pBudgetT == 0 then pBudgetT = t end
  pBudget = math.min(PARTY_BUDGET_CAP, pBudget + (t - pBudgetT) * ch.rate / 60)
  pBudgetT = t
end
-- other voices to pace with: cro/x users in my group, or nearby ones who answered a hello
function G.hasVoices() return (grouped() and #others() > 0) or #nearPeers() > 0 end
function G.fightStart() pBudget, pBudgetT = math.min(pBudget, 1.0), 0 end
function G.sinceAny(t) return t - lastPartySpoke end
function G.paceBlock(t)
  local cdb = ns.cdb
  if not cdb.turns or not G.hasVoices() then return nil end
  if t - lastPartySpoke < PARTY_HOLD then return "party: holding after someone spoke" end
  local crowded = G.chatBlock(t, 4)
  if crowded then return crowded end
  refillParty(t)
  if pBudget < 1 then return "party: pace for the whole party" end
  if lastPartySpeaker == me() and t - lastPartySpoke < 15 then return "party: letting someone else talk" end
end

local function notePartyLine(who)
  local t = now()
  refillParty(t)
  pBudget = math.max(0, pBudget - 1)
  lastPartySpoke, lastPartySpeaker = t, who
  partyTimes[#partyTimes + 1] = t
  while #partyTimes > 20 do table.remove(partyTimes, 1) end
end

local function noteLine(t)
  lineTimes[#lineTimes + 1] = t
  while #lineTimes > 30 do table.remove(lineTimes, 1) end
end
-- Crowding limit: no matter the dials, a party of voices does not say more than a few lines in ten seconds. Said lines
-- stop at 4, answers at 5; the thanks and answers to thanks that trail an exchange stop sooner, at 3, so they never pile on top of it.
local CROWD_SECS = 10
function G.chatBlock(t, limit)
  if not ns.cdb.turns or not G.hasVoices() then return nil end
  local n = 0
  for i = #lineTimes, 1, -1 do
    if t - lineTimes[i] <= CROWD_SECS then n = n + 1 else break end
  end
  if n >= limit then return "party: too many lines just now" end
end

-- Core calls this after any line goes out. kind: "said" | "call" | "reply"
function G.noteSpoke(kind, yelled)
  noteLine(now())
  if kind == "call" then return end          -- a call counts only once answered (the reply counts the pair)
  notePartyLine(me())
  if yelled then
    lastPartyYell = now()
    send("SP", kind == "reply" and 1 or 0, ns.chattyNow(), "Y")
    sendNear("SP", kind == "reply" and 1 or 0, ns.chattyNow(), "Y")
  else
    send("SP", kind == "reply" and 1 or 0, ns.chattyNow())
    sendNear("SP", kind == "reply" and 1 or 0, ns.chattyNow())
  end
end
-- Calls for help: the party makes one at a time. Without this, a pull that goes wrong has everyone calling and answering
-- at once, which no dial can calm. The gap after a call is shorter at louder paces (90 / lines a minute, kept between 15
-- and 60 seconds). A held call is not lost: the press falls through to the ordinary line, and the call comes again at
-- the next press once the gap is over.
function G.callBlock(t)
  if not ns.cdb.turns or #others() == 0 then return nil end
  local ch = ns.CHATTY[loudest()] or ns.CHATTY[3]
  local gap = math.max(EXCH_GAP_MIN, math.min(EXCH_GAP_MAX, 90 / ch.rate))
  if t - lastCallAny < gap then return "party: someone just called for help" end
end
-- true while someone in the party has just yelled: only one shout at a time
function G.yellBlock(t)
  if not G.hasVoices() then return false end
  return t - lastPartyYell < PARTY_YELL_GAP
end

------------------------------------------------------------------------
-- Saying calls and replies
------------------------------------------------------------------------
local function distanceChannel(name)
  if ns.simParty then                      -- the simulator has no distances: say, with the odd one far enough to yell
    return (ns.cdb.yell and math.random() < 0.12) and "YELL" or "SAY"
  end
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
  local ok = ns.deliver(c, ctx, pool, {ally = other, allyClass = m and m.class},
    {channel = distanceChannel(other), kind = kind, noBroadcast = kind == "call"})
  if ok and kind == "call" then noteLine(now()) end       -- calls and thanks skip the broadcast, but they are still lines
  return ok
end

-- Call and response dials (Options > Group). Each is a level 1-4; 4 = always, as before. A is asking for help, B is
-- answering one. Staying quiet never means refusing to help: the ability still goes off, only the line is skipped.
-- Room left for the rest of the plan (see docs/Raid and Multi-Speaker (proposal).md): offering aid, chiming in on
-- other people's A and B lines (C), and a party member remarking on a call that went unanswered.
local CR_CHANCE = {[1] = 0.25, [2] = 0.5, [3] = 0.8, [4] = 1}
G.CR_CHANCE = CR_CHANCE
function G.crRoll(key)
  local p = CR_CHANCE[(ns.cdb and ns.cdb[key]) or 4] or 1
  return p >= 1 or math.random() < p
end
G.unanswered = 0

-- B: the reply, when the caller's need is actually met
local function reply(kind, caller, ctx)
  if G.chatBlock(now(), kind == "thanks" and 3 or 5) then
    pendingReply = nil                           -- too many voices just now: the help still happened, the line is skipped
    return false
  end
  if not G.crRoll("crGive") then
    -- the help happened but this one stays quiet: the call goes unanswered (a later build can have the party remark on it)
    local pr = pendingReply
    pendingReply = nil
    G.unanswered = G.unanswered + 1
    for i = #exchanges, 1, -1 do
      if pr and exchanges[i].id == pr.xid then exchanges[i].unanswered = true break end
    end
    return false
  end
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
    if G.chatBlock(t, 3) then return false end
    if sayCR("cr:thanks:call", "call", pt.helper) then send("THANKS", pt.helper) return true end
  elseif pt then pendingThanks = nil end

  if not ns.inCombat or #others() == 0 then return false end
  if G.callBlock(t) then return false end

  -- debuff help: replaces the debuff callout
  local q = ns.debuffQueue
  local d = q[1]
  if d and FLAG_OF[d.kind or ""] and d.kind ~= "magic" and cooled("debuffhelp", 20) then
    local helper = helperFor(FLAG_OF[d.kind])
    if helper and not G.crRoll("crAsk") then
      lastCall.debuffhelp = t        -- not asking this time; the normal callout goes ahead, ask again after the cooldown
    elseif helper then
      table.remove(q, 1)
      local ctx = ns.makeCtx(nil, nil)
      ctx.debuffName, ctx.debuffType = d.name, d.kind
      if sayCR("cr:debuffhelp:call", "call", helper, ctx) then
        lastCall.debuffhelp = t
        local x = newExchangeId()
        noteExchange(x, "debuffhelp", me(), {helper})
        lastCallAny = t
        send("CALL", "debuffhelp", helper, d.kind, x)
        return true
      end
    end
  end

  -- low health
  local hp = ns.pct("player")
  if hp and hp < 35 and cooled("lowhealth", 30) then
    local helper = helperFor("H")
    if helper and not G.crRoll("crAsk") then
      lastCall.lowhealth = t
    elseif helper then
      if sayCR("cr:lowhealth:call", "call", helper) then
        lastCall.lowhealth = t
        local x = newExchangeId()
        noteExchange(x, "lowhealth", me(), {helper})
        lastCallAny = t
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
    if ns.simParty then onMe = ns.sim and ns.sim.onMe or false end
    if onMe then
      local helper = helperFor("T")
      if helper and not G.crRoll("crAsk") then
        lastCall.getoff = t
      elseif helper and sayCR("cr:getoff:call", "call", helper) then
        lastCall.getoff = t
        local x = newExchangeId()
        noteExchange(x, "getoff", me(), {helper})
        lastCallAny = t
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
  if ch == "WHISPER" then                    -- a nearby cro/x user (not in my group): hellos and "just spoke" notices only
    if not nearOn() or unitFor(from) then return end
    local t = now()
    local n = near[from]
    local isNew = not n or t - (n.seen or 0) >= NEAR_FRESH
    if not n then n = {} near[from] = n end
    n.seen = t
    if kind == "HI" then
      n.level = tonumber(parts[7]) or n.level
      if isNew then whisper(sender, helloMsg()) end
    elseif kind == "SP" then
      n.level = tonumber(parts[5]) or n.level
      if parts[6] == "Y" then lastPartyYell = t end
      notePartyLine(from)
      noteLine(t)
    end
    return
  end
  if safe(IsInRaid) and sub ~= mySubgroup() then return end
  local m = members[from] or {}
  members[from] = m
  m.seen = now()
  local t = now()
  if kind == "HI" then
    local isNew = not m.ver
    m.ver, m.class, m.proto = parts[4], parts[5], tonumber(parts[6])
    m.level = tonumber(parts[7]) or m.level
    if isNew then send("HI", ns.VERSION, ns.profile.class or "", G.PROTO, ns.chattyNow()) end
  elseif kind == "ST" then
    m.flags, m.flagsT = parts[4] or "", t
  elseif kind == "SP" then
    m.level = tonumber(parts[5]) or m.level
    if parts[6] == "Y" then lastPartyYell = t end
    if not ns.simParty then notePartyLine(from) noteLine(t) end      -- (the simulator's party shares one budget, so the speaker's own line already counted)
  elseif kind == "CALL" then
    lastCallAny = t
    if not ns.simParty then noteLine(t) end
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
    if not ns.simParty then noteLine(t) end
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
  if ns.simParty or not ns.cdb or not ns.cdb.on or not ns.cdb.cr or not grouped() or not ns.inCombat then return end
  local fl = myFlags()
  local t = now()
  if fl ~= lastFlags or t - lastSent >= 4 then
    lastFlags, lastSent = fl, t
    send("ST", fl)
  end
end)

local ev = CreateFrame("Frame")
for _, e in ipairs({"CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
  "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "CHAT_MSG_ADDON" then pcall(onAddon, ...) return end
  if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_EMOTE" then
    local _, sender = ...
    pcall(probe, sender)
    return
  end
  if not ns.cdb or not ns.cdb.on then return end
  if event == "PLAYER_REGEN_DISABLED" then
    lastFlags = nil
    return
  end
  if grouped() then send("HI", ns.VERSION, ns.profile.class or "", G.PROTO, ns.chattyNow()) end
end)

------------------------------------------------------------------------
-- Simulator support: each simulated player keeps its own roster, pending replies and call times; the party budget
-- is shared (in the game every addon ends up with nearly the same one)
------------------------------------------------------------------------
G.simInbox = {}
function G.simFresh() return {members = {}, lastCall = {}, exchanges = {}} end
function G.simGet() return {members = members, pendingReply = pendingReply, pendingThanks = pendingThanks, lastCall = lastCall, exchanges = exchanges} end
function G.simSet(g)
  g = g or G.simFresh()
  members, pendingReply, pendingThanks, lastCall, exchanges = g.members, g.pendingReply, g.pendingThanks, g.lastCall, g.exchanges
  G.members, G.exchanges = members, exchanges
end
function G.simPending() return pendingReply end
function G.simResetParty() pBudget, pBudgetT, lastPartySpoke, lastPartySpeaker, lastPartyYell, lastCallAny = 1.0, 0, -1000, nil, -1000, -1000 for i = #partyTimes, 1, -1 do partyTimes[i] = nil end for i = #lineTimes, 1, -1 do lineTimes[i] = nil end end
-- what a character of this class can help with, as the status flags the real addon sends
local SIM_FLAGS = {WARRIOR = "T", PALADIN = "PDMH", PRIEST = "DMH", SHAMAN = "PDHT", DRUID = "PCHT", MAGE = "C", HUNTER = "", ROGUE = "", WARLOCK = ""}
function G.simFlags(class, spec)
  local f = SIM_FLAGS[class or ""] or ""
  if (class == "WARRIOR" and spec == "Protection") or (class == "DRUID" and spec == "Feral") then f = f .. "K" end
  return f
end
-- deliver everything queued: each message goes to every other simulated player, through the real receiving code
function G.simFlush(forEach)
  local guard = 0
  while #G.simInbox > 0 and guard < 200 do
    guard = guard + 1
    local item = table.remove(G.simInbox, 1)
    forEach(item.from, item.msg)
  end
end
function G.simReceive(sender, msg) onAddon(PREFIX, msg, "PARTY", sender) end

G._test = {probe = probe, near = near, nearPeers = nearPeers, answerers = answerers, exchanges = exchanges, onAddon = onAddon, members = members, setPending = function(v) pendingReply = v end,
  setThanks = function(v) pendingThanks = v end, myFlags = myFlags, helperFor = helperFor}
