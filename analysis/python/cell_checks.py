#!/usr/bin/env python3
"""cell_checks.py - the cell-level checks of Sections 8.1, 8.7, 8.8 and 8.9.

Recomputes, from the archived campaign files, the numbers of the paper that
are not produced by reproduce_paper.m:

  [8.1]  null calibration of theta: a metric unrelated to the outcome, one random
         value per (method, length), scored as in Table 4 over 5000 draws
         (primary configuration, RS(31,21) and RS(24,16));
  [8.1]  Kendall's tau in place of Spearman's rho at the matching threshold:
         same C2 partition, rank agreement of the two orderings;
  [8.7]  one method family left out (five families of Table 1);
  [8.8]  between-metric association and the rank-partial association with RES
         given giniLoad, given delta_G;
  [8.9]  C5 against the number of lengths (random 17- and 23-length subsets of
         the 44 common-grid lengths) and against the number of codewords per
         frame (common grid restricted to N in (24n, 96n]).

The statistic is that of Table 4 throughout: (method, length) cell means on the
common support N > 24n, in-scope field (freqDeterm and freqRandom excluded),
Spearman within length, Fisher z over lengths with weight (cells - 3), mean of
|rho| over the conditions. Design-time statistics are read from
design_cells_all_n15.csv (written by export_design_cells_all.m); the
a posteriori metrics and RES from correlation_data_*.mat.

Seeds are fixed, so every printed number reproduces exactly.

Usage
  python cell_checks.py --primary DATA/results --design DATA/results/design_cells_all_n15.csv \
                        [--code31 DATA/campaigns/code31] [--code24 DATA/campaigns/code24]

Requires Python 3.9+, NumPy, SciPy, h5py. Nothing in the MATLAB suite depends on it.

R.T. Sirmen, 2026-11
"""
import argparse, csv, glob, os
import numpy as np
import h5py
from scipy.stats import rankdata, kendalltau, spearmanr

OUTS = {'freqDeterm', 'freqRandom'}
PUB = ['delta_G', 'eta_ES', 'S_ECC', 'delta_BS', 'eta_sep', 'sepMin', 'U_ECC', 'laplacianEnergy',
       'PSR', 'V_ECC', 'S_sf', 'adjMin', 'adjCV', 'S_factor']
FAMILIES = {
    'block lineage': ['block', 'matrix', 'snake', 'helical', 'helicalScan', 'diagonal', 'spiral', 'S',
                      'blockCM', 'multiDim', 'hierarchical', 'latinSquare'],
    'convolutional': ['convolutional', 'convCM'],
    'turbo-code / algebraic': ['goldenRP', 'srandom', 'turbo', 'algebraic', 'drp', 'arp', 'prime'],
    'pseudo-random': ['random', 'chaotic'],
    'time': ['time'],
}


def load_corr(f):
    """correlation_data_*.mat (MATLAB v7.3) -> method names, column dict."""
    h = h5py.File(f, 'r')
    g = h[[k for k in h.keys() if k != '#refs#'][0]]
    names = [''.join(chr(c) for c in h[r][()].flatten()) for r in g['methodNames'][()].flatten()]
    cols = {k: g[k][()].flatten() for k in g.keys() if k not in ('methodNames', 'standardizedOn')}
    return names, cols


