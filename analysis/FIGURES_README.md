# The seven figures

## Read this before the next run

**v22: Fig. 3 (C_NN) stacked in one column.** 3.5 x 3.66 in, (a) above
(b), one-line panel titles, two-line y label. Side by side it cost 2 x 2.59
column-inches plus a full-width caption and two section breaks; stacked it
saves about 1.8 column-inches (roughly eleven lines). Rerun
`fig_cnn_justification` and send fig3_cnn.emf.

**v21 (after the v20 run).**
- Fig. 6 (RES split): the legend is now placed so its right edge sits just
  left of the zero line, and the negative side of the axis is widened if
  it does not fit. It can no longer run onto the positive bars.
- Fig. 7 (bracket): 2.05 -> 1.65 in; label rows, arrow and captions pulled
  in; bottom margin only what ticks and the label need.
- Fig. 5 (C5 boxes) and Fig. 3 (C_NN): bottom margin cut to 0.36-0.38 in,
  axes placed in inches.

**v20: no white bands, legends inside.**
- `fig_style` now writes EMF and the 600 dpi PNG through `exportgraphics`,
  which crops to the drawn content (it already did so for the PDF). The
  top and bottom margins `print` used to leave are gone.
- Legends moved inside, as in the author's v18 edits: Fig. 4 top left
  (axis fixed at [0 1]), Fig. 6 top left over the empty negative half of the
  leading rows, Fig. 1 inside the right panel at the bottom centre.
- Heights cut to match: Fig. 1 -0.21 in, Fig. 4 2.75 -> 2.0 in, Fig. 6
  -0.35 in, Fig. 3 3.0 -> 2.6 in, Fig. 2 2.5 -> 2.36 in.
- Check each PNG once: a legend inside the axes can only be placed where
  the data leave room, and that depends on the data.

**v19 changes (rerun all seven, then send `figures/*_600dpi.png`).**
- Fig. 1: one colour per length (blue N = 1200, bluish green N = 1440) and
  the circle drawn larger than the square, so a coinciding pair shows as a
  square inside a ring. Confined methods are drawn filled. The admissibility
  criteria are now called A1/A2 (they clashed with predictions P1-P3 and ARP
  P0-P3), so the axis reads "A1 at 0.25".
- Fig. 2: redrawn at ONE column (3.5 x 2.5 in). Row labels vertical, lists
  broken by hand; the 19-metric count check still runs.
- Fig. 3: labels of panel (a) no longer run into panel (b).
- The manuscript takes the 600 dpi PNG of every figure, inserted at exactly
  the drawn size (3.5 in or 7.16 in wide), so the type stays at 9 pt.

**Noise fidelity: run, and answered.** `check_noise_fidelity` found that the
four Gilbert-Elliott sweeps realized about 0.22 in every noise bin (slope
0.03-0.06, kappa 1.23 -> 0.84); single and multi honour their labels exactly.
The two single/multi tables printing identical numbers is expected, not a
copy error: in those regimes the corrupted count is round(rho*N), so realized
density depends only on N and rho, which the two share.

**Next: `check_kappa_sensitivity`.** By Lemma 1, C_NN = BE_j * kappa, so every
GE CR carries a bin-dependent kappa common to all methods in a trial. Within a
trial that cannot reorder anything; RES, standardized across bins, can move a
little. This script removes kappa (C_NN := BE_j) from the saved tables,
restandardizes exactly as the harness did (it recovers the grouping and
population from the stored CR_z and reports the reproduction error), and
prints the shift in each method's mean RES, every rank move, and the
per-length agreement the validation uses. No re-simulation.

```matlab
K  = check_kappa_sensitivity(dataDir, struct('write', true));
S2 = metric_scorecard(fullfile(dataDir, 'kappa_free'));   % compare with Table IX
```

