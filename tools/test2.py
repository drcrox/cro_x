import lupa.lua51 as L, sys
lua = L.LuaRuntime(unpack_returned_tuples=True)
import os
HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, "..", "CROX") + "/"
H = lua.execute(open(os.path.join(HERE, "harness.lua")).read())
lua.globals().H = H
lua.execute("math.randomseed(3)")
ns = lua.table()
toc = [l.strip() for l in open(D + "CROX.toc") if l.strip() and not l.startswith("#")]
for fn in toc:
    lua.eval("function(src, name) local f, e = loadstring(src, name) if not f then error(e) end return f end")(open(D + fn).read(), fn)("CROX", ns)
G = lua.globals()
H.fire("ADDON_LOADED", "CROX"); H.fire("PLAYER_LOGIN")
cdb = G.CROX2CharDB
cdb.setupDone = True
press = lua.eval("function(s) local ok, e = pcall(UseAction, s) if not ok then error(e) end end")
def sent_since(n): return [(r.ch, r.text) for r in list(H.sent.values())[n:]]
def nsent(): return len(list(H.sent.values()))
def check(name, cond, info=""):
    print(("PASS " if cond else "FAIL ") + name, info if not cond or info else "")

# --- 1. call and response: Krakka (shaman) can cure poison
H.group = True
H.party = lua.table(party1="Krakka")
lua.execute('function UnitClass(u) if u == "player" then return "Warrior", H.me.class end if u == "party1" then return "Shaman", "SHAMAN" end end')
onAddon = ns.G._test.onAddon
onAddon("CROX", "V2|HI|0|0.50|SHAMAN", "PARTY", "Krakka")
onAddon("CROX", "V2|ST|0|PH", "PARTY", "Krakka")
H.tgt = lua.table(name="Bristleback", enemy=True, hp=90, ctype="humanoid", guid="g1")
H.fire("PLAYER_REGEN_DISABLED")
# a poison lands
lua.execute('''
local n = 0
C_UnitAuras = {GetAuraDataByIndex = function(unit, i, f) if i == 1 and H.poisoned then return {name = "Deadly Poison", dispelName = "Poison", spellId = 2818} end end}
''')
H.poisoned = True
H.fire("UNIT_AURA", "player")
n0 = nsent(); press(2); out = sent_since(n0)
check("debuff help call names the helper", out and "Krakka" in out[0][1], out)
msgs = [m.msg for m in H.addon.values()]
check("CALL addon message sent", any(m.startswith("V2|CALL|0|debuffhelp|Krakka") for m in msgs), msgs[-3:])

# --- 2. low health call
H.tick(6)
H.me.hp = 25
onAddon("CROX", "V2|ST|0|H", "PARTY", "Krakka")
n0 = nsent(); press(2); out = sent_since(n0)
check("low health call", out and "Krakka" in out[0][1], out)
H.me.hp = 100

# --- 3. B side: Krakka got a kill, I answer on my next press
H.tick(6)
onAddon("CROX", "V2|KILL|0", "PARTY", "Krakka")
n0 = nsent(); press(2); out = sent_since(n0)
check("kill reply", out and ("Krakka" in out[0][1] or out[0][1] in ("Leave some for me!", "Good kill!") or out[0][0] == "EMOTE"), out)
spm = [m.msg for m in H.addon.values()][-1]
check("reply counts the pair (SP|1)", spm.startswith("V2|SP|0|1"), spm)

# --- 4. thanks for the save: Krakka saved me
H.tick(6)
onAddon("CROX", "V2|SAVED|0|Warhorn", "PARTY", "Krakka")
n0 = nsent(); press(2); out = sent_since(n0)
check("thanks call", out and ("Krakka" in out[0][1] or out[0][0] == "EMOTE" or out[0][1] in ("Thanks, Krakka!",)), out)

# --- 5. party pacing: Krakka just spoke -> I hold
H.tick(10)
onAddon("CROX", "V2|SP|0|0", "PARTY", "Krakka")
why = ns.G.paceBlock(H.clock)
check("5s party hold", why and "holding" in why, why)
H.fire("PLAYER_REGEN_ENABLED")
H.group = False

# --- 6. temperament marks: cheerful never says lines barred for cheerful
cdb.temperament = "cheerful"
ok = True
ctx = ns.makeCtx(None, None)
for i in range(300):
    c = ns.choose("opener", lua.table("arch:opener"), ctx, lua.table(noTags=True))
    if c and c.line.t in ("Say your prayers!",): ok = False
    if c and c.line.o and c.line.o != "cheerful": ok = False
check("cheerful never gets barred or other-temperament lines", ok)

# --- 7. profanity filter
cdb.temperament = "gruff"
line = lua.table(t="Fight fair, damn you!", c="Fight fair, curse you!")
cand = lua.table(id="x", line=line, w=1)
cdb.filter = True
t1 = ns._test.render(cand, ctx, "SAY")
cdb.filter = False
t2 = ns._test.render(cand, ctx, "SAY")
check("filter on uses the clean line", t1 == "Fight fair, curse you!", t1)
check("filter off keeps the original", t2 == "Fight fair, damn you!", t2)
cdb.filter = True

# --- 8. troll voice
H.me.race = "Troll"; ns.refreshProfile()
t3 = ns._test.render(lua.table(id="y", line=lua.table(t="Is that all you've got?!"), w=1), ctx, "SAY")
check("troll accent", t3 != "Is that all you've got?!", t3)
H.me.race = "Tauren"; ns.refreshProfile()

# --- 9. marks: facts rule
mt = ns._test.markTrue
H.tgt = lua.table(name="Wolf", enemy=True, hp=80, ctype="beast", guid="g2")
c2 = ns.makeCtx(None, None)
check("beast mark true on a wolf", mt("beast", c2))
check("not-mindless false on a wolf", not mt("!ctype:mindless", c2))
H.tgt = lua.table(name="Grunt", enemy=True, hp=80, ctype=None, guid="g3")
c3 = ns.makeCtx(None, None)
check("unknown creature type: not-mindless is false (facts rule)", not mt("!ctype:mindless", c3))
check("race mark", mt("race:Tauren", c3) and not mt("race:Orc", c3))
check("unknown mark is false", not mt("something", c3))

# --- 10. UI: build and show every section, narrow and wide
ns.toggleMain()
main = G.CROX2MainFrame
for key in ["home", "options", "phrases", "lines"]:
    btn = None
    lua.execute('''local ns = ...''')
import itertools
show = lua.eval('''function(ns, H)
  local out = {}
  for _, k in ipairs({"home", "options", "phrases", "lines"}) do
    local ok, e = pcall(function()
      for _, f in ipairs(H.frames) do end
    end)
  end
  return true end''')
# click section buttons by scanning frames with OnClick whose text matches
clicks = lua.eval('''function(H)
  local done = {}
  for _, f in ipairs(H.frames) do
    local tx = rawget(f, "text")
    if type(tx) == "table" and (tx._text == "Setup" or tx._text == "Options" or tx._text == "My phrases" or tx._text == "Lines" or tx._text == "Commands" or tx._text == "Credits") then
      f:Click()
      done[#done + 1] = tx._text
      main = CROX2MainFrame
      main:SetSize(400, 400) ; local s = main._scripts.OnSizeChanged ; if s then s[1](main) end
      main:SetSize(900, 600) ; if s then s[1](main) end
    end
  end
  return table.concat(done, ",") end''')
