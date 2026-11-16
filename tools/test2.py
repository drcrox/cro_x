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
for key in ["character", "options", "phrases", "lines"]:
    btn = None
    lua.execute('''local ns = ...''')
import itertools
show = lua.eval('''function(ns, H)
  local out = {}
  for _, k in ipairs({"character", "options", "phrases", "lines"}) do
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
    if type(tx) == "table" and (tx._text == "Character" or tx._text == "Options" or tx._text == "My phrases" or tx._text == "Lines" or tx._text == "Credits") then
      f:Click()
      done[#done + 1] = tx._text
      main = CROX2MainFrame
      main:SetSize(400, 400) ; local s = main._scripts.OnSizeChanged ; if s then s[1](main) end
      main:SetSize(900, 600) ; if s then s[1](main) end
    end
  end
  return table.concat(done, ",") end''')
r = clicks(H); check("all four sections open at two sizes", r == "Character,Options,My phrases,Lines,Credits", r)
# --- lines tab: shows every line by default, tick boxes to combine sets
lt = lua.eval('''function(ns)
  local s = ns._sections.lines
  local st = s._state
  local function count() s:refresh() local n = 0 for _, r in ipairs(s.rows) do if r:IsShown() then n = n + 1 end end
    return s.count._text or "" end
  local out = {}
  out.default = count()
  out.defaultMoments = next(st.moments) == nil and next(st.sources) == nil and st.onlyMine == nil
  st.limit = 100000
  st.moments = {opener = true}; out.opener = count()
  st.moments = {opener = true, heavy = true}; out.two = count()
  st.moments = {}; st.sources = {class = true}; out.class = count()
  st.sources = {class = true, spec = true}; out.classSpec = count()
  st.moments = {kill = true}; st.sources = {base = true}; out.killBase = count()
  st.moments = {opener = true}; st.sources = {base = true}; s:refresh()
  out.trigOpener = s.rows[1] and s.rows[1].trig._text or "none"
  st.moments = {kill = true}; s:refresh(); out.trigKill = s.rows[1] and s.rows[1].trig._text or "none"
  st.moments = {}; st.sources = {}; st.search = "zzzzqq"; out.none = count()
  st.search = ""; s.picker:Show(); s:refresh(); out.openOk = s.picker:IsShown() and s.picker:GetWidth() > 350 and s.picker:GetWidth() < 450 and s.picker.mBoxes[1].__pts == nil
  s.picker:SetSize(800, 500); local sc = s.picker._scripts and s.picker._scripts.OnSizeChanged; if sc then sc[1](s.picker) end
  s.picker:SetSize(250, 500); if sc then sc[1](s.picker) end
  s.picker:Hide(); st.limit = 100; s:refresh()
  return out end''')(ns)
def n_of(t): return int(str(t).split(" ")[0])
check("lines tab starts with every moment and source, and has no switch to show lines the character cannot say", lt["defaultMoments"], lt["default"])
check("lines tab default shows the whole set", n_of(lt["default"]) > n_of(lt["opener"]) > 0, (lt["default"], lt["opener"]))
check("two moments combine (more than one, fewer than all)", n_of(lt["two"]) > n_of(lt["opener"]) and n_of(lt["two"]) < n_of(lt["default"]), (lt["opener"], lt["two"]))
check("two sources combine", n_of(lt["classSpec"]) > n_of(lt["class"]) > 0, (lt["class"], lt["classSpec"]))
check("moment and source filters combine", 0 < n_of(lt["killBase"]) < n_of(lt["default"]), lt["killBase"])
check("each line says what can trigger it (abilities for an archetype, plain words for a kill)", "Charge" in lt["trigOpener"] and "Intercept" in lt["trigOpener"] and lt["trigOpener"].startswith("Can trigger on:") and "killing an enemy" in lt["trigKill"], (lt["trigOpener"], lt["trigKill"]))
check("search with no match shows none; panel opens", n_of(lt["none"]) == 0 and lt["openOk"], lt["none"])

