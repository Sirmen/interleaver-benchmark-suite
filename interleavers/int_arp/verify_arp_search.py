#!/usr/bin/env python3
"""Check every claim in ARP_SEARCH_RESULTS.txt, without using the search's shortcut.

WHY THIS EXISTS
---------------------------------------------------------------------------
Section 3.3 rests on a table of seventeen rows produced by one C program,
arp_derived_search.c, whose feasibility comes from an algebraic shortcut: the
offsets make the permutation difference constant within a residue class mod 4,
so the minimum spatial distance Smin can be read off four integers instead of
a length-N permutation.  That shortcut is what brings N = 2400 from
unreachable to about ninety seconds, and it is also the single place where a
wrong assumption would make every number in the table wrong together, quietly
and consistently.

verify_arp_table checks the identity inside MATLAB, but only to N = 240 - the
direct computation is too slow above that in MATLAB, which is why the C
program exists in the first place.  The rows that matter most for the claim
are the long ones, and those were the unchecked ones.

This script closes that.  It computes Smin by BRUTE FORCE over all pairs, in
Python, using none of the class identity:

    Smin = min over i < j of  |i - j| + circular |p(i) - p(j)|

For N = 2400 that is 2.9 million pairs, which is nothing in NumPy and was
merely slow in MATLAB.  If the shortcut were wrong, the brute-force value
would differ, and it would differ on the long rows first.

It also re-derives the three things the table states as given rather than
computed: that P0 is the coprime of N nearest sqrt(2N), that every row is a
bijection, and that the published rows satisfy the declared constraints
(P2 = 0 mod 4; P1, P3 even; P1 = P3 mod 4).

RESULT
---------------------------------------------------------------------------
Everything reproduces, on all seventeen lengths:

  - Smin by brute force equals the derived column, 17 of 17, and equals the
    published column for the standard's own parameters, 17 of 17. The
    shortcut is sound at every length, not only up to 240.
  - The C program, compiled with gcc -O2 and run on all seventeen lengths,
    returns the table's Smin AND the table's optimising offsets, 17 of 17,
    including the four rows whose optimum is not at (0,0,0). N = 2400 took
    82 s, against the "about 90 s" the source claims.
  - P0 is the nearest coprime to sqrt(2N) on all seventeen rows. Note that
    the rule needs the real square root: truncating to the integer square
    root first disagrees on seven rows, which is a trap for anyone
    reimplementing it.
  - All 34 permutations (seventeen published, seventeen derived) are
    bijections; every published row has gcd(P0, N) = 1 and meets the
    declared constraints.
  - The three totals hold: derived higher than published in 12 rows, equal
    in 5, lower in 0; the optimum is at (0,0,0) in 11 rows; the degenerate
    published rows are exactly N = 36, 48, 120, 180, 216.

HOW TO RUN IT
---------------------------------------------------------------------------
    gcc -O2 -o arp_derived_search arp_derived_search.c
    python3 verify_arp_search.py ./arp_derived_search

The C path is optional: without it the brute-force and rule checks still run,
and the script says the C comparison was skipped rather than passing it
silently.

R. Tanju Sirmen study.
"""
import math
import subprocess
import sys

import numpy as np

# interleaver_arp.m, local_published: N, P0, P1, P2, P3 as IEEE Std 802.16-2017
# cl. 8.4.9.2.3.2 gives them.
PUBLISHED = [
    (24, 5, 0, 0, 0), (36, 11, 18, 0, 18), (48, 13, 24, 0, 24),
    (72, 11, 6, 0, 6), (96, 7, 48, 24, 72), (108, 11, 54, 56, 2),
    (120, 13, 60, 0, 60), (144, 17, 74, 72, 2), (180, 11, 90, 0, 90),
    (192, 11, 96, 48, 144), (216, 13, 108, 0, 108), (240, 13, 120, 60, 180),
    (480, 53, 62, 12, 2), (960, 43, 64, 300, 824), (1440, 43, 720, 360, 540),
    (1920, 31, 8, 24, 16), (2400, 53, 66, 24, 2),
]

# ARP_SEARCH_RESULTS.txt: N, derived P0, derived Smin, optimising (P1,P2,P3),
# published Smin.
DERIVED = [
    (24, 7, 6, (0, 0, 0), 6), (36, 7, 6, (0, 0, 0), 6),
    (48, 11, 8, (0, 0, 0), 8), (72, 11, 12, (12, 0, 12), 6),
    (96, 13, 12, (0, 0, 0), 6), (108, 13, 12, (0, 0, 0), 6),
    (120, 17, 12, (0, 0, 0), 12), (144, 17, 16, (0, 0, 0), 16),
    (180, 19, 18, (18, 0, 18), 12), (192, 19, 18, (48, 96, 144), 12),
    (216, 19, 18, (0, 0, 0), 14), (240, 23, 20, (20, 0, 20), 10),
    (480, 31, 30, (0, 0, 0), 20), (960, 43, 36, (18, 148, 46), 32),
    (1440, 53, 44, (0, 0, 0), 30), (1920, 61, 60, (0, 0, 0), 38),
    (2400, 71, 60, (210, 600, 250), 42),
]
DEGENERATE_CLAIMED = [36, 48, 120, 180, 216]