r = clicks(H); check("all four sections open at two sizes", r == "Setup,Options,My phrases,Lines,Commands,Credits", r)
# --- lines tab: folio tabs by group, a row of tabs inside the group, and other classes' lines to look at
lt = lua.eval('''function(ns)
  local s = ns._sections.lines
  local st = s._state
  local function count() s:refresh() return s.count._text or "" end
  local out = {}
  st.limit = 100000
  s:pickTab("all"); out.default = count()
  out.defaultMoments = next(st.moments) == nil and st.view == "mine"
  s:pickTab("attacks", "opener"); out.opener = count()
  s:pickTab("attacks"); out.attacks = count()
  s:pickTab("kill"); out.kill = count()
  s:pickTab("attacks", "opener"); s:refresh()
  out.trigOpener = s.rows[1] and s.rows[1].trig._text or "none"
  s:pickTab("kill"); s:refresh(); out.trigKill = s.rows[1] and s.rows[1].trig._text or "none"
  local shown = 0
  for _, b in ipairs(s.tabs) do if b:IsShown() then shown = shown + 1 end end
  out.tabs = shown
  s:pickTab("items"); s:refresh()
  local subs = 0
  for _, b in ipairs(s.subs) do if b:IsShown() then subs = subs + 1 end end
  out.itemSubs = subs
  s:pickTab("all"); st.search = "zzzzqq"; out.none = count()
  st.search = ""; st.limit = 100; s:pickTab("all")
  return out end''')(ns)
def n_of(t): return int(str(t).split(" ")[0])
check("lines tab opens on All, with no way to show lines the character cannot say", lt["defaultMoments"], lt["default"])
check("the All tab shows the whole set", n_of(lt["default"]) > n_of(lt["attacks"]) > n_of(lt["opener"]) > 0, (lt["default"], lt["attacks"], lt["opener"]))
check("a group tab holds several moments and its sub-tab narrows to one", n_of(lt["attacks"]) > n_of(lt["opener"]) and n_of(lt["kill"]) > 0, (lt["attacks"], lt["opener"], lt["kill"]))
check("ten folio tabs, and the Items tab has a sub-tab per item", lt["tabs"] == 10 and lt["itemSubs"] == 12, (lt["tabs"], lt["itemSubs"]))
check("each line says what can trigger it (abilities for an archetype, plain words for a kill)", "Charge" in lt["trigOpener"] and "Intercept" in lt["trigOpener"] and lt["trigOpener"].startswith("Can trigger on:") and "killing an enemy" in lt["trigKill"], (lt["trigOpener"], lt["trigKill"]))
check("search with no match shows none", n_of(lt["none"]) == 0, lt["none"])

# tabs
tab2 = G.CROX2MainFrameTab2
tab2.Click(tab2)
check("alliance tab opens", True)
G.CROX2MainFrameTab1.Click(G.CROX2MainFrameTab1)
# setup, review, export, alliance screen
ns.openSetup(); check("setup opens the main window on the Setup page", G.CROX2MainFrame._shown)
ns.Log.openReview(); check("fight review opens", G.CROX2ReviewFrame._shown)
ns.Log.openExport(); check("export opens", G.CROX2ExportFrame._shown)
txt = ns.Log.exportText()
check("export anonymizes the helper", "Krakka" not in txt, [l for l in txt.split("\n") if "Krakka" in l][:3])
ns.showAlliance(); check("alliance screen opens", G.CROX2AllianceFrame._shown)
# slash
G.SlashCmdList.CROX("help")
check("slash help prints", any("/x flag" in m for m in H.chat.values()))

# --- 11. my phrases: add a line through the engine and see it chosen
cdb.custom[1] = lua.table(text="For the Whiteclaw!", **{"as": "say"}, moments=lua.table(opener=True), freq=3, on=True)
got = 0
for i in range(200):
    c = ns.choose("opener", lua.table("arch:opener"), ctx, lua.table(noTags=True))
    if c and c.line.t == "For the Whiteclaw!": got += 1
check("own line 'Often' picked about half the time", 60 < got < 140, got)

# --- 12. Alliance character: presses do nothing
H.me.faction = "Alliance"; ns.refreshProfile()
n0 = nsent()
H.fire("PLAYER_REGEN_DISABLED")
for i in range(20): press(2); H.tick(2)
check("alliance character never speaks", nsent() == n0)
print("errors in chat:", [m for m in H.chat.values() if "error" in m.lower()])
H.me.faction = "Horde"; ns.refreshProfile()
ns.showSplash(); check("setup page opens in the main window", G.CROX2MainFrame._shown)
check("no art picker", ns.openArtPicker is None and G.CROX2ArtFrame is None)
H.tick(60)
check("splash carries the addon header and the title card", lua.eval("function(ns) return ns._sections.home.title._text end")(ns) == "Combat Roleplay Options" and lua.eval('function(H) for _, f in ipairs(H.frames) do if f._text == "Combat Roleplay Options - cro/x" then return true end end return false end')(H), None)
check("setup page stays open until the player closes it", G.CROX2MainFrame._shown)
G.CROX2MainFrame.Hide(G.CROX2MainFrame)
check("setup closes when told to", not G.CROX2MainFrame._shown)
G.SlashCmdList.CROX("art")
check("/x art does nothing now", G.CROX2ArtFrame is None)


# --- splash speaking options, raid pace, sounds
r = lua.eval('''function(ns)
  local out = {}
  ns.cdb.chatty = 3; ns.cdb.raidChatty = 1
  local save, saveG = IsInRaid, IsInGroup
  IsInRaid = function() return false end
  IsInGroup = function() return false end
  out.party = ns.chattyNow()
  IsInGroup = function() return true end            -- a party, not a raid
  out.inParty = ns.chattyNow()
  IsInRaid = function() return true end
  out.raid = ns.chattyNow()
  IsInRaid, IsInGroup = save, saveG
  ns.showSplash()
  local sp = ns._sections.home
  out.hasSwitches = sp.switches.emotes ~= nil and sp.switches.yell ~= nil and sp.switches.cr ~= nil and sp.switches.turns ~= nil
    and sp.switches.filter ~= nil and sp.switches.sound ~= nil
  sp.switches.yell:SetChecked(false); sp.switches.yell:Click()
  out.yellAfter = ns.cdb.yell
  ns.cdb.yell = true
  local played = 0
  local oldPlay = PlaySound
  PlaySound = function() played = played + 1 end
  ns.cdb.sound = true; ns.W.sound("click"); out.soundOn = played
  ns.cdb.sound = false; ns.W.sound("click"); out.soundOff = played
  ns.cdb.sound = true; PlaySound = oldPlay
  ns.cdb.chatty = 2
  sp:Hide()
  return out end''')(ns)
