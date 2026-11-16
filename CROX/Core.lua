-- cro/x (Combat Roleplay Options /x) — core engine, second alpha.
-- One action-button press sends at most one message (WoW only lets /say and /yell out on a key press).
-- Rules this file follows (see the Design doc):
--   * The facts rule: a line is said only when every fact it needs is known to be true.
--   * Say it only when it's true: lines that name an action fire only on that action.
--   * Pace: about 2-4 lines a minute solo (Normal); party pacing lives in Group.lua.

local ADDON, ns = ...
ns = ns or {}
local VERSION = "0.60"
-- Display label. Public releases read "0.60-beta"; private working builds add a counter: "0.60-beta.1", ".2"...
local BUILD = "0.60-beta.8"
local BUILD_DATE = "2026-11-15"

local unpack = unpack or table.unpack
local db, cdb                 -- account / character saved settings

------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------
local function p(s) DEFAULT_CHAT_FRAME:AddMessage("|cffb22222cro/x:|r " .. s) end
local function secret(v) return issecretvalue and issecretvalue(v) or false end
-- ns.simClock is the combat simulator's pretend clock (seconds); it is nil in real play
local function now() return ns.simClock or GetTime() end
local function wall() return ((time and time()) or math.floor(GetTime())) + (ns.simWallAdd or 0) end
local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end
local function safe(fn, ...)
  if not fn then return nil end
  local r = {pcall(fn, ...)}
  if not r[1] then return nil end
  return select(2, unpack(r))
end
local function str(v) if type(v) == "string" and not secret(v) then return v end end
local function num(v) if type(v) == "number" and not secret(v) then return v end end
local function bool(v) if secret(v) then return nil end return v and true or false end

local function spellName(id)
  if not id or secret(id) then return nil end
  if type(id) == "string" then return id end
  return str(safe(C_Spell and C_Spell.GetSpellName, id)) or str(safe(GetSpellInfo, id))
end

ns.p, ns.secret, ns.safe, ns.str, ns.num, ns.now, ns.wall = p, secret, safe, str, num, now, wall
ns.VERSION, ns.BUILD, ns.BUILD_DATE = VERSION, BUILD, BUILD_DATE

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------
local TEMPERAMENTS = {"gruff", "cheerful", "grim", "cocky", "calm", "hot-headed"}
local UPBRINGINGS = {"soldier", "farmer", "noble", "outlaw", "scholar", "wanderer"}
local DRIVES = {"honor", "coin", "vengeance", "faith", "glory", "duty"}
ns.TEMPERAMENTS, ns.UPBRINGINGS, ns.DRIVES = TEMPERAMENTS, UPBRINGINGS, DRIVES

local CHAR_DEFAULTS = {
  profLines = true, testing = false, lineHide = {}, simFakes = {},
  on = true, chatty = 3, raidChatty = 3, chattyScale = 3, crAsk = 4, crGive = 4, sound = true, emotes = true, yell = true, cr = true, turns = true,
  filter = true, troll = "accent", logging = true, includeOwn = false,
  temperament = "gruff", homeland = nil, upbringing = "soldier", drive = "honor", pronouns = "they",
  setupDone = false, off = {}, said = {}, last = {}, custom = {}, recipes = {}, recipeNames = {},
  textScale = 1, window = nil, minimap = false, splash = true, alliance = {disabled = false},
}
local ACCOUNT_DEFAULTS = {custom = {}, minimap = {}}

local function fillDefaults(t, d)
  for k, v in pairs(d) do
    if t[k] == nil then
      if type(v) == "table" then local c = {} fillDefaults(c, v) t[k] = c else t[k] = v end
    end
  end
end

-- Put every setting and every choice back to the defaults (the player's own phrases and the recipe lists the
-- game gave us are kept), clear the lines they switched off and the said-history, and mark setup as not done.
function ns.resetAll()
  if not cdb then return end
  local keep = {custom = cdb.custom, recipes = cdb.recipes, recipeNames = cdb.recipeNames, alliance = cdb.alliance}
  for k in pairs(cdb) do cdb[k] = nil end
  fillDefaults(cdb, CHAR_DEFAULTS)
  for k, v in pairs(keep) do cdb[k] = v end
  for _, k in ipairs({"art", "bg", "page", "charBg"}) do db[k] = nil end
end

local function initDB()
  CROX2DB = CROX2DB or {}
  CROX2CharDB = CROX2CharDB or {}
  db, cdb = CROX2DB, CROX2CharDB
  -- How chatty grew from three levels to five (Hushed added at the bottom, Chatterbox at the top): move old numbers up
  if cdb.chatty ~= nil and (cdb.chattyScale or 1) < 2 then
    cdb.chatty = math.min(5, math.max(1, tonumber(cdb.chatty) or 2) + 1)
    if cdb.raidChatty ~= nil then cdb.raidChatty = math.min(5, math.max(1, tonumber(cdb.raidChatty) or 1) + 1) end
    cdb.chattyScale = 2
  end
  -- ...and from five to seven (Silent at the bottom, Loud and Roaring for groups): move the five up by rate
  if cdb.chatty ~= nil and (cdb.chattyScale or 1) < 3 then
    local map = {2, 3, 4, 5, 6}
    cdb.chatty = math.min(5, map[math.max(1, math.min(5, tonumber(cdb.chatty) or 3))])
    if cdb.raidChatty ~= nil then cdb.raidChatty = map[math.max(1, math.min(5, tonumber(cdb.raidChatty) or 2))] end
    cdb.chattyScale = 3
  end
  fillDefaults(db, ACCOUNT_DEFAULTS)
  fillDefaults(cdb, CHAR_DEFAULTS)
  ns.db, ns.cdb = db, cdb
end
ns.initDB = initDB

------------------------------------------------------------------------
-- Who the character is
------------------------------------------------------------------------
local RACE_KEY = {Scourge = "Forsaken", Undead = "Forsaken"}
local profile = {}
ns.profile = profile

local PROF_KEYS = {
  ["alchemy"] = "alchemy", ["blacksmithing"] = "blacksmithing", ["enchanting"] = "enchanting",
  ["engineering"] = "engineering", ["herbalism"] = "herbalism", ["leatherworking"] = "leatherworking",
  ["mining"] = "mining", ["skinning"] = "skinning", ["tailoring"] = "tailoring", ["cooking"] = "cooking",
  ["first aid"] = "first_aid", ["fishing"] = "fishing",
}
local SPEC_ORDER = {
  WARRIOR = {"Arms", "Fury", "Protection"}, PALADIN = {"Holy", "Protection", "Retribution"},
  HUNTER = {"Beast Mastery", "Marksmanship", "Survival"}, ROGUE = {"Assassination", "Combat", "Subtlety"},
  PRIEST = {"Discipline", "Holy", "Shadow"}, SHAMAN = {"Elemental", "Enhancement", "Restoration"},
  MAGE = {"Arcane", "Fire", "Frost"}, WARLOCK = {"Affliction", "Demonology", "Destruction"},
  DRUID = {"Balance", "Feral", "Restoration"},
}

ns.SPEC_ORDER = SPEC_ORDER

local function addProf(out, name)
  name = str(name)
  if name and PROF_KEYS[name:lower()] then out[PROF_KEYS[name:lower()]] = true end
end

-- Professions: the classic skill list where the client has it, otherwise the modern profession list (the one
-- Forever uses). The trade-skill-line list is NOT used: it names every profession in the game, not yours.
local function readProfessions()
  local out = {}
  for i = 1, (num(safe(GetNumSkillLines)) or 0) do
    local name, header = safe(GetSkillLineInfo, i)
    if not header then addProf(out, name) end
  end
  if GetProfessions then
    local list = {safe(GetProfessions)}
    for i = 1, 6 do
      local idx = num(list[i])
      if idx then addProf(out, (safe(GetProfessionInfo, idx))) end
    end
  end
  return out
end

local function currentSpecName()
  local fn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
  local idx = num(safe(fn))
  if not idx then return nil end
  local info = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
  local r = {safe(info, idx)}
  return str(r[2])
end

