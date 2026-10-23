#!/usr/bin/env python3
"""Reproduce Table 13's per-trial columns from the raw campaign files.

WHY THIS EXISTS
---------------------------------------------------------------------------
Table 13's columns were recomputed for v98 because the a priori (n,t) cell
changes its primary metric, and the recomputation has to use the SAME
averaging the published table used.  Two attempts missed, and each miss was
charged to the wrong thing: first to the burst length B, then to the averaging
itself.  Neither was at fault.  The caption states the rule outright:

    "Cell means over noise bins and runs at the 44 common-grid lengths with
     N > 24n, averaged over the four burst regimes; the last column is the
     same on the standards grid (5 lengths) ... giniLoad and overT at B = 12n."

and the two errors were a scope floor of 12n instead of 24n, and pooling the
standards grid into columns that are common-grid only.

This script tests that rule against the published numbers, in a language the
harness does not share with it, so that a shared helper cannot make a wrong
rule look right.  It needs nothing but the campaign files: the six columns it
checks are per-trial fields of correlation_data and are not derived from any
permutation, so the check isolates the averaging and the scope filter from
everything else.

RESULT, on the v2 campaign
---------------------------------------------------------------------------
All six columns reproduce for all 23 in-scope methods, worst deviation 0.0005
on the columns printed to three decimals and 0.0049 on S_ECC, which is printed
to two.  The standards-grid RES column reproduces as well.  144 published
values from one rule.  The design is exactly balanced - 44 lengths x 5 noise
bins x 35 replicates in each of the four regimes - so for a permutation-only
quantity the rule reduces to an unweighted mean over the 44 lengths.

R. Tanju Sirmen study.
"""
import glob
import os
import sys

import h5py
import numpy as np

COLS = ['eta_sep', 'delta_G', 'S_ECC', 'CR', 'BE', 'RES']
OUTS = {'freqDeterm', 'freqRandom'}
# three decimals in the table, except S_ECC which is printed to two
TOL = {c: 0.0006 for c in COLS}
TOL['S_ECC'] = 0.006

# Table 13 as published, common grid.  ARP is omitted: it is defined only on
# the standards grid, which is why its row is dashes in every other column.
PUB = {
    'block':         (0.113, 0.375,  -4.60, 0.226, 1.000, -0.036),
    'matrix':        (0.099, 0.326,  -5.31, 0.194, 0.989, -0.596),
    'snake':         (0.113, 0.368,  -4.82, 0.215, 1.000, -0.062),
    'helical':       (0.103, 0.324,  -5.51, 0.197, 0.989, -0.590),
    'helicalScan':   (0.103, 0.318,  -5.91, 0.188, 0.992, -0.481),
    'diagonal':      (0.068, 0.236,  -7.84, 0.136, 1.000, -0.243),
    'spiral':        (0.074, 0.180, -11.24, 0.214, 0.989, -0.567),
    'latinSquare':   (0.100, 0.444,  -4.23, 0.271, 1.000,  0.063),
    'goldenRP':      (0.683, 0.522,  -3.22, 0.360, 1.000,  0.248),
    'srandom':       (0.676, 0.518,  -4.15, 0.366, 1.000,  0.264),
    'prime':         (0.665, 0.486,  -4.71, 0.351, 0.997,  0.082),
    'convolutional': (0.111, 0.326,  -5.84, 0.185, 1.000, -0.127),
    'blockCM':       (0.248, 0.651,  -1.64, 0.516, 1.000,  0.583),
    'convCM':        (0.247, 0.623,  -1.91, 0.441, 1.000,  0.425),
    'turbo':         (0.754, 0.537,  -3.03, 0.295, 1.000,  0.114),
    'random':        (0.668, 0.490,  -4.73, 0.347, 1.000,  0.224),
    'S':             (0.998, 0.542,  -2.75, 0.359, 1.000,  0.252),
    'chaotic':       (0.905, 0.524,  -3.95, 0.369, 1.000,  0.271),
    'drp':           (0.666, 0.576,  -2.59, 0.410, 1.000,  0.358),
    'multiDim':      (0.434, 0.557,  -2.65, 0.404, 1.000,  0.344),
    'algebraic':     (0.334, 0.349,  -6.11, 0.225, 1.000, -0.049),
    'hierarchical':  (0.094, 0.310,  -5.78, 0.190, 1.000, -0.120),
    'time':          (0.122, 0.343,  -5.82, 0.194, 1.000, -0.106),
}
# Table 13's last column: the same quantity on the standards grid.
PUB_STD_RES = {
    'block': -0.090, 'matrix': -0.656, 'snake': -0.117, 'helical': -0.668,
    'helicalScan': -0.285, 'diagonal': -0.256, 'spiral': -0.660,
    'latinSquare': 0.037, 'goldenRP': 0.267, 'srandom': 0.190,
    'prime': -0.091, 'convolutional': -0.135, 'blockCM': 0.470,
    'convCM': 0.372, 'turbo': -0.011, 'random': 0.143, 'S': 0.208,
    'chaotic': 0.192, 'drp': 0.342, 'multiDim': 0.263, 'algebraic': -0.071,
    'hierarchical': -0.170, 'time': -0.164,
}


