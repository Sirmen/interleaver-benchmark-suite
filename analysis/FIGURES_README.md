# The seven figures

All seven go through `fig_style.m`, so they share type, weights, colour and
export format. Each writes three files into `./figures`: a **PDF** (vector),
an **EMF** (vector inside Word, for the .docx manuscript), and a 600 dpi PNG
as a fallback for the cases where a vector import misbehaves.

Draw at final size and never scale on insertion. Scaling a figure scales its
text with it, and the point sizes stop meaning anything. The manuscript takes
the 600 dpi PNG of every figure, inserted at exactly the drawn size (3.5 in
or 7.16 in wide), so the type stays at 9 pt.

## Running them

```matlab
dataDir = 'path/to/campaign/results';   % the folder holding KPItableDetailed_*.mat

% Figures 1 and 6 — both come out of one screen, so run it once each.
R1 = fig1_screen(dataDir);
R6 = fig6_resdecomp(dataDir);   % also prints the reordering, for checking the text

% Figures 4 and 5 — both read one scorecard. Run it ONCE and pass it in, so
% the figures and Table 8 come from the same computation and cannot disagree.
S  = metric_scorecard([], struct('dataDir', dataDir));
O4 = fig4_bsweep(S);
O5 = fig5_c5box(S);

% Figure 3
fig_cnn_justification(dataDir, struct('save', true));

% Figures 2 and 7 — no campaign data needed.
fig2_taxonomy;
O7 = fig7_bracket;              % ~200 permutations at N = 1200, under a minute
```

You do not have to name the precomputed-table folder. `find_table_dir.m` looks
for `table_factors_precomputed.mat` next to the results folder, in its parent
and the usual siblings, in the current folder, and finally on the MATLAB path,
and says which one answered. Pass `opts.tableDir` to override it.

`metric_scorecard` returns `perLength` and `lengths`, which is what Figure 5
draws. A scorecard saved before those fields existed does not have them, and
the figure says so rather than guessing.

## Widths

| Figure | Width | Why |
|---|---|---|
| 1 screen, two panels | 3.5 in, one column | one row per method, so it grows with the field |
| 2 taxonomy grid | 7.16 in, full width | six cells naming twenty-five metrics |
| 3 C_NN | 7.16 in, full width | two panels, (a) above (b) |
| 4 B sweep | 3.5 in, one column | five curves, one axis |
| 5 C5 boxes | 3.5 in, one column | grows with the metric count |
| 6 RES decomposition | 3.5 in, one column | grows with the method count |
| 7 bracket | 3.5 in, one column | one axis |

## Type size

One knob, applied to every figure:

```matlab
fig_style('scale', 1.5);     % 12 pt axis labels; set before drawing
```

`1.0` is strict IEEE — 8 pt on a 3.5 in column, which is what the printed page
wants and what looks small on a monitor. The default is **1.15**, giving 9 pt,
on the reasoning that a reviewer reads the PDF on a screen long before anyone
prints it. Line width and marker size move with the square root of the factor,
so the marks do not swamp the type. The setting lasts for the MATLAB session;
put the call at the top of a figure run to make it repeatable.

## Layout conventions

- **Fig. 3 (C_NN)** is stacked in one column, 3.5 x 3.66 in, (a) above (b),
  one-line panel titles, two-line y label. Side by side it cost 2 x 2.59
  column-inches plus a full-width caption and two section breaks.
- **Fig. 1** uses one colour per length (blue N = 1200, bluish green
  N = 1440) and draws the circle larger than the square, so a coinciding pair
  shows as a square inside a ring. Confined methods are drawn filled. The
  admissibility criteria are called A1/A2 — they clashed with the predictions
  P1-P3 and with ARP's P0-P3 — so the axis reads "A1 at 0.25".
