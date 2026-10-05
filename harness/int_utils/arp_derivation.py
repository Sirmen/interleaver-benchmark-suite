"""Derived-ARP side study (Section III-C): can the published 802.16 CTC parameters be recovered from published
constraints plus Berrou's spread criterion?  Declared search:
  P0 = the integer coprime with N nearest sqrt(2N) (ties: the smaller);
  offsets (P1, P2, P3): P1, P3 even, P1 = P3 (mod 4), P2 = 0 (mod 4), each in [0, N);
  the map must be a bijection; criterion S_min (Berrou) over all pairs, as local_Smin in interleaver_arp.m.
  Exhaustive for N <= 240; above that, (0,0,0) plus 20 000 uniformly drawn admissible triples (seed 1).
  Ties are broken toward (0,0,0)."""
import numpy as np, math, json, sys
T = [(24,5,0,0,0),(36,11,18,0,18),(48,13,24,0,24),(72,11,6,0,6),(96,7,48,24,72),(120,13,60,0,60),(144,17,74,72,2),
     (180,11,90,0,90),(192,11,96,48,144),(216,13,108,0,108),(240,13,120,60,180),(480,53,62,12,2),(960,43,64,300,824),
     (1440,43,720,360,540),(1920,31,8,24,16),(2400,53,66,24,2)]
def amap(N,P0,P1,P2,P3):
    j=np.arange(N); Pv=np.zeros(N,np.int64); Pv[j%4==1]=N//2+P1; Pv[j%4==2]=P2; Pv[j%4==3]=N//2+P3
    return (P0*j+Pv+1)%N+1
def smin(p, stop=None):
    s=10**9; d=1; N=len(p)
    while d<s and d<N:
        s=min(s,d+int(np.min(np.abs(p[d:]-p[:-d])))); d+=1
    return s
def p0(N):
    r=math.sqrt(2*N); c=sorted([k for k in range(1,N) if math.gcd(k,N)==1], key=lambda k:(abs(k-r),k)); return c[0]
rng=np.random.default_rng(1)
rows=[]
for N,P0p,P1p,P2p,P3p in T:
    P0=p0(N); pub=smin(amap(N,P0p,P1p,P2p,P3p))
    best=smin(amap(N,P0,0,0,0)); arg=(0,0,0)
    if N<=240:
        cands=((a,b,c) for a in range(0,N,2) for b in range(0,N,4) for c in range(a%4,N,4))
    else:
        cands=[(int(a),int(b),int(c)) for a,b,c in zip(rng.integers(0,N//2,20000)*2, rng.integers(0,N//4,20000)*4, rng.integers(0,N//4,20000)*4)]
        cands=[(a,b,(c+a%4)%N) for a,b,c in cands]
    for a,b,c in cands:
        if (a,b,c)==(0,0,0): continue
        p=amap(N,P0,a,b,c)
        if len(np.unique(p))!=N: continue
        v=smin(p)
        if v>best: best,arg=v,(a,b,c)
    rows.append(dict(N=N,P0_rule=P0,P0_pub=P0p,Smin_pub=pub,Smin_derived=best,offsets=arg,zero=arg==(0,0,0)))
    print(rows[-1], flush=True)
json.dump(rows,open('/root/work/analysis/arp_derivation.json','w'),indent=1)
z=sum(r['zero'] for r in rows); hi=sum(r['Smin_derived']>r['Smin_pub'] for r in rows); eq=sum(r['Smin_derived']==r['Smin_pub'] for r in rows); lo=sum(r['Smin_derived']<r['Smin_pub'] for r in rows)
print(f'zero offsets optimal at {z}/16; derived higher {hi}, equal {eq}, lower {lo}')
