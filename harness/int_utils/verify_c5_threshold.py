#!/usr/bin/env python3
"""Reproduce Table 8's |rho|, pass and IQR columns, then sweep the C5 threshold.

WHY THIS EXISTS
---------------------------------------------------------------------------
Two numbers in the validation have no written provenance: the retention
threshold theta = 0.30 and the C5 interquartile-range threshold 0.15.

theta is already defended in Section 8.7, and defended the right way - not by
deriving the number but by showing the claims do not depend on it, over
theta = 0.25 to 0.40.  The C5 threshold has no such paragraph.  Its FORM is
argued ("an average of 0.40 from lengths scattered between -0.3 and +0.9 and
one from lengths all near 0.40 are different claims"), but the VALUE 0.15 is
asserted and never tested.  A referee who asks "why 0.15" currently has
nothing to read.

This script supplies the same kind of answer theta has.  It does two things,
and keeping them apart is the point:

  1. It reproduces the columns the sweep rests on, from the raw campaign
     files, in a language the harness does not share with it.  A sweep over
     numbers that cannot be reproduced is worth nothing.
  2. It then sweeps the threshold and reports every value at which a verdict
     in Table 8 actually changes.

WHAT HAD TO BE GOT RIGHT
---------------------------------------------------------------------------
Two definitions matter and neither is obvious from the caption.

|rho| is the mean over the eight conditions of the per-condition correlation,
with the ABSOLUTE VALUE TAKEN INSIDE each condition.  Taking it outside -
combining the signed Fisher-z values across conditions and then taking the
modulus - is a different statistic and it is wrong where it matters most:
VECC, whose sign reverses between burst regimes, comes out at 0.044 instead
of the published 0.297, because the regimes cancel.  VECC is precisely the
metric the C4 discussion is about, so the wrong definition would have hidden
the thing that discussion exists to show.

IQR is computed with MATLAB's prctile convention, not the usual one.  MATLAB
places the sorted values at plotting positions (i - 0.5)/n and interpolates
linearly; NumPy's default places them at (i - 1)/(n - 1).  On 44 lengths the
two differ enough to matter: the default convention misses the published IQR
column by up to 0.038, which looks like a definitional disagreement and is
only a quantile rule.  NumPy calls MATLAB's convention 'hazen'.  The IQR is
taken on the SIGNED per-length correlations within a condition, and the eight
condition IQRs are then averaged.

With both of those right, all three columns reproduce for all 14 per-trial
metrics of Table 8, worst deviation 0.0005.

WHAT THE SWEEP FINDS
---------------------------------------------------------------------------
The recommended set is unchanged for every threshold in [0.132, 0.168).  The
published 0.15 lies inside that band, 0.018 from either edge.  Below 0.132
esLoad is withdrawn, below 0.112 sepmin follows, below 0.110 maxErrCW; above
0.168 overT is recommended, and cvLoad only above 0.299.

One honest caveat, and it belongs in the output rather than in a footnote:
0.15 is the exact midpoint of [0.132, 0.168), and that is a COINCIDENCE of
the v98 table, not the reason the number was chosen.  esLoad, which sets the
lower edge at 0.132, is one of the six metrics added in v98; in v97 the band
was [0.112, 0.168) and 0.15 was not its midpoint.  The defensible claim is
that the threshold is not load-bearing, not that it was derived.

R. Tanju Sirmen study.
"""
import glob
import os
import sys
import warnings

import h5py
import numpy as np
from scipy.stats import spearmanr

warnings.filterwarnings('ignore')

DROP = {'freqDeterm', 'freqRandom'}
MIN_N = 360                      # N > 24n, the common support of Table 8

# The 14 per-trial metrics of Table 8: field -> (label, published |rho|,
# published pass count, published IQR).
PERTRIAL = {
    'delta_G':         ('dG',        0.924, 8, 0.042),
    'eta_ES':          ('etaES',     0.924, 8, 0.043),
    'S_ECC':           ('SECC',      0.841, 8, 0.073),
    'delta_BS':        ('dBS',       0.817, 8, 0.098),
    'eta_sep':         ('etasep',    0.676, 8, 0.092),
    'laplacianEnergy': ('LE',        0.584, 8, 0.103),
    'U_ECC':           ('UECC',      0.583, 8, 0.098),
    'sepMin':          ('sepmin',    0.455, 8, 0.112),
    'PSR':             ('APSR',      0.318, 5, 0.112),
    'V_ECC':           ('VECC',      0.297, 4, 0.457),
    'S_sf':            ('Ssf',       0.260, 2, 0.171),
    'adjMin':          ('adjmin',    0.189, 0, 0.215),
    'adjCV':           ('adjCV',     0.179, 0, 0.124),
    'S_factor':        ('Sfactor',   0.155, 0, 0.145),
}

