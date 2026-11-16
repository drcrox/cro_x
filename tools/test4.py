# Beta tools: error catcher, /x bug report, /x test
import lupa.lua51 as L, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
lua = L.LuaRuntime(unpack_returned_tuples=True)
D = os.path.join(HERE, "..", "CROX") + "/"
# a stand-in error handler chain, to prove the catcher passes errors on
lua.execute('''
HANDLED = {}
local cur = function(e) table.insert(HANDLED, e) end
function geterrorhandler() return cur end
function seterrorhandler(f) cur = f end
function CALLHANDLER(e) return cur(e) end
function GetBuildInfo() return "1.15.7", "63912", "Nov 1 2026", 11507 end
''')
H = lua.execute(open(os.path.join(HERE, "harness.lua")).read())
lua.globals().H = H
lua.execute("math.randomseed(3)")
ns = lua.table()
toc = [l.strip() for l in open(D + "CROX.toc") if l.strip() and not l.startswith("#")]
for fn in toc:
    lua.eval("function(src, name) local f, e = loadstring(src, name) if not f then error(e) end return f end")(open(D + fn).read(), fn)("CROX", ns)
G = lua.globals()
H.fire("ADDON_LOADED", "CROX"); H.fire("PLAYER_LOGIN")
cdb = G.CROX2CharDB; cdb.setupDone = True; cdb.temperament = "gruff"
press = lua.eval("function(s) local ok, e = pcall(UseAction, s) if not ok then error(e) end end")
def check(name, cond, info=""):
    print(("PASS " if cond else "FAIL ") + name, info if not cond or info else "")
def chat(): return [str(c) for c in H.chat.values()]
slash = lambda m: G.SlashCmdList["CROX"](m)

# 1. error catcher: a cro/x error is noted once, a stranger's error is not, and both reach the old handler
G.CALLHANDLER("Interface\\AddOns\\CROX\\Core.lua:123: attempt to index nil")
G.CALLHANDLER("Interface\\AddOns\\Other\\Thing.lua:5: boom")
check("catcher counts only cro/x errors", ns.Bug.errorCount() == 1, ns.Bug.errorCount())
check("old handler still gets every error", len(list(G.HANDLED.values())) == 2)
told = [c for c in chat() if "hit a snag" in c]
check("one chat line points to /x bug", len(told) == 1 and "/x bug" in told[0], told)
G.CALLHANDLER("Interface\\AddOns\\CROX\\Core.lua:123: attempt to index nil")
check("same error again: counted, not announced twice", ns.Bug.errorCount() == 2 and len([c for c in chat() if "hit a snag" in c]) == 1)

# 2. an error inside the button hook is caught
orig = ns.isAlliance
ns.isAlliance = lua.eval('function() error("kaboom in the engine") end')
before = ns.Bug.errorCount()
try: press(2)
except Exception as e: pass
ns.isAlliance = orig
check("press-hook errors are captured", ns.Bug.errorCount() > before, ns.Bug.errorCount())

# 3. play a fight, then build reports
H.tgt = lua.table(name="Razormane Hunter", enemy=True, hp=100, ctype="humanoid", guid="g1")
H.fire("PLAYER_REGEN_DISABLED")
for i in range(14):
    press(2 + i % 5); H.tick(1.6)
H.fire("PLAYER_REGEN_ENABLED")
rep = str(ns.Bug.report("wording", "this line felt wrong " * 12, True))
check("report fits Discord's limit", len(rep) <= 2000, len(rep))
check("report names version, game build, reason", "0.61-beta" in rep and "1.15.7" in rep and "awkward" in rep)
check("report includes the last error", "last error" in rep and "kaboom in the engine" in rep)
check("report includes the last fight", "last fight" in rep and "Warhorn" in rep)
rep2 = str(ns.Bug.report("silent", "", False))
check("fight section can be left out", "last fight" not in rep2)
check("report never holds the email or character name", "sales@" not in rep and "virtuecraft" not in rep.lower())
# a huge error and note still fit
for i in range(6): G.CALLHANDLER("Interface\\AddOns\\CROX\\X%d.lua:1: " % i + "z" * 900)
big = str(ns.Bug.report("error", "n" * 400, True))
check("worst case still under the limit", len(big) <= 2000, len(big))

# 4. the window opens, updates, and the slash commands work
slash("bug")
f = G.CROX2BugFrame
check("/x bug opens the window", f is not None and f.IsShown(f))
check("window shows a character count", "/ 2000" in str(f.count.GetText(f.count)))
f.reason = "chatty"; f.update(f)
check("window re-builds the report when the reason changes", "spoke too much" in str(f.eb.GetText(f.eb)))

# 5. /x test explains quiet presses in plain words
n0 = len(chat())
sent0 = len(list(H.sent.values()))
slash("test")
out = chat()[n0:]
check("/x test prints plain reasons", any("dice said" in l or "too soon" in l or "spoken" in l for l in out), out[:6])
check("/x test mentions the pace and budget", any("Pace" in l and "budget" in l for l in out))
check("/x test mentions errors", any("errors this session" in l for l in out))
check("/x test prints only to your own chat", len(list(H.sent.values())) == sent0)
slash("help")
check("help lists /x bug and /x test", any("/x bug - " in l for l in chat()) and any("/x test - " in l for l in chat()))