def build_cells(files, design_csv, n, drop=()):
    """Per condition: (method, length) keys, lengths, metric matrix X, RES cell means."""
    des, DES = {}, []
    if design_csv:
        rows = list(csv.DictReader(open(design_csv)))
        DES = [c for c in rows[0] if c not in ('method', 'encodedLen')]
        des = {(r['method'], int(float(r['encodedLen']))):
               [float(r[c]) if r[c] not in ('', 'NaN', 'nan') else np.nan for c in DES] for r in rows}
    names_all = DES + PUB
    conds = []
    for f in files:
        nm, d = load_corr(f)
        meth = np.array([nm[int(i) - 1] for i in d['methodID']])
        ln = d['encodedLen'].astype(int)
        keep = (ln > 24 * n) & ~np.isin(meth, list(OUTS) + list(drop))
        keys = sorted(set(zip(meth[keep], ln[keep])))
        idx = {k: i for i, k in enumerate(keys)}
        gi = np.array([idx[k] for k in zip(meth[keep], ln[keep])])

        def cm(v):
            v = v[keep]; ok = np.isfinite(v)
            s = np.bincount(gi[ok], weights=v[ok], minlength=len(keys))
            c = np.bincount(gi[ok], minlength=len(keys))
            return np.where(c > 0, s / np.maximum(c, 1), np.nan)

        X = np.full((len(keys), len(names_all)), np.nan)
        for i, k in enumerate(keys):
            if k in des:
                X[i, :len(DES)] = des[k]
        for j, p in enumerate(PUB):
            if p in d:
                X[:, len(DES) + j] = cm(d[p])
        conds.append(dict(file=os.path.basename(f), keys=keys, gl=np.array([k[1] for k in keys]),
                          X=X, RES=cm(d['RES'])))
    return conds, names_all


def rs(x, y):
    rx = rankdata(x); ry = rankdata(y); rx = rx - rx.mean(); ry = ry - ry.mean()
    d = np.sqrt((rx ** 2).sum() * (ry ** 2).sum())
    return rx @ ry / d if d > 0 else np.nan


def fisher(c, j, kind='rho'):
    zs, ws = [], []
    for L in np.unique(c['gl']):
        a = c['gl'] == L; x = c['X'][a, j]; y = c['RES'][a]; ok = np.isfinite(x) & np.isfinite(y)
        if ok.sum() < 5 or np.ptp(x[ok]) == 0:
            continue
        r = kendalltau(x[ok], y[ok]).statistic if kind == 'tau' else rs(x[ok], y[ok])
        zs.append(np.arctanh(np.clip(r, -.999999, .999999))); ws.append(ok.sum() - 3)
    return np.tanh(np.dot(zs, ws) / np.sum(ws))


def iqr_matlab(v):
    """MATLAB iqr (prctile with midpoint plotting positions)."""
    v = np.sort(v[np.isfinite(v)]); m = len(v); x = (np.arange(1, m + 1) - 0.5) / m * 100
    return np.interp(75, x, v) - np.interp(25, x, v)


# ----------------------------------------------------------------------------- 8.1 null
def null_primary(C, names, NREP=5000, seed=20261118):
    rng = np.random.default_rng(seed)
    j = names.index('giniLoad_B180')
    Z = {'shared': np.zeros((NREP, len(C))), 'indep': np.zeros((NREP, len(C))), 'shuf': np.zeros((NREP, len(C)))}
    grid = lambda c: 's' if 'standards' in c['file'] else 'c'
    shared_perm, shuf_perm = {}, {}
    for ci, c in enumerate(C):
        zs = {k: [] for k in Z}; ws = []
        for L in np.unique(c['gl']):
            a = c['gl'] == L; y = c['RES'][a]; x = c['X'][a, j]; ok = np.isfinite(y) & np.isfinite(x); m = ok.sum()
            ry = rankdata(y[ok]); ry = ry - ry.mean(); ry /= np.sqrt((ry ** 2).sum())
            rx = rankdata(x[ok]); rx = rx - rx.mean(); rx /= np.sqrt((rx ** 2).sum())
            key = (grid(c), L, m)
            if key not in shared_perm: shared_perm[key] = np.argsort(rng.random((NREP, m)), axis=1)
            if key not in shuf_perm: shuf_perm[key] = np.argsort(rng.random((NREP, m)), axis=1)
            base = np.arange(m) - (m - 1) / 2; base = base / np.sqrt((base ** 2).sum())
            Rs = base[shared_perm[key]]
            Ri = base[np.argsort(rng.random((NREP, m)), axis=1)]
            Rg = rx[shuf_perm[key]]
            for k, R in (('shared', Rs), ('indep', Ri), ('shuf', Rg)):
                zs[k].append(np.arctanh(np.clip(R @ ry, -0.999999, 0.999999)))
            ws.append(m - 3)
        ws = np.array(ws)
        for k in Z:
            Z[k][:, ci] = np.tanh(np.array(zs[k]).T @ ws / ws.sum())
    print('\n[8.1] Null calibration, primary configuration (%d draws, %d conditions)' % (NREP, len(C)))
    lab = {'shared': 'random value per (method, length), shared by the regimes of a grid',
           'indep': 'random value drawn independently per condition',
           'shuf': 'giniLoad shuffled among methods within length'}
    for k, M in Z.items():
        a = np.abs(M); mr = a.mean(1); pas = (a >= 0.30).sum(1)
        print('  %-66s mean|rho| 95%% %.3f  99%% %.3f  99.9%% %.3f  max %.3f | draws reaching 6/8: %d, max pass %d/8'
              % (lab[k], *np.percentile(mr, [95, 99, 99.9]), mr.max(), int((pas >= 6).sum()), pas.max()))