-- Talent trees in the newer system (Forever): the class has ONE tree and the specs sit side by side in it, so a
-- node's spec comes from where it sits across (posX split into thirds, in SPEC_ORDER order) and its row from
-- posY (rows are 600 apart, the first at 2130). Bands follow the classic rule: deepest row 1-2 early, 3-4 middle,
-- 5+ deep. Returns nil when this client doesn't offer it or nothing is spent.
local ROW_TOP, ROW_STEP = 2130, 600
local function readSpecTraits()
  local CT, TR = C_ClassTalents, C_Traits
  if not (CT and TR and TR.GetConfigInfo and TR.GetTreeNodes and TR.GetNodeInfo) then return nil end
  local cid = num(safe(CT.GetActiveConfigID))
  if not cid then return nil end
  local cfg = safe(TR.GetConfigInfo, cid)
  if type(cfg) ~= "table" or type(cfg.treeIDs) ~= "table" then return nil end
  local class = profile.class or ""
  local order, data = SPEC_ORDER[class] or {}, CROX2_SPEC and CROX2_SPEC[class]
  if not data or #order == 0 then return nil end
  local deepest, any = {}, false
  for _, tid in ipairs(cfg.treeIDs) do
    local infos, minX, maxX = {}, nil, nil
    for _, nid in ipairs(safe(TR.GetTreeNodes, tid) or {}) do
      local info = safe(TR.GetNodeInfo, cid, nid)
      if type(info) == "table" then
        infos[#infos + 1] = info
        local x = num(info.posX)
        if x then minX = math.min(minX or x, x) maxX = math.max(maxX or x, x) end
      end
    end
    if minX and maxX and maxX > minX then
      local width = (maxX - minX + 1) / #order
      for _, info in ipairs(infos) do
        if (num(info.currentRank) or 0) > 0 and num(info.posX) then
          local idx = math.min(#order, math.floor((info.posX - minX) / width) + 1)
          local row = math.max(1, math.floor(((num(info.posY) or ROW_TOP) - ROW_TOP) / ROW_STEP + 0.5) + 1)
          local name = order[idx]
          if data[name] then
            any = true
            deepest[name] = math.max(deepest[name] or 0, row)
          end
        end
      end
    end
  end
  if not any then return nil end
  local out = {}
  for name in pairs(data) do
    local d = deepest[name] or 0
    out[name] = d >= 5 and 3 or d >= 3 and 2 or d >= 1 and 1 or 0
  end
  return out
end

-- spec bands unlocked per tree: {["Arms"] = 2, ...} (1 early, 2 middle, 3 deep)
local function readSpec()
  local out = {}
  local order = SPEC_ORDER[profile.class or ""] or {}
  local tabs = num(safe(GetNumTalentTabs)) or 0
  for tab = 1, tabs do
    local r = {safe(GetTalentTabInfo, tab)}
    local tname = type(r[1]) == "number" and str(r[2]) or str(r[1])
    local data = CROX2_SPEC and CROX2_SPEC[profile.class or ""]
    if not (tname and data and data[tname]) then tname = order[tab] end
    local deepest = 0
    for i = 1, (num(safe(GetNumTalents, tab)) or 0) do
      local t = {safe(GetTalentInfo, tab, i)}
      local tier, rank = num(t[3]), num(t[5])
      if tier and rank and rank > 0 and tier > deepest then deepest = tier end
    end
    if tname then
      out[tname] = deepest >= 5 and 3 or deepest >= 3 and 2 or deepest >= 1 and 1 or 0
    end
  end
  if next(out) == nil then out = readSpecTraits() or out end
  -- nothing else worked: use the chosen specialization's name, counted as fully unlocked
  if next(out) == nil then
    local name = currentSpecName()
    local data = CROX2_SPEC and CROX2_SPEC[profile.class or ""]
    if name and data and data[name] then out[name] = 3 end
  end
  return out
end

local function refreshProfile()
  local _, classFile = safe(UnitClass, "player")
  local _, raceFile = safe(UnitRace, "player")
  profile.class = str(classFile)
  profile.raceFile = str(raceFile)
  local rf = profile.raceFile or ""
  profile.race = RACE_KEY[rf] or (rf:lower():find("sky") and "Skyborne") or rf
  profile.faction = str(safe(UnitFactionGroup, "player"))
  profile.name = str(safe(UnitName, "player"))
  profile.profs = readProfessions()
  profile.spec = readSpec()
end
ns.refreshProfile = refreshProfile

-- The name to show for the character: first and last name from Total RP 3 when it is loaded and has them, otherwise
-- the game's character name. Only displayed on the Setup page; never stored or sent.
function ns.fullName()
  local first, last
  pcall(function()
    local p = AddOn_TotalRP3 and AddOn_TotalRP3.Player and AddOn_TotalRP3.Player.GetCurrentUser and AddOn_TotalRP3.Player.GetCurrentUser()
    if p then
      first = p.GetFirstName and p:GetFirstName()
      last = p.GetLastName and p:GetLastName()
    end
    if (not first or first == "") and TRP3_API and TRP3_API.profile and TRP3_API.profile.getData then
      local ch = TRP3_API.profile.getData("player/characteristics")
      if type(ch) == "table" then first, last = ch.FN, ch.LN end
    end
  end)
  if type(first) ~= "string" or first == "" then first = profile.name or "" end
  if type(last) ~= "string" or last == "" then return first end
  return first .. " " .. last
end
-- the player's class colour as r, g, b (nil when the game does not have one)
function ns.classColor(classFile)
  local c = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
  if c and c.r then return c.r, c.g, c.b end
end

-- homeland options for this character's race
function ns.homelands()
  local rf = profile.raceFile
  local key = profile.race == "Forsaken" and "Scourge" or profile.race
  return (CROX2_HOMELANDS and (CROX2_HOMELANDS[rf or ""] or CROX2_HOMELANDS[key or ""])) or {}
end

function ns.isAlliance() return profile.faction == "Alliance" end
function ns.isTroll() return profile.raceFile == "Troll" end

------------------------------------------------------------------------
-- Facts about the moment
------------------------------------------------------------------------
local MINDLESS = {beast = true, elemental = true, mechanical = true, critter = true, totem = true, ["non-combat pet"] = true}
local FISH_WORDS = {"fish", "salmon", "trout", "snapper", "catfish", "mackerel", "grouper", "eel", "yellowtail",
  "sagefish", "smallfish", "squid", "lobster", "crab", "clam", "bass", "perch", "redgill", "mightfish", "nightfin"}

local healthLast, hurtAt = nil, -100
local stealthBefore = false

local function pct(unit)
  if ns.sim and unit == "player" then return ns.sim.hp end       -- the simulator's pretend health
  local h, m = safe(UnitHealth, unit), safe(UnitHealthMax, unit)
  if secret(h) or secret(m) or type(h) ~= "number" or type(m) ~= "number" or m <= 0 then return nil end
  return h / m * 100
end
ns.pct = pct

local function unitIs(a, b) return bool(safe(UnitIsUnit, a, b)) end

local function targetFacts()
  if ns.sim then return ns.sim.tgt end        -- the combat simulator supplies a pretend target
  local t = {}
  t.exists = bool(safe(UnitExists, "target")) or false
  if not t.exists then return t end
  t.name = str(safe(UnitName, "target"))
  t.self = unitIs("target", "player")
  local can = safe(UnitCanAttack, "player", "target")
  t.enemy = not secret(can) and can and true or false
  local fr = safe(UnitIsFriend, "player", "target")
  t.friend = not secret(fr) and fr and not t.self and true or false
  t.player = bool(safe(UnitIsPlayer, "target"))
  local ct = str(safe(UnitCreatureType, "target"))
  t.ctype = ct and ct:lower() or nil
  local _, race = safe(UnitRace, "target")
  t.race = str(race)
  t.faction = str(safe(UnitFactionGroup, "target"))
  t.hp = pct("target")
  t.dead = bool(safe(UnitIsDeadOrGhost, "target"))
  local casting = safe(UnitCastingInfo, "target") or safe(UnitChannelInfo, "target")
  if secret(casting) then t.casting = nil else t.casting = casting and true or false end
  t.guid = str(safe(UnitGUID, "target"))
  local cls = str(safe(UnitClassification, "target"))
  local lvl = num(safe(UnitLevel, "target"))
  t.boss = (cls == "worldboss" or cls == "elite" or cls == "rareelite") or lvl == -1
  return t
end

local function itemIsFish(name)
  if not name then return false end
  local l = " " .. name:lower():gsub("[^%a]", " ") .. " "
  for _, w in ipairs(FISH_WORDS) do if l:find(" " .. w .. "s? ") or l:find(w, 1, true) then return true end end
  return false
end

local function equippedKnown(slots)
  for _, s in ipairs(slots) do
    local id = num(safe(GetInventoryItemID, "player", s))
    if id and cdb.recipes[id] then return true end
  end
  return false
end

local function weaponEnchanted()
  local link = str(safe(GetInventoryItemLink, "player", 16))
  if not link then return nil end
  local ench = link:match("item:%d+:(%d*)")
  return ench ~= nil and ench ~= "" and ench ~= "0"
end

-- build the facts for a press
local function makeCtx(ability, info, item)
  local ctx = {ability = ability, info = info or {}, item = item}
  ctx.tgt = targetFacts()
  ctx.hp = ns.sim and ns.sim.hp or pct("player")
  ctx.hurt = ns.sim and ns.sim.hurt or (now() - hurtAt) < 3
  ctx.stealth = stealthBefore
  ctx.group = ns.simParty ~= nil or bool(safe(IsInGroup)) or false
  ctx.raid = bool(safe(IsInRaid)) or false
  ctx.pet = bool(safe(UnitExists, "pet")) or false
  local outdoors = safe(IsOutdoors)
  ctx.outdoors = (not secret(outdoors)) and outdoors and true or false
  ctx.combat = ns.inCombat
  local tg = ctx.tgt
  ctx.onEnemy = tg.exists and tg.enemy or false
  ctx.onAlly = tg.exists and tg.friend and not tg.self or false
  ctx.onSelf = (not ctx.onAlly) and not ctx.onEnemy
  return ctx
end
ns.makeCtx = makeCtx

local CURE_CLASSES = {poison = {SHAMAN = 1, DRUID = 1, PALADIN = 1}, disease = {PRIEST = 1, SHAMAN = 1, PALADIN = 1},
  curse = {DRUID = 1, MAGE = 1}, magic = {PRIEST = 1, PALADIN = 1}}
local function groupCanCure(dtype)
  local want = CURE_CLASSES[dtype or ""]
  if not want then return false end
  local n = num(safe(GetNumGroupMembers)) or 0
  local raid = bool(safe(IsInRaid))
  for i = 1, n do
    local unit = raid and ("raid" .. i) or (i == n and "player" or ("party" .. i))
    local _, cf = safe(UnitClass, unit)
    if str(cf) and want[cf] and not unitIs(unit, "player") then return true end
  end
  return false
end

local function inList(csv, v)
  if not v then return false end
  for x in csv:gmatch("[^,]+") do if trim(x):lower() == v:lower() then return true end end
  return false
end

-- one mark -> true / false (unknown is false: the facts rule)
local function markTrue(tok, ctx)
  local tg = ctx.tgt
  if tok:sub(1, 3) == "nt:" then return cdb.temperament ~= tok:sub(4) end
  if tok == "ally" then return ctx.onAlly end
  if tok == "self" then return ctx.onSelf end
  if tok == "enemy" then return ctx.onEnemy end
  if tok == "group" then return ctx.group end
  if tok == "hurt" then return ctx.hurt end
  if tok == "hp50" then return ctx.hp ~= nil and ctx.hp < 50 end
  if tok == "hp35" then return ctx.hp ~= nil and ctx.hp < 35 end
  if tok == "allyhp35" then return ctx.onAlly and tg.hp ~= nil and tg.hp < 35 end
  if tok == "grpcure" then return groupCanCure(ctx.debuffType) end
  if tok == "instant" then return ctx.instant == true end
  if tok == "combat" then return ctx.combat == true end
  if tok == "enemytarget" then return ctx.onEnemy end
  if tok == "pet" then return ctx.pet end
  if tok == "stealth" then return ctx.stealth == true end
  if tok == "beast" then return tg.ctype == "beast" end
  if tok == "outdoors" then return ctx.outdoors end
  if tok == "fish" then return ctx.isFish == true end
  if tok == "enchanted" then return weaponEnchanted() == true end
  if tok == "allianceplayer" then return tg.player == true and tg.faction == "Alliance" end
  if tok == "!enemyplayer" then return tg.exists and tg.player == false end
  if tok == "recipe" then return ctx.itemID ~= nil and cdb.recipes[ctx.itemID] == true end
  if tok == "recipe:weapon" then return equippedKnown({16, 17, 18}) end
  if tok == "recipe:armor" then return equippedKnown({1, 3, 5, 6, 7, 8, 9, 10, 15}) end
  if tok:sub(1, 4) == "dmg:" then
    for want in tok:sub(5):gmatch("[^|]+") do
      for _, have in ipairs(ctx.info.dmg or {}) do if have == want then return true end end
    end
    return false
  end
  if tok:sub(1, 7) == "!ctype:" then
    local what = tok:sub(8)
    if not tg.ctype then return false end
    if what == "mindless" then return not MINDLESS[tg.ctype] end
    return tg.ctype ~= what
  end
  if tok:sub(1, 6) == "!race:" then return profile.race ~= nil and not inList(tok:sub(7), profile.race) end
  if tok:sub(1, 5) == "race:" then return inList(tok:sub(6), profile.race) end
  if tok:sub(1, 6) == "erace:" then return inList(tok:sub(7), tg.race) end
  return false
end

local function lineOK(line, ctx)
  if line.o and line.o ~= cdb.temperament then return false end
  if line.m then
    for _, tok in ipairs(line.m) do if not markTrue(tok, ctx) then return false end end
  end
  return true
end
ns.lineOK = lineOK

------------------------------------------------------------------------
-- Choosing a line
------------------------------------------------------------------------
local NO_REPEAT = 30 * 60   -- seconds of wall time before a line may come again (when there's a choice)

local function lineId(pool, line) return pool .. "|" .. line.t end
ns.lineId = lineId

local function isOff(id) return cdb.off[id] == true end

-- candidates: list of {id, line, w, pool}
local function addCands(cands, pool, lines, ctx, opt)
  if not lines then return end
  opt = opt or {}
  for _, line in ipairs(lines) do
    local okKind = (opt.emote == nil) or ((line.e and true or false) == opt.emote)
    local okArch = true
    if opt.arch and line.a then
      okArch = false
      for _, a in ipairs(line.a) do if a == opt.arch then okArch = true break end end
    end
    if okKind and okArch then
      local id = lineId(pool, line)
      if not isOff(id) and lineOK(line, ctx) then
        local w = opt.w or 1
        if line.rare then w = w * 0.25 end
        cands[#cands + 1] = {id = id, line = line, w = w, pool = pool}
      end
    end
  end
end

local function pick(cands)
  if #cands == 0 then return nil end
  local t = wall()
  local fresh, total = {}, 0
  for _, c in ipairs(cands) do
    local last = cdb.last[c.id]
    if not last or t - last >= NO_REPEAT then fresh[#fresh + 1] = c total = total + c.w end
  end
  if #fresh == 0 then
    -- everything was said recently: the one said longest ago
    local best
    for _, c in ipairs(cands) do
      if not best or (cdb.last[c.id] or 0) < (cdb.last[best.id] or 0) then best = c end
    end
    return best
  end
  local r = math.random() * total
  for _, c in ipairs(fresh) do
    r = r - c.w
    if r <= 0 then return c end
  end
  return fresh[#fresh]
end

-- tag groups this character has, with weights (design: class 20, drive 15, homeland 10, upbringing 10, spec 10,
-- professions 10)
local function tagGroups()
  local g = {}
  local function add(w, keys) g[#g + 1] = {w = w, keys = keys} end
  if profile.class then add(20, {"class:" .. profile.class}) end
  if cdb.drive then add(15, {"drive:" .. cdb.drive}) end
  local home = {}
  if cdb.homeland then home[#home + 1] = cdb.homeland end
  if profile.race == "Skyborne" then home[#home + 1] = "home:skyborne_all" end
  if #home > 0 then add(10, home) end
  if cdb.upbringing then add(10, {"up:" .. cdb.upbringing}) end
  local profs = {}
  if cdb.profLines ~= false then
    for k in pairs(profile.profs or {}) do profs[#profs + 1] = "prof:" .. k end
  end
  if #profs > 0 then add(10, profs) end
  return g
end

local function specLines(arch, ctx, cands)
  local data = CROX2_SPEC and CROX2_SPEC[profile.class or ""]
  if not data then return end
  for tree, band in pairs(profile.spec or {}) do
    local t = data[tree]
    if t then
      for b = 1, band do addCands(cands, "spec:" .. tree .. ":" .. b, t[b], ctx, {arch = arch, emote = false}) end
    end
  end
end

local TAG_SHARE = 1 / 3
local EMOTE_SHARE = 0.15
local DMG_SHARE = 0.2
local DAMAGE_ARCH = {opener = 1, filler = 1, heavy = 1, area = 1, upkeep = 1, reactive = 1, finisher = 1}

-- custom lines for a moment
local CUSTOM_W = {1, 3}   -- Rarely, Sometimes; Often = half of everything
local function customFor(moment, ctx, wantEmote)
  local out = {}
  for _, list in ipairs({cdb.custom, db.custom}) do
    for _, c in ipairs(list) do
      if c.on ~= false and c.text and c.moments and c.moments[moment] then
        local isEmote = c.as == "emote"
        if wantEmote == nil or wantEmote == isEmote then out[#out + 1] = c end
      end
    end
  end
  return out
end
ns.customFor = customFor

-- choose a line for a moment. pools: base pool keys. Returns {text, emote, id, pool, line, custom}
local function choose(moment, pools, ctx, opt)
  opt = opt or {}
  local wantEmote = false
  if opt.emoteOnly then wantEmote = true
  elseif cdb.emotes and math.random() < EMOTE_SHARE then wantEmote = true end

  local function base(emote)
    local cands = {}
    for _, pk in ipairs(pools) do
      addCands(cands, pk, CROX2_POOLS[pk], ctx, {emote = emote, w = pk:find("^summon:") and pk ~= "summon:any" and 3 or 1})
    end
    return cands
  end

  -- tag lines (voice only), about 1 in 3
  local cands
  if not wantEmote and not opt.noTags and math.random() < (opt.tagShare or TAG_SHARE) then
    local groups = {}
    for _, g in ipairs(tagGroups()) do
      local c = {}
      for _, key in ipairs(g.keys) do addCands(c, "tag:" .. key, CROX2_TAGS[key], ctx, {arch = moment, emote = false}) end
      if #c > 0 then groups[#groups + 1] = {w = g.w, c = c} end
    end
    local sc = {}
    specLines(moment, ctx, sc)
    if #sc > 0 then groups[#groups + 1] = {w = 10, c = sc} end
    local total = 0
    for _, g in ipairs(groups) do total = total + g.w end
    if total > 0 then
      local r = math.random() * total
      for _, g in ipairs(groups) do r = r - g.w if r <= 0 then cands = g.c break end end
    end
  end

  -- damage-type extras
  if not cands and not wantEmote and DAMAGE_ARCH[moment] and ctx.info.dmg and math.random() < DMG_SHARE then
    local c = {}
    for _, d in ipairs(ctx.info.dmg) do addCands(c, "dmg:" .. d, CROX2_DMG and CROX2_DMG[d], ctx, {emote = false}) end
    if #c > 0 then cands = c end
  end

  if not cands then
    cands = base(wantEmote)
    if #cands == 0 and wantEmote and not opt.emoteOnly then cands = base(false) wantEmote = false end
    -- your own lines
    local own = customFor(moment, ctx, wantEmote and true or false)
    if #own > 0 then
      local total = 0
      for _, c in ipairs(cands) do total = total + c.w end
      for _, c in ipairs(own) do
        local w = c.freq == 3 and math.max(1, total) or CUSTOM_W[c.freq or 2] or 3
        cands[#cands + 1] = {id = "own|" .. c.text, line = {t = c.text, e = c.as == "emote"}, w = w, custom = c}
      end
    end
  end

  local c = pick(cands)
  if not c then return nil end
  return c
end
ns.choose = choose

------------------------------------------------------------------------
-- Text: profanity filter, troll voice, placeholders
------------------------------------------------------------------------
local PRON = {
  he = {they = "he", them = "him", their = "his", themself = "himself", theirs = "his"},
  she = {they = "she", them = "her", their = "her", themself = "herself", theirs = "hers"},
  they = {they = "they", them = "them", their = "their", themself = "themself", theirs = "theirs", plural = true},
}
ns.PRON = PRON

local function capsShare(s)
  local up, all = 0, 0
  for ch in s:gmatch("%a") do all = all + 1 if ch:match("%u") then up = up + 1 end end
  return all >= 4 and up / all or 0
end

-- final text for a chosen line (nil if a placeholder can't be filled)
local function render(c, ctx, channel, extra)
  local line = c.line
  local text = line.t
  if cdb.filter and line.c then text = line.c end
  local troll = (not line.e) and not c.custom and ns.isTroll() and cdb.troll == "accent" and CROX_Trollify
  if troll then text = CROX_Trollify(text, channel == "YELL") end
  local pr = PRON[cdb.pronouns] or PRON.they
  local ok = true
  text = text:gsub("%[(%a+)%]", function(w)
    local lw = w:lower()
    if lw == "target" then
      local n = ctx.tgt and ctx.tgt.name
      if not n then ok = false return "" end
      return n
    elseif lw == "ally" then
      if not (extra and extra.ally) then ok = false return "" end
      return extra.ally
    elseif lw == "debuff" then
      if not ctx.debuffName then ok = false return "" end
      return ctx.debuffName
    elseif lw == "name" then
      return profile.name or ""
    end
    local v = pr[lw]
    if type(v) ~= "string" then return "[" .. w .. "]" end
    if troll and CROX_TrollWord then v = CROX_TrollWord(v) end
    if w:sub(1, 1):match("%u") then v = v:sub(1, 1):upper() .. v:sub(2) end
    return v
  end)
  if not ok then return nil end
  -- emotes start with the character's name automatically; "[name]" typed by a player is dropped
  if line.e then text = text:gsub("^%s+", "") end
  return text
end

local YELLY = {rally = true, taunt = true, powerup = true, laststand = true}
-- A yell has to be earned. A line that wants to be shouted is only shouted when
--   * it has been a while since this character last yelled (the gap shrinks as the pace gets louder),
--   * nobody else in the party has yelled just now (one shout at a time), and
--   * the moment has stakes: health is low, the enemy is a boss or elite, or the fight has dragged on.
-- Anything else is said instead. A phrase the player marked "yell" is always yelled, and calls to far allies are
-- yelled in Group.lua because they have to carry.
local YELL_GAP_MIN, YELL_GAP_MAX, DRAGGED_ON = 30, 120, 30
local lastYell, fightT0, fightYells = -1000, 0, 0
local function yellGap()
  local c = ns.CHATTY and (ns.CHATTY[ns.chattyNow()] or ns.CHATTY[3]) or {rate = 3}
  return math.max(YELL_GAP_MIN, math.min(YELL_GAP_MAX, 180 / c.rate))
end
local function yellEarned(moment, ctx, t)
  if t - lastYell < yellGap() then return false, "yell gap" end
  if ns.G and ns.G.yellBlock and ns.G.yellBlock(t) then return false, "party yell" end
  if moment == "laststand" then return true end
  ctx = ctx or {}
  local hp = ctx.hp
  if hp and hp < 50 then return true end
  if ctx.tgt and ctx.tgt.boss then return true end
  if ns.inCombat and fightT0 > 0 and t - fightT0 >= DRAGGED_ON then return true end
  return false, "no stakes"
end
local function channelFor(c, moment, opt, ctx)
  if c.line.e then return "EMOTE" end
  if c.custom and c.custom.as == "say" then return "SAY" end
  local want = "SAY"
  local forced = false
  if c.custom and c.custom.as == "yell" then want, forced = "YELL", true
  elseif opt and opt.yell then want, forced = "YELL", true
  elseif YELLY[moment] or capsShare(c.line.t) >= 0.6 then want = "YELL" end
  if want == "YELL" and not cdb.yell then want = "SAY" end
  local held
  if want == "YELL" and not forced then
    local ok, why = yellEarned(moment, ctx, now())
    if not ok then want, held = "SAY", why end
  end
  return want, held
end
ns.channelFor = channelFor

------------------------------------------------------------------------
-- Sending and pace
------------------------------------------------------------------------
-- Five paces. mult scales how often a press speaks; gap = least seconds between lines; perMin = most lines a minute.
-- est is the rough number of lines a minute to expect in a fight.
-- Pace. Each level has a target spread of lines a minute, a rate (the middle of the spread, used to refill the speech
-- budget) and a chance multiplier. In a party the loudest member's rate sets the whole party's budget.
local CHATTY = {
  [1] = {name = "Hushed", est = "0-1 a minute", rate = 0.5, mult = 0.05},
  [2] = {name = "Reserved", est = "1-3 a minute", rate = 2.0, mult = 0.3},
  [3] = {name = "Social", est = "2-4 a minute", rate = 3.0, mult = 0.6},
  [4] = {name = "Talkative", est = "3-5 a minute", rate = 4.0, mult = 0.85},
  [5] = {name = "Chatty", est = "4-6 a minute", rate = 5.0, mult = 1.2},
  [6] = {name = "Windbag", est = "5-7 a minute", rate = 6.0, mult = 1.6},      -- group setting only
  [7] = {name = "Deafening", est = "6-7 a minute", rate = 6.5, mult = 1.9},   -- group setting only
}
local SOLO_LEVELS = 5       -- the solo setting offers the first five; the last two are for groups
-- Speech budget: it refills steadily at the level's rate, a line costs one, and it holds at most two, so there can
-- be a small burst at the pull and then a natural recovery. Big moments are always allowed (they still spend it).
local SAFE_GAP = 2          -- seconds between any two of your lines, always (keeps chat from throttling)
local BUDGET_CAP = 2.0
local budget, budgetT = 1.0, 0
local spokeTimes = {}
local lastSpoke = -1000
local SILENCE_FULL = 30     -- seconds of quiet in a fight after which the chance has risen to its top
local REFRACTORY = 10       -- seconds over which the chance recovers after a line
ns.CHATTY = CHATTY
function ns.chattyItems(group)
  local t = {}
  for i, c in ipairs(CHATTY) do
    if group or i <= SOLO_LEVELS then t[#t + 1] = {i, c.name} end
  end
  return t
end
-- the pace setting in force: any party or raid uses the group setting (stored as raidChatty), alone uses the solo one
function ns.chattyNow()
  local c = ns.cdb or cdb
  if ns.simParty or bool(safe(IsInGroup)) or bool(safe(IsInRaid)) then return math.min(7, c.raidChatty or 3) end
  return math.min(SOLO_LEVELS, c.chatty or 3)
end

function ns.sinceSpoke() return now() - lastSpoke end

local function refillBudget(t)
  local ch = CHATTY[ns.chattyNow()] or CHATTY[3]
  if budgetT == 0 then budgetT = t end
  budget = math.min(BUDGET_CAP, budget + (t - budgetT) * ch.rate / 60)
  budgetT = t
end
ns.getBudget = function() refillBudget(now()) return budget end

-- may a normal line go out now? (nil = yes, otherwise why not)
local function paceBlock(t, big)
  if t - lastSpoke < SAFE_GAP then return "pace: " .. SAFE_GAP .. "s between lines" end
  if big then return nil end
  refillBudget(t)
  if budget < 1 then return "pace: speech budget is spent" end
  if ns.G and ns.G.paceBlock then
    local why = ns.G.paceBlock(t)
    if why then return why end
  end
end
ns.paceBlock = paceBlock

local function send(channel, text)
  if ns.simOut then ns.simOut(channel, text) return true end     -- the simulator shows lines in its own window
  local ok, err = pcall(SendChatMessage, text, channel)
  return ok, err
end

-- say a chosen line; kind: "said" | "call" | "reply"; returns true if it went out
local function deliver(c, ctx, moment, extra, opt)
  local channel, held = channelFor(c, moment, opt, ctx)
  if opt and opt.channel then channel = c.line.e and "EMOTE" or opt.channel end
  local text = render(c, ctx, channel, extra)
  if not text or text == "" then return false end
  local ok = send(channel, text)
  if not ok then return false end
  local t = now()
  refillBudget(t)
  budget = math.max(0, budget - 1)
  lastSpoke = t
  if channel == "YELL" then lastYell, fightYells = t, fightYells + 1 end
  spokeTimes[#spokeTimes + 1] = t
  while #spokeTimes > 30 do table.remove(spokeTimes, 1) end
  cdb.last[c.id] = wall()
  cdb.said[c.id] = (cdb.said[c.id] or 0) + 1
  if ns.Log then
    ns.Log.said({moment = moment, ability = ctx.ability, item = ctx.itemName, text = text, channel = channel,
      pool = c.pool, own = c.custom and true or nil, target = ctx.tgt and ctx.tgt.name, tgtPlayer = ctx.tgt and ctx.tgt.player,
      onAlly = ctx.onAlly, onSelf = ctx.onSelf, ally = extra and extra.ally, allyClass = extra and extra.allyClass,
      kind = (opt and opt.kind) or "said", held = held})
  end
  if ns.G and ns.G.noteSpoke and not (opt and opt.noBroadcast) then ns.G.noteSpoke(opt and opt.kind, channel == "YELL") end
  return true
end
ns.deliver = deliver

-- choose + deliver for a moment; returns true if spoken
local function sayMoment(moment, pools, ctx, opt, extra)
  local c = choose(moment, pools, ctx, opt)
  if not c then
    if ns.Log then ns.Log.quiet(ctx, moment, "no true line") end
    return false
  end
  return deliver(c, ctx, moment, extra, opt)
end
ns.sayMoment = sayMoment

------------------------------------------------------------------------
-- Action buttons
------------------------------------------------------------------------
local slotSpell = {}      -- [slot] = {kind="spell"/"item", name=..., id=...}
local before = {}         -- [slot] = {usable, range, cd}
local formBefore

local DRINK_WORDS = {"water", "juice", "milk", "ale", "mead", "wine", "tea", "cider", "nectar", "grog", "rum",
  "lager", "stout", "coffee", "drink", "punch", "dew", "brew", "lemonade"}
local BOMB_WORDS = {"bomb", "dynamite", "grenade", "explosive", "sapper", "seaforium", "detonator", "charge"}
local function hasWord(name, words)
  local l = " " .. name:lower():gsub("[^%a]", " ") .. " "
  for _, w in ipairs(words) do if l:find(" " .. w .. "s? ") then return true end end
end
local function itemInfo(id)
  local name = str(safe(C_Item and C_Item.GetItemNameByID, id)) or str(safe(GetItemInfo, id))
  local r = {safe(C_Item and C_Item.GetItemInfoInstant, id)}
  if r[1] == nil then r = {safe(GetItemInfoInstant, id)} end
  local classID, subID = r[6], r[7]
  if secret(classID) or secret(subID) then classID, subID = nil, nil end
  return name, classID, subID
end
-- consumable moment for an item id: "item:healing", "item:food", ...
local function itemMoment(id)
  if not id or secret(id) then return nil end
  local name, classID, subID = itemInfo(id)
  local l = name and name:lower() or ""
  if l:find("healthstone") then return "item:healing", name end
  if name and hasWord(name, BOMB_WORDS) then return "item:explosives", name end
  if classID == 7 and subID == 2 then return "item:explosives", name end
  local isPotion = (classID == 0 and subID == 1) or l:find("potion") or l:find("draught")
  if isPotion then
    if l:find("mana") then return "item:mana", name end
    if l:find("rage") then return "item:rage", name end
    if l:find("heal") or l:find("health") or l:find("rejuvenation") then return "item:healing", name end
    return "item:potion", name
  end
  if (classID == 0 and subID == 2) or l:find("elixir") then return "item:elixir", name end
  if (classID == 0 and subID == 3) or l:find("^flask") then return "item:flask", name end
  if (classID == 0 and subID == 4) or l:find("^scroll of") then return "item:scroll", name end
  if (classID == 0 and subID == 7) or l:find("bandage") then return "item:bandage", name end
  if classID == 0 and subID == 5 then
    if name and hasWord(name, DRINK_WORDS) then return "item:drink", name end
    return "item:food", name
  end
end
ns.itemMoment = itemMoment

local function resolveSlot(slot)
  local ok, kind, id = pcall(GetActionInfo, slot)
  if not ok or secret(kind) or secret(id) then return nil end
  if kind == "spell" then local n = spellName(id) return n and {kind = "spell", name = n, id = id} end
  if kind == "item" then return {kind = "item", id = id} end
  if kind == "macro" then
    local sid = safe(GetMacroSpell, id)
    if sid and not secret(sid) then local n = spellName(sid) return n and {kind = "spell", name = n, id = sid} end
    local iname, ilink = safe(GetMacroItem, id)
    if iname and not secret(iname) then
      local iid = type(ilink) == "string" and not secret(ilink) and tonumber(ilink:match("item:(%d+)"))
      return {kind = "item", id = iid or iname}
    end
  end
end

local function flag(v)
  if secret(v) then return "hidden" end
  if v == nil then return nil end
  return v and true or false
end

local function slotState(slot)
  local st = {}
  st.usable = flag(safe(IsUsableAction, slot))
  st.range = flag(safe(IsActionInRange, slot))
  if C_ActionBar and C_ActionBar.GetActionCooldown then
    local info = safe(C_ActionBar.GetActionCooldown, slot)
    if type(info) == "table" then st.cd = flag(info.isActive) end
  end
  if st.cd == nil then
    local start, dur = safe(GetActionCooldown, slot)
    if secret(start) or secret(dur) then st.cd = "hidden"
    elseif type(dur) == "number" then st.cd = dur > 1.6 end   -- the global cooldown doesn't count
  end
  return st
end

local function activeForm()
  local idx = safe(GetShapeshiftForm)
  if not idx or secret(idx) or idx == 0 then return nil end
  local r = {safe(GetShapeshiftFormInfo, idx)}
  return str(r[2]) or spellName(r[4])
end
ns.activeForm = activeForm

local function refreshMap()
  for slot = 1, 180 do slotSpell[slot] = resolveSlot(slot) end
end

local function abilityInfo(name)
  local cls = CROX2_ABILITIES and CROX2_ABILITIES[profile.class or ""]
  local a = cls and cls[name]
  if not a and CROX2_ABILITIES and CROX2_ABILITIES.ANY then a = CROX2_ABILITIES.ANY[name] end
  return a
end
ns.abilityInfo = abilityInfo

local function isInstant(name)
  local info = safe(C_Spell and C_Spell.GetSpellInfo, name)
  if type(info) == "table" and num(info.castTime) then return info.castTime == 0 end
  local r = {safe(GetSpellInfo, name)}
  local ct = num(r[4])
  if ct then return ct == 0 end
  return nil
end

------------------------------------------------------------------------
-- Fight state
------------------------------------------------------------------------
ns.inCombat = false
local fightOpened = false
local killPending          -- {t, name}
local lastEnemyGUID, lastEnemyName, enemyWasAlive = nil, nil, false
local debuffQueue = {}     -- {pool, name, dtype, t}
local lastDebuffCallout = -100
local lastProfEmote = -1000

local FREQ = {
  filler = 5, upkeep = 5, heal = 5,
  heavy = 10, area = 10, reactive = 10, guard = 10, ward = 10, groupheal = 10,
  opener = 25, finisher = 25, lockdown = 25, weaken = 25, rally = 25,
  interrupt = 35, snare = 35, taunt = 35, escape = 35, sneak = 35, cleanse = 35, bless = 35, summon = 35,
  laststand = 100, clutch = 100, raise = 100, powerup = 100,
  kill = 40,
  ["item:healing"] = 50, ["item:mana"] = 40, ["item:rage"] = 50, ["item:potion"] = 50, ["item:explosives"] = 40,
  ["item:bandage"] = 35, ["item:food"] = 30, ["item:drink"] = 30, ["item:elixir"] = 35, ["item:flask"] = 35,
  ["item:scroll"] = 35,
}
local BIG = {laststand = true, clutch = true, raise = true, powerup = true}
ns.FREQ, ns.BIG = FREQ, BIG

-- which tag/profession pools speak on item moments
local PROF_FOR_ITEM = {
  ["item:potion"] = "alchemy", ["item:healing"] = "alchemy", ["item:mana"] = "alchemy", ["item:rage"] = "alchemy",
  ["item:elixir"] = "alchemy", ["item:flask"] = "alchemy", ["item:explosives"] = "engineering",
  ["item:bandage"] = "first_aid", ["item:food"] = "cooking",
}

local DEBUFF_POOL = {Curse = "debuff:cursed", Poison = "debuff:poisoned", Disease = "debuff:diseased", Magic = "debuff:magic"}
local DEBUFF_KIND = {Curse = "curse", Poison = "poison", Disease = "disease", Magic = "magic"}
local CC_WORDS = {"stun", "stunned", "bash", "hammer of justice", "cheap shot", "kidney shot", "war stomp", "concussion blow",
  "pounce", "impact", "knockdown", "sap", "gouge", "polymorph", "hibernate", "sleep", "hex", "seduction", "blind",
  "scatter shot", "wyvern sting", "freezing trap", "repentance", "fear", "terrify", "howl of terror", "psychic scream",
  "intimidating shout", "scare", "horrify", "panic", "death coil", "root", "roots", "frost nova", "entangling roots", "net",
  "freeze", "frostbite", "hamstring", "slow", "crippling poison", "wing clip", "frostbolt", "chilled", "concussive shot",
  "dazed", "piercing howl", "cone of cold", "frost shock", "earthbind", "silence", "silenced", "counterspell", "disarm",
  "spell lock"}
local FROST_WORDS = {"frost", "chill", "chilled", "ice", "freeze", "frozen", "cold", "frostbite", "blizzard"}
local function wordIn(name, words)
  if not name then return false end
  local l = " " .. name:lower():gsub("[^%a]", " "):gsub("%s+", " ") .. " "
  for _, w in ipairs(words) do if l:find(" " .. w .. " ", 1, true) then return true end end
  return false
end

local debuffsNow, hiddenBefore = {}, 0
local function readDebuff(i)
  local name, dtype, sid
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local a = safe(C_UnitAuras.GetAuraDataByIndex, "player", i, "HARMFUL")
    if a == nil then return nil end
    if secret(a) or type(a) ~= "table" then return true end
    pcall(function() name, dtype, sid = a.name, a.dispelName, a.spellId end)
  else
    local r = {safe(UnitAura or UnitDebuff, "player", i, "HARMFUL")}
    if r[1] == nil then return nil end
    name, dtype, sid = r[1], r[4], r[10]
  end
  name, dtype = str(name), str(dtype)
  if secret(sid) or type(sid) ~= "number" then sid = nil end
  return true, name, dtype, sid
end

local function scanDebuffs(announce)
  local seen, hidden, found = {}, 0, {}
  for i = 1, 40 do
    local any, name, dtype, sid = readDebuff(i)
    if not any then break end
    local key = (sid and ("id" .. sid)) or (name and ("n" .. name))
    if key then
      if not seen[key] then seen[key] = true found[#found + 1] = {key, name, dtype} end
    else hidden = hidden + 1 end
  end
  if announce and cdb and cdb.on then
    for _, f in ipairs(found) do
      if not debuffsNow[f[1]] and #debuffQueue < 5 then
        local pool = wordIn(f[2], CC_WORDS) and "debuff:cc" or DEBUFF_POOL[f[3] or ""] or "debuff:physical"
        debuffQueue[#debuffQueue + 1] = {pool = pool, name = f[2], dtype = f[3], kind = DEBUFF_KIND[f[3] or ""],
          frost = wordIn(f[2], FROST_WORDS), t = now()}
      end
    end
    for _ = 1, hidden - hiddenBefore do
      if #debuffQueue < 5 then debuffQueue[#debuffQueue + 1] = {pool = "debuff:physical", t = now()} end
    end
  end
  debuffsNow, hiddenBefore = seen, hidden
end
ns.debuffQueue = debuffQueue

------------------------------------------------------------------------
-- The press
------------------------------------------------------------------------
-- How often the moments that mark a fight should speak, as a baseline set with the designer (2026-11-15):
-- often / sometimes / rarely, each a chance at the Normal pace (the other paces scale it). Low health and a new
-- debuff are already always-or-nearly-always (clutch is a big moment; debuff call-outs only wait for the budget).
local TIER = {often = 0.7, sometimes = 0.33, rarely = 0.1}
local SITUATION = {opener = "sometimes", kill = "sometimes"}
ns.SITUATION = SITUATION
local function chanceOK(moment, big)
  if big then return true end
  local base = FREQ[moment] or 25
  local mult = (CHATTY[ns.chattyNow()] or CHATTY[3]).mult
  local tier = SITUATION[moment] and TIER[SITUATION[moment]]
  if tier then base = tier * 100 / mult * math.max(0.3, math.min(1.9, mult / 0.75)) end
  local t = now()
  local since = t - lastSpoke
  if ns.G and ns.G.sinceAny then since = math.min(since, ns.G.sinceAny(t)) end
  -- right after a line the next one is less likely; in a fight, a long quiet stretch makes one likelier
  local refr = 0.2 + 0.8 * math.min(1, (t - lastSpoke) / REFRACTORY)
  local boost = ns.inCombat and (1 + math.min(since, SILENCE_FULL) / 20) or 1
  local pct_ = base * mult * refr * boost
  ns._lastChance = pct_
  return math.random() * 100 < pct_
end

local function quiet(ctx, moment, why)
  if ns.Log then ns.Log.quiet(ctx, moment, why) end
end

local function onItem(slot, info, t)
  local moment, iname = itemMoment(info.id)
  if not moment then return end
  local ctx = makeCtx(nil, nil, true)
  ctx.itemName, ctx.itemID = iname, type(info.id) == "number" and info.id or nil
  ctx.isFish = moment == "item:food" and itemIsFish(iname)
  -- food and drink are eaten out of combat too; potions and bandages mostly in it
  local why = paceBlock(t, false)
  if why then quiet(ctx, moment, why) return end
  if not chanceOK(moment) then quiet(ctx, moment, "chance roll") return end
  local pools = {moment}
  if moment == "item:healing" or moment == "item:mana" or moment == "item:rage" then pools[2] = "item:potion" end
  -- profession lines: about half the time when the character has that profession
  local prof = PROF_FOR_ITEM[moment]
  if prof and cdb.profLines ~= false and profile.profs and profile.profs[prof] and math.random() < 0.5 then
    local cands = {}
    addCands(cands, "tag:prof:" .. prof, CROX2_TAGS["prof:" .. prof], ctx, {arch = moment, emote = false})
    if moment == "item:food" and profile.profs.fishing then
      addCands(cands, "tag:prof:fishing", CROX2_TAGS["prof:fishing"], ctx, {arch = moment, emote = false})
    end
    local c = pick(cands)
    if c and deliver(c, ctx, moment) then return end
  end
  sayMoment(moment, pools, ctx, {noTags = true})
end

-- archetype for this press, after the special rules
local function resolveArch(a, ctx, name)
  local arch = a.arch
  if ctx.onAlly or ctx.onSelf then
    if a.friend then arch = a.friend end
  end
  if not arch then return nil end
  -- the first harmful press of a fight opens it
  if ctx.onEnemy and not fightOpened and (arch == "filler" or arch == "heavy" or arch == "upkeep" or arch == "opener"
      or arch == "area" or arch == "snare" or arch == "weaken" or arch == "lockdown" or arch == "taunt") then
    arch = "opener"
  end
  if arch == "interrupt" and ctx.tgt.casting ~= true then return "filler", "interrupt with nothing to interrupt" end
  if arch == "clutch" then
    local hp = ctx.onAlly and ctx.tgt.hp or ctx.hp
    if not (hp and hp < 35) then arch = "heal" end
  end
  if arch == "sneak" and ctx.stealth then return nil, "already in stealth" end
  if arch == "groupheal" and not ctx.group then return nil, "group heal outside a group" end
  return arch
end

local function onSpell(slot, info, t)
  local name = info.name
  local a = abilityInfo(name)
  if not a then return end
  local ctx = makeCtx(name, a)
  ctx.instant = isInstant(name)
  if a.quiet then return end
  local arch, why = resolveArch(a, ctx, name)
  if ctx.onEnemy then
    fightOpened = true
    lastEnemyGUID, lastEnemyName, enemyWasAlive = ctx.tgt.guid, ctx.tgt.name, not ctx.tgt.dead
  end
  if not arch then quiet(ctx, a.arch, why or "quiet") return end
  -- a resurrection outside combat stays quiet
  if arch == "raise" and not ns.inCombat then quiet(ctx, arch, "raise outside combat") return end

  -- group call and response wants to see helper presses (cleanse, heal, taunt)
  if ns.G and ns.G.onAbility and ns.G.onAbility(arch, ctx) then return end

  local big = a.big or BIG[arch]
  local w = paceBlock(t, big)
  if w then quiet(ctx, arch, w) return end
  if not chanceOK(arch, big) then quiet(ctx, arch, "chance roll") return end

  local pools = {"arch:" .. arch}
  local opt = {}
  if arch == "summon" then
    pools = {"summon:any"}
    if a.demon then pools[2] = "summon:" .. a.demon end
    opt.noTags = true
  end
  if a.emoteOnly then opt.emoteOnly = true end
  if sayMoment(arch, pools, ctx, opt) and arch == "rally" and ns.G and ns.G.onRallySpoken then ns.G.onRallySpoken() end
end

local STATUS_MAX_AGE = 10

local function onPress(slot)
  if not cdb or not cdb.on then return end
  if ns.isAlliance() then return end
  local t = now()
  local info = slotSpell[slot] or resolveSlot(slot)

  -- 1) call and response: replies and calls that any press can carry
  if ns.G and ns.G.onPress and cdb.cr then
    local ok, spoke = pcall(ns.G.onPress, info, t)
    if ok and spoke then return end
  end

  local b = before[slot]
  local ready = b and b.usable ~= false and b.cd ~= true and b.range ~= false

  -- 2) after a kill
  if killPending and t - killPending.t <= 5 then
    local kp = killPending
    killPending = nil
    local ctx = makeCtx(info and info.name, info and info.name and abilityInfo(info.name))
    ctx.killed = kp.name
    local w = paceBlock(t, false)
    if w then quiet(ctx, "kill", w)
    elseif not chanceOK("kill") then quiet(ctx, "kill", "chance roll")
    elseif sayMoment("kill", {"kill"}, ctx, {}) then
      if ns.G and ns.G.onKillSpoken then ns.G.onKillSpoken() end
      return
    end
  end

  -- 3) a new debuff on you (solo, or with nobody to help)
  while debuffQueue[1] and t - debuffQueue[1].t > STATUS_MAX_AGE do table.remove(debuffQueue, 1) end
  if debuffQueue[1] and ns.inCombat and t - lastDebuffCallout >= 20 then
    local d = table.remove(debuffQueue, 1)
    local ctx = makeCtx(nil, nil)
    ctx.debuffName, ctx.debuffType = d.name, d.kind
    local w = paceBlock(t, false)
    if not w then
      lastDebuffCallout = t
      local moment = d.frost and "debuff:frost" or d.pool
      if sayMoment(moment, {d.pool}, ctx, {noTags = not d.frost and moment ~= "debuff:diseased",
          tagShare = d.frost and 0.5 or nil}) then return end
    else
      quiet(ctx, d.pool, w)
    end
  end

  if not info then return end
  if not ready then
    if b and ns.inCombat then quiet(makeCtx(info.name), nil, "button not ready") end
    return
  end
  if info.kind == "item" then onItem(slot, info, t) return end
  if info.kind == "spell" then onSpell(slot, info, t) end
end
ns.onPress = onPress

------------------------------------------------------------------------
-- Professions: recipes and out-of-combat emotes
------------------------------------------------------------------------
local function scanRecipes()
  if not cdb then return end
  local profName = str(safe(GetTradeSkillLine))
  local key = profName and PROF_KEYS[profName:lower()]
  for i = 1, (num(safe(GetNumTradeSkills)) or 0) do
    local name, kind = safe(GetTradeSkillInfo, i)
    name, kind = str(name), str(kind)
    if name and kind ~= "header" then
      local link = str(safe(GetTradeSkillItemLink, i))
      local id = link and tonumber(link:match("item:(%d+)"))
      if id then cdb.recipes[id] = true end
      if key then cdb.recipeNames[name] = key end
    end
  end
  -- enchanting uses the craft window in older clients
  local craftName = str(safe(GetCraftDisplaySkillLine)) or str(safe(GetCraftSkillLine, 1))
  local ckey = craftName and PROF_KEYS[craftName:lower()]
  for i = 1, (num(safe(GetNumCrafts)) or 0) do
    local name, _, kind = safe(GetCraftInfo, i)
    name, kind = str(name), str(kind)
    if name and kind ~= "header" and ckey then cdb.recipeNames[name] = ckey end
  end
end

local GATHER = {["Herb Gathering"] = "herbalism", ["Mining"] = "mining", ["Skinning"] = "skinning"}
local PROF_EMOTE_COOLDOWN = 300
local function profEmote(kind, prof)
  if not cdb or not cdb.on or not cdb.emotes or cdb.profLines == false or ns.inCombat or ns.isAlliance() then return end
  local t = now()
  if t - lastProfEmote < PROF_EMOTE_COOLDOWN then return end
  if math.random() >= 0.1 then return end
  local key = kind .. ":" .. prof
  local lines = CROX2_PROF_EMOTES and CROX2_PROF_EMOTES[key]
  if not lines then return end
  local cands = {}
  local ctx = makeCtx(nil, nil)
  addCands(cands, "profemote:" .. key, lines, ctx, {emote = true})
  local c = pick(cands)
  if not c then return end
  local text = render(c, ctx, "EMOTE")
  if text and send("EMOTE", text) then
    lastProfEmote = t
    cdb.last[c.id] = wall()
    cdb.said[c.id] = (cdb.said[c.id] or 0) + 1
    if ns.Log then ns.Log.said({moment = key, text = text, channel = "EMOTE", pool = c.pool, kind = "said"}) end
  end
end

local function onSpellcast(unit, spellID)
  if unit ~= "player" then return end
  local name = spellName(spellID)
  if not name then return end
  if GATHER[name] then profEmote("gather", GATHER[name]) return end
  local prof = cdb and cdb.recipeNames[name]
  if prof then profEmote("craft", prof) end
end

------------------------------------------------------------------------
-- Ticker: button snapshots, kills, stealth, being hurt
------------------------------------------------------------------------
local snapAcc, mapAcc = 0, 1
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, el)
  if not cdb then return end
  el = el or 0
  snapAcc, mapAcc = snapAcc + el, mapAcc + el
  if mapAcc >= 1 then mapAcc = 0 pcall(refreshMap) end
  if snapAcc >= 0.1 then
    snapAcc = 0
    for slot in pairs(slotSpell) do before[slot] = slotState(slot) end
    formBefore = activeForm()
    local st = safe(IsStealthed)
    stealthBefore = (not secret(st)) and st and true or false
    -- your health dropping = you took damage
    local h = pct("player")
    if h and healthLast and h < healthLast - 0.5 then hurtAt = now() end
    healthLast = h
    -- the enemy you were fighting just died
    if lastEnemyName and enemyWasAlive then
      local same = true
      local g = str(safe(UnitGUID, "target"))
      if lastEnemyGUID and g and g ~= lastEnemyGUID then same = false end
      if same and bool(safe(UnitExists, "target")) then
        local dead = bool(safe(UnitIsDeadOrGhost, "target"))
        if dead then
          killPending = {t = now(), name = lastEnemyName}
          enemyWasAlive = false
          if ns.Log then ns.Log.event({kind = "kill", target = lastEnemyName}) end
        end
      end
    end
  end
end)

------------------------------------------------------------------------
-- Startup and events
------------------------------------------------------------------------
local hookOK = false
if hooksecurefunc and UseAction then
  hookOK = pcall(hooksecurefunc, "UseAction", function(slot) local ok, err = pcall(onPress, slot)
    if not ok then
      if ns.Bug then ns.Bug.capture(err) end
      if ns.debug then p("error: " .. tostring(err)) end
    end end)
end
ns.hookOK = function() return hookOK end

local ev = CreateFrame("Frame")
for _, e in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE",
  "CHARACTER_POINTS_CHANGED", "SKILL_LINES_CHANGED", "ACTIONBAR_SLOT_CHANGED", "UPDATE_SHAPESHIFT_FORMS",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_AURA", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE",
  "CRAFT_SHOW", "CRAFT_UPDATE", "UNIT_SPELLCAST_SUCCEEDED", "LOOT_OPENED", "PLAYER_SPECIALIZATION_CHANGED",
  "TRADE_SKILL_LIST_UPDATE"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, ...)
  if event == "ADDON_LOADED" then
    if a1 == ADDON then
      initDB()
      if ns.Log and ns.Log.init then ns.Log.init() end
    end
    return
  end
  if not cdb then return end
  if event == "PLAYER_LOGIN" then
    refreshProfile()
    pcall(refreshMap)
    pcall(scanDebuffs, false)
    -- skills and talents often aren't loaded yet at login: read again a little later
    if C_Timer and C_Timer.After then
      for _, secs in ipairs({4, 12}) do C_Timer.After(secs, function() refreshProfile() if ns.refreshUI then pcall(ns.refreshUI) end end) end
    end
    if ns.isAlliance() then
      if ns.showAlliance and not cdb.alliance.disabled then pcall(ns.showAlliance) end
      return
    end
    p(("cro_x %s loaded%s. Type /x to open."):format(BUILD, hookOK and "" or " — |cffff6666button hook FAILED|r"))
    -- the splash page (and, the first time, the setup walkthrough) open from UI.lua
  elseif event == "PLAYER_ENTERING_WORLD" then
    pcall(scanDebuffs, false)
  elseif event == "UNIT_AURA" then
    if a1 == "player" then pcall(scanDebuffs, true) end
  elseif event == "PLAYER_REGEN_DISABLED" then
    ns.inCombat = true
    refillBudget(now())
    budget = math.min(budget, 1.0)    -- a short pull starts with at most one line to spend
    fightT0, fightYells = now(), 0
    if ns.G and ns.G.fightStart then ns.G.fightStart() end
    if ns.Log then ns.Log.fightStart() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    ns.inCombat = false
    fightOpened = false
    lastEnemyName, lastEnemyGUID, enemyWasAlive = nil, nil, false
    if ns.Log then ns.Log.fightEnd() end
  elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_SHAPESHIFT_FORMS" then
    pcall(refreshMap)
  elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" or event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
    pcall(scanRecipes)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local spellID = select(2, ...)
    pcall(onSpellcast, a1, spellID)
  elseif event == "LOOT_OPENED" then
    if bool(safe(IsFishingLoot)) then pcall(profEmote, "gather", "fishing") end
  else
    refreshProfile()
  end
  if ns.refreshUI then pcall(ns.refreshUI) end
end)

-- sample line for the setup and the Character section (printed to your own chat only)
function ns.sample(kind)
  local ctx = makeCtx(nil, nil)
  local cands = {}
  if kind == "temperament" then
    for _, pk in ipairs({"arch:opener", "arch:filler", "arch:finisher", "kill"}) do
      for _, line in ipairs(CROX2_POOLS[pk] or {}) do
        if line.o == cdb.temperament and not line.e and not line.m then cands[#cands + 1] = {id = pk, line = line, w = 1} end
      end
    end
  elseif kind == "homeland" and cdb.homeland then
    addCands(cands, "tag", CROX2_TAGS[cdb.homeland], ctx, {emote = false})
  elseif kind == "upbringing" then
    addCands(cands, "tag", CROX2_TAGS["up:" .. (cdb.upbringing or "")], ctx, {emote = false})
  elseif kind == "drive" then
    addCands(cands, "tag", CROX2_TAGS["drive:" .. (cdb.drive or "")], ctx, {emote = false})
  else
    for _, pk in ipairs({"arch:opener", "kill"}) do addCands(cands, pk, CROX2_POOLS[pk], ctx, {emote = false}) end
  end
  -- samples ignore marks that need a fight
  if #cands == 0 then
    local src = kind == "homeland" and CROX2_TAGS[cdb.homeland or ""] or kind == "upbringing" and CROX2_TAGS["up:" .. (cdb.upbringing or "")]
      or kind == "drive" and CROX2_TAGS["drive:" .. (cdb.drive or "")] or {}
    for _, line in ipairs(src) do
      if not line.o or line.o == cdb.temperament then cands[#cands + 1] = {id = "s", line = line, w = 1} end
    end
  end
  if #cands == 0 then return nil end
  local c = cands[math.random(#cands)]
  local text = c.line.t
  if cdb.filter and c.line.c then text = c.line.c end
  if ns.isTroll() and cdb.troll == "accent" and CROX_Trollify then text = CROX_Trollify(text) end
  local pr = PRON[cdb.pronouns] or PRON.they
  text = text:gsub("%[(%a+)%]", function(w)
    if w:lower() == "target" then return "your target" end
    local v = pr[w:lower()]
    return type(v) == "string" and v or "[" .. w .. "]"
  end)
  return text
end

------------------------------------------------------------------------
-- Combat simulator hooks (UI/Sim.lua drives these; nothing here touches the game's own combat)
------------------------------------------------------------------------
local SIM_SLOT = 99999
function ns.simPress(name)
  slotSpell[SIM_SLOT] = {kind = "spell", name = name}
  before[SIM_SLOT] = {usable = true, cd = false, range = true}
  onPress(SIM_SLOT)
end
function ns.simFight(on)
  if on then
    ns.inCombat = true
    refillBudget(now())
    budget = math.min(budget, 1.0)
    fightOpened = false
    fightT0, fightYells = now(), 0
    if ns.G and ns.G.fightStart then ns.G.fightStart() end
    if ns.Log then ns.Log.fightStart(true) end
  else
    ns.inCombat = false
    fightOpened = false
    lastEnemyName, lastEnemyGUID, enemyWasAlive = nil, nil, false
    killPending = nil
    if ns.Log then ns.Log.fightEnd() end
  end
end
function ns.simKill(name)
  killPending = {t = now(), name = name}
  enemyWasAlive = false
  if ns.Log then ns.Log.event({kind = "kill", target = name}) end
end
function ns.simHurt() hurtAt = now() end
-- the simulator must not leave a mark on the real "said recently" memory
function ns.simSnapshot() local c = {said = {}, last = {}} for k, v in pairs(cdb.said) do c.said[k] = v end for k, v in pairs(cdb.last) do c.last[k] = v end return c end
function ns.simRestore(c) if c then cdb.said, cdb.last = c.said, c.last end end


-- Simulated players for the simulator. An actor is {profile, cdb, db, state, sim, user}: the line-picking code reads "the
-- character" from the profile and cdb it holds, so becoming an actor swaps those (and the pace memory) in, and
-- swapping back puts the real character back exactly as it was. Nothing here touches the real game or its saved data.
function ns.simNewCharDB(over)
  local t = {}
  for k, v in pairs(over or {}) do t[k] = v end
  fillDefaults(t, CHAR_DEFAULTS)
  t.on, t.testing, t.logging = true, false, false
  return t
end
local function paceGet()
  return {budget = budget, budgetT = budgetT, lastSpoke = lastSpoke, hurtAt = hurtAt, killPending = killPending,
    fightOpened = fightOpened, spoke = spokeTimes, debuffCall = lastDebuffCallout,
    lastYell = lastYell, fightT0 = fightT0, fightYells = fightYells}
end
local function paceSet(st)
  budget, budgetT, lastSpoke, hurtAt, killPending, fightOpened, spokeTimes, lastDebuffCallout =
    st.budget, st.budgetT, st.lastSpoke, st.hurtAt, st.killPending, st.fightOpened, st.spoke, st.debuffCall or -100
  lastYell, fightT0, fightYells = st.lastYell or -1000, st.fightT0 or 0, st.fightYells or 0
end
function ns.simFreshState() return {budget = 1.0, budgetT = 0, lastSpoke = -1000, hurtAt = -100, spoke = {}, debuffCall = -100, lastYell = -1000, fightT0 = 0, fightYells = 0} end
-- the simulator hands the current character a new debuff (dtype: Poison, Disease, Curse or Magic)
local SIM_DEBUFF_NAMES = {Poison = "Serpent Sting", Disease = "Plague Cloud", Curse = "Curse of Agony", Magic = "Frost Nova"}
function ns.simDebuff(dtype)
  if #debuffQueue >= 5 then return end
  debuffQueue[#debuffQueue + 1] = {pool = DEBUFF_POOL[dtype] or "debuff:physical", name = SIM_DEBUFF_NAMES[dtype] or "a debuff",
    dtype = dtype, kind = DEBUFF_KIND[dtype], frost = false, t = now()}
end
local simCurrent
-- begin: remember the real character's pace memory, to hand back at the end
function ns.simBegin(userActor)
  local snap = {state = paceGet(), g = ns.G and ns.G.simGet and ns.G.simGet(), actor = userActor, db = db}
  userActor.profile = {}
  for k, v in pairs(profile) do userActor.profile[k] = v end
  userActor.cdb, userActor.db, userActor.state = cdb, db, ns.simFreshState()
  simCurrent = nil
  ns.simActor = nil
  return snap
end
function ns.simBecome(a)
  if simCurrent == a then return end
  if simCurrent then
    simCurrent.state = paceGet()
    if ns.G and ns.G.simGet then simCurrent.g = ns.G.simGet() end
  end
  simCurrent, ns.simActor = a, a
  if not a then return end
  for k in pairs(profile) do profile[k] = nil end
  for k, v in pairs(a.profile) do profile[k] = v end
  cdb, ns.cdb = a.cdb, a.cdb
  db, ns.db = a.db, a.db
  paceSet(a.state)
  ns.sim = a.sim
  if ns.G and ns.G.simSet then ns.G.simSet(a.g) end
end
function ns.simEnd(snap, userActor)
  ns.simBecome(userActor)
  paceSet(snap.state)
  if ns.G and ns.G.simSet and snap.g then ns.G.simSet(snap.g) end
  simCurrent, ns.simActor, ns.sim = nil, nil, nil
  ns.simClock, ns.simWallAdd, ns.simParty = nil, nil, nil
end

-- test helpers for the harness
ns._test = {markTrue = markTrue, resolveArch = resolveArch, render = render, pick = pick, itemMoment = itemMoment,
  setPending = function(k) killPending = k end, debuffQueue = debuffQueue, readSpec = readSpec,
  setBudget = function(v) budget, budgetT = v, now() end,
  resetPace = function() lastSpoke = -1000 budget, budgetT = 1.0, 0 for i = #spokeTimes, 1, -1 do spokeTimes[i] = nil end end,
  setFightOpened = function(v) fightOpened = v end, refreshMap = refreshMap, slotSpell = slotSpell, before = before,
  setHurt = function() hurtAt = now() end}