# Every row of Table 8, transcribed from v98. The regrouping in later
# versions changed the row order and the verdict wording, not the values.
# The design-time rows have no per-trial series, so their IQR is read from the
# table rather than recomputed here; the reproduction above is what licenses
# using the table's own numbers for the sweep.
TABLE8 = [
    ('dG',        0.924, 8, 0.042, False), ('etaES',    0.924, 8, 0.043, False),
    ('giniLoad',  0.898, 8, 0.066, False), ('esLoad',   0.881, 8, 0.132, False),
    ('meanMaxCW', 0.862, 8, 0.060, False), ('SECC',     0.841, 8, 0.073, False),
    ('dBS',       0.817, 8, 0.098, False), ('cvLoad',   0.761, 8, 0.299, False),
    ('overT',     0.751, 8, 0.168, False), ('maxErrCW', 0.720, 8, 0.110, False),
    ('etasep',    0.676, 8, 0.092, False), ('LE',       0.584, 8, 0.103, True),
    ('UECC',      0.583, 8, 0.098, True),  ('Bguar',    0.521, 8, 0.092, False),
    ('sepmin',    0.455, 8, 0.112, False), ('APSR',     0.318, 5, 0.112, False),
    ('VECC',      0.297, 4, 0.457, False), ('Ssf',      0.260, 2, 0.171, False),
    ('Snew',      0.218, 1, 0.139, False), ('adjmin',   0.189, 0, 0.215, False),
    ('adjgamma',  0.187, 0, 0.135, False), ('adjCV',    0.179, 0, 0.124, False),
    ('Sfactor',   0.155, 0, 0.145, False), ('Sach',     0.097, 0, 0.127, False),
    ('gamma',     0.053, 0, 0.131, False),
]
C2_MIN_PASS = 6                  # C2 requires six conditions of eight


def strings(f, ds):
    """A MATLAB cell of char arrays, stored as object references."""
    return [''.join(chr(c) for c in np.array(f[r]).ravel())
            for r in np.array(ds).ravel()]


def per_length_rho(path):
    """One condition file -> {field: [(rho, n-3), ... one per length]}.

    Cell means first, then a Spearman correlation against RES across the
    methods present at that length.  A length with fewer than four methods
    carries no correlation worth having and is dropped.
    """
    with h5py.File(path, 'r') as f:
        key = [k for k in f.keys() if k != '#refs#'][0]
        g = f[key]
        names = strings(f, g['methodNames'])
        scope = set(strings(f, g['standardizedOn']))
        mid = np.array(g['methodID']).ravel().astype(int)
        meth = np.array([names[i - 1] for i in mid])
        ln = np.array(g['encodedLen']).ravel()
        res = np.array(g['RES']).ravel()
        vals = {m: np.array(g[m]).ravel() for m in PERTRIAL}

    keep = (~np.isin(meth, list(DROP))
            & np.isin(meth, list(scope))
            & (ln > MIN_N))
    meth, ln, res = meth[keep], ln[keep], res[keep]
    vals = {m: v[keep] for m, v in vals.items()}

    cell = np.char.add(ln.astype(int).astype(str), meth)
    _, inv = np.unique(cell, return_inverse=True)
    n_cell = inv.max() + 1
    c_len = np.array([ln[inv == i][0] for i in range(n_cell)])
    c_res = np.array([res[inv == i].mean() for i in range(n_cell)])

    out = {}
    for m, v in vals.items():
        c_val = np.array([v[inv == i].mean() for i in range(n_cell)])
        rows = []
        for length in np.unique(c_len):
            s = c_len == length
            if s.sum() < 4:
                continue
            r, _ = spearmanr(c_val[s], c_res[s])
            if np.isfinite(r):
                rows.append((float(np.clip(r, -0.999999, 0.999999)),
                             float(s.sum() - 3)))
        out[m] = rows
    return out, n_cell, len(np.unique(c_len))


def matlab_iqr(a):
    """MATLAB's iqr: prctile at Hazen plotting positions (i - 0.5)/n."""
    q75, q25 = np.percentile(np.asarray(a, float), [75, 25], method='hazen')
    return float(q75 - q25)