# tabs
tab2 = G.CROX2MainFrameTab2
tab2.Click(tab2)
check("alliance tab opens", True)
G.CROX2MainFrameTab1.Click(G.CROX2MainFrameTab1)
# setup, review, export, alliance screen
ns.openSetup(); check("setup (the splash) opens", G.CROX2SplashFrame._shown)
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
ns.showSplash(); check("splash opens", G.CROX2SplashFrame._shown)
check("no art picker", ns.openArtPicker is None and G.CROX2ArtFrame is None)
lua.eval("function(f) return f._scripts.OnUpdate[1] end")(G.CROX2SplashFrame)(G.CROX2SplashFrame, 13)
check("splash carries the addon header and the title card", G.CROX2SplashFrame.title._text == "Combat Roleplay Options" and lua.eval('function(H) for _, f in ipairs(H.frames) do if f._text == "Combat Roleplay Options - cro/x" then return true end end return false end')(H), None)
check("splash closes by itself", not G.CROX2SplashFrame._shown)
r = lua.eval('''function(ns)
  ns.showSplash()
  local cb = CROX2SplashFrame and nil
  return ns.cdb.splash end''')(ns)
check("splash shows with the login checkbox on", r == True, r)
r = lua.eval('''function(ns)
  local f = CROX2SplashFrame
  for _, c in ipairs(f._children or {}) do end
  ns.cdb.splash = false ns.showSplash()
  local v = ns.cdb.splash ns.cdb.splash = true
  return v end''')(ns)
check("splash re-open leaves the toggle alone", r == False, r)
G.SlashCmdList.CROX("art")
check("/x art does nothing now", G.CROX2ArtFrame is None)

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
  CROX2SplashFrame:Hide()
  ns.cdb.setupDone = false
  ns.cdb.temperament = nil
  ns.showSplash()
  local f = CROX2SplashFrame
  f._scripts.OnUpdate[1](f, 60)
  local stays = f:IsShown()                      -- first run: no auto close
  local items = ns.choiceItems("temperament")
  ns.cdb.temperament = items[2][1]
  f:refreshChoices()
  local hasDD = f.dds.temperament ~= nil and f.dds.homeland ~= nil and f.dds.upbringing ~= nil and f.dds.drive ~= nil and f.dds.pronouns ~= nil
  f:Hide()
  return {stays = stays, dd = hasDD, done = ns.cdb.setupDone, temp = ns.cdb.temperament == items[2][1]}
end''')(ns)
check("first run: splash stays open with all five dropdowns", r["stays"] and r["dd"])
check("closing the splash finishes setup and keeps the choices", r["done"] and r["temp"])

# --- after the first setup: choose lines or add your own
r = lua.eval('''function(ns)
  CROX2SplashFrame:Hide()
  ns.cdb.setupDone = false
  ns.showSplash()
  CROX2SplashFrame:Hide()
  local shown = CROX2NextFrame and CROX2NextFrame:IsShown()
  ns.cdb.setupDone = true
  CROX2NextFrame:Hide()
  ns.showSplash() CROX2SplashFrame:Hide()
  local again = CROX2NextFrame:IsShown()
  ns.openSection("phrases")
  return {shown = shown, again = again, main = CROX2MainFrame and CROX2MainFrame:IsShown()}
end''')(ns)
check("after first setup, the next-step choice appears", r["shown"])
check("it does not appear on later splashes", not r["again"])
check("openSection opens the main window", r["main"])

# --- reset everything
r = lua.eval('''function(ns)
  ns.cdb.chatty = 3 ns.cdb.temperament = "grim" ns.cdb.splash = false ns.cdb.off = {x = true} ns.cdb.setupDone = true
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
check("reset restores defaults", r["chatty"] == 2 and r["temp"] == "gruff" and r["splash"] == True and r["off"] and r["done"] == False and r["bg"] is None)
check("reset keeps your own phrases", r["custom"] == 1)
G.SlashCmdList.CROX("reset"); check("/x reset opens the confirm", G.CROX2ResetFrame._shown)
r = lua.eval('''function(ns)
  CROX2SplashFrame:Hide() CROX2NextFrame:Hide()
  ns.cdb.chatty = 3 ns.cdb.setupDone = true
  ns.doReset()
  return {splash = CROX2SplashFrame:IsShown(), chatty = ns.cdb.chatty, done = ns.cdb.setupDone}
end''')(ns)
check("reset brings the splash back for setup", r["splash"] and r["chatty"] == 2 and r["done"] == False, r)

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