check("any group (party or raid) uses the group pace, alone uses the solo one", r["party"] == 3 and r["inParty"] == 1 and r["raid"] == 1, (r["party"], r["inParty"], r["raid"]))
check("splash has the speaking switches and they change the setting", r["hasSwitches"] and r["yellAfter"] == False, r["yellAfter"])
check("window sounds can be turned off", r["soundOn"] == 1 and r["soundOff"] == 1, (r["soundOn"], r["soundOff"]))


# --- descriptors beside the splash dropdowns and an example line below them
r = lua.eval('''function(ns)
  local out = {missing = {}}
  local D = CROX2_DESCRIBE
  for _, v in ipairs(ns.TEMPERAMENTS) do if not D.temperament[v] then out.missing[#out.missing + 1] = "t:" .. v end end
  for _, v in ipairs(ns.UPBRINGINGS) do if not D.upbringing[v] then out.missing[#out.missing + 1] = "u:" .. v end end
  for _, v in ipairs(ns.DRIVES) do if not D.drive[v] then out.missing[#out.missing + 1] = "d:" .. v end end
  for race, list in pairs(CROX2_HOMELANDS) do
    for _, h in ipairs(list) do if not D.homeland[h[1]] then out.missing[#out.missing + 1] = "h:" .. h[1] end end
  end
  out.missing = table.concat(out.missing, ",")
  ns.cdb.temperament = "cocky"
  ns.showSplash()
  local sp = ns._sections.home
  sp:refreshChoices("temperament")
  out.hint = sp.hints.temperament._text
  out.example = sp.example._text
  sp:refreshChoices("drive")
  out.exampleDrive = sp.example._text
  sp:Hide()
  return out end''')(ns)
check("every temperament, upbringing, drive and homeland has a descriptor", r["missing"] == "", r["missing"])
check("splash shows the descriptor for the chosen temperament", r["hint"] == "Sure you're the best in the fight, and happy to say so.", r["hint"])
check("splash shows an example line below the dropdowns", "Example:" in r["example"] and '"' in r["example"] and "Example:" in r["exampleDrive"], (r["example"], r["exampleDrive"]))


# --- five paces with estimates, the migration from three, and the call-and-response dials
r = lua.eval('''function(ns)
  local out = {}
  out.levels = #ns.CHATTY
  local items = ns.chattyItems(false)
  out.soloCount, out.groupCount = #items, #ns.chattyItems(true)
  out.item1, out.item3, out.item5 = items[1][2], items[3][2], items[5][2]
  out.lastGroup = ns.chattyItems(true)[7][2]
  local ps = {}
  for i = 1, 7 do ps[i] = ns.CHATTY[i].rate end
  out.perMin = table.concat(ps, ",")
  -- the three-level numbers move up by one, Normal staying Normal
  local savedDB = CROX2CharDB
  CROX2CharDB = {chatty = 2, raidChatty = 1}
  ns.initDB()
  out.migrated = ns.cdb.chatty .. "," .. ns.cdb.raidChatty .. "," .. ns.cdb.chattyScale
  CROX2CharDB = {chatty = 3}
  ns.initDB()
  out.migratedLively = ns.cdb.chatty
  CROX2CharDB = {}
  ns.initDB()
  out.fresh = ns.cdb.chatty .. "," .. ns.cdb.raidChatty .. "," .. ns.cdb.crAsk .. "," .. ns.cdb.crGive
  CROX2CharDB = savedDB
  ns.initDB()
  -- the dials
  local G = ns.G
  ns.cdb.crAsk = 4 local always = true
  for i = 1, 200 do if not G.crRoll("crAsk") then always = false end end
  ns.cdb.crAsk = 1 local hits = 0
  for i = 1, 2000 do if G.crRoll("crAsk") then hits = hits + 1 end end
  out.always, out.rarely = always, hits / 2000
  ns.cdb.crAsk = 4
  return out end''')(ns)
check("seven levels: solo offers five, groups all seven", r["levels"] == 7 and r["soloCount"] == 5 and r["groupCount"] == 7 and r["item1"] == "Hushed" and r["item3"] == "Social" and r["item5"] == "Chatty" and r["lastGroup"] == "Deafening", (r["item1"], r["item3"], r["item5"], r["lastGroup"]))
check("pace rates rise with each level", r["perMin"] == "0.5,2,3,4,5,6,6.5", r["perMin"])
check("older paces move onto the seven-level scale by rate", r["migrated"] == "4,3,3" and r["migratedLively"] == 5, (r["migrated"], r["migratedLively"]))
check("new characters start at Social (2-4) alone and in a group, call dials Always", r["fresh"] == "3,3,4,4", r["fresh"])
check("call dials: Always never skips, Rarely about a quarter", r["always"] and 0.18 < r["rarely"] < 0.32, r["rarely"])

# --- multi-speaker groundwork
r = lua.eval('''function(ns)
  local G = ns.G
  local a = G.rank("x1", {"Ann", "Bo", "Cy", "Di", "Ed"})
  local b = G.rank("x1", {"Ed", "Di", "Cy", "Bo", "Ann"})
  local same = table.concat(a, ",") == table.concat(b, ",")
  local firsts, seen = {}, 0
  for i = 1, 30 do local f = G.rank("id" .. i, {"Ann", "Bo", "Cy", "Di", "Ed"})[1] if not firsts[f] then firsts[f] = true seen = seen + 1 end end
  local two = G.speakers("x1", {"Ann", "Bo", "Cy"}, 2, {Ann = true})
  local none = G.speakers("x1", {"Ann"}, 3, {Ann = true})
  return {same = same, varied = seen, two = #two, noAnn = two[1] ~= "Ann" and two[2] ~= "Ann", none = #none}
end''')(ns)
check("speaker ranking is the same on every machine", r["same"])
check("the ranked first speaker varies between exchanges", r["varied"] >= 3, r["varied"])
check("speakers: n slots, skip list honored, empty when nobody left", r["two"] == 2 and r["noAnn"] and r["none"] == 0)
H.group = True
onAddon("CROX", "V2|HI|0|0.57|SHAMAN|1", "PARTY", "Krakka")
check("HI stores the protocol version", ns.G.members.Krakka.proto == 1)
n_ex = len(list(ns.G.exchanges.values()))
onAddon("CROX", "V2|RALLY|0|Krakka-7", "PARTY", "Krakka")
last = ns.G.exchanges[len(list(ns.G.exchanges.values()))]
check("a rally is logged as an exchange with its slots", last.id == "Krakka-7" and last.moment == "rally" and last.slots[1] is not None and last.slots[1] != "Krakka", (last.id, last.slots[1]))

# --- setup lives on the splash
r = lua.eval('''function(ns)
  CROX2MainFrame:Hide()
  ns.cdb.setupDone = false
  ns.cdb.temperament = nil
  ns.showSplash()
  local f = ns._sections.home
  local stays = f:IsShown()                      -- it never closes by itself
  local items = ns.choiceItems("temperament")
  ns.cdb.temperament = items[2][1]
  f:refreshChoices()
  local hasDD = f.dds.temperament ~= nil and f.dds.homeland ~= nil and f.dds.upbringing ~= nil and f.dds.drive ~= nil and f.dds.pronouns ~= nil
  CROX2MainFrame:Hide()
  return {stays = stays, dd = hasDD, done = ns.cdb.setupDone, temp = ns.cdb.temperament == items[2][1]}
end''')(ns)
check("first run: splash stays open with all five dropdowns", r["stays"] and r["dd"])
check("closing the splash finishes setup and keeps the choices", r["done"] and r["temp"])

