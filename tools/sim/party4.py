import random, statistics as st
TARGET={1:1.5,2:2.5,3:3.5,4:4.5,5:5.5}
def run(levels, fight, seed, mult, variant, ppm=40, avg=16.5, cap=2.0):
    rnd=random.Random(seed); n=len(levels); loud=max(levels)
    rate=[TARGET[l]/60 for l in levels]; prate=TARGET[loud]/60
    bucket=[1.0+0.5*(fight>=30)]*n; pb=2.0 if fight>=30 else 1.0
    last=[-1e9]*n; lastp=-1e9; lastspk=None; ev=[]; t=0.0
    nxt=[rnd.random()*1.5 for _ in range(n)]; step=60.0/ppm
    while t<fight:
        for i in range(n): bucket[i]=min(cap,bucket[i]+rate[i]*0.25)
        pb=min(2.5,pb+prate*0.25)
        order=list(range(n)); rnd.shuffle(order)
        for i in order:
            if nxt[i]>t: continue
            nxt[i]=t+step*(0.7+0.6*rnd.random())
            sil=min(t-lastp if lastp>-1e8 else t,30)
            boost=1+sil/20.0
            since=t-last[i]
            connected = rnd.random()<0.15
            if variant=="A":              # floor 5-8, refractory step
                if since<5+rnd.random()*3: continue
                refr=0.35 if since<8 else 1.0
            elif variant=="B":            # floor 2, smooth refractory
                if since<2: continue
                refr=0.2+0.8*min(1,since/10)
            else:                         # C: floor 4, follow-up lane for connected moments (1 in 8)
                if since<4 and not (connected and since>=2 and rnd.random()<0.125): continue
                refr=0.2+0.8*min(1,since/10)
            if rnd.random()*100>=avg*mult*boost*refr*(1.6 if (variant=="C" and connected and since<4) else 1): continue
            if bucket[i]<1 and not (variant=="C" and since<4): continue
            if n>1:
                if t-lastp<(5 if variant=="A" else 3): continue
                if pb<1 and not (variant=="C" and since<4): continue
                if lastspk==i and t-lastp<15 and not (variant=="C" and since<4): continue
            bucket[i]=max(0,bucket[i]-1); pb=max(0,pb-1) if n>1 else pb
            last[i]=t; lastp=t; lastspk=i; ev.append((t,i))
        t+=0.25
    return ev
def calib(variant):
    m={}
    for l in range(1,6):
        best=None
        for x in [k/20 for k in range(2,60)]:
            r=st.mean(len(run([l],300,s,x,variant)) for s in range(20))/5
            if best is None or abs(r-TARGET[l])<abs(best[1]-TARGET[l]): best=(x,r)
        m[l]=best[0]
    return m
def metrics(variant,mult,levels,fight=180,N=40):
    cv=[];gaps=[];b3=[];b10=[];quick=[];sil=[];cnt=[]
    for s in range(N):
        ev=run(levels,fight,s,mult[max(levels)] if False else 1,variant) if False else None
    return None
if __name__=="__main__":
    res={}
    for v in "ABC":
        mult=calib(v); res[v]=mult; print(v,"mults",mult)
    print("\nSOLO, 3-minute fights.  gaps: share of lines <5s after previous | most lines in any 3s | any 10s | gap variation | rate a minute")
    print(f"{'lvl':4}{'var':4}{'<5s':>7}{'3s':>6}{'10s':>6}{'vary':>7}{'/min':>7}")
    for l in (2,3,5):
        for v in "ABC":
            quick=[];b3=[];b10=[];cv=[];cnt=[]
            for s in range(60):
                ts=[e[0] for e in run([l],180,s,res[v][l],v)]
                g=[b-a for a,b in zip(ts,ts[1:])]
                if len(g)>2: cv.append(st.pstdev(g)/st.mean(g))
                quick.append(sum(1 for x in g if x<5)/max(1,len(g)))
                b3.append(max((sum(1 for x in ts if a<=x<a+3) for a in ts),default=0))
                b10.append(max((sum(1 for x in ts if a<=x<a+10) for a in ts),default=0))
                cnt.append(len(ts)/3)
            print(f"{l:<4}{v:<4}{st.mean(quick)*100:6.0f}%{max(b3):6d}{st.mean(b10):6.1f}{st.mean(cv):7.2f}{st.mean(cnt):7.1f}")
    print("\nPARTY 3 min.  (levels)   var   silence  <5s%  worst 3s   /min")
    for lv in [(3,3,3,3,3),(1,3,5),(1,2,3,4,5),(5,5,5,5,5)]:
        for v in "ABC":
            mm=res[v][max(lv)]
            sil=[];q=[];w3=[];cnt=[]
            for s in range(40):
                ev=run(list(lv),180,s,0,v) if False else run(list(lv),180,s,mm if True else 1,v)
                ts=[e[0] for e in ev]
                pts=[0]+ts+[180]; sil.append(max(b-a for a,b in zip(pts,pts[1:])))
                g=[b-a for a,b in zip(ts,ts[1:])]; q.append(sum(1 for x in g if x<5)/max(1,len(g)))
                w3.append(max((sum(1 for x in ts if a<=x<a+3) for a in ts),default=0)); cnt.append(len(ts)/3)
            print(f"{str(lv):18}{v:>4}{st.mean(sil):8.0f}{st.mean(q)*100:7.0f}%{max(w3):8d}{st.mean(cnt):8.1f}")
