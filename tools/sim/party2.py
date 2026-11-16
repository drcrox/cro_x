import random, statistics as st
HOLD=5; HARD=5
PACE={1:(25,2,0.65),2:(18,3,1.5),3:(12,4,1.9),4:(9,5,2.25),5:(7,6,2.65)}
def run(levels, capf, fight=600, ppm=40, avg=16.5, seed=0):
    rnd=random.Random(seed); n=len(levels)
    last=[-1e9]*n; times=[[] for _ in range(n)]; ptimes=[]; lastp=-1e9; lastspk=None
    cnt=[0]*n; t=0.0
    nxt=[rnd.random()*1.5 for _ in range(n)]; step=60.0/ppm
    cap=capf(levels)
    while t<fight:
        order=list(range(n)); rnd.shuffle(order)
        for i in order:
            if nxt[i]>t: continue
            nxt[i]=t+step*(0.7+0.6*rnd.random())
            gap,pm,mult=PACE[levels[i]]
            if rnd.random()*100>=avg*mult: continue
            if t-last[i]<HARD or t-last[i]<gap: continue
            if sum(1 for x in times[i] if t-x<60)>=pm: continue
            if n>1:
                if t-lastp<HOLD: continue
                if sum(1 for x in ptimes if t-x<60)>=(cap if isinstance(cap,(int,float)) else cap[i]): continue
                if lastspk==i and t-lastp<20: continue
            last[i]=t; times[i].append(t); ptimes.append(t); lastp=t; lastspk=i; cnt[i]+=1
        t+=0.25
    return [c/(fight/60) for c in cnt]
# party cap models. top = party combined ceiling
def own(m): return lambda lv:[m[l] for l in lv]            # each client uses its own level's cap (current design)
def maxlvl(m): return lambda lv: max(m[l] for l in lv)     # everyone uses the loudest member's cap (levels shared in HI)
def minlvl(m): return lambda lv: min(m[l] for l in lv)
S={1:2,2:3,3:4,4:5,5:6}              # cap = solo top
S1={1:3,2:4,3:5,4:6,5:7}
MODELS={
 "1 own cap = solo top (2-6)": own(S),
 "2 loudest member's cap = solo top (2-6)": maxlvl(S),
 "3 loudest member's cap, +1 (3-7)": maxlvl(S1),
 "4 loudest member, flat 6 combined": lambda lv:6,
}
combos=[(3,),(5,),(3,3),(5,5),(3,3,3),(3,3,3,3,3),(5,5,5,5,5),(1,1,1,1,1),(2,2,2,2,2),(4,4,4,4,4),(1,3,5),(1,1,5),(5,5,1),(1,2,3,4,5),(3,3,3,5,5),(1,1,3,3,5)]
if __name__=="__main__":
    for name,mf in MODELS.items():
        print("\n==",name); print(f"{'levels':16}{'combined':>9}   per-player a minute")
        for lv in combos:
            per=[run(list(lv),mf,seed=s) for s in range(30)]
            tot=st.mean(sum(r) for r in per)
            pp=[round(sum(p[i] for p in per)/len(per),1) for i in range(len(lv))]
            print(f"{str(lv):16}{tot:8.1f}   {pp}")