`write` copies the config and correlation_data files into
`<dataDir>\kappa_free\`, so check the free disk space first. The scorecard's
"1 trial" column reads correlation_data and is therefore not kappa-free.

**The scorecard now defaults to the in-scope field, and that is a change.**
`metric_scorecard` defaulted to `dropMethods = {}`, the full twenty-three
methods, while `metric_crosscorr` defaulted to dropping the two frequency
interleavers. So the documented command reproduced numbers that appear in no
table — 1012 cells against the manuscript's 924, coefficients moving by up to
0.2 — with nothing on screen to say why. The default is now the in-scope
field, the run prints `FIELD: in scope, ...` so it can never be ambiguous, and
asking for the full field prints a warning that those are the ablation numbers
of Section VIII-G. **Expect 924 cells, 44 lengths, 21 methods on the common
grid.** If you still see 1012 and 23, the old file is being picked up.

**Which brings up shadowing.** A run of `fig_cnn_justification` wrote
`...\results\figs\fig_cnn_ge0p70_common_260829_1.png` — the old name and the
old message, from a copy of the script that predates the `fig_style` export.
The file in this package writes `fig3_cnn_<tag>` through `fig_style` like the
rest. Before the next run:

```matlab
for f = {'fig_cnn_justification','metric_scorecard','screen_methods', ...
         'fig1_screen','fig2_taxonomy','fig4_bsweep','fig5_c5box', ...
         'fig6_resdecomp','fig7_bracket','fig_style','find_table_dir', ...
         'check_noise_fidelity','check_kappa_sensitivity'}
   w = which(f{1}, '-all');
   if numel(w) > 1, fprintf(2, '%s: %d copies on the path\n', f{1}, numel(w)); disp(w); end
end
```

Anything reporting more than one copy is the reason its output does not match
what this package says it should.

**The bootstrap is now seeded, so the confidence intervals will move once.**
It drew from whatever state MATLAB's global stream was in, which is why the
same data gave 1.067 on one run and 1.068 in the manuscript. The seed is fixed
per sweep and the caller's stream is restored afterwards. The next run gives
the canonical intervals; the point estimates do not change, only the third
decimal of some interval endpoints, and those go into Table IX from that run.

**`mcheck.py` replaces the parse check.** Octave is gone from the container
that edits these files, so `__parse_file__` is no longer available and edits
were going out unverified. `python3 mcheck.py *.m` checks block balance, which
is the one thing editing by script actually breaks. It is not a parser and
does not pretend to be one.

All seven go through `fig_style.m`, so they share type, weights, colour and
export format. Each writes three files into `./figures`: a **PDF** (vector, for
the eventual IEEEtran submission), an **EMF** (vector inside Word, for the
.docx manuscript), and a 600 dpi PNG as a fallback for the cases where a
vector import misbehaves.

Draw at final size and never scale on insertion. Scaling a figure scales its
text with it, and the point sizes stop meaning anything.

## Running them

```matlab
dataDir = 'path/to/campaign/results';   % the folder holding KPItableDetailed_*.mat

% Figures 1 and 6 — both come out of one screen, so run it once each.
R1 = fig1_screen(dataDir);
R6 = fig6_resdecomp(dataDir);   % also prints the reordering, for checking the text

% Figures 4 and 5 — both read one scorecard. Run it ONCE and pass it in, so
% the figures and Table IX come from the same computation and cannot disagree.
S  = metric_scorecard([], struct('dataDir', dataDir));
O4 = fig4_bsweep(S);
O5 = fig5_c5box(S);

% Figure 3 — already written, now exporting through the shared style.
fig_cnn_justification(dataDir, struct('save', true));