def null_code(folder, n, NREP=5000):
    files = sorted(glob.glob(os.path.join(folder, 'correlation_data_*.mat')))
    if not files:
        print('  RS n = %d: no correlation_data in %s - skipped' % (n, folder)); return
    rng = np.random.default_rng(n); Z = np.zeros((NREP, len(files))); perms = {}
    for ci, f in enumerate(files):
        nm, d = load_corr(f); meth = np.array([nm[int(i) - 1] for i in d['methodID']]); ln = d['encodedLen'].astype(int)
        keep = (ln > 24 * n) & ~np.isin(meth, list(OUTS)); keys = sorted(set(zip(meth[keep], ln[keep])))
        idx = {k: i for i, k in enumerate(keys)}; gi = np.array([idx[k] for k in zip(meth[keep], ln[keep])])
        y = np.bincount(gi, weights=d['RES'][keep]) / np.bincount(gi); gl = np.array([k[1] for k in keys]); zs = []; ws = []
        for L in np.unique(gl):
            a = gl == L; m = a.sum(); ry = rankdata(y[a]); ry -= ry.mean(); ry /= np.sqrt((ry ** 2).sum())
            if (L, m) not in perms: perms[(L, m)] = np.argsort(rng.random((NREP, m)), axis=1)
            base = np.arange(m) - (m - 1) / 2; base /= np.sqrt((base ** 2).sum())
            zs.append(np.arctanh(np.clip(base[perms[(L, m)]] @ ry, -.999999, .999999))); ws.append(m - 3)
        ws = np.array(ws); Z[:, ci] = np.tanh(np.array(zs).T @ ws / ws.sum())
    a = np.abs(Z); mr = a.mean(1); pas = (a >= 0.3).sum(1); need = int(np.ceil(0.75 * len(files)))
    print('  n = %-3d %d conditions, %d lengths: mean|rho| 95%% %.3f  99%% %.3f  99.9%% %.3f  max %.3f | draws reaching %d/%d: %d'
          % (n, len(files), len(ws), *np.percentile(mr, [95, 99, 99.9]), mr.max(), need, len(files), int((pas >= need).sum())))


# ----------------------------------------------------------------------------- 8.1 Kendall
TAB4 = ['delta_G', 'eta_ES', 'giniLoad_B180', 'esLoad_B180', 'meanMaxCW_B360', 'S_ECC', 'delta_BS', 'maxErrCW_B360',
        'eta_sep', 'B_guar', 'sepMin', 'cvLoad_B360', 'overT_B180', 'laplacianEnergy', 'U_ECC', 'PSR', 'V_ECC',
        'S_sf', 'Snew', 'adjMin', 'adjDispersion', 'adjCV', 'S_factor', 'S_ach', 'dispersion']


def kendall(C, names):
    th = (2 / np.pi) * np.arcsin(2 * np.sin(np.pi * 0.30 / 6))
    print('\n[8.1] Kendall tau against Spearman rho (tau threshold matching rho = 0.30: %.3f)' % th)
    R = {}
    for m in TAB4:
        j = names.index(m)
        r = np.array([fisher(c, j, 'rho') for c in C]); t = np.array([fisher(c, j, 'tau') for c in C])
        R[m] = (np.mean(abs(r)), (abs(r) >= 0.3).sum(), np.mean(abs(t)), (abs(t) >= th).sum())
        print('  %-16s rho %.3f %d/8   tau %.3f %d/8' % (m, *R[m]))
    a = [R[m][0] for m in TAB4]; b = [R[m][2] for m in TAB4]
    diff = [m for m in TAB4 if (R[m][1] >= 6) != (R[m][3] >= 6)]
    print('  C2 partition identical: %s %s;  ordering agreement (Spearman of the two |.| columns): %.3f'
          % (not diff, diff or '', spearmanr(a, b)[0]))


