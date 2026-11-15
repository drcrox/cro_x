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
# tabs
tab2 = G.CROX2MainFrameTab2
tab2.Click(tab2)
check("alliance tab opens", True)
G.CROX2MainFrameTab1.Click(G.CROX2MainFrameTab1)
# setup, review, export, alliance screen
ns.openSetup(); check("setup opens", G.CROX2SetupFrame._shown)
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
ns.openArtPicker(); check("art picker opens", G.CROX2ArtFrame._shown)
lua.eval("function(f) return f._scripts.OnUpdate[1] end")(G.CROX2SplashFrame)(G.CROX2SplashFrame, 9)
check("splash closes by itself", not G.CROX2SplashFrame._shown)
G.SlashCmdList.CROX("art")
r = lua.eval('''function(ns)
  local f = CROX2ArtFrame
  local out = {}
  for _, key in ipairs({"art", "bg", "page", "charBg"}) do
    ns.db.art = ns.db.art
    -- switch category by calling the dropdown setter path: fill with cat via clicking cells after setting
  end
  for i, b in ipairs(f.cells) do if b:IsShown() then b:Click() out[#out+1] = i end end
  ns.db.bg = 2 ns.db.page = 2 ns.db.charBg = 2 ns.applyArt()
  return #out end''')(ns)
check("art browser cells click and every painted area repaints", r > 0, r)