% Figures 2 and 7 — no campaign data needed.
fig2_taxonomy;
O7 = fig7_bracket;              % ~200 permutations at N = 1200, under a minute
```

You no longer have to name the precomputed-table folder. `find_table_dir.m`
looks for `table_factors_precomputed.mat` next to the results folder, in its
parent and the usual siblings, in the current folder, and finally on the
MATLAB path, and says which one answered. Pass `opts.tableDir` to override it.

`metric_scorecard` now returns two new fields, `perLength` and `lengths`, which
is what Figure 5 draws. A scorecard saved before this change does not have
them and the figure will say so rather than guessing.

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

## Widths

| Figure | Width | Why |
|---|---|---|
| 1 screen, two panels | 3.5 in, one column | one row per method, so it grows with the field |
| 2 taxonomy grid | 7.16 in, full width | six cells naming nineteen metrics |
| 3 C_NN | 7.16 in, full width | two panels side by side |
| 4 B sweep | 3.5 in, one column | five curves, one axis |
| 5 C5 boxes | 3.5 in, one column | grows with the metric count |
| 6 RES decomposition | 3.5 in, one column | grows with the method count |
| 7 bracket | 3.5 in, one column | one axis |

Figures 2 and 3 sit in their own one-column sections of the manuscript,
because Word spans a figure across both columns only that way. The subsection
headings that were above them were moved below, so no heading is left alone at
the foot of a section.

## What to check once, by eye

The scripts verify what can be verified numerically — Figure 2 counts the
metrics it names against the nineteen the study scores, Figure 6 checks the
Lemma 4 identity, Figure 5 reproduces the `prctile` quantile definition so its
boxes and the C5 column of Table IX are the same statistic, Figure 4 reports
the shape of each statistic in B (plateau,
peak-then-fall, or swing). What they cannot check is collision:
whether a label overlaps a marker at 3.5 inches. Open each PDF at 100 % once.

## Two things the first run turned up

**`random` and `freqRandom` redraw their permutation on every call.** Three
runs of `screen_methods` at the same N returned `reach` = 0.953, 0.973 and
0.990 for `random` — a four per cent spread in a column the manuscript quotes.
The two ensemble methods are now averaged over `opts.nDraw` draws (15 by
default) and their standard deviation is printed below the table, so it is
visible which rows are a measurement and which are a sample. `widest`, the
column P1 actually uses, was 1.000 in all three runs, so the scope partition
never depended on the draw.

**ARP has no permutation at N = 1200** — its parameters are published only at
the standards lengths, so every structural column is NaN there. The row used
to read "in scope, ranked on merit", which is a clean bill of health from a
test that never ran. It now reads "NOT SCREENED: no permutation at this
length". At N = 1440, a standards length, it screens normally.

## Fixed after the first render

- **Fig. 1 had its axes the wrong way round.** Reach takes two values in this
  field, about 0.03 and about 1.0, so on the horizontal axis the comparison
  collapsed into two stacks of coincident points. Reach is now vertical and
  logarithmic, the load spreads the points sideways, and the two bands and the
  gap between them are the first thing the figure shows. The legend moved out
  of the plot, where it was printing over the two labels.
- **Fig. 7 was missing the identity**, the anchor it is named after. The upper
  axis limit was computed without it, and for giniLoad the identity is the
  HIGHEST value in the figure, so it fell outside the axes. Worse, the verdict
  text read as though larger were better: the identity returns giniLoad 0.899
  at N = 1200 and B = 8n against about 0.41 for a random draw, so smaller is
  better and the bracket runs downward. Both are fixed, candidate labels now
  alternate between two rows, and the axis carries a "better" arrow.
- **Fig. 6 legend named the wrong things.** `legend` called with labels but no
  handles attaches them to the axes children in order, and the zero reference
  line drawn first took the first label — so the printed legend showed a grey
  line for the recovery term and the blue patch for the rate term, both wrong.
  The handles are now named explicitly.
- **Fig. 5 was drawing the same metric five times.** It selected the twelve
  strongest scorecard columns, and the scorecard holds each design statistic
  once per burst length, so giniLoad and meanMaxCW filled the figure and half
  the suite was absent. It now draws the recommended suite, one entry per
  metric at the B that table names, with the paper's symbols as labels.
  Margins are computed in inches from the longest label instead of guessed,
  which is what clipped `meanMaxCW_B180` to `neanMaxCW_B180` and cut the right
  end off the x label.
- **Fig. 4 legend moved below the axes** and the 16n tick label was dropped
  (the tick stays). **Fig. 2** row labels were running off the canvas.
- **Type scale eased to 1.15** (9 pt). The first pass was 1.25 and the trouble
  was layout, not size.

## Fixed after the second render

- **Fig. 1 is now two panels, one row per method.** Reach carries almost no
  resolution — two values, 0.03 and 1.0 — so as a coordinate it put twenty-two
  markers on one line, separated only by an integer load that several of them
  share, and they sat on top of each other. One row per method makes overlap
  impossible, shows the count, and lets every method be named. Left panel is
  the criterion, right panel the load that does not separate them.
- **Fig. 5 now plots |ρ|.** The load statistics correlate negatively by
  construction, so their boxes sat at −0.85 to −0.90 and the separation
  metrics at +0.85, with the whole axis spent on a fact that is a definition
  and the boxes that actually differ squeezed into a tenth of the width. The
  sign is now a symbol at the left of each row, and an asterisk marks any
  metric that reversed at some length — for that one, and only that one, the
  absolute value would understate the spread.
- **Fig. 6 (was 7) "better" arrow is drawn in data coordinates.** `annotation`
  places in figure coordinates; at this figure height the arrow landed behind
  the axes and never appeared.
- **Fig. 3 legend moved inside, top left**, and the panel is given headroom
  for it. Every curve there is a ratio of realized to target density and none
  exceeds 1, so the band above 1 is empty by construction and a legend in it
  cannot cover anything. Below the axes it was costing a third of the height.
- **Figs. 2 and 4 keep their form; their captions now carry the argument** —
  what the two axes of the taxonomy mean and why the empty cell matters, and
  why a plateau rather than a best score decides B. The Fig. 4 caption also
  stopped promising an "8n knee marked" that the script does not draw.

## Fixed after the third render

- **Fig. 3 panel (a): the curves were crushed by my own legend.** Putting the
  legend inside the panel needed headroom above the data, and the whole
  finding there lives inside two per cent of the axis — the curves are flat
  lines at 1.000, 0.995, 0.992 and 0.983 — so the headroom squeezed them into
  a sliver. The legend is gone: the axis is now fitted to the data and each
  cluster is named at its own right-hand end with its BE. That separates the
  curves and saves more space than the legend ever cost.
- **Fig. 6 (bracket): the arrow ran through the drp label.** Raised above
  both label rows.
- **Fig. 1: the floating P1 glyph is gone.** Set loose in the plot it landed
  among the tick marks and read as debris; the threshold is named in the axis
  label instead.
- **Table XV is now two blocks of eleven rows.** As a single 22-row block it
  cost about twice the page area of the figure it replaced; side by side it
  costs the same. The rank-by-RES column went with it: the rows are in RES
  order, so that column was restating the ordering.

## Fixed after the fourth render

- **Panel (a) of Figure 3 was showing the wrong quantity.** It plotted realized
  density over TARGET density, and that ratio carries a large effect common to
  every method: the injected count is an integer, so how far it lands from the
  target swings the ratio from about 1.22 in the lowest noise bin to 0.83 in
  the highest. The panel's subject — the one to two per cent by which the
  extending methods sit below the rest — is twenty times smaller, so all five
  curves drew on top of one another and the figure showed a property of the
  noise grid. Dividing by the unextended methods bin for bin cancels the common
  term and leaves exactly the quantity of Lemma 1: each extending method is a
  flat line at its own bandwidth efficiency. Tightening the axis was not enough
  on its own and would not have been honest either — the curves really were
  indistinguishable on that ratio.
  *Later correction:* the "integer count" explanation of the 1.22 -> 0.83 swing
  is not established and has been taken out of the Fig. 3 caption; see
  `check_noise_fidelity` at the top of this file.

## Fixed after the fifth render

- **Fig. 4's "monotone in B" line contradicted the manuscript**, and the fault
  was the test: strict monotonicity counts a 0.005 dip inside giniLoad's
  plateau as a violation, so it printed NO for all five and distinguished
  nothing. The quantity that separates them is the largest fall BEFORE the
  peak — giniLoad 0.000, meanMaxCW 0.024, maxErrCW 0.033, overT 0.040,
  cvLoad 0.229. Only cvLoad swings, which is what the paper claims; overT
  peaks and then falls, which is the saturation the paper reports as a finding
  and not a defect. The column now says which of the three shapes each curve
  has.
- **Fig. 2 carried the same note twice.** The highlighted cell said "vacant in
  the published suite" above the metrics and "occupied here (Section VI-G)"
  below them; the five printed names already say the second. The first stays —
  it is the reason the cell is highlighted — and the section pointer lives in
  the caption.

## Fixed after the sixth render

- **Fig. 2 used "vacant" for two different things.** The highlighted cell was
  empty in the published suite [2] and is filled here; the lower-left cell is
  empty and stays empty. Both carried the same word, and the note on the
  highlighted one — "vacant in the published suite" — was the paper's coined
  term, which a reader of the figure alone cannot decode. The highlighted cell
  now says "none in [2]; introduced here", the other says "(none)", and the
  caption explains the difference.

## Fixed after the seventh run

- **fig2_taxonomy stopped with `vertcat: dimensions not consistent`.** My edit
  put a comment-only line inside the cell literal, after a `...`. A
  comment-only line ends the continuation, its newline becomes a row
  separator, and the second row came out one cell short. `mcheck.py` now
  catches exactly this, and the rule is written above the literal.
- **Figure 3 now lands in `./figures` as `fig3_cnn`**, beside the other six,
  instead of `<dataPath>\figs\fig3_cnn_<sweep tag>`. The condition it was
  drawn from is printed rather than encoded in the file name. `opts.figPath`
  and `opts.stem` override both.
- **The "axes toolbar" export warning is gone**: the toolbar is hidden on
  every axes before `fig_style` writes the files.

## Known deviations from the previous artwork

`fig_cnn_justification` was drawn at 1020 by 440 pixels with 12 pt text and
scaled on insertion. It is now drawn at 7.16 by 3.0 inches with the house
sizes, and its axes carry the shared style, so its box and tick direction have
changed. The data and the panels are untouched.