- **Legends sit inside the axes** where the data leave room: Fig. 4 top left
  (axis fixed at [0 1]), Fig. 6 top left over the empty negative half of the
  leading rows, Fig. 1 inside the right panel at the bottom centre. A legend
  inside the axes can only be placed where the data leave room, and that
  depends on the data, so check each PNG once.
- `fig_style` writes the EMF and the 600 dpi PNG through `exportgraphics`,
  which crops to the drawn content, so there are no white bands.

## Before a run: check for shadowed copies

A figure whose output does not match what this file says it should is almost
always a second copy of the script earlier on the path.

```matlab
for f = {'fig_cnn_justification','metric_scorecard','screen_methods', ...
         'fig1_screen','fig2_taxonomy','fig4_bsweep','fig5_c5box', ...
         'fig6_resdecomp','fig7_bracket','fig_style','find_table_dir', ...
         'check_noise_fidelity','check_kappa_sensitivity'}
   w = which(f{1}, '-all');
   if numel(w) > 1, fprintf(2, '%s: %d copies on the path\n', f{1}, numel(w)); disp(w); end
end
```

## What the scripts check, and what you must check by eye

The scripts verify what can be verified numerically: Figure 2 counts the
metrics it names against the twenty-five the study scores, Figure 6 checks the
equation (4) identity, Figure 5 reproduces the `prctile` quantile definition
so its boxes and the C5 column of Table 8 are the same statistic, and Figure 4
reports the shape of each statistic in B (plateau, peak-then-fall, or swing).

What they cannot check is collision: whether a label overlaps a marker at
3.5 inches. Open each PDF at 100 % once.

## Things to know before reading the output

- **The scorecard defaults to the in-scope field.** Expect **924 cells, 44
  lengths, 21 methods** on the common grid, and the run prints
  `FIELD: in scope, ...` so it cannot be ambiguous. Asking for the full field
  prints a warning that those are the ablation numbers of Section 8.7; it
  gives 1012 cells and coefficients up to 0.2 different, and those appear in
  no table.
- **The bootstrap is seeded** per sweep, with the caller's stream restored
  afterwards, so the confidence intervals reproduce to the last digit.
- **`random` and `freqRandom` redraw their permutation on every call.** Both
  are averaged over `opts.nDraw` draws (15 by default) and their standard
  deviation is printed below the table, so it is visible which rows are a
  measurement and which are a sample. `widest`, the column the A1 screen uses,
  was 1.000 in every draw, so the scope partition never depended on one.
- **ARP has no permutation at N = 1200.** Its parameters are published only at
  the standards lengths, so every structural column is NaN there and the row
  reads "NOT SCREENED: no permutation at this length". At N = 1440, a
  standards length, it screens normally.
- **The Gilbert-Elliott sweeps realize about 0.22 in every noise bin**
  (`check_noise_fidelity`: slope 0.03-0.06, kappa 1.23 to 0.84), so treat the
  bins there as replicates at one density. Single and multi honour their
  labels exactly, and the two printing identical numbers is expected: in those
  regimes the corrupted count is round(rho*N), which depends only on N and
  rho.
- **A kappa-free reading is available** without re-simulating.
  `check_kappa_sensitivity` removes kappa (C_NN := BE_j) from the saved
  tables, restandardizes the way the harness did, and reports the shift in
  each method's mean RES and every rank move:

  ```matlab
  K  = check_kappa_sensitivity(dataDir, struct('write', true));
  S2 = metric_scorecard(fullfile(dataDir, 'kappa_free'));   % compare with Table 8
  ```

  `write` copies the config and correlation_data files into
  `<dataDir>/kappa_free/`, so check the free disk space first. The scorecard's
  "1 trial" column reads correlation_data and is therefore not kappa-free.

## Editing these scripts

`python3 mcheck.py *.m` checks block balance, which is the one thing editing
by script actually breaks. It is not a parser and does not pretend to be one.
One rule it exists to enforce: never put a comment-only line inside a cell
literal after a `...` — the comment ends the continuation, its newline becomes
a row separator, and the row comes out one cell short.