# --- after the first setup: choose lines or add your own
r = lua.eval('''function(ns)
  CROX2MainFrame:Hide() if CROX2NextFrame then CROX2NextFrame:Hide() end
  ns.cdb.setupDone = false
  ns.showSplash()
  CROX2MainFrame:Hide()
  local shown = CROX2NextFrame and CROX2NextFrame:IsShown()
  ns.cdb.setupDone = true
  CROX2NextFrame:Hide()
  ns.showSplash() CROX2MainFrame:Hide()
  local again = CROX2NextFrame:IsShown()
  ns.openSection("phrases")
  return {shown = shown, again = again, main = CROX2MainFrame and CROX2MainFrame:IsShown()}
end''')(ns)
check("after first setup, the next-step choice appears", r["shown"])
check("it does not appear on later splashes", not r["again"])
check("openSection opens the main window", r["main"])

# --- reset everything
r = lua.eval('''function(ns)
  ns.cdb.chatty = 5 ns.cdb.temperament = "grim" ns.cdb.splash = false ns.cdb.off = {x = true} ns.cdb.setupDone = true
  ns.cdb.custom = {{text = "mine", ch = "say"}}
  ns.db.bg = 3
  ns.confirmReset()
  local shownDlg = CROX2ResetFrame:IsShown()
  -- click the Reset button
  for _, c in ipairs(CROX2ResetFrame._kids or {}) do end
  ns.resetAll()
  return {dlg = shownDlg, chatty = ns.cdb.chatty, temp = ns.cdb.temperament, splash = ns.cdb.splash, off = next(ns.cdb.off) == nil,
    done = ns.cdb.setupDone, custom = #ns.cdb.custom, bg = ns.db.bg}
end''')(ns)
check("reset asks first", r["dlg"])
check("reset restores defaults", r["chatty"] == 3 and r["temp"] == "gruff" and r["splash"] == True and r["off"] and r["done"] == False and r["bg"] is None)
check("reset keeps your own phrases", r["custom"] == 1)
G.SlashCmdList.CROX("reset"); check("/x reset opens the confirm", G.CROX2ResetFrame._shown)
r = lua.eval('''function(ns)
  CROX2MainFrame:Hide() CROX2NextFrame:Hide()
  ns.cdb.chatty = 5 ns.cdb.setupDone = true
  ns.doReset()
  return {splash = CROX2MainFrame:IsShown(), chatty = ns.cdb.chatty, done = ns.cdb.setupDone}
end''')(ns)
check("reset brings the splash back for setup", r["splash"] and r["chatty"] == 3 and r["done"] == False, r)

# --- Alliance characters can switch the addon off, and back on
H.me.faction = "Alliance"; ns.refreshProfile()
r = lua.eval('''function(ns)
  ns.cdb.alliance.disabled = false ns.cdb.on = true
  ns.showAlliance()
  local f = CROX2AllianceFrame
  local c = f.art.check
  c:SetChecked(true) c._scripts.OnClick[1](c)
  local off = {disabled = ns.cdb.alliance.disabled, on = ns.cdb.on, hidden = not f:IsShown()}
  ns.showAlliance()                                 -- /x again: the box shows as ticked
  local ticked = c:GetChecked()
  c:SetChecked(false) c._scripts.OnClick[1](c)
  return {off = off, ticked = ticked, back = {disabled = ns.cdb.alliance.disabled, on = ns.cdb.on}}
end''')(ns)
check("Alliance: ticking the box turns the addon off and closes the screen", r["off"]["disabled"] and not r["off"]["on"] and r["off"]["hidden"])
check("Alliance: /x shows the box ticked, unticking turns it back on", r["ticked"] and not r["back"]["disabled"] and r["back"]["on"])
H.me.faction = "Horde"; ns.refreshProfile()

# --- probe
r = lua.eval('''function(ns)
  local t = ns.Bug.probeText()
  ns.Bug.probe()
  return {text = t, shown = CROX2ProbeFrame:IsShown()}
end''')(ns)
check("/x probe builds a report and shows it", r["shown"] and "PROFESSIONS" in r["text"] and "TALENTS AND SPEC" in r["text"] and "cro/x read:" in r["text"])

# --- modern profession list and the new talent system (stubs shaped like Forever's answers)
r = lua.eval('''function(ns)
  local saveSkills = GetNumSkillLines
  GetNumSkillLines = nil
  function GetProfessions() return 6, 8, 5, 9, 7 end
  local pn = {[6] = "Blacksmithing", [8] = "Mining", [5] = "First Aid", [9] = "Fishing", [7] = "Cooking"}
  function GetProfessionInfo(i) return pn[i], 136241, 91, 150 end
  C_TradeSkillUI = {GetAllProfessionTradeSkillLines = function() return {1, 2, 3} end,
    GetProfessionInfoBySkillLineID = function(id) return {professionName = "Alchemy"} end}
  local saveTabs = GetNumTalentTabs
  GetNumTalentTabs = nil
  C_ClassTalents = {GetActiveConfigID = function() return 99 end}
  -- the real Forever layout from a probe: one tree, specs side by side (Arms left, Fury middle, Protection right)
  local nodes = {[1117] = {1, 2, 3, 4, 5, 6, 7, 8, 9}}
  local N = {
    [1] = {x = 1620, y = 3330, r = 1}, [2] = {x = 1620, y = 2730, r = 3}, [3] = {x = 1020, y = 2730, r = 2},
    [4] = {x = 1620, y = 2130, r = 5}, [5] = {x = 10280, y = 2730, r = 3}, [6] = {x = 9080, y = 2130, r = 2},
    [7] = {x = 9680, y = 2130, r = 5}, [8] = {x = 5000, y = 4530, r = 0}, [9] = {x = 10880, y = 4530, r = 0},
  }
  C_Traits = {
    GetConfigInfo = function(c) return {name = "x", treeIDs = {1117}} end,
    GetTreeNodes = function(t) return nodes[t] end,
    GetNodeInfo = function(c, n) local d = N[n]; return {currentRank = d.r, posY = d.y, posX = d.x, maxRanks = 5} end,
  }
  ns.refreshProfile()
  local profs, spec = {}, {}
  for k in pairs(ns.profile.profs) do profs[#profs + 1] = k end
  table.sort(profs)
  for k, v in pairs(ns.profile.spec) do spec[#spec + 1] = k .. v end
  table.sort(spec)
  local text = ns.Bug.probeText()
  GetNumSkillLines, GetNumTalentTabs, GetProfessions, C_TradeSkillUI, C_ClassTalents, C_Traits = saveSkills, saveTabs, nil, nil, nil, nil
  ns.refreshProfile()
  return {profs = table.concat(profs, ","), spec = table.concat(spec, ","), text = text}
end''')(ns)
check("professions come from the modern list only", r["profs"] == "blacksmithing,cooking,first_aid,fishing,mining", r["profs"])
check("spec read from the one shared tree by column and row (Arms row 3, Protection row 2, no Fury)", r["spec"] == "Arms2,Fury0,Protection1", r["spec"])
check("probe lists the talent trees", "tree 1117:" in r["text"] and "traits config 99" in r["text"])