def method_names(h, g):
    """methodNames is a cell of char arrays, stored as object references."""
    return [''.join(chr(c[0]) for c in h[r][:]) for r in g['methodNames'][0]]


def condition(path):
    """One condition file -> {method: (per-column cell-mean average, nLen, balanced)}."""
    with h5py.File(path, 'r') as h:
        key = [k for k in h.keys() if not k.startswith('#')][0]
        g = h[key]
        names = method_names(h, g)
        mid = g['methodID'][:].ravel().astype(int)
        meth = np.array([names[i - 1] for i in mid])
        ln = g['encodedLen'][:].ravel()
        nb = g['noiseBin'][:].ravel()
        vals = {c: g[c][:].ravel() for c in COLS}
    return meth, ln, nb, vals


def average(files, min_n):
    """The caption's rule.  Cell means over (length, noise bin), averaged over
    the cells of a condition, then averaged over the conditions."""
    per, diag = {}, []
    for f in files:
        meth, ln, nb, vals = condition(f)
        keep = (ln > min_n) & ~np.isin(meth, list(OUTS))
        meth, ln, nb = meth[keep], ln[keep], nb[keep]
        vals = {c: v[keep] for c, v in vals.items()}
        ref = meth == meth[0]
        lens = np.unique(ln[ref])
        bins = [len(np.unique(nb[ref & (ln == x)])) for x in lens]
        reps = [int(np.sum(ref & (ln == lens[0]) & (nb == b)))
                for b in np.unique(nb[ref])]
        diag.append((os.path.basename(f), len(lens), sorted(set(bins)),
                     sorted(set(reps))))
        for m in np.unique(meth):
            sel = meth == m
            key = ln[sel] * 1000 + nb[sel]
            _, inv = np.unique(key, return_inverse=True)
            row = [np.nanmean([np.nanmean(vals[c][sel][inv == i])
                               for i in range(inv.max() + 1)]) for c in COLS]
            per.setdefault(m, []).append(np.array(row))
    return {m: np.mean(np.vstack(v), axis=0) for m, v in per.items()}, diag


def main(data_dir, out_csv):
    common = sorted(glob.glob(os.path.join(data_dir, 'correlation_data_*_common_*.mat')))
    stand = sorted(glob.glob(os.path.join(data_dir, 'correlation_data_*_standards_*.mat')))
    if not common:
        sys.exit('no common-grid correlation_data_*.mat in %s' % data_dir)

    got, diag = average(common, 360)
    gotS, diagS = average(stand, 360) if stand else ({}, [])

    print('\n  condition files, lengths above 360, noise bins per length, replicates per cell')
    for name, nl, bins, reps in diag + diagS:
        print('    %-52s %3d  %-8s %s' % (name, nl, bins, reps))

    bad, n = [], 0
    rows = []
    for m, ref in PUB.items():
        if m not in got:
            continue
        n += 1
        row = {'method': m}
        for j, c in enumerate(COLS):
            d = abs(got[m][j] - ref[j])
            row[c] = got[m][j]
            row[c + '_pub'] = ref[j]
            if d > TOL[c]:
                bad.append('%-14s %-8s here %.4f pub %.4f dev %.4f'
                           % (m, c, got[m][j], ref[j], d))
        if m in gotS:
            row['RES_standards'] = gotS[m][COLS.index('RES')]
            row['RES_standards_pub'] = PUB_STD_RES.get(m, float('nan'))
            d = abs(row['RES_standards'] - row['RES_standards_pub'])
            if d > TOL['RES']:
                bad.append('%-14s %-8s here %.4f pub %.4f dev %.4f'
                           % (m, 'RES(std)', row['RES_standards'],
                              row['RES_standards_pub'], d))
        rows.append(row)

    print('\n  %d in-scope methods x %d columns, plus the standards RES column.' % (n, len(COLS)))
    if bad:
        print('  DOES NOT REPRODUCE:')
        for b in bad:
            print('    ' + b)
    else:
        print('  REPRODUCES. Every column, every method, within its printed precision.')
        print('  The averaging rule is the published one: common grid, encodedLen > 24n,')
        print('  cell means over noise bins and runs, mean over the four burst regimes.')

    if rows:
        keys = ['method']
        for c in COLS:
            keys += [c, c + '_pub']
        keys += ['RES_standards', 'RES_standards_pub']
        with open(out_csv, 'w') as fh:
            fh.write(','.join(keys) + '\n')
            for r in rows:
                fh.write(','.join(
                    r['method'] if k == 'method'
                    else ('%.6g' % r[k] if k in r else '')
                    for k in keys) + '\n')
        print('\n  wrote %s\n' % out_csv)
    return 1 if bad else 0


if __name__ == '__main__':
    d = sys.argv[1] if len(sys.argv) > 1 else '.'
    o = sys.argv[2] if len(sys.argv) > 2 else 'table13_pertrial_reproduction.csv'
    sys.exit(main(d, o))