# ----------------------------------------------------------------------------- 8.7 families
SEL = ['delta_G', 'eta_ES', 'giniLoad_B180', 'esLoad_B180', 'meanMaxCW_B360', 'S_ECC', 'delta_BS', 'maxErrCW_B360',
       'eta_sep', 'B_guar', 'sepMin', 'overT_B180']


def families(files, design, n):
    print('\n[8.7] One method family left out (mean |rho|, conditions clearing 0.30)')
    print('  %-26s' % 'left out' + ''.join('%15s' % s.split('_B')[0][:13] for s in SEL))
    for fam, ms in [('none (Table 4)', [])] + list(FAMILIES.items()):
        C, nm = build_cells(files, design, n, drop=ms)
        row = []
        for s in SEL:
            v = np.array([fisher(c, nm.index(s)) for c in C]); row.append('   %.3f %d/%d ' % (np.mean(abs(v)), (abs(v) >= .3).sum(), len(C)))
        print('  %-26s' % fam + ''.join(row))


# ----------------------------------------------------------------------------- 8.8 between metrics
XM = ['delta_G', 'eta_ES', 'giniLoad_B180', 'esLoad_B180', 'meanMaxCW_B360', 'S_ECC', 'delta_BS', 'maxErrCW_B360',
      'eta_sep', 'B_guar', 'sepMin', 'cvLoad_B360', 'overT_B180']


def partial_rs(x, y, z):
    rx = rankdata(x); ry = rankdata(y); Zr = np.column_stack([np.ones(len(x))] + [rankdata(q) for q in z])
    ex = rx - Zr @ np.linalg.lstsq(Zr, rx, rcond=None)[0]; ey = ry - Zr @ np.linalg.lstsq(Zr, ry, rcond=None)[0]
    d = np.sqrt((ex ** 2).sum() * (ey ** 2).sum()); return ex @ ey / d if d > 1e-12 else np.nan


def between(C, names):
    J = [names.index(m) for m in XM]
    print('\n[8.8] Between-metric association: mean over conditions of |within-length rho|, Fisher-z combined')
    K = len(XM); XC = np.zeros((len(C), K, K))
    for ci, c in enumerate(C):
        for a in range(K):
            for b in range(a + 1, K):
                zs, ws = [], []
                for L in np.unique(c['gl']):
                    s = c['gl'] == L; x = c['X'][s, J[a]]; y = c['X'][s, J[b]]; ok = np.isfinite(x) & np.isfinite(y)
                    if ok.sum() < 5 or len(np.unique(x[ok])) < 2 or len(np.unique(y[ok])) < 2: continue
                    zs.append(np.arctanh(np.clip(rs(x[ok], y[ok]), -.999999, .999999))); ws.append(ok.sum() - 3)
                XC[ci, a, b] = XC[ci, b, a] = np.tanh(np.dot(zs, ws) / np.sum(ws))
    M = np.abs(XC).mean(0); np.fill_diagonal(M, 1)
    lab = [m.split('_B')[0][:8] for m in XM]
    print('  %-9s' % '' + ''.join('%9s' % l for l in lab))
    for a in range(K): print('  %-9s' % lab[a] + ''.join('%9.2f' % M[a, b] for b in range(K)))
    for ctrl_name in ('giniLoad_B180', 'delta_G'):
        jc = names.index(ctrl_name)
        print('  rank-partial association with RES given %s:' % ctrl_name.split('_B')[0])
        for a, m in enumerate(XM):
            if J[a] == jc: continue
            v = []
            for c in C:
                zs, ws = [], []
                for L in np.unique(c['gl']):
                    s = c['gl'] == L; x = c['X'][s, J[a]]; y = c['RES'][s]; z = c['X'][s, jc]
                    ok = np.isfinite(x) & np.isfinite(y) & np.isfinite(z)
                    if ok.sum() < 6 or len(np.unique(x[ok])) < 2: continue
                    r = partial_rs(x[ok], y[ok], [z[ok]])
                    if not np.isfinite(r): continue
                    zs.append(np.arctanh(np.clip(r, -.999999, .999999))); ws.append(ok.sum() - 4)
                v.append(np.tanh(np.dot(zs, ws) / np.sum(ws)))
            v = np.array(v)
            print('    %-16s %.3f  %d/8  %s' % (m, np.nanmean(np.abs(v)), int((np.abs(v) >= .3).sum()),
                                              '+' if (v > 0).all() else '-' if (v < 0).all() else 'mix'))