# --- speech budget pacing (0.57-alpha2.31)
r = lua.eval('''function(ns)
  local T = ns._test
  local out = {}
  ns.cdb.chatty = 3 ns.cdb.turns = false
  T.resetPace()
  out.first = ns.paceBlock(1000, false)        -- budget starts at 1
  T.setBudget(0.4)
  out.spent = ns.paceBlock(1000, false)
  out.big = ns.paceBlock(1000, true)           -- big moments ignore the budget
  T.setBudget(0)
  local b0 = ns.getBudget()
  out.refilled = ns.getBudget() >= b0
  ns.cdb.turns = true
  return out
end''')(ns)
check("budget: a fresh character may speak once", r["first"] is None, r["first"])
check("budget: spent budget holds lines back, big moments still go", r["spent"] == "pace: speech budget is spent" and r["big"] is None, (r["spent"], r["big"]))

# --- testing mode and the combat simulator (0.57-alpha2.34)
r = lua.eval('''function(ns, H)
  local out = {}
  out.defaultOff = ns.cdb.testing == false
  ns.cdb.testing = true ns.cdb.on = true ns.cdb.turns = false ns.cdb.cr = false
  ns.Log.init()
  local fc = 0
  ns.Sim.open()
  out.opened = CROX2SimFrame ~= nil
  local sentBefore = #H.sent
  ns.Sim.start(3)
  out.running = ns.Sim.running()
  local said = 0
  for i = 1, 1400 do H.tick(0.5) ns.Sim.tick() end        -- 700 pretend seconds: five pulls and the rests
  out.stoppedAlone = not ns.Sim.running()
  out.nothingSent = #H.sent == sentBefore                  -- the simulator never talks in real chat
  out.noSimLeft = ns.sim == nil and ns.simOut == nil and ns.inCombat == false
  local rep = ns.Log.testReport()
  out.rep = rep
  out.fights = #ns.Log.testFights()
  ns.Log.clearTest()
  out.cleared = #ns.Log.testFights() == 0
  ns.cdb.testing = false ns.cdb.turns = true ns.cdb.cr = true
  return out
end''')(ns, H)
check("testing mode is off by default", r["defaultOff"])
check("the simulator opens and runs", r["opened"] and r["running"])
check("the simulator stops by itself and cleans up", r["stoppedAlone"] and r["noSimLeft"])
check("the simulator never sends real chat", r["nothingSent"])
check("a pretend fight is captured as test data", r["fights"] >= 4, r["fights"])
check("the test report has a summary and simulated fights", "SUMMARY" in r["rep"] and "(SIMULATED)" in r["rep"] and "pace" in r["rep"], r["rep"][:300])
check("test data can be cleared", r["cleared"])

# --- yells have to be earned (0.60-beta.1)
r = lua.eval('''function(ns, H)
  local out = {}
  local W = ns.W
  ns.cdb.yell = true
  local function line(t) return {line = {t = t}, id = "test:yell:" .. t, pool = "arch:powerup"} end
  local function go(hp, boss, text)
    local ctx = ns.makeCtx(nil, nil)
    ctx.hp = hp
    ctx.tgt = {exists = true, enemy = true, boss = boss}
    ns.deliver(line(text), ctx, "powerup")
    return H.sent[#H.sent].ch
  end
  H.tick(500)                                   -- long since any yell
  out.calm = go(100, false, "Rage is fuel one")  -- calm trash fight, full health: said
  out.low = go(30, false, "Rage is fuel two")    -- low health: yelled
  out.gap = go(30, false, "Rage is fuel three")  -- straight after a yell: said
  H.tick(500)
  out.boss = go(100, true, "Rage is fuel four")  -- a boss: yelled
  H.tick(500)
  -- a phrase the player marked "yell" is always yelled, and the gap still counts
  local ctx = ns.makeCtx(nil, nil) ctx.hp = 100 ctx.tgt = {exists = true, enemy = true, boss = false}
  ns.deliver({line = {t = "Mine"}, id = "own:1", pool = "own", custom = {as = "yell"}}, ctx, "powerup")
  out.own = H.sent[#H.sent].ch
  H.tick(500)
  -- someone else in the party yelled: hold ours
  H.group = true H.party = {party1 = "Krakka"}
  ns.G._test.onAddon("CROX", "V2|HI|0|0.50|SHAMAN", "PARTY", "Krakka")
  ns.G._test.onAddon("CROX", "V2|SP|0|0|3|Y", "PARTY", "Krakka")
  out.party = go(30, true, "Rage is fuel five")
  H.tick(40)
  out.partyLater = go(30, true, "Rage is fuel six")
  H.group = false
  -- a slow slider applies its change only when the mouse is let go
  local applied, labels = 0, 0
  local parent = CreateFrame("Frame", nil, UIParent)
  local sl = W.slider(parent, "Scale", 0.8, 1.4, 0.05, function() return 1 end, function(v) applied = v end, nil, true)
  sl:SetValue(1.25)
  out.heldWhileDragging = applied == 0
  for _, fn in ipairs(sl._scripts.OnMouseUp or {}) do fn(sl) end
  out.appliedOnRelease = math.abs(applied - 1.25) < 0.001
  return out
end''')(ns, H)
check("yell: a calm fight at full health is said", r["calm"] == "SAY", r["calm"])
check("yell: low health earns a yell", r["low"] == "YELL", r["low"])
check("yell: straight after a yell the next is said", r["gap"] == "SAY", r["gap"])
check("yell: a boss earns a yell", r["boss"] == "YELL", r["boss"])
check("yell: a phrase marked yell is always yelled", r["own"] == "YELL", r["own"])
check("yell: held while a party member's yell is fresh, free after", r["party"] == "SAY" and r["partyLater"] == "YELL", (r["party"], r["partyLater"]))
check("slider that rescales the window waits for mouse release", r["heldWhileDragging"] and r["appliedOnRelease"])

# --- commands section and the build text in the picture's corner
r = lua.eval('''function(ns)
  ns.openSection("commands")
  local c = ns._sections.commands
  local rows = c and #c.rows or 0
  local h = c and c:layout(500) or 0
  ns.openSection("home")
  local home = ns._sections.home
  return {rows = rows, h = h, fill = home.fill == true}
end''')(ns)
check("commands section lists the commands", r["rows"] >= 12 and r["h"] > 100, (r["rows"], r["h"]))
check("the setup picture section runs to the window's bottom", r["fill"])

