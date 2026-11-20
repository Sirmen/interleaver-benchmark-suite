# Interleaver Benchmark Suite

Code for

> Refik Tanju Sirmen, "A Code-Aware Evaluation Framework for Interleavers Under
> Burst Errors: Metric Taxonomy, Validation, and Parameter Provenance,"
> manuscript, 2026.

This package regenerates every permutation, metric value, table and figure in
the paper and in its Supplementary Material. It holds four things:

- the interleaver implementations, each with the parameter rule it uses and
  the source of that rule;
- the grid generator and the precomputed permutation tables;
- the metric implementations;
- the simulation harness, the campaign drivers and the analysis scripts.

The campaign data are archived separately on Zenodo, because they are too
large for git:

- code, this repository, archived: https://doi.org/10.5281/zenodo.23170142
  (the concept DOI: it always resolves to the latest version, and every
  version has its own DOI on that page. The paper cites the exact version
  and commit it used.)
- campaign data: https://doi.org/10.5281/zenodo.23136340
  (the concept DOI of the data record. Version 2.0.0 holds the primary
  campaign, the five further campaigns of Section 8.9 and the
  Supplementary Material; version 1.0.0 holds the primary campaign only.)

## What changed in 1.1.0

Release 1.1.0 adds what is needed to rerun and reanalyze the five further
campaigns of Section 8.9 (RS (31, 21), RS (24, 16), RS (15, 11), RS (15, 7),
and RS (15, 9) below capacity): the shortened Reed–Solomon code, the campaign
modes of `configure_simulation`, the drivers in `harness/campaigns/`, the
permutations at their lengths in `tables/table_factors_precomputed.mat`, and
`analysis/further_campaigns.m`. No number reported for the primary campaign
changes; `reproduce_paper` reproduces it from the archive of release 1.0.x
as before.

## Requirements

- MATLAB with the Communications Toolbox, the Statistics and Machine Learning
  Toolbox and the Signal Processing Toolbox. The campaigns and every figure
  were produced on MATLAB 25.2; no earlier release has been tested.
  `exportgraphics`, which the figure export uses, needs R2020a or later, so
  that is a lower bound on the figure path rather than a tested one.
  MATLAB's dependency resolver also names the Symbolic Math and Mapping
  Toolboxes, because `divisors` and `distance` exist in both. Neither is
  needed. Three names in this repository share a name with an installed
  toolbox: `divisors` (`common/octave_compat/`, also in Symbolic Math),
  `distance` (`common/`, also in Mapping) and `calculateSNR` (`common/`, also
  in the Mixed-Signal Blockset). The copies here are the ones the campaigns
  ran with. `setup_paths` puts the repository in front of the rest of the
  path so they keep winning, and `check_path_shadowing` refuses to run if any
  of them resolves elsewhere.
- Disk space for the campaign data; the file sizes are listed on the data
  record.
- `factors.mat`, the precomputed divisor table (235 MB), is archived with the
  campaign data rather than here, because it exceeds GitHub's per-file limit.
  It is optional: `PrimeFactorLoader` runs without it, and snake, algebraic
  and S then compute their own divisor pairs. `verify_tablefree_equivalence`
  found the two paths identical at every length of the primary grid. To use
  the cache, put it in `tables/` beside `table_factors_precomputed.mat`.
- `tables/table_factors_precomputed.mat` is about 52 MB, so GitHub prints a
  large-file warning when it is pushed or cloned. That is expected.
- The KPI tables are also provided as gzip CSV, so the data can be read
  without MATLAB.
- Python 3 with NumPy, SciPy and h5py for the optional checks listed below.
- A campaign takes several hours on one desktop. None is needed to reproduce
  the paper: the analysis runs on the archived data.

## Layout

```
harness/            simulation harness: configuration, grid, noise generation, sweep driver
harness/campaigns/  drivers of the five further campaigns (Section 8.9)
interleavers/       one folder per interleaver family (int_S, int_arp, int_drp, ...)
metrics/            metric implementations (Section 6 of the paper)
common/             shared numeric helpers and the Reed-Solomon codec wrappers
tables/             precomputed permutation and factor tables
health/             campaign health checks H0-H6 and their self-test (Supplementary Section S4)
analysis/           scripts that produce the tables and figures of the paper
analysis/python/    cell_checks.py: the cell-level checks of Sections 8.1, 8.7, 8.8 and 8.9
plotting/           the campaign's own diagnostic plots, not the paper's figures
zenodo_dataset/     scripts that build and audit the archived data package
figures/            where the figure scripts write; regenerated, not shipped
setup_paths.m       adds everything above to the MATLAB path
reproduce_paper.m
```

## Reproducing the paper from the archived data

Download the data record into `data/`: the primary-campaign files into
`data/results/`, and each `campaign_<code>.zip` unzipped into `data/campaigns/`,
so that `data/campaigns/code31/`, `data/campaigns/c15t2/` and so on exist.
Then:

