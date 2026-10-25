# Interleaver Benchmark Suite

Code for

> Refik Tanju Sirmen, "Code-Aware Interleaver Metrics for Burst-Error Channels:
> Taxonomy and Validation on a Provenance-Governed Benchmark,"
> arXiv:XXXX.XXXXX, 2026.

This package regenerates every permutation, metric value, table and figure in
the paper. It holds four things:

- the interleaver implementations, each with the parameter rule it uses and
  the source of that rule;
- the grid generator and the precomputed permutation tables;
- the metric implementations;
- the simulation harness and the analysis scripts.

The campaign data (the eight sweeps the paper reports) are archived
separately on Zenodo, because they are too large for git:

- code, this repository, archived: https://doi.org/10.5281/zenodo.23170142
  (the concept DOI: it always resolves to the latest version, and every
  version has its own DOI on that page. The paper cites the exact version
  and commit it used.)
- campaign data: https://doi.org/10.5281/zenodo.23136341

## Requirements

- MATLAB with the Communications Toolbox, the Statistics and Machine Learning
  Toolbox and the Signal Processing Toolbox. The campaign and every figure were
  produced on MATLAB 25.2; no earlier release has been tested. `exportgraphics`,
  which the figure export uses, needs R2020a or later, so that is a lower bound
  on the figure path rather than a tested one.
  MATLAB's dependency resolver also names the Symbolic Math and Mapping Toolboxes,
  because `divisors` and `distance` exist in both. Neither is needed. Three names
  in this repository share a name with an installed toolbox — `divisors`
  (`common/octave_compat/`, also in Symbolic Math), `distance` (`common/`, also in
  Mapping) and `calculateSNR` (`common/`, also in the Mixed-Signal Blockset) — and
  the copies here are the ones the campaign ran with. `setup_paths` puts the
  repository in front of the rest of the path so they keep winning, and
  `check_path_shadowing` refuses to run if any of them resolves elsewhere.
- About 530 MB of free disk space for the campaign data (the Zenodo archive is 79 files, 529 MB).
- `factors.mat`, the precomputed divisor table, comes with the campaign data archive rather
  than with this repository: at 235 MB it exceeds GitHub's per-file limit. Put it in `tables/`
  beside `table_factors_precomputed.mat`, or anywhere `find_table_dir` looks. Nothing runs
  without it, including the analysis on archived data.
  The KPI tables are also provided as gzip CSV, so the data can be read
  without MATLAB.
- The full campaign (eight sweeps) takes several hours on one desktop. It is
  not needed to reproduce the paper: the analysis runs on the archived data.

## Layout

```
harness/        simulation harness: configuration, grid, noise generation, sweep driver
interleavers/   one folder per interleaver family (int_S, int_arp, int_drp, ...)
metrics/        metric implementations (defined in Section 6 of the paper)
common/         shared numeric helpers and the Reed-Solomon codec wrappers
tables/         precomputed permutation and factor tables
health/         campaign health checks H0-H6 and their self-test (Appendix B)
analysis/       scripts that produce the tables and figures of the paper
plotting/       the campaign's own diagnostic plots, not the paper's figures
zenodo_dataset/ scripts that build and audit the archived data package
figures/        where the figure scripts write; regenerated, not shipped
setup_paths.m   adds everything above to the MATLAB path
reproduce_paper.m
```

Three optional Python scripts re-derive single claims without MATLAB, so that
a helper shared with the harness cannot make a wrong rule look right:
`harness/int_utils/verify_c5_threshold.py` recomputes Table 8's association,
pass and IQR columns from the raw campaign files and then sweeps the C5
threshold, reporting every value at which a verdict would change;
`harness/int_utils/verify_table13_averaging.py` recomputes Table 13's
per-trial columns to test the averaging rule and scope filter its caption
states; and `interleavers/int_arp/verify_arp_search.py` checks every row of
`ARP_SEARCH_RESULTS.txt` by brute force over all index pairs, using none of
the residue-class shortcut that makes `arp_derived_search.c` feasible, which
covers the long lengths `verify_arp_table` cannot reach in MATLAB. They need
Python 3 with h5py and NumPy, SciPy for the first, and a compiled
`arp_derived_search` for the third. Nothing in the suite depends on them.

## Reproducing the paper from the archived data

```matlab
setup_paths
dataDir = fullfile(pwd, 'data', 'results');   % unzip the Zenodo data here
reproduce_paper(dataDir)
```

`reproduce_paper` runs, in order:

0. `check_path_shadowing`, which stops if any file of this release is shadowed by
   a copy elsewhere on your path, or appears twice inside the release. A number
   nobody can attribute to a specific file is not reproducible;
1. the noise-fidelity check (Section 7.3);
2. the kappa sensitivity (Section 8.7);
3. the metric scorecard (Table 8);
4. the structural screen (Table 5);
5. the seven figures.

It writes the figures to `./figures` as PDF, EMF (on Windows) and 600 dpi PNG.
The bootstrap is seeded, so the confidence intervals reproduce to the last digit.

## Running a new campaign

```matlab
setup_paths
verify_setup(find_table_dir())  % file versions, grid, table coverage, permutations
run_simulations_sci             % grid and burst regime chosen in configure_simulation
```

`verify_setup` wants the TABLE directory — the one holding
`table_factors_precomputed.mat`, which in this repository is `tables/` — and
not the results directory. The two look alike and are not, which is what
`find_table_dir` exists to settle; passing a results folder makes the table
coverage check fail on a tree that is in fact complete.

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
the paper and in the header of its implementation. Tier 2 methods (parameters
derived by a declared rule) are reported separately from Tier 1 (canonical,
parameter-free) and Tier 3 (published parameters). ARP runs only at the eight
IEEE 802.16 block sizes where its parameters are published, and returns an
error elsewhere by design. Its table is read from IEEE Std 802.16-2017,
clause 8.4.9.2.3.2; `verify_arp_table` re-checks every published row and
reproduces the audit counts of Section 3.3.

## License

The code is under the MIT license (see `LICENSE`). The campaign data on
Zenodo are under CC BY 4.0.

## Citation

See `CITATION.cff`. Please cite both the paper and the archived release you used.