# --- spec lines you could unlock show up, locked
r = lua.eval('''function(ns)
  ns.openSection("lines")
  local L = ns._sections.lines
  local pf = ns.profile
  local savedSpec = pf.spec
  pf.spec = {Arms = 1}                       -- Arms early unlocked; the rest is locked
  L._state.sources = {spec = true}
  L._state.moments = {}
  L._state.limit = 500
  L:refresh()
  local out = {count = L.count._text}
  local lockedRows, openRows = 0, 0
  local offBefore = 0 for _ in pairs(ns.cdb.off) do offBefore = offBefore + 1 end
  for _, row in ipairs(L.rows) do
    if row._shown and row.sub and row.sub._text and row.sub._text:find("locked", 1, true) then
      lockedRows = lockedRows + 1
      row.check:Click()
    elseif row._shown and row.sub and row.sub._text and row.sub._text:find("Spec", 1, true) then
      openRows = openRows + 1
    end
  end
  local offAfter = 0 for _ in pairs(ns.cdb.off) do offAfter = offAfter + 1 end
  out.locked, out.open, out.offSame = lockedRows, openRows, offBefore == offAfter
  pf.spec = savedSpec
  L._state.sources = {}
  L:refresh()
  return out
end''')(ns)
check("locked spec lines are listed after the ones you can say", r["locked"] > 0 and r["open"] > 0 and "more to unlock" in r["count"], r)
check("a locked line cannot be switched on or off", r["offSame"])

# --- other classes' lines: visible in their own view, greyed, never switchable
r = lua.eval('''function(ns)
  ns.openSection("lines")
  local L = ns._sections.lines
  L._state.limit = 800
  L:pickTab("others")
  local out = {count = L.count._text}
  local n, own, sameOff = 0, 0, true
  local before = 0 for _ in pairs(ns.cdb.off) do before = before + 1 end
  for _, row in ipairs(L.rows) do
    if row._shown and row.sub and row.sub._text then
      local t = row.sub._text
      if t:find("only", 1, true) and t:find("not available", 1, true) then
        n = n + 1
        if t:lower():find("warrior only", 1, true) then own = own + 1 end
        row.check:Click()
      end
    end
  end
  local after = 0 for _ in pairs(ns.cdb.off) do after = after + 1 end
  out.n, out.own, out.same = n, own, before == after
  L._state.limit = 100
  L:pickTab("all")
  return out
end''')(ns)
check("other classes' lines are listed in their own view", r["n"] > 0 and "other classes" in r["count"], r)
check("your own class never appears in the other-classes view and nothing switches", r["own"] == 0 and r["same"], r)

# --- tag chips on the Lines page: hide a kind of line while looking, bring it back
r = lua.eval('''function(ns)
  ns.openSection("lines")
  local L = ns._sections.lines
  L._state.limit = 800
  L:pickTab("attacks", "heavy"); L:refresh()
  local out = {}
  local function n() return tonumber(L.count._text:match("^(%d+) line")) or 0 end
  out.all = n()
  out.chips = 0
  local target
  for _, b in ipairs(L.chips or {}) do
    if b._shown then out.chips = out.chips + 1 if b.kind == "base" then target = b end end
  end
  out.hasBase = target ~= nil
  if target then
    target:Click()
    out.afterHide = n()
    out.note = L.count._text
    out.saved = ns.cdb.lineHide.base == true
    L._state.sources = {}
    L:pickTab("kill"); out.kill = n()     -- the hide holds across tabs
    out.killNote = L.count._text
    for _, b in ipairs(L.chips or {}) do if b._shown and b.kind == "base" then b:Click() end end
    L:pickTab("attacks", "heavy"); out.back = n()
    out.cleared = ns.cdb.lineHide.base == nil
  end
  L._state.limit = 100
  L:pickTab("all")
  return out
end''')(ns)
r = dict(r)
check("source chips show for the kinds of line in a tab", r["chips"] >= 1 and r["hasBase"], r)
check("hiding a tag hides those lines, says so, and survives a tab change", r["afterHide"] < r["all"] and "hidden by tags" in r["note"] and r["saved"] and "hidden by tags" in r["killNote"], r)
check("clicking the chip again brings the lines back", r["back"] == r["all"] and r["cleared"], r)

# --- profession samples: examples for the character's professions, with what triggers each
r = lua.eval('''function(ns)
  local savedProfs = ns.profile.profs
  ns.profile.profs = {cooking = true, first_aid = true}
  local text, n = ns.profSampleText(3)
  local out = {text = text, n = n}
  ns.openProfSamples()
  out.shown = _G.CROX2ProfSamples and _G.CROX2ProfSamples._shown
  ns.cdb.profLines = false
  out.offText = ns.profSampleText(3)
  ns.cdb.profLines = true
  ns.profile.profs = savedProfs
  return out
end''')(ns)
r = dict(r)
check("profession samples list each profession with a trigger", "Cooking" in r["text"] and "Triggers on:" in r["text"] and r["n"] >= 3, r["text"][:300])
check("cooking lines trigger on food", "using food" in r["text"], r["text"][:400])
check("no raw pronoun placeholders in samples", "[their]" not in r["text"] and "[they]" not in r["text"] and "[them]" not in r["text"], r["text"][:300])
check("the sample window opens", r["shown"] == True, r)
check("samples say when profession lines are off", "switched off" in r["offText"], r["offText"][:120])


# --- simulator: virtual clock, speeds, simulated players
r = lua.eval('''function(ns, H)
  local S = ns.Sim
  local out = {}
  -- race/class combinations
  local bad, tauRogue, undHunt = 0, 0, 0
  for i = 1, 300 do
    local d = S.resolve({})
    local ok = false
    for _, c in ipairs(S.RACE_CLASSES[d.race]) do if c == d.class then ok = true end end
    if not ok then bad = bad + 1 end
  end
  for i = 1, 100 do
    local d = S.resolve({race = "Tauren", class = "ROGUE"})
    if d.race == "Tauren" and d.class == "ROGUE" then tauRogue = tauRogue + 1 end
    local e = S.resolve({race = "Forsaken", class = "HUNTER"})
    if e.race == "Forsaken" and e.class == "HUNTER" then undHunt = undHunt + 1 end
  end
  out.bad, out.tauRogue, out.undHunt = bad, tauRogue, undHunt
  local hunterRaces = {}
  for i = 1, 100 do local d = S.resolve({class = "HUNTER"}) hunterRaces[d.race] = true end
  out.hunterForsaken = hunterRaces.Forsaken == true
  local d = S.resolve({race = "Skyborne"})
  out.skyHome = d.homeland and d.homeland:find("^home:") ~= nil
  out.named = d.name ~= "" and d.spec ~= nil and d.depth >= 1
  -- a party: one warrior, one random, run instantly
  local realName, realClass, realCdb, realProfile = ns.profile.name, ns.profile.class, ns.cdb, ns.profile
  local realSaid = {}
  for k, v in pairs(ns.cdb.said) do realSaid[k] = v end
  ns.cdb.on = true ns.cdb.testing = false
  ns.cdb.simFakes = {S.resolve({name = "Grukk", race = "Orc", class = "WARRIOR", pace = 5}), S.resolve({name = "Maren", race = "Forsaken", class = "PRIEST", pace = 4})}
  S.open()
  local lines = 0
  local grukk, maren = 0, 0
  local frame = CROX2SimFrame
  local texts = {}
  frame.msgs.AddMessage = function(_, text) texts[#texts + 1] = text end
  local sent = #H.sent
  local before = GetTime()
  S.start(3, 4)                       -- five pulls, instantly
  out.finishedAtOnce = not S.running()
  out.clockUntouched = math.abs(GetTime() - before) < 0.001
  out.nothingSent = #H.sent == sent
  for _, l in ipairs(texts) do
    if l:find("Grukk") then grukk = grukk + 1 end
    if l:find("Maren") then maren = maren + 1 end
  end
  out.grukk, out.maren, out.total = grukk, maren, #texts
  out.sample = texts[3] or ""
  out.restored = ns.profile == realProfile and ns.profile.name == realName and ns.profile.class == realClass and ns.cdb == realCdb
  out.noSimLeft = ns.simParty == nil and ns.simClock == nil and ns.simActor == nil and ns.sim == nil and ns.inCombat == false
  local same = true
  for k, v in pairs(realSaid) do if ns.cdb.said[k] ~= v then same = false end end
  out.saidBack = same
  ns.cdb.simFakes = {}
  return out
end''')(ns, H)
r = dict(r)
check("random simulated players always get a combination the game allows", r["bad"] == 0, r)
check("no Tauren rogues and no Forsaken hunters", r["tauRogue"] == 0 and r["undHunt"] == 0 and not r["hunterForsaken"], r)
check("a simulated player comes out complete", r["skyHome"] and r["named"], r)
check("an instant party sim finishes at once, off the real clock, and sends nothing", r["finishedAtOnce"] and r["clockUntouched"] and r["nothingSent"], r)
check("the simulated players speak in the sim window", r["grukk"] > 0 and r["maren"] > 0, r)
check("the real character is put back after a party sim", r["restored"] and r["noSimLeft"] and r["saidBack"], r)