def permutation(n, p0, p1, p2, p3):
    """interleaver_arp's local_map, zero-based: i = (P0 j + P_{j mod 4} + 1) mod N.

    The asymmetry is the easy thing to get wrong: P1 and P3 carry N/2, P2 does
    not, and the j = 0 class carries no offset at all.
    """
    j = np.arange(n, dtype=np.int64)
    off = np.zeros(n, dtype=np.int64)
    off[j % 4 == 1] = n // 2 + p1
    off[j % 4 == 2] = p2
    off[j % 4 == 3] = n // 2 + p3
    return (p0 * j + off + 1) % n


def smin_bruteforce(p):
    """min over all pairs of |i - j| + circular |p(i) - p(j)|.

    No class identity, no early algebra - only the definition. The loop stops
    once d alone exceeds the incumbent, which is sound because the second term
    cannot be negative.
    """
    n = len(p)
    best = 2 * n
    for d in range(1, n):
        if d >= best:
            break
        w = np.abs(p[d:] - p[:-d])
        np.minimum(w, n - w, out=w)
        cand = d + int(w.min())
        if cand < best:
            best = cand
    return best


def nearest_coprime(n):
    """The coprime of n nearest sqrt(2n). The REAL square root: see header."""
    target = math.sqrt(2 * n)
    return min((x for x in range(2, n) if math.gcd(x, n) == 1),
               key=lambda x: (abs(x - target), x))


def run_c(binary, n, p0):
    out = subprocess.run([binary, str(n), str(p0)], capture_output=True,
                         text=True, timeout=1800)
    if out.returncode != 0:
        return None
    f = out.stdout.split()
    return int(f[1]), (int(f[2]), int(f[3]), int(f[4]))


def main(binary=None):
    bad = []

    print('\n  PUBLISHED ROWS - bijection, gcd, declared constraints, Smin')
    for (n, p0, p1, p2, p3), drow in zip(PUBLISHED, DERIVED):
        pub_smin = drow[4]
        p = permutation(n, p0, p1, p2, p3)
        bij = len(np.unique(p)) == n
        smin = smin_bruteforce(p)
        constraints = (p2 % 4 == 0 and p1 % 2 == 0 and p3 % 2 == 0
                       and (p1 - p3) % 4 == 0)
        off = [0, (n // 2 + p1) % n, p2 % n, (n // 2 + p3) % n]
        degenerate = off[1] == 0 and off[2] == 0 and off[3] == 0
        ok = bij and constraints and math.gcd(p0, n) == 1 and smin == pub_smin
        if not ok:
            bad.append('published N=%d' % n)
        print('    N=%-5d bij=%d gcd=%d constraints=%d  Smin %3d (table %3d)%s%s'
              % (n, bij, math.gcd(p0, n) == 1, constraints, smin, pub_smin,
                 '  DEGENERATE' if degenerate else '', '' if ok else '  <<<'))

    print('\n  DERIVED ROWS - P0 rule, bijection, Smin by brute force%s'
          % (', and the C program' if binary else ' (C program not given)'))
    for n, p0, smin_tab, (p1, p2, p3), _ in DERIVED:
        p = permutation(n, p0, p1, p2, p3)
        bij = len(np.unique(p)) == n
        smin = smin_bruteforce(p)
        rule = nearest_coprime(n)
        c_txt = ''
        c_ok = True
        if binary:
            got = run_c(binary, n, p0)
            if got is None:
                c_txt, c_ok = '  C FAILED', False
            else:
                c_ok = got[0] == smin_tab and got[1] == (p1, p2, p3)
                c_txt = '  C %3d %s' % (got[0], 'ok' if c_ok else 'MISMATCH')
        ok = bij and smin == smin_tab and rule == p0 and c_ok
        if not ok:
            bad.append('derived N=%d' % n)
        print('    N=%-5d P0 %3d (rule %3d) bij=%d  Smin brute %3d  table %3d%s%s'
              % (n, p0, rule, bij, smin, smin_tab, c_txt, '' if ok else '  <<<'))

    higher = sum(1 for r in DERIVED if r[2] > r[4])
    equal = sum(1 for r in DERIVED if r[2] == r[4])
    lower = sum(1 for r in DERIVED if r[2] < r[4])
    zero = sum(1 for r in DERIVED if r[3] == (0, 0, 0))
    degen = [n for (n, p0, p1, p2, p3) in PUBLISHED
             if (n // 2 + p1) % n == 0 and p2 % n == 0 and (n // 2 + p3) % n == 0]

    print('\n  TOTALS')
    for label, got, want in (('derived higher', higher, 12),
                             ('equal', equal, 5),
                             ('lower', lower, 0),
                             ('optimum at (0,0,0)', zero, 11)):
        mark = '' if got == want else '  <<<'
        if got != want:
            bad.append(label)
        print('    %-22s %2d  (table says %2d)%s' % (label, got, want, mark))
    if degen != DEGENERATE_CLAIMED:
        bad.append('degenerate list')
    print('    degenerate rows        %s  (table says %s)%s'
          % (degen, DEGENERATE_CLAIMED, '' if degen == DEGENERATE_CLAIMED else '  <<<'))

    if bad:
        print('\n  FAILED: %s\n' % ', '.join(bad))
        return 1
    print('\n  Every claim in ARP_SEARCH_RESULTS.txt reproduces, on all seventeen\n'
          '  lengths, with Smin computed from the definition rather than from the\n'
          '  class identity the search relies on.\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else None))