def reproduce(data_dir):
    files = sorted(glob.glob(os.path.join(data_dir, 'correlation_data_*.mat')))
    if not files:
        sys.exit('no correlation_data_*.mat in %s' % data_dir)
    conds = []
    print('\n  conditions, cells and lengths above %d' % MIN_N)
    for p in files:
        rho, n_cell, n_len = per_length_rho(p)
        conds.append(rho)
        print('    %-52s %5d cells %3d lengths' % (os.path.basename(p), n_cell, n_len))

    print('\n  Table 8, the three columns, recomputed from the raw files')
    print('  %-9s %7s %7s   %5s %5s   %7s %7s' %
          ('metric', 'rho', 'pub', 'pass', 'pub', 'IQR', 'pub'))
    rows, bad = [], []
    for field, (lab, p_rho, p_pass, p_iqr) in PERTRIAL.items():
        rhos, iqrs, passes = [], [], 0
        for cond in conds:
            r = np.array([x[0] for x in cond[field]])
            w = np.array([x[1] for x in cond[field]])
            # absolute value INSIDE the condition - see the header
            rc = abs(np.tanh(np.sum(np.arctanh(r) * w) / np.sum(w)))
            rhos.append(rc)
            if rc >= 0.30:
                passes += 1
            iqrs.append(matlab_iqr(r))        # signed, MATLAB convention
        rho, iq = float(np.mean(rhos)), float(np.mean(iqrs))
        rows.append((lab, rho, p_rho, passes, p_pass, iq, p_iqr))
        for name, got, pub, tol in (('rho', rho, p_rho, 0.0015),
                                    ('IQR', iq, p_iqr, 0.0015)):
            if abs(got - pub) > tol:
                bad.append('%-9s %s here %.4f pub %.3f' % (lab, name, got, pub))
        if passes != p_pass:
            bad.append('%-9s pass here %d pub %d' % (lab, passes, p_pass))
        print('  %-9s %7.3f %7.3f   %5d %5d   %7.3f %7.3f' %
              (lab, rho, p_rho, passes, p_pass, iq, p_iqr))
    if bad:
        print('\n  DOES NOT REPRODUCE:')
        for b in bad:
            print('    ' + b)
    else:
        print('\n  REPRODUCES. All three columns, all %d per-trial metrics.' % len(rows))
    return rows, bad


def recommended(tau):
    return sorted(n for n, r, p, q, w in TABLE8
                  if p >= C2_MIN_PASS and not w and q <= tau)


def sweep(out_csv):
    live = sorted([x for x in TABLE8 if x[2] >= C2_MIN_PASS and not x[4]],
                  key=lambda x: x[3])
    print('\n  C2-passing, non-withdrawn metrics by IQR:')
    print('    ' + '  '.join('%s %.3f' % (n, q) for n, r, p, q, w in live))

    edges = sorted(set(q for n, r, p, q, w in live))
    bands, prev = [], None
    for a, b in zip([0.0] + edges, edges + [float('inf')]):
        tau = (a + b) / 2 if b != float('inf') else a + 0.01
        s = recommended(tau)
        if s != prev:
            bands.append((a, b, s))
            prev = s
    print('\n  threshold band          recommended')
    for a, b, s in bands:
        print('    [%-5.3f , %-5s)  %2d  %s' %
              (a, ('%.3f' % b) if b != float('inf') else 'inf', len(s),
               ', '.join(s) if s else '(none)'))

    lo = max(q for q in edges if q <= 0.15)
    hi = min(q for q in edges if q > 0.15)
    print('\n  The published threshold 0.15 lies in [%.3f, %.3f): no verdict in\n'
          '  Table 8 changes anywhere in that band, %.3f from the edge below\n'
          '  and %.3f from the edge above.' % (lo, hi, 0.15 - lo, hi - 0.15))
    print('  It is also the exact midpoint of that band - a coincidence of the\n'
          '  v98 table, not a derivation: esLoad sets the lower edge and esLoad\n'
          '  is new in v98. Claim the invariance, not the midpoint.')
    print('\n  The metric closest to failing C5 among those recommended is\n'
          '  esLoad at 0.132, inside the threshold by 0.018. That is worth\n'
          '  stating in the paper rather than leaving to be found.')

    with open(out_csv, 'w') as fh:
        fh.write('tau_low,tau_high,n_recommended,recommended\n')
        for a, b, s in bands:
            fh.write('%.3f,%s,%d,"%s"\n' %
                     (a, ('%.3f' % b) if b != float('inf') else '', len(s),
                      ' '.join(s)))
    print('\n  wrote %s\n' % out_csv)


if __name__ == '__main__':
    d = sys.argv[1] if len(sys.argv) > 1 else '.'
    o = sys.argv[2] if len(sys.argv) > 2 else 'c5_threshold_sweep.csv'
    _, failures = reproduce(d)
    sweep(o)
    sys.exit(1 if failures else 0)