# ----------------------------------------------------------------------------- 8.9 C5
C5M = ['delta_G', 'eta_ES', 'giniLoad_B180', 'esLoad_B180', 'meanMaxCW_B360', 'S_ECC', 'delta_BS', 'maxErrCW_B360',
       'eta_sep', 'B_guar', 'sepMin', 'cvLoad_B360', 'overT_B180']


def c5(C, names, n=15):
    C = [c for c in C if 'common' in c['file']]
    PL = {}
    for m in C5M:
        j = names.index(m); rows = []
        for c in C:
            r = []
            for L in np.unique(c['gl']):
                a = c['gl'] == L; x = c['X'][a, j]; y = c['RES'][a]; ok = np.isfinite(x) & np.isfinite(y)
                r.append(rs(x[ok], y[ok]))
            rows.append(np.array(r))
        PL[m] = rows
    rng = np.random.default_rng(3); NL = len(PL[C5M[0]][0])
    print('\n[8.9] C5 against the number of lengths: random subsets of the %d common-grid lengths (2000 each)' % NL)
    for m in C5M:
        full = np.mean([iqr_matlab(r) for r in PL[m]]); out = []
        for k in (17, 23):
            s = np.array([np.mean([iqr_matlab(r[idx]) for r in PL[m]])
                          for idx in (rng.choice(NL, k, replace=False) for _ in range(2000))])
            out.append('%d lengths: median %.3f, P(IQR > 0.15) %.3f' % (k, np.median(s), (s > 0.15).mean()))
        print('  %-16s all %d: %.3f | %s' % (m, NL, full, ' | '.join(out)))
    Ls = np.unique(C[0]['gl'])
    print('[8.9] C5 against the number of codewords per frame (common grid)')
    for lo, hi in ((24 * n, 96 * n), (96 * n, 200 * n), (24 * n, 200 * n)):
        idx = np.where((Ls > lo) & (Ls <= hi))[0]
        print('  N in (%d, %d], %d to %d codewords, %d lengths: ' % (lo, hi, Ls[idx].min() // n, Ls[idx].max() // n, len(idx))
              + ', '.join('%s %.3f' % (m.split('_B')[0], np.mean([iqr_matlab(r[idx]) for r in PL[m]])) for m in C5M))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--primary', required=True, help='folder with the 8 correlation_data_*.mat of the primary campaign')
    ap.add_argument('--design', required=True, help='design_cells_all_n15.csv')
    ap.add_argument('--code31', default='', help='folder with the correlation_data of RS(31,21)')
    ap.add_argument('--code24', default='', help='folder with the correlation_data of RS(24,16)')
    a = ap.parse_args()
    files = sorted(glob.glob(os.path.join(a.primary, 'correlation_data_*.mat')))
    if len(files) != 8:
        raise SystemExit('cell_checks: %d correlation_data files in %s, expected 8' % (len(files), a.primary))
    C, names = build_cells(files, a.design, 15)
    print('primary configuration: %d conditions, %s cells' % (len(C), [len(c['keys']) for c in C]))
    null_primary(C, names)
    if a.code31: null_code(a.code31, 31)
    if a.code24: null_code(a.code24, 24)
    kendall(C, names)
    families(files, a.design, 15)
    between(C, names)
    c5(C, names)


if __name__ == '__main__':
    main()