```matlab
setup_paths
reproduce_paper(fullfile(pwd, 'data'))
```

A folder holding the primary files directly, as in release 1.0.x, is also
accepted; the further campaigns are then looked for in `opts.campaignRoot`,
and skipped with a note if it is not given.

`reproduce_paper` runs, in order:

0. `check_path_shadowing`, which stops if any file of this release is shadowed
   by a copy elsewhere on your path, or appears twice inside the release;
1. the noise-fidelity check (Section 7.2);
2. the kappa sensitivity (Section 8.7);
3. the metric scorecard (Table 4, and Table S2, its full form);
4. the validation supplement and the target sensitivity (Table S3);
5. the structural screen at N = 1200 and 1440 (Table S1);
6. the five further campaigns (Table 6 and the ratios of Section 8.9);
7. Figures 1-6, and the table of the RES decomposition of Section 10.2;
8. the command that runs `analysis/python/cell_checks.py` on the same data.

Script names keep the numbering of release 1.0.x: `fig7_bracket` draws
Figure 6, and `fig6_resdecomp` prints the decomposition that Section 10.2
reports in the text, without drawing it. `analysis/FIGURES_README.md` maps
every script to its figure.

Figures go to `./figures` as PDF, EMF (on Windows) and 600 dpi PNG; logs of
the target sensitivity go to `./campaign_logs`. The bootstrap is seeded, so
the confidence intervals reproduce to the last digit.

### Optional checks without MATLAB

Four Python scripts re-derive claims in a language the harness does not
share, so that a helper common to both cannot make a wrong rule look right:

- `analysis/python/cell_checks.py`: the null calibration of θ and Kendall's τ
  (Section 8.1), one method family left out (8.7), the between-metric and
  partial associations (8.8), and C5 against the number of lengths and of
  codewords (8.9). `reproduce_paper` prints the command that runs it.
- `harness/int_utils/verify_c5_threshold.py`: recomputes Table 4's
  association, pass and IQR columns from the campaign files and sweeps the C5
  threshold, reporting every value at which a verdict changes.
- `harness/int_utils/verify_table13_averaging.py`: recomputes the per-trial
  columns of the per-method reference table of release 1.0.x (archived with
  the data; the current article does not print it).
- `interleavers/int_arp/verify_arp_search.py`: checks every row of
  `ARP_SEARCH_RESULTS.txt` by brute force over all index pairs, using none of
  the residue-class shortcut that makes `arp_derived_search.c` feasible. It
  needs a compiled `arp_derived_search`.

Nothing in the suite depends on them.

## Running a campaign

```matlab
setup_paths
verify_setup(find_table_dir())  % file versions, grid, table coverage, permutations
run_simulations_sci             % grid and burst regime chosen in configure_simulation
```

`verify_setup` wants the table directory, the one holding
`table_factors_precomputed.mat` (`tables/` here), not a results directory.

Results go to `SINT_RESULTS` if that environment variable is set; the
further campaigns write to `SINT_CAMPAIGNS/<code>` (default: a `campaigns`
folder beside the results folder, which is `data/campaigns/<code>` when
neither variable is set), and their drivers write logs and a status file to
`SINT_LOGS` (default `./campaign_logs`). `harness/campaigns/code2_run_all`
runs table check, smoke test, sweeps and analysis for each further campaign
in turn. The primary campaign draws the substituted error values per method,
as release 1.0.x did; the further campaigns draw them once per trial and
share them across methods (Sections 7.4 and 8.9). `configure_simulation`
sets this per mode.

After regenerating any permutation table, call `clearHarnessCaches`: four of
the loaders cache by directory path.

## Evaluating an interleaver the paper does not contain

Follow Section 10 of the paper:

1. Screen the method structurally with `screen_methods`.
2. Record the provenance of every parameter.
3. Fix the design.
4. Run the health checks.
5. Read each design metric against the identity-to-random bracket (`fig7_bracket`).

## Parameter provenance

Every method's structure source and parameter source are listed in Table 1 of
the paper and in the header of its implementation, with its tier: published
values at the length (PV), a published rule applied and declared (PR), or
parameters the benchmark derived by a declared search (BD). Results obtained
with BD parameters are reported as such. ARP runs only at the eight IEEE
802.16 block sizes where its parameters are published, and returns an error
elsewhere by design. Its table is read from IEEE Std 802.16-2017, clause
8.4.9.2.3.2; `verify_arp_table` re-checks every published row and reproduces
the audit counts of Section 3.3 and Supplementary Section S5.

## License

The code is under the MIT license (see `LICENSE`). The campaign data on
Zenodo are under CC BY 4.0.

## Citation

See `CITATION.cff`. Please cite both the paper and the archived release you used.
