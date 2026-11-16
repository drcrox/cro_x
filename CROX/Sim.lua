-- cro/x — combat simulator. A small window that looks like a chat frame and plays pretend fights through the
-- real line-picking logic, so a player can see (and the log can capture) how their character would talk without
-- needing an enemy. Nothing is sent to chat: lines appear only in this window, and the "said recently" memory is
-- put back when the test stops.
--
-- Time is pretend too: the sim runs on its own clock (ns.simClock) at 2x, 4x, 6x or instantly, never in real time.
-- Up to four simulated players (SimP) can join the party. Each is a full character (race, class, background, pace) that
-- runs the same line-picking and group code as the real one, so party pacing, calls and replies play out for real.

local ADDON, ns = ...
local W = ns.W
local Sim = {}
ns.Sim = Sim

local SCENARIOS = {
  {1, "One pull (30 seconds)", pulls = 1, dur = 30},
  {2, "Boss fight (3 minutes)", pulls = 1, dur = 180, boss = true},
  {3, "Five pulls in a row", pulls = 5, dur = 30},
}
local SPEEDS = {{1, "2x", 2}, {2, "4x", 4}, {3, "6x", 6}, {4, "Instant", 0}}
local STEP = 0.25          -- pretend seconds per step
local REAL_TICK = 0.25     -- real seconds between ticks
-- What the sim can fight. Each kind sets the facts the addon reads about a target: creature type, boss or elite,
-- an enemy player and their race, and how often it casts (so interrupt lines get tested). The fight itself plays the
-- same for all of them.
local ENEMIES = {
  {"humanoid", "Humanoid", ctype = "humanoid", foes = {"Razormane Scout", "Venture Co. Laborer", "Bristleback Hunter", "Kolkar Raider",
    "Burning Blade Cultist", "Gnoll Brute", "Defias Pillager"}},
  {"beast", "Beast", ctype = "beast", foes = {"Mottled Boar", "Dire Mottled Boar", "Plainstrider", "Savannah Prowler", "Venomtail Scorpid",
    "Dustwind Harpy", "Elder Mangy Wolf"}},
  {"undead", "Undead", ctype = "undead", foes = {"Rotting Dead", "Skeletal Warrior", "Scarlet Zombie", "Shambling Ghoul", "Restless Shade"}},
  {"demon", "Demon", ctype = "demon", foes = {"Felguard Sentry", "Fel Hound", "Voidwalker", "Burning Imp", "Doomguard Lackey"}},
  {"elemental", "Elemental", ctype = "elemental", foes = {"Living Flame", "Dust Devil", "Stonelash Elemental", "Water Spirit"}},
  {"mechanical", "Mechanical", ctype = "mechanical", foes = {"Harvest Golem", "Rogue Clockwork", "Scrapyard Automaton"}},
  {"dragonkin", "Dragonkin", ctype = "dragonkin", foes = {"Black Whelp", "Scalebane Drakeling", "Red Dragonspawn"}},
  {"giant", "Giant", ctype = "giant", foes = {"Hill Giant", "Mosshide Ogre", "Brutish Ogre Warrior"}},
  {"aberration", "Aberration", ctype = "aberration", foes = {"Gelatinous Ooze", "Toxic Slime", "Mire Crawler"}},
  {"alliance", "Alliance player", ctype = "humanoid", player = true, faction = "Alliance",
    foes = {"Aldric", "Thorgrim", "Lirien", "Fizzwick", "Brannoc", "Selwyn", "Tamsin"},
    races = {{"Human", "Human"}, {"Dwarf", "Dwarf"}, {"NightElf", "Night Elf"}, {"Gnome", "Gnome"}, {"Draenei", "Draenei"}, {"Skyborne", "Skyborne"}}},
  {"boss", "Boss or elite", ctype = "humanoid", boss = true, foes = {"Warlord Kragmar", "Captain Redjaw", "Gorefang the Elder", "The Pale Matron"}},
  {"caster", "Caster", ctype = "humanoid", cast = 0.3, foes = {"Defias Conjurer", "Dark Cultist", "Burning Blade Warlock", "Frostmane Shaman"}},
}
local ENEMY_BY = {}
for _, e in ipairs(ENEMIES) do ENEMY_BY[e[1]] = e end
-- pick the enemy for one pull: a named kind, or a random mix
local function pickEnemy(key)
  local e = ENEMY_BY[key or ""] or ENEMIES[math.random(#ENEMIES)]
  local info = {kind = e[1], kindName = e[2], ctype = e.ctype, player = e.player or false, faction = e.faction, boss = e.boss or false, cast = e.cast or 0.08}
  info.name = e.foes[math.random(#e.foes)]
  if e.races then
    local r = e.races[math.random(#e.races)]
    info.race, info.raceName = r[1], r[2]
  end
  return info
end
local REST = 6          -- pretend seconds between pulls

------------------------------------------------------------------------
-- Who can be what. The Horde race and class combinations in WoW: Forever (Horde Skyborne are Windshapers).
------------------------------------------------------------------------
Sim.RACES = {"Orc", "Tauren", "Troll", "Forsaken", "Skyborne"}
Sim.RACE_CLASSES = {
  Orc = {"HUNTER", "MAGE", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"},
  Tauren = {"DRUID", "HUNTER", "SHAMAN", "WARRIOR"},
  Troll = {"HUNTER", "MAGE", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"},
  Forsaken = {"MAGE", "PALADIN", "PRIEST", "ROGUE", "WARLOCK", "WARRIOR"},
  Skyborne = {"DRUID", "HUNTER", "ROGUE", "SHAMAN", "WARRIOR"},
}
local ALL_CLASSES = {"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}
local RACE_FILE = {Orc = "Orc", Tauren = "Tauren", Troll = "Troll", Forsaken = "Scourge", Skyborne = "Skyborne"}
local HOME_KEY = {Forsaken = "Scourge"}
local NAMES = {
  Orc = {"Grukk", "Mazra", "Thokka", "Durgash", "Zogra", "Ushak", "Brakka", "Korvash"},
  Tauren = {"Kahnar", "Tahli", "Ruukah", "Moonhorn", "Bahru", "Yarra", "Hakulo", "Nahlia"},
  Troll = {"Zan'tho", "Jin'rok", "Tala'ji", "Ras'kala", "Vola'jin", "Mojaro", "Zeela", "Kuntai"},
  Forsaken = {"Corvin", "Maren", "Hollis", "Isolde", "Wystan", "Ysabeau", "Dunmore", "Thessaly"},
  Skyborne = {"Thalindra", "Vaelis", "Sylnaar", "Aeluin", "Zephren", "Iravel", "Quillith", "Orindel"},
}
local PRONOUNS = {{"he", "He / him"}, {"she", "She / her"}, {"they", "They / them"}}

local function cap(s) return s and (s:sub(1, 1):upper() .. s:sub(2):lower()) or "" end
local function has(list, v) for _, x in ipairs(list or {}) do if x == v then return true end end return false end
local function pick(list) return list[math.random(#list)] end

function Sim.classesFor(race)
  if race and Sim.RACE_CLASSES[race] then return Sim.RACE_CLASSES[race] end
  return ALL_CLASSES
end
function Sim.racesFor(class)
  local out = {}
  for _, r in ipairs(Sim.RACES) do if has(Sim.RACE_CLASSES[r], class) then out[#out + 1] = r end end
  return out
end
function Sim.homelandsFor(race)
  if not race or not CROX2_HOMELANDS then return {} end
  return CROX2_HOMELANDS[HOME_KEY[race] or race] or {}
end

-- turn a simulated player's choices (any of them may be "random") into a complete character that obeys the game's race
-- and class combinations. taken = names already in use.
function Sim.resolve(def, taken)
  local d = {}
  for k, v in pairs(def or {}) do d[k] = v end
  local race = (d.race and d.race ~= "random") and d.race or nil
  local class = (d.class and d.class ~= "random") and d.class or nil
  if race and not Sim.RACE_CLASSES[race] then race = nil end
  if race and class and not has(Sim.RACE_CLASSES[race], class) then class = nil end
  if not race and class then
    local rs = Sim.racesFor(class)
    if #rs > 0 then race = pick(rs) else class = nil end
  end
  race = race or pick(Sim.RACES)
  class = class or pick(Sim.RACE_CLASSES[race])
  d.race, d.class = race, class
  local specs = (ns.SPEC_ORDER or {})[class] or {}
  if d.spec == nil or d.spec == "random" or not has(specs, d.spec) then d.spec = pick(specs) end
  if d.depth == nil or d.depth == "random" then d.depth = math.random(1, 3) end
  if d.pronouns == nil or d.pronouns == "random" then d.pronouns = pick(PRONOUNS)[1] end
  if d.temperament == nil or d.temperament == "random" then d.temperament = pick(ns.TEMPERAMENTS) end
  if d.upbringing == nil or d.upbringing == "random" then d.upbringing = pick(ns.UPBRINGINGS) end
  if d.drive == nil or d.drive == "random" then d.drive = pick(ns.DRIVES) end
  local homes = Sim.homelandsFor(race)
  local okHome = false
  for _, h in ipairs(homes) do if h[1] == d.homeland then okHome = true end end
  if not okHome then d.homeland = homes[1] and pick(homes)[1] or nil end
  if d.pace == nil or d.pace == "random" then d.pace = math.random(2, 6) end
  local name = (d.name or ""):match("^%s*(.-)%s*$")
  taken = taken or {}
  if name == "" then
    local pool = {}
    for _, n in ipairs(NAMES[race]) do if not taken[n] then pool[#pool + 1] = n end end
    name = #pool > 0 and pick(pool) or (pick(NAMES[race]) .. math.random(2, 9))
  elseif taken[name] then name = name .. math.random(2, 9) end
  d.name = name
  return d
end

local function fakes() ns.cdb.simFakes = ns.cdb.simFakes or {} return ns.cdb.simFakes end
local FIELDS = {"race", "class", "spec", "depth", "pronouns", "temperament", "upbringing", "drive", "homeland", "pace"}
local function blankDef() local d = {name = ""} for _, k in ipairs(FIELDS) do d[k] = "random" end return d end
-- how many simulated players are in the party: set by the SimP boxes (saves from before the boxes counted: the slots filled in a row)
local function partyN()
  local n = ns.cdb.simFakeN
  if n == nil then n = 0 while n < 4 and fakes()[n + 1] do n = n + 1 end end
  return math.max(0, math.min(4, n))
end
function Sim.fakeCount() return partyN() end
-- set the party to n simulated players; the ones already built are kept (also when the party shrinks and grows again)
function Sim.setCount(n)
  n = math.max(0, math.min(4, math.floor(n or 0)))
  ns.cdb.simFakeN = n
  for i = 1, n do if not fakes()[i] then fakes()[i] = blankDef() end end
end

------------------------------------------------------------------------
-- The pretend party
------------------------------------------------------------------------
local frame, msgs, run, snapshot, simSnap, ticker
local actors, userActor, byName
local details = false

local function clock(vt) vt = math.floor(vt or 0) return ("%d:%02d"):format(math.floor(vt / 60), vt % 60) end
local function say(text, r, g, b)
  if msgs then msgs:AddMessage(text, r or 1, g or 1, b or 1) end
end
local function stamp() return run and ("|cff888888[" .. clock(run.vt) .. "]|r ") or "" end

-- lines as the default chat window writes them (ns.profile is whoever is speaking right now)
local function chatLine(channel, text)
  local name = ns.profile and ns.profile.name or "You"
  if channel == "YELL" then say(("%s%s yells: %s"):format(stamp(), name, text), 1, 0.25, 0.25)
  elseif channel == "EMOTE" then say(("%s%s %s"):format(stamp(), name, text), 1, 0.5, 0.25)
  else say(("%s%s says: %s"):format(stamp(), name, text), 1, 1, 1) end
end

local function byArch(class)
  local cls = CROX2_ABILITIES and CROX2_ABILITIES[class or ""] or {}
  local by = {}
  for name, a in pairs(cls) do
    if not a.quiet and a.arch then by[a.arch] = by[a.arch] or {}; table.insert(by[a.arch], name) end
  end
  for _, l in pairs(by) do table.sort(l) end
  return by
end

local function foeTarget(r)
  local f = r.foeInfo or {}
  return {exists = true, name = r.foe, enemy = true, friend = false, self = false, player = f.player or false, ctype = f.ctype or "humanoid",
    race = f.race, faction = f.faction, hp = r.foeHp, dead = r.foeHp <= 0, casting = r.casting, guid = "sim-" .. r.pull,
    boss = (r.scen and r.scen.boss) or f.boss or false}
end
local function selfTarget(a)
  return {exists = true, name = a.name, enemy = false, friend = false, self = true, player = true,
    hp = a.hp, dead = false, casting = false, guid = "sim-self-" .. a.name}
end
local function allyTarget(b)
  return {exists = true, name = b.name, enemy = false, friend = true, self = false, player = true,
    hp = b.hp, dead = false, casting = false, guid = "sim-ally-" .. b.name}
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

local function anyOf(a, archs)
  local names = {}
  for _, arch in ipairs(archs) do for _, n in ipairs(a.by[arch] or {}) do names[#names + 1] = n end end
  if #names == 0 then return nil end
  return pick(names)
end

-- what this character presses next: a reply someone is waiting for, a heal on a hurt ally, or the usual fight
local function choose(a, t)
  local G = ns.G
  local pr = G and G.simPending and G.simPending()
  if pr and t - pr.t <= 6 then
    local caller = byName[pr.caller]
    if caller and caller ~= a then
      if pr.kind == "lowhealth" then
        local n = anyOf(a, {"heal", "clutch", "ward"})
        if n then return {name = n, tgt = allyTarget(caller), heal = caller} end
      elseif pr.kind == "debuffhelp" then
        local n = anyOf(a, {"cleanse"})
        if n then return {name = n, tgt = allyTarget(caller)} end
      elseif pr.kind == "getoff" then
        local n = anyOf(a, {"taunt"})
        if n then return {name = n, tgt = foeTarget(run)} end
      end
    end
  end
  -- a healer looks after whoever is hurt
  if a.canHeal and actors and #actors > 1 then
    local low
    for _, b in ipairs(actors) do
      if b ~= a and b.hp < 55 and (not low or b.hp < low.hp) then low = b end
    end
    if low and math.random() < 0.6 then
      local n = anyOf(a, low.hp < 35 and {"clutch", "heal", "ward"} or {"heal", "ward", "groupheal"})
      if n then return {name = n, tgt = allyTarget(low), heal = low} end
    end
  end
  local c = Sim.pickAbility({by = a.by, foeHp = run.foeHp, hp = a.hp, casting = run.casting})
  if not c then return nil end
  return {name = c.name, tgt = c.selfCast and selfTarget(a) or foeTarget(run), selfHeal = c.selfCast and a}
end

local function setStatus(text) if frame and frame.status then frame.status:SetText(text) end end

local function flush()
  local G = ns.G
  if G and G.simFlush and ns.simParty then
    G.simFlush(function(from, msg)
      for _, b in ipairs(actors) do
        if b ~= from then
          ns.simBecome(b)
          local ok, err = pcall(G.simReceive, from.name, msg)
          if not ok and ns.Bug then ns.Bug.capture(err) end
        end
      end
    end)
  end
  ns.simBecome(userActor)
end

local function refreshRoster(t)
  local G = ns.G
  for _, a in ipairs(actors) do
    for _, b in ipairs(actors) do
      if b ~= a then
        local m = a.g.members[b.name]
        if not m then m = {} a.g.members[b.name] = m end
        m.class, m.ver, m.proto = b.profile.class, ns.VERSION, G.PROTO
        m.level = m.level or b.cdb.raidChatty
        m.flags, m.flagsT, m.seen = b.flags, t, t
      end
    end
  end
end

local function makeActor(name, profile, cdbT, user)
  local topSpec, band = nil, 0
  for tree, b in pairs(profile.spec or {}) do if b > band then topSpec, band = tree, b end end
  local flags = ns.G.simFlags(profile.class, topSpec)
  return {name = name, user = user, profile = profile, cdb = cdbT, db = user and nil or {custom = {}},
    state = ns.simFreshState(), g = ns.G.simFresh(), by = byArch(profile.class), flags = flags,
    tank = flags:find("K", 1, true) ~= nil, canHeal = flags:find("H", 1, true) ~= nil,
    sim = {tgt = {exists = false}, hp = 100, hurt = false}, hp = 100}
end

local function fakeActor(def)
  local profile = {name = def.name, class = def.class, race = def.race, raceFile = RACE_FILE[def.race], faction = "Horde",
    spec = {[def.spec] = def.depth}, profs = {}}
  local c = ns.simNewCharDB({temperament = def.temperament, upbringing = def.upbringing, drive = def.drive,
    homeland = def.homeland, pronouns = def.pronouns, raidChatty = def.pace, chatty = math.min(5, def.pace), setupDone = true})
  return makeActor(def.name, profile, c, false)
end

local function startPull(t)
  run.pull = run.pull + 1
  run.foeInfo = pickEnemy(run.enemy)
  run.foe = run.foeInfo.name
  run.foeHp, run.casting, run.killed = 100, false, false
  run.start = t
  run.phase = "fight"
  for i, a in ipairs(actors) do
    ns.simBecome(a)
    a.hp = 100
    a.hurtAt = -100
    a.nextPress = t + 0.8 + (i - 1) * 0.35 + math.random() * 0.5
    a.nextHurt = t + (a.tank and 3 or 5) + math.random() * 6
    a.nextDebuff = t + 20 + math.random() * 40
    a.nextThreat = t + 12 + math.random() * 20
    a.threatUntil = 0
    a.sim.tgt, a.sim.hp, a.sim.hurt, a.sim.onMe = foeTarget(run), 100, false, false
    ns.simFight(true)
  end
  ns.simBecome(userActor)
  local fi = run.foeInfo
  local what = fi.player and ("Alliance " .. (fi.raceName or "") .. " player") or ((fi.boss and "boss or elite " or "") .. (fi.ctype or ""))
  if fi.kind == "caster" then what = "caster" end
  say(("%s-- Pull %d: %s (%s) --"):format(stamp(), run.pull, run.foe, what), 0.7, 0.7, 0.7)
end

local function endPull(t)
  for _, a in ipairs(actors) do
    ns.simBecome(a)
    a.sim.tgt, a.sim.onMe = {exists = false}, false
    ns.simFight(false)
  end
  ns.simBecome(userActor)
  if run.pull >= run.scen.pulls then Sim.stop(true) return end
  run.phase = "rest"
  run.nextAt = t + REST
end

local function pressFor(a, t)
  local c = choose(a, t)
  if not c then return end
  a.sim.tgt = c.tgt
  a.sim.hp = a.hp
  a.sim.hurt = (t - (a.hurtAt or -100)) < 3
  if details then say(("%s   %s > %s"):format(stamp(), a.name, c.name), 0.45, 0.6, 0.9) end
  local ok, err = pcall(ns.simPress, c.name)
  if not ok and ns.Bug then ns.Bug.capture(err) end
  if c.heal then c.heal.hp = math.min(100, c.heal.hp + 30) end
  if c.selfHeal then a.hp = math.min(100, a.hp + 18) end
end

local function stepActor(a, t, elapsed)
  ns.simBecome(a)
  local s = a.sim
  if not run.killed and t >= a.nextHurt then
    a.hp = math.max(8, a.hp - ((a.tank and 12 or 15) + math.random() * 25))
    a.hurtAt = t
    ns.simHurt()
    a.nextHurt = t + (a.tank and 4 or 6) + math.random() * (a.tank and 5 or 8)
  elseif a.hp < 100 then
    a.hp = math.min(100, a.hp + 0.4)
  end
  s.hp = a.hp
  s.hurt = (t - (a.hurtAt or -100)) < 3
  -- an enemy on someone who is not the tank (only when the party has a tank)
  if not run.killed and run.hasTank and not a.tank and t >= a.nextThreat then
    a.threatUntil = t + 8
    a.nextThreat = t + 30 + math.random() * 30
  end
  s.onMe = (a.threatUntil or 0) > t
  local force
  if not run.killed and t >= a.nextDebuff then
    ns.simDebuff(pick({"Poison", "Disease", "Curse", "Magic"}))
    a.nextDebuff = t + 40 + math.random() * 60
    force = true
  end
  if force or t >= a.nextPress then
    pressFor(a, t)
    a.nextPress = t + 1.4 + math.random() * 0.5
  end
  flush()
end

-- advance the pretend fight by one step (a quarter of a pretend second)
function Sim.step()
  if not run then return end
  run.vt = run.vt + STEP
  ns.simClock = run.clock0 + run.vt
  ns.simWallAdd = run.vt
  local t = ns.simClock
  if t >= run.nextRoster then refreshRoster(t) run.nextRoster = t + 4 end
  if run.phase == "rest" then
    setStatus(("Resting · next pull in %ds · %s"):format(math.max(0, math.ceil(run.nextAt - t)), SPEEDS[run.speed][2]))
    if t >= run.nextAt then startPull(t) end
    return
  end
  local elapsed = t - run.start
  run.foeHp = run.killed and 0 or math.max(0, 100 - 100 * elapsed / run.scen.dur + (math.random() - 0.5) * 3)
  run.casting = math.random() < ((run.foeInfo and run.foeInfo.cast) or 0.08)
  run.rot = (run.rot + 1) % #actors
  for k = 0, #actors - 1 do
    stepActor(actors[(run.rot + k) % #actors + 1], t, elapsed)
    if not run then return end
  end
  ns.simBecome(userActor)
  if not run.killed and elapsed >= run.scen.dur then
    run.killed, run.killAt, run.foeHp = true, t, 0
    for _, a in ipairs(actors) do
      ns.simBecome(a)
      ns.simKill(run.foe)
      a.nextPress = math.min(a.nextPress, t + 0.5 + math.random() * 1.5)
    end
    ns.simBecome(userActor)
  end
  if run.killed and t >= run.killAt + 3.5 then endPull(t) return end
  if run then
    setStatus(("Pull %d of %d · %s · %s · budget %.1f"):format(run.pull, run.scen.pulls, clock(elapsed), SPEEDS[run.speed][2],
      ns.getBudget and ns.getBudget() or 0))
  end
end

-- the real-time heartbeat: runs as many pretend steps as the speed allows. Instant runs the whole thing at once.
function Sim.tick()
  if not run then return end
  local sp = SPEEDS[run.speed] or SPEEDS[1]
  if sp[3] == 0 then
    local n = 0
    while run and n < 40000 do Sim.step() n = n + 1 end
  else
    for _ = 1, math.max(1, math.floor(sp[3] * REAL_TICK / STEP + 0.5)) do if run then Sim.step() end end
  end
end

function Sim.running() return run ~= nil end
function Sim.setSpeed(i) if SPEEDS[i] then if frame then frame.speed = i end if run then run.speed = i end end end

function Sim.start(scenario, speed, enemy)
  if run then return end
  if not ns.cdb or not ns.cdb.on then say("cro/x is switched off for this character. Turn it on first (/x on).", 1, 0.5, 0.5) return end
  if ns.isAlliance and ns.isAlliance() then return end
  if InCombatLockdown and InCombatLockdown() then say("You are in a real fight. Try again when it's over.", 1, 0.5, 0.5) return end
  local scen = SCENARIOS[scenario or (frame and frame.scenario) or 1] or SCENARIOS[1]
  speed = speed or (frame and frame.speed) or 1
  snapshot = ns.simSnapshot()
  local G = ns.G
  -- the pretend clock starts where the real one is, and only ever moves when the sim steps
  local clock0 = GetTime()
  ns.simClock, ns.simWallAdd = clock0, 0
  userActor = makeActor(ns.profile.name or "You", {}, ns.cdb, true)
  simSnap = ns.simBegin(userActor)
  userActor.by = byArch(userActor.profile.class)
  local topSpec, band = nil, 0
  for tree, b in pairs(userActor.profile.spec or {}) do if b > band then topSpec, band = tree, b end end
  userActor.flags = G.simFlags(userActor.profile.class, topSpec)
  userActor.tank = userActor.flags:find("K", 1, true) ~= nil
  userActor.canHeal = userActor.flags:find("H", 1, true) ~= nil
  actors, byName = {userActor}, {[userActor.name] = userActor}
  local taken = {[userActor.name] = true}
  local names = {}
  for i = 1, partyN() do
    local d = Sim.resolve(fakes()[i] or blankDef(), taken)
    taken[d.name] = true
    local a = fakeActor(d)
    actors[#actors + 1] = a
    byName[a.name] = a
    names[#names + 1] = ("%s (%s %s)"):format(a.name, d.race, cap(d.class))
  end
  ns.simParty = #actors > 1 and actors or nil
  G.simResetParty()
  local hasTank = false
  for _, a in ipairs(actors) do if a.tank then hasTank = true end end
  run = {scen = scen, pull = 0, phase = "rest", nextAt = clock0, foeHp = 100, casting = false, vt = 0, clock0 = clock0,
    speed = speed, rot = 0, nextRoster = clock0, hasTank = hasTank, enemy = enemy or (frame and frame.enemy) or "mix"}
  ns.simOut = chatLine
  ns.simQuiet = function(ctx, moment, why)
    if details then
      say(("%s   (%s quiet: %s - %s)"):format(stamp(), ns.simActor and ns.simActor.name or "?", ctx and ctx.ability or moment or "?", why or "?"), 0.55, 0.55, 0.55)
    end
  end
  refreshRoster(clock0)
  ns.simBecome(userActor)
  say(("-- Simulating: %s as %s, %s, %s --"):format(scen[2], userActor.name, SPEEDS[speed][2] == "Instant" and "instantly" or ("at " .. SPEEDS[speed][2]),
    #names > 0 and ("in a party with " .. table.concat(names, ", ")) or "alone"), 0.7, 0.7, 0.7)
  if C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(REAL_TICK, function() Sim.tick() end) end
  if frame and frame.go then frame.go:SetText("Stop") end
  Sim.step()
  if SPEEDS[speed][3] == 0 then Sim.tick() end      -- instant: play it all now
end

function Sim.stop(finished)
  if not run then return end
  if ticker and ticker.Cancel then ticker:Cancel() end
  ticker = nil
  for _, a in ipairs(actors) do
    ns.simBecome(a)
    if ns.inCombat then ns.simFight(false) end
  end
  run = nil
  ns.simOut, ns.simQuiet = nil, nil
  ns.simEnd(simSnap, userActor)
  if ns.G then ns.G.simResetParty() end
  ns.simRestore(snapshot)
  snapshot, simSnap, actors, userActor, byName = nil, nil, nil, nil, nil
  say(finished and "-- Done. Your test data is in /x testdata if testing mode was on. --" or "-- Stopped. --", 0.7, 0.7, 0.7)
  setStatus("Idle")
  if frame and frame.go then frame.go:SetText("Start") end
end

------------------------------------------------------------------------
-- The window: chat area, controls, the SimP boxes and the simulated players' window
------------------------------------------------------------------------
local function fakeLabel(d)
  local function v(x) return (x == nil or x == "random") and "random" or x end
  local nm = (d.name and d.name ~= "") and d.name or "Random name"
  return ("%s - %s %s"):format(nm, cap(v(d.race)), cap(v(d.class)))
end

local function refreshBoxes()
  if not frame then return end
  local n = partyN()
  for i, b in ipairs(frame.boxes) do
    b:SetText(i <= n and ("|cffffd100" .. i .. " SimP|r") or (i .. " SimP"))
  end
  if frame.none then frame.none:SetText(n == 0 and "|cffffd100None|r" or "None") end
end

-- The simulated players' own window, a separate pop-out beside the simulator: one tab per simulated player in the party, each tab
-- holding that character's choices. Changes are kept as you make them. "Random" is kept as Random and rolled fresh
-- each run, always inside the game's race and class combinations.
local function buildFakeWindow()
  local win = W.panel("CROX2SimFakesFrame", "cro/x - simulated players", 500, 342)
  win:ClearAllPoints()
  win:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
  local d = {}
  win.def = d
  local loading = false

  local dds = {}
  local function refreshAll() for _, dd in ipairs(dds) do dd.refresh() end end
  local function save()
    if loading or not win.slot then return end
    local c = {}
    for k, v in pairs(d) do c[k] = v end
    c.name = d.name or ""
    fakes()[win.slot] = c
    if frame and frame.boxes then refreshBoxes() end
  end
  win.save = save

  -- tabs: SimP 1 .. SimP 4, only as many as the party has
  win.tabs = {}
  for i = 1, 4 do
    local b = W.button(win, "SimP " .. i, 84, function() win:showSlot(i) end)
    if i == 1 then b:SetPoint("TOPLEFT", 12, -34) else b:SetPoint("LEFT", win.tabs[i - 1], "RIGHT", 4, 0) end
    win.tabs[i] = b
  end
  win.title2 = W.heading(win, "")
  win.title2:SetPoint("TOPLEFT", 14, -64)
  local sub = W.hint(win, "Leave anything on Random and it is rolled fresh every run; the Randomize buttons fill the choices in so you can see them. Only combinations the game allows are offered.")
  sub:SetPoint("TOPLEFT", 14, -82)
  sub:SetWidth(470)

  local function label(text, x, y)
    local l = W.text(win, text, "GameFontNormalSmall")
    l:SetPoint("TOPLEFT", x, y - 6)
    l:SetWidth(78)
    return l
  end
  local function dropdown(key, text, x, y, items, onSet)
    label(text, x, y)
    local dd = W.dropdown(win, 112, items, function() return d[key] end, function(v)
      d[key] = v
      if onSet then onSet(v) end
      refreshAll()
      save()
    end)
    dd:SetPoint("TOPLEFT", x + 80, y + 2)
    dds[#dds + 1] = dd
    return dd
  end
  local RANDOM = {"random", "Random"}
  local function listWith(list)
    local out = {RANDOM}
    for _, it in ipairs(list) do out[#out + 1] = it end
    return out
  end
  local function keys(list, label2)
    local out = {}
    for _, k in ipairs(list) do out[#out + 1] = {k, label2 and label2(k) or cap(k)} end
    return listWith(out)
  end

  label("Name", 14, -106)
  local nameBox = W.edit(win, 130, 20)
  nameBox:SetPoint("TOPLEFT", 96, -106)
  nameBox:SetScript("OnTextChanged", function(self) d.name = self:GetText() save() end)
  local nh = W.hint(win, "(blank = a random name)")
  nh:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
  win.nameBox = nameBox

  local y0 = -136
  local H = 34
  dropdown("race", "Race", 14, y0, function() return keys(Sim.RACES) end, function(v)
    if v ~= "random" and d.class ~= "random" and not has(Sim.RACE_CLASSES[v], d.class) then d.class = "random" d.spec = "random" end
    local ok = false
    for _, h in ipairs(Sim.homelandsFor(v ~= "random" and v or nil)) do if h[1] == d.homeland then ok = true end end
    if not ok then d.homeland = "random" end
  end)
  dropdown("class", "Class", 14, y0 - H, function()
    local list = {}
    for _, c in ipairs(Sim.classesFor(d.race ~= "random" and d.race or nil)) do list[#list + 1] = c end
    return keys(list)
  end, function(v)
    if v == "random" or not has((ns.SPEC_ORDER or {})[v], d.spec) then d.spec = "random" end
  end)
  dropdown("spec", "Talent spec", 14, y0 - H * 2, function()
    if d.class == "random" then return {RANDOM} end
    return keys((ns.SPEC_ORDER or {})[d.class] or {}, function(k) return k end)
  end)
  dropdown("depth", "Talents spent", 14, y0 - H * 3, function()
    return {RANDOM, {1, "Early"}, {2, "Middle"}, {3, "Deep"}}
  end)
  dropdown("pronouns", "Pronouns", 14, y0 - H * 4, function() return listWith(PRONOUNS) end)

  dropdown("temperament", "Temperament", 250, y0, function() return keys(ns.TEMPERAMENTS) end)
  dropdown("upbringing", "Origin", 250, y0 - H, function() return keys(ns.UPBRINGINGS) end)
  dropdown("drive", "Motivation", 250, y0 - H * 2, function() return keys(ns.DRIVES) end)
  dropdown("homeland", "Homeland", 250, y0 - H * 3, function()
    return listWith(Sim.homelandsFor(d.race ~= "random" and d.race or nil))
  end)
  dropdown("pace", "Pace in a group", 250, y0 - H * 4, function()
    local out = {RANDOM}
    for i = 1, 7 do out[#out + 1] = {i, ns.CHATTY[i].name} end
    return out
  end)

  function win:refreshTabs()
    local n = partyN()
    for i, b in ipairs(self.tabs) do
      b:SetShown(i <= n)
      b:SetText(i == self.slot and ("|cffffd100SimP " .. i .. "|r") or ("SimP " .. i))
      if i == self.slot then b:LockHighlight() else b:UnlockHighlight() end
    end
  end
  -- show one simulated player's tab (what was on the last tab was already kept as it was changed)
  function win:showSlot(slot)
    slot = math.max(1, math.min(slot or 1, math.max(1, partyN())))
    self.slot = slot
    loading = true
    local cur = fakes()[slot] or blankDef()
    for k in pairs(d) do d[k] = nil end
    for _, k in ipairs(FIELDS) do d[k] = "random" end
    for k, v in pairs(cur) do d[k] = v end
    d.name = cur.name or ""
    nameBox:SetText(d.name)
    self.title2:SetText(("Simulated player %d  (%d in the party)"):format(slot, partyN()))
    refreshAll()
    self:refreshTabs()
    loading = false
  end
  -- the Randomize buttons roll real choices and put them in the dropdowns, so you can see who will be added
  local function taken(except)
    local t = {[ns.profile and ns.profile.name or ""] = true}
    for i = 1, partyN() do
      if i ~= except and fakes()[i] and (fakes()[i].name or "") ~= "" then t[fakes()[i].name] = true end
    end
    return t
  end
  local function roll(slot)
    local r = Sim.resolve(blankDef(), taken(slot))
    local c = {}
    for _, k in ipairs(FIELDS) do c[k] = r[k] end
    c.name = r.name
    return c
  end
  local rnd = W.button(win, "Randomize this one", 140, function()
    local c = roll(win.slot)
    for k, v in pairs(c) do d[k] = v end
    nameBox:SetText(c.name)
    refreshAll()
    save()
  end)
  rnd:SetPoint("BOTTOMLEFT", 14, 14)
  local rndAll = W.button(win, "Randomize all", 110, function()
    for i = 1, partyN() do fakes()[i] = roll(i) end
    win:showSlot(win.slot)
    refreshBoxes()
  end)
  rndAll:SetPoint("LEFT", rnd, "RIGHT", 6, 0)
  local close = W.button(win, "Close", 80, function() win:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -14, 14)
  win:Hide()
  return win
end

-- open the simulated players' window on one tab (not while a simulation runs)
function Sim.showFakes(slot)
  if run then say("Stop the simulation before changing the party.", 1, 0.5, 0.5) return end
  if not frame then Sim.open() end
  if partyN() == 0 then if frame.popup then frame.popup:Hide() end return end
  if not frame.popup then frame.popup = buildFakeWindow() end
  frame.popup:showSlot(slot or frame.popup.slot or 1)
  frame.popup:Show()
end
-- the SimP boxes: n simulated players in the party, and their window opens
function Sim.pickCount(n)
  if run then say("Stop the simulation before changing the party.", 1, 0.5, 0.5) return end
  if not frame then Sim.open() end
  Sim.setCount(n)
  refreshBoxes()
  Sim.showFakes()
end
function Sim.editFake(slot)
  if run then say("Stop the simulation before changing the party.", 1, 0.5, 0.5) return end
  if not frame then Sim.open() end
  slot = slot or 1
  if slot > partyN() then Sim.setCount(slot) refreshBoxes() end
  Sim.showFakes(slot)
end

function Sim.open()
  if ns.isAlliance and ns.isAlliance() then return end
  if not frame then
    local f = W.panel("CROX2SimFrame", "cro/x - combat simulator", 640, 440)
    frame = f
    f.scenario, f.speed, f.enemy = 1, 1, "mix"
    -- the chat-style area
    local chat = CreateFrame("Frame", nil, f)
    chat:SetPoint("TOPLEFT", 12, -52)
    chat:SetPoint("BOTTOMRIGHT", -12, 138)
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
    msgs:SetMaxLines(500)
    msgs:SetFading(false)
    msgs:EnableMouseWheel(true)
    msgs:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
    f.msgs = msgs

    -- simulated players: how many are in the party; their own window opens with one tab each
    local fl = W.text(f, "Simulated Players:", "GameFontNormal")
    fl:SetPoint("BOTTOMLEFT", 14, 108)
    f.boxes = {}
    for i = 1, 4 do
      local b = W.button(f, i .. " SimP", 70, function() Sim.pickCount(i) end)
      if i == 1 then b:SetPoint("LEFT", fl, "RIGHT", 10, 0) else b:SetPoint("LEFT", f.boxes[i - 1], "RIGHT", 4, 0) end
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(i .. (i == 1 and " simulated player" or " simulated players") .. " in the party", 1, 0.82, 0)
        for j = 1, i do
          local d = fakes()[j]
          GameTooltip:AddLine(j .. ": " .. (d and fakeLabel(d) or "Random"), 1, 1, 1)
        end
        GameTooltip:AddLine("Click to set the party size and open their window. The sim plays each as a full cro/x character.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      f.boxes[i] = b
    end
    local none = W.button(f, "None", 56, function()
      if run then say("Stop the simulation before changing the party.", 1, 0.5, 0.5) return end
      Sim.setCount(0)
      refreshBoxes()
      if f.popup then f.popup:Hide() end
    end)
    none:SetPoint("LEFT", f.boxes[4], "RIGHT", 4, 0)
    f.none = none
    local edit = W.button(f, "Edit...", 60, function() Sim.showFakes() end)
    edit:SetPoint("LEFT", none, "RIGHT", 4, 0)
    f.edit = edit

    -- scenario, speed, start
    local dd = W.dropdown(f, 170, function()
      local t = {}
      for i, s in ipairs(SCENARIOS) do t[i] = {s[1], s[2]} end
      return t
    end, function() return f.scenario end, function(v) f.scenario = v end)
    dd:SetPoint("BOTTOMLEFT", 2, 50)
    f.dd = dd
    local ed = W.dropdown(f, 130, function()
      local t = {{"mix", "Random mix"}}
      for _, e in ipairs(ENEMIES) do t[#t + 1] = {e[1], e[2]} end
      return t
    end, function() return f.enemy end, function(v) f.enemy = v end)
    ed:SetPoint("LEFT", dd, "RIGHT", -14, 0)
    f.ed = ed
    local el = W.hint(f, "Enemy")
    el:SetPoint("BOTTOM", ed, "TOP", 0, -2)
    local sp = W.dropdown(f, 66, function()
      local t = {}
      for i, s in ipairs(SPEEDS) do t[i] = {s[1], s[2]} end
      return t
    end, function() return f.speed end, function(v) Sim.setSpeed(v) end)
    sp:SetPoint("LEFT", ed, "RIGHT", -14, 0)
    f.sp = sp
    local sl = W.hint(f, "Speed")
    sl:SetPoint("BOTTOM", sp, "TOP", 0, -2)
    local go = W.button(f, "Start", 76, function() if run then Sim.stop() else Sim.start(f.scenario, f.speed, f.enemy) end end)
    go:SetPoint("LEFT", sp, "RIGHT", -6, 2)
    f.go = go
    local clear = W.button(f, "Clear", 64, function() msgs:Clear() end)
    clear:SetPoint("LEFT", go, "RIGHT", 6, 0)
    local det = W.check(f, "Show presses and why it stayed quiet", function(_, on) details = on and true or false end)
    det:SetPoint("BOTTOMLEFT", 12, 14)
    f.det = det
    f.status = W.hint(f, "Idle")
    f.status:SetPoint("BOTTOMRIGHT", -14, 20)
    f:HookScript("OnHide", function() Sim.stop() if f.popup then f.popup:Hide() end end)
  end
  frame:Show()
  frame.dd.refresh()
  frame.ed.refresh()
  frame.sp.refresh()
  refreshBoxes()
  if not frame.welcomed then
    frame.welcomed = true
    say("Pretend fights run through your character's real lines. Nothing here goes to chat.", 0.7, 0.7, 0.7)
    say("The sim keeps its own clock: pick 2x, 4x, 6x or Instant. Click a SimP box to set how many simulated players are in the party.", 0.7, 0.7, 0.7)
    say("Pick a fight and an enemy (or a random mix) and press Start. Turn on testing mode in Options to keep the data.", 0.7, 0.7, 0.7)
  end
end