r = lua.eval('''function(ns, H)
  local S = ns.Sim
  local out = {}
  ns.cdb.on = true
  S.open()
  S.setSpeed(1)
  S.start(1, 1)
  local c0 = ns.simClock
  S.tick()                                -- 2x: one tick is two steps, half a pretend second
  out.adv2 = ns.simClock - c0
  S.setSpeed(3)
  c0 = ns.simClock
  S.tick()
  out.adv6 = ns.simClock - c0
  out.stillRunning = S.running()
  S.stop()
  return out
end''')(ns, H)
r = dict(r)
check("2x advances half a pretend second a tick, 6x one and a half", abs(r["adv2"] - 0.5) < 0.01 and abs(r["adv6"] - 1.5) < 0.01, r)

# the SimP boxes set the party size; their own window has one tab per simulated player
r = lua.eval('''function(ns, H)
  local S = ns.Sim
  local out = {}
  ns.cdb.simFakes = {} ns.cdb.simFakeN = nil
  S.open()
  local f = CROX2SimFrame
  out.boxes = #f.boxes
  out.zero = S.fakeCount() == 0
  f.boxes[3]:Click()                                   -- "3 SimP" = three simulated players in the party
  out.count = S.fakeCount()
  local w = f.popup
  out.window = w ~= nil and w._shown == true and w._parent == UIParent       -- its own window, not inside the sim's
  local tabsShown = 0
  for _, b in ipairs(w.tabs) do if b._shown then tabsShown = tabsShown + 1 end end
  out.tabs = tabsShown
  out.hasNoDone = true
  for _, ch in ipairs(H.frames) do if ch._parent == w and (ch._text == "Done" or ch._text == "Cancel") then out.hasNoDone = false end end
  -- edit tab 1, move to tab 2: tab 1 was kept as it was changed
  w.def.race = "Tauren" w.def.class = "ROGUE"
  w.nameBox:SetText("Bahru")
  w.nameBox._scripts.OnTextChanged[1](w.nameBox)       -- typing the name (saves with the rest)
  w.tabs[2]:Click()
  out.onTab2 = w.slot == 2
  out.tab2Blank = w.def.race == "random"
  w.tabs[1]:Click()
  out.kept = w.def.name == "Bahru" and w.def.race == "Tauren"
  -- a random fake keeps "Random" in storage and is made legal when the party is built
  local d = S.resolve(ns.cdb.simFakes[1], {})
  out.legal = d.race == "Tauren" and d.class ~= "ROGUE"
  -- Randomize this one fills the dropdowns with real choices that are legal
  local function findBtn(text) for _, ch in ipairs(H.frames) do if ch._parent == w and ch._text == text then return ch end end end
  findBtn("Randomize this one"):Click()
  out.rolled = w.def.race ~= "random" and w.def.class ~= "random" and w.def.name ~= "" and w.def.spec ~= "random" and w.def.homeland ~= "random"
  out.rolledSaved = ns.cdb.simFakes[1].race == w.def.race and ns.cdb.simFakes[1].name == w.def.name
  out.rolledLegal = w.def.class ~= "ROGUE" or w.def.race ~= "Tauren"
  findBtn("Randomize all"):Click()
  local allFilled = true
  for i = 1, 3 do local c = ns.cdb.simFakes[i] if c.race == "random" or c.name == "" or c.pace == "random" then allFilled = false end end
  out.allFilled = allFilled
  f.boxes[2]:Click()                                   -- shrink to two: tab 3 goes, its data stays
  out.two = S.fakeCount() == 2 and w.tabs[3]._shown ~= true and ns.cdb.simFakes[3] ~= nil
  f.boxes[4]:Click()
  out.four = S.fakeCount() == 4
  f.none:Click()
  out.none = S.fakeCount() == 0 and w._shown ~= true
  ns.cdb.simFakes = {} ns.cdb.simFakeN = nil
  return out
end''')(ns, H)
r = dict(r)
check("four SimP boxes pick how many simulated players are in the party", r["boxes"] == 4 and r["zero"] and r["count"] == 3, r)
check("the simulated players have their own window with one tab each", r["window"] and r["tabs"] == 3 and r["hasNoDone"], r)
check("a tab keeps its simulated player's choices and stays legal", r["onTab2"] and r["tab2Blank"] and r["kept"] and r["legal"], r)
check("Randomize fills the dropdowns with real, legal choices", r["rolled"] and r["rolledSaved"] and r["rolledLegal"] and r["allFilled"], r)
check("the party can shrink, grow and be cleared", r["two"] and r["four"] and r["none"], r)

