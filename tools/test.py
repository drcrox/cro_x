import lupa.lua51 as L, re, sys, collections
lua = L.LuaRuntime(unpack_returned_tuples=True)
import os
HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, "..", "CROX") + "/"
H = lua.execute(open(os.path.join(HERE, "harness.lua")).read())
lua.globals().H = H
ns = lua.table()
toc = [l.strip() for l in open(D + "CROX.toc") if l.strip() and not l.startswith("#")]
for fn in toc:
    chunk = lua.eval("function(src, name) local f, e = loadstring(src, name) if not f then error(e) end return f end")(open(D + fn).read(), fn)
    chunk("CROX", ns)
G = lua.globals()
H.fire("ADDON_LOADED", "CROX")
H.fire("PLAYER_LOGIN")
cdb = G.CROX2CharDB
cdb.temperament = "gruff"; cdb.homeland = "home:stonespire_lands"; cdb.setupDone = True
H.tick(0.2)
errors = []
def press(slot):
    lua.eval("function(s) local ok, e = pcall(UseAction, s) if not ok then error(e) end end")(slot)

def target(**kw):
    t = lua.table(**kw)
    H.tgt = t
mode = sys.argv[1] if len(sys.argv) > 1 else "solo"
import random
random.seed(1)
lua.execute("math.randomseed(7)")

def fight(n_presses, foe="Razormane Hunter", slots=(2, 3, 2, 5, 2, 3, 6, 4, 7, 10)):
    target(name=foe, enemy=True, hp=100, ctype="humanoid", guid="g-" + foe, race=None)
    H.fire("PLAYER_REGEN_DISABLED")
    press(1); H.tick(1.5)
    for i in range(n_presses):
        s = slots[i % len(slots)]
        H.tgt.hp = max(1, 100 - i * 100 // n_presses)
        if i % 9 == 4: H.me.hp = max(20, H.me.hp - 15); H.tick(0.2)
        press(s); H.tick(1.5)
    H.tgt.dead = True; H.tick(0.2); press(2); H.tick(1.5)
    H.fire("PLAYER_REGEN_ENABLED"); H.me.hp = 100

for k in range(12):
    fight(30, foe="Razormane %d" % k)
    H.tick(10)
sent = [(r.t, r.ch, r.text) for r in H.sent.values()]
print("lines sent:", len(sent), "over", round((sent[-1][0] - sent[0][0]) / 60, 1), "min")
per = collections.Counter(int((t - sent[0][0]) // 60) for t, _, _ in sent)
print("max per minute:", max(per.values()), "| gaps < 10s:", sum(1 for a, b in zip(sent, sent[1:]) if b[0] - a[0] < 10))
for t, ch, tx in sent[:40]: print(" ", ch, tx)
bad = [tx for _, _, tx in sent if "[" in tx or "]" in tx]
print("unfilled:", bad)
chat = list(H.chat.values())
print("chat:", chat[:6])
# dump a few log events
log = cdb.log.sessions[1]
print("fights logged:", len(list(log.fights.values())))
f1 = log.fights[1]
for e in list(f1.events.values())[:12]:
    print("  ev", e.kind, e.moment, e.ability, e.why, e.text)
print(G.CROX2_FlagBinding is not None)
exp = ns.Log.exportText()
print(exp[:1500])
