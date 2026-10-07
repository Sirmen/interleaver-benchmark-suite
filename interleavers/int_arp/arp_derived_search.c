/* ARP_DERIVED_SEARCH  Exhaustive derived-ARP search over the published
 * constraint set, for Section III-C of the manuscript.
 *
 * Builds two ways from this one file.
 *
 *   As a MEX function, from inside MATLAB (no external toolchain beyond a
 *   supported C compiler; the free MATLAB Support for MinGW-w64 add-on is
 *   enough on Windows):
 *
 *       mex arp_derived_search.c
 *       [sminD, P] = arp_derived_search(N, P0);
 *
 *   sminD is the best Smin found; P is [P1 P2 P3], the offsets that attain
 *   it. verify_arp_table uses it automatically when it is present.
 *
 *   As a standalone program, if you would rather not use mex:
 *
 *       gcc -O2 -o arp_derived_search arp_derived_search.c
 *       ./arp_derived_search 2400 71          ->  "2400 60 210 600 250"
 *
 * WHAT IT SEARCHES
 * ---------------------------------------------------------------------------
 * The derivation rule declared in Section III-C: C = 4 with C | N, P0 the
 * coprime of N nearest sqrt(2N) (passed in), P2 a multiple of 4, P1 and P3
 * even with P1 = P3 (mod 4), offsets chosen to maximise Berrou's minimum
 * spatial distance Smin.
 *
 * WHY IT IS FEASIBLE
 * ---------------------------------------------------------------------------
 * N^3/32 offset triples, and Smin read off the permutation costs O(N*s) each,
 * which puts N = 2400 out of reach. It is not needed. With
 *
 *     p(j) = (P0*j + e_{j mod 4} + 1) mod N,  e = [0, N/2+P1, P2, N/2+P3],
 *
 * the class of j+d is (j+d) mod 4, so within one class
 *
 *     p(j+d) - p(j) = P0*d + e_{(c+d) mod 4} - e_c   (mod N),
 *
 * the same value for every j of that class. Both the positive and the
 * negative representative occur among those j, so the smallest |difference|
 * at distance d is min over the four classes of min(w, N-w). Smin then costs
 * O(s) from the four offsets alone, with no length-N array: a factor of N.
 * verify_arp_table checks this identity against the direct computation on
 * every published row before it trusts it.
 *
 * Candidates are abandoned as soon as they cannot beat the incumbent, so the
 * run is far below the worst case: N = 2400 takes about 90 s.
 *
 * BIJECTION TEST
 * ---------------------------------------------------------------------------
 * With 4 | N and gcd(P0,N) = 1, class c covers exactly the residues congruent
 * to A_c = (P0*c + e_c + 1) mod 4, so the map is a bijection iff the four A_c
 * are distinct mod 4. That is a four-integer test, not a sort of N values.
 *
 * R.T. Sirmen harness, 2026-10-07
 */

#include <stdlib.h>

static long N, P0;

static long smin_bounded(const long *e, long bound)
{
    long s = 2 * N, d, c, w, v, m;
    for (d = 1; d < s && d < N; d++) {
        m = N;
        for (c = 0; c < 4; c++) {
            w = (P0 % N) * (d % N) % N + (e[(c + d) & 3] - e[c]) % N;
            w %= N; if (w < 0) w += N;
            v = (w < N - w) ? w : N - w;
            if (v < m) m = v;
        }
        if (d + m < s) s = d + m;
        if (s <= bound) return s;          /* cannot beat the incumbent */
    }
    return s;
}

static void search(long *best, long *bP1, long *bP2, long *bP3)
{
    long half = N / 2, P1, P2, P3, e[4], s, A0, A1, A2, A3;
    *best = -1; *bP1 = *bP2 = *bP3 = 0;
    A0 = 1 & 3;
    for (P1 = 0; P1 < N; P1 += 2) {
        A1 = (((P0 + half + P1 + 1) % 4) + 4) & 3;
        if (A1 == A0) continue;
        e[1] = (half + P1) % N;
        for (P3 = P1 & 3; P3 < N; P3 += 4) {
            A3 = (((3 * P0 + half + P3 + 1) % 4) + 4) & 3;
            if (A3 == A0 || A3 == A1) continue;
            e[3] = (half + P3) % N;
            for (P2 = 0; P2 < N; P2 += 4) {
                A2 = (((2 * P0 + P2 + 1) % 4) + 4) & 3;
                if (A2 == A0 || A2 == A1 || A2 == A3) continue;
                e[0] = 0; e[2] = P2 % N;
                s = smin_bounded(e, *best);
                if (s > *best) { *best = s; *bP1 = P1; *bP2 = P2; *bP3 = P3; }
            }
        }
    }
}

#ifdef MATLAB_MEX_FILE
#include "mex.h"
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    long best, P1, P2, P3;
    double *o;
    if (nrhs != 2)
        mexErrMsgIdAndTxt("arp:nargin", "arp_derived_search(N, P0)");
    N  = (long) mxGetScalar(prhs[0]);
    P0 = (long) mxGetScalar(prhs[1]);
    if (N <= 0 || N % 4 != 0)
        mexErrMsgIdAndTxt("arp:N", "N must be a positive multiple of 4");
    search(&best, &P1, &P2, &P3);
    plhs[0] = mxCreateDoubleScalar((double) best);
    if (nlhs > 1) {
        plhs[1] = mxCreateDoubleMatrix(1, 3, mxREAL);
        o = mxGetPr(plhs[1]); o[0] = (double) P1; o[1] = (double) P2; o[2] = (double) P3;
    }
}
#else
#include <stdio.h>
int main(int argc, char **argv)
{
    long best, P1, P2, P3;
    if (argc != 3) { fprintf(stderr, "usage: arp_derived_search N P0\n"); return 1; }
    N = atol(argv[1]); P0 = atol(argv[2]);
    search(&best, &P1, &P2, &P3);
    printf("%ld %ld %ld %ld %ld\n", N, best, P1, P2, P3);
    return 0;
}
#endif