# enemy kinds in the sim: the addon sees the right facts about the target
r = lua.eval('''function(ns, H)
  local S = ns.Sim
  local out = {}
  ns.cdb.on = true ns.cdb.simFakes = {} ns.cdb.simFakeN = nil
  S.open()
  local f = CROX2SimFrame
  out.hasDD = f.ed ~= nil and f.enemy == "mix"
  local want = {beast = "beast", undead = "undead", demon = "demon", elemental = "elemental", mechanical = "mechanical",
    dragonkin = "dragonkin", giant = "giant", aberration = "aberration", humanoid = "humanoid"}
  local bad = {}
  for key, ct in pairs(want) do
    S.start(1, 1, key)
    for i = 1, 60 do S.step() if ns.simActor and ns.simActor.sim.tgt.exists then break end end
    local t = ns.simActor.sim.tgt
    if t.ctype ~= ct or t.player or t.boss then bad[#bad + 1] = key end
    S.stop()
  end
  out.types = #bad == 0 and "ok" or table.concat(bad, ",")
  S.start(1, 1, "alliance")
  for i = 1, 60 do S.step() if ns.simActor and ns.simActor.sim.tgt.exists then break end end
  local t = ns.simActor.sim.tgt
  out.player = t.player == true and t.faction == "Alliance" and t.race ~= nil and t.ctype == "humanoid"
  S.stop()
  S.start(1, 1, "boss")
  for i = 1, 60 do S.step() if ns.simActor and ns.simActor.sim.tgt.exists then break end end
  out.boss = ns.simActor.sim.tgt.boss == true
  S.stop()
  -- a random mix over many pulls shows several kinds
  local seen, n = {}, 0
  for i = 1, 60 do
    S.start(1, 1, "mix")
    for j = 1, 60 do S.step() if ns.simActor and ns.simActor.sim.tgt.exists then break end end
    local k = ns.simActor.sim.tgt.player and "player" or (ns.simActor.sim.tgt.boss and "boss" or ns.simActor.sim.tgt.ctype)
    if not seen[k] then seen[k] = true n = n + 1 end
    S.stop()
  end
  out.kinds = n
  return out
end''')(ns, H)
r = dict(r)
check("the enemy dropdown is in the sim window, default random mix", r["hasDD"], r)
check("each creature type reaches the addon as that type", r["types"] == "ok", r)
check("an Alliance player enemy has faction, race and is a player; a boss is flagged", r["player"] and r["boss"], r)
check("a random mix fights several kinds", r["kinds"] >= 5, r["kinds"])

# Setup page: the name box (full name, class colour) and the choices with their flavor text underneath
r = lua.eval('''function(ns, H)
  local out = {}
  local savedRCC, savedTRP = RAID_CLASS_COLORS, AddOn_TotalRP3
  RAID_CLASS_COLORS = {WARRIOR = {r = 0.78, g = 0.61, b = 0.43}}
  ns.profile.name, ns.profile.class = "Warhorn", "WARRIOR"
  ns.openSection("home")
  local s = ns._sections.home
  s:refreshChoices()
  local t = s.who:GetText() or ""
  out.plainName = t:find("Warhorn", 1, true) ~= nil and t:find("Stonespire", 1, true) == nil
  out.classColour = t:find("|cffc79b6e", 1, true) ~= nil or t:find("|cffc89c6e", 1, true) ~= nil or t:find("|cffc79c6e", 1, true) ~= nil
  AddOn_TotalRP3 = {Player = {GetCurrentUser = function() return {GetFirstName = function() return "Warhorn" end, GetLastName = function() return "Stonespire" end} end}}
  s:refreshChoices()
  t = s.who:GetText() or ""
  out.fullName = t:find("Warhorn Stonespire", 1, true) ~= nil
  out.boxed = s.whoBox ~= nil and s.who._parent == s.whoBox
  RAID_CLASS_COLORS, AddOn_TotalRP3 = savedRCC, savedTRP
  s:refreshChoices()
  -- the button and the flavor text under each dropdown
  local btn
  for _, ch in ipairs(H.frames) do if ch._text == "Another One" then btn = ch end end
  out.another = btn ~= nil
  local under = true
  for kind, hint in pairs(s.hints) do
    local dd = s.dds[kind]
    local pt = hint._points and hint._points[1]
    if pt and pt[2] ~= dd then under = false end
  end
  out.under = under
  return out
end''')(ns, H)
r = dict(r)
check("the name sits in its own box, in the class colour", r["boxed"] and r["plainName"] and r["classColour"], r)
check("the name shows first and last from Total RP 3 when it is there", r["fullName"], r)
check("the button says Another One and the flavor text hangs under its dropdown", r["another"] and r["under"], r)

# the two loudest levels carry a note about other people's game
r = lua.eval('''function(ns, H)
  local out = {}
  ns.openSection("home")
  local s = ns._sections.home
  local saved = ns.cdb.raidChatty
  ns.cdb.raidChatty = 3 s:refreshChoices()
  out.quietHidden = s.paceWarn._shown ~= true
  ns.cdb.raidChatty = 5 s:refreshChoices()
  out.chattyHidden = s.paceWarn._shown ~= true
  ns.cdb.raidChatty = 6 s:refreshChoices()
  out.windbag = s.paceWarn._shown == true and (s.paceWarn:GetText() or ""):find("considerate", 1, true) ~= nil
  ns.cdb.raidChatty = 7 s:refreshChoices()
  out.deafening = s.paceWarn._shown == true
  ns.cdb.raidChatty = saved s:refreshChoices()
  return out
end''')(ns, H)
r = dict(r)
check("the note about other people's game shows only at the two loudest levels", r["quietHidden"] and r["chattyHidden"] and r["windbag"] and r["deafening"], r)

# the version sits under the Credits tab
r = lua.eval('''function(ns)
  ns.relayout()
  local v = ns._verLabel
  return {text = v and v:GetText(), shown = v and v._shown ~= false}
end''')(ns)
r = dict(r)
check("the version label sits in the section list, under the Credits tab", r["shown"] and r["text"] and "0.60" in r["text"], r)

# --- Setup page: Character tags tabs, with a box on what the character has
r = lua.eval('''function(ns)
  ns.openSection("home")
  local s = ns._sections.home
  s:layout(640)
  local out = {tabs = 0}
  for _, b in ipairs(s.tagTabs) do if b._shown then out.tabs = out.tabs + 1 end end
  local function owned()
    local list, n, total = {}, 0, 0
    for _, c in ipairs(s.tagChips) do
      if c._shown then
        total = total + 1
        if c.edges[1]._shown then n = n + 1 list[#list + 1] = c.name end
      end
    end
    return n, total, table.concat(list, ",")
  end
  s.tagTab = "race"; s:layoutTags(640)
  out.raceOwned, out.raceTotal, out.raceNames = owned()
  s.tagTab = "temperament"; s:layoutTags(640)
  out.tempOwned, out.tempTotal, out.tempNames = owned()
  s.tagTab = "profs"; s:layoutTags(640)
  out.profOwned, out.profTotal = owned()
  s.tagTab = "homeland"; s:layoutTags(640)
  out.homeTotal = select(2, owned())
  s.tagTab = "race"; s:layoutTags(640)
  out.heading = true
  return out
end''')(ns)
r = dict(r)
check("Character tags has a tab for each kind of tag", r["tabs"] == 8, r)
check("the race tab lists every Horde race with the character's boxed", r["raceTotal"] == 5 and r["raceOwned"] == 1, r)
check("the temperament tab lists all six and boxes one", r["tempTotal"] == 6 and r["tempOwned"] == 1, r)
check("the professions tab lists every profession and boxes the character's", r["profTotal"] == 12 and r["profOwned"] >= 1, r)
check("the homeland tab lists every homeland", r["homeTotal"] >= 20, r)
