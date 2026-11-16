import random, statistics as st
import party2 as OLD
TARGET={1:1.5,2:2.5,3:3.5,4:4.5,5:5.5}
CAP_OLD={1:2,2:3,3:4,4:5,5:6}
HARD=5
def run_new(levels, fight, seed, ppm=40, avg=16.5, mult=None, cap=2.0, party_hold=5):
    rnd=random.Random(seed); n=len(levels); loud=max(levels)
    rate=[TARGET[l]/60 for l in levels]; prate=TARGET[loud]/60
    bucket=[min(cap,1.0+0.5*(fight>=30)) for _ in levels]       # short pulls start low, long fights start fuller
    pbucket=2.0 if fight>=30 else 1.0
    last=[-1e9]*n; lastp=-1e9; lastspk=None; ev=[]; t=0.0
    nxt=[rnd.random()*1.5 for _ in range(n)]; step=60.0/ppm
    while t<fight:
        for i in range(n):
            bucket[i]=min(cap,bucket[i]+rate[i]*0.25)
        pbucket=min(2.5,pbucket+prate*0.25)
        order=list(range(n)); rnd.shuffle(order)
        for i in order:
            if nxt[i]>t: continue
            nxt[i]=t+step*(0.7+0.6*rnd.random())
            sil=min(t-max(lastp,0) if lastp>-1e8 else t,30)
            boost=1+sil/20.0                           # longer silence -> likelier
            refr=0.35 if t-last[i]<8 else 1.0           # just spoke -> less likely
            m=mult[levels[i]]
            if rnd.random()*100>=avg*m*boost*refr: continue
            if t-last[i]<HARD+rnd.random()*3: continue   # jittered gap
            if bucket[i]<1: continue
            if n>1:
                if t-lastp<party_hold: continue
                if pbucket<1: continue
                if lastspk==i and t-lastp<15: continue
            bucket[i]-=1; pbucket-=1 if n>1 else 0
            last[i]=t; lastp=t; lastspk=i; ev.append((t,i))
        t+=0.25
    return ev
def run_old(levels, fight, seed, ppm=40):
    # replay the old engine and return events
    import party2 as P
    rnd=random.Random(seed); n=len(levels); cap=P.maxlvl(CAP_OLD)(levels)
    last=[-1e9]*n; times=[[] for _ in range(n)]; ptimes=[]; lastp=-1e9; lastspk=None; ev=[]
    nxt=[rnd.random()*1.5 for _ in range(n)]; step=60.0/ppm; t=0.0
    while t<fight:
        order=list(range(n)); rnd.shuffle(order)
        for i in order:
            if nxt[i]>t: continue
            nxt[i]=t+step*(0.7+0.6*rnd.random())
            gap,pm,mult=P.PACE[levels[i]]
            if rnd.random()*100>=16.5*mult: continue
            if t-last[i]<5 or t-last[i]<gap: continue
            if sum(1 for x in times[i] if t-x<60)>=pm: continue
            if n>1:
                if t-lastp<5: continue
                if sum(1 for x in ptimes if t-x<60)>=cap: continue
                if lastspk==i and t-lastp<20: continue
            last[i]=t; times[i].append(t); ptimes.append(t); lastp=t; lastspk=i; ev.append((t,i))
        t+=0.25
    return ev
def stats(fn, levels, fight, N=60, **kw):
    counts=[]; cvs=[]; burst=[]; silent=[]
    for s in range(N):
        ev=fn(levels,fight,s,**kw); ts=[e[0] for e in ev]
        counts.append(len(ts))
        g=[b-a for a,b in zip(ts,ts[1:])]
        if len(g)>2: cvs.append(st.pstdev(g)/st.mean(g))
        w=max((sum(1 for x in ts if a<=x<a+10) for a in ts),default=0); burst.append(w)
        pts=[0]+ts+[fight]; silent.append(max(b-a for a,b in zip(pts,pts[1:])))
    return st.mean(counts), (st.mean(cvs) if cvs else 0), st.mean(burst), st.mean(silent)
if __name__=="__main__":
    # calibrate new-model mult per level: solo 300s
    mult={}
    for l in range(1,6):
        best=None
        for m in [x/20 for x in range(2,60)]:
            mu={k:m for k in range(1,6)}
            r=st.mean(len(run_new([l],300,s,mult=mu)) for s in range(25))/5
            if best is None or abs(r-TARGET[l])<abs(best[1]-TARGET[l]): best=(m,r)
        mult[l]=best[0]
    print("new mults",mult)
    print("\nSOLO, fight length -> lines (old / new)    [target a minute: 1.5, 2.5, 3.5, 4.5, 5.5]")
    print(f"{'lvl':4}{'15s':>12}{'45s':>12}{'3min':>14}{'10min/min':>14}")
    for l in range(1,6):
        row=[]
        for f in (15,45,180,600):
            o=stats(run_old,[l],f,N=40)[0]; n_=stats(run_new,[l],f,N=40,mult=mult)[0]
            if f==600: o/=10; n_/=10
            row.append(f"{o:4.1f} / {n_:4.1f}")
        print(f"{l:<4}"+"".join(f"{r:>12}" for r in row))
    print("\nFEEL, 3-minute fight: gap variation (higher = less metronome), most lines in any 10s, longest silence (s)")
    print(f"{'party':14}{'':8}{'varies':>8}{'burst10s':>10}{'silence':>9}{'lines':>7}")
    for lv in [(3,),(5,),(3,3),(3,3,3,3,3),(1,3,5),(1,2,3,4,5)]:
        for name,fn,kw in (("old",run_old,{}),("new",run_new,{"mult":mult})):
            c,cv,b,s=stats(fn,list(lv),180,N=40,**kw)
            print(f"{str(lv):14}{name:8}{cv:8.2f}{b:10.1f}{s:9.0f}{c:7.1f}")
    print("\nPARTY a minute (10 min fights)")
    print(f"{'party':16}{'old':>7}{'new':>7}   new per player")
    for lv in [(3,3),(5,5),(3,3,3,3,3),(5,5,5,5,5),(1,1,5),(1,3,5),(1,2,3,4,5),(3,3,3,5,5)]:
        o=stats(run_old,list(lv),600,N=20)[0]/10
        evs=[run_new(list(lv),600,s,mult=mult) for s in range(20)]
        n_=st.mean(len(e) for e in evs)/10
        per=[round(st.mean(sum(1 for x in e if x[1]==i) for e in evs)/10,1) for i in range(len(lv))]
        print(f"{str(lv):16}{o:7.1f}{n_:7.1f}   {per}")
