# Interleaver Benchmark Suite

Code for

> R. T. Sirmen, "Reproducibility in Interleaver Benchmarking: A Validated
> Evaluation Suite with Metric Taxonomy and Parameter Provenance," arXiv:XXXX.XXXXX, 2026.

This package regenerates every permutation, metric value, table and figure in
the paper. It holds four things:

- the interleaver implementations, each with the parameter rule it uses and
  the source of that rule;
- the grid generator and the precomputed permutation tables;
- the metric implementations;
- the simulation harness and the analysis scripts.

The campaign data (the eight sweeps the paper reports) are archived
separately on Zenodo, because they are too large for git:

- code, this repository, archived release: https://doi.org/10.5281/zenodo.XXXXXXX
- campaign data: https://doi.org/10.5281/zenodo.23136341

## Requirements

- MATLAB R2020a or later, with the Communications Toolbox, the Statistics and Machine
  Learning Toolbox and the Signal Processing Toolbox.
  MATLAB's dependency resolver also names the Symbolic Math and Mapping Toolboxes,
  because `divisors` and `distance` exist in both. Neither is needed. Three names
  in this repository share a name with an installed toolbox — `divisors`
  (`common/octave_compat/`, also in Symbolic Math), `distance` (`common/`, also in
  Mapping) and `calculateSNR` (`common/`, also in the Mixed-Signal Blockset) — and
  the copies here are the ones the campaign ran with. `setup_paths` puts the
  repository in front of the rest of the path so they keep winning, and
  `check_path_shadowing` refuses to run if any of them resolves elsewhere.
  R2020a is the first release with `exportgraphics`; on older releases the
  figures fall back to `print`.
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
metrics/        metric implementations (the call site is listed in Section V-A of the paper)
tables/         precomputed permutation and factor tables
health/         campaign health checks H0-H6 and their self-test (Section XI-B)
analysis/       scripts that produce the tables and figures of the paper
setup_paths.m   adds everything above to the MATLAB path
reproduce_paper.m
```

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
1. the noise-fidelity check (Section IX-A);
2. the kappa sensitivity (Section VIII-G);
3. the metric scorecard (Table IX);
4. the structural screen (Table VI);
5. the seven figures.

It writes the figures to `./figures` as PDF, EMF (on Windows) and 600 dpi PNG.
The bootstrap is seeded, so the confidence intervals reproduce to the last digit.

## Running a new campaign

```matlab
setup_paths
verify_setup(dataDir)          % file versions, grid, tables, permutation integrity
run_simulations_sci            % grid and burst regime chosen in configure_simulation
```

After regenerating any permutation table, call `clearHarnessCaches`: four of
the loaders cache by directory path.

## Evaluating an interleaver the paper does not contain

Follow Section XI of the paper:

1. Screen the method structurally with `screen_methods`.
2. Record the provenance of every parameter.
3. Fix the design.
4. Run the health checks.
5. Read each design metric against the identity-to-random bracket (`fig7_bracket`).

## Parameter provenance

Every method's structure source and parameter source are listed in Table I of
the paper and in the header of its implementation. Tier 2 methods (parameters
derived by a declared rule) are reported separately from Tier 1 (canonical,
parameter-free) and Tier 3 (published parameters). ARP runs only at the eight
IEEE 802.16 block sizes where its parameters are published, and returns an
error elsewhere by design.

## License

The code is under the MIT license (see `LICENSE`). The campaign data on
Zenodo are under CC BY 4.0.

## Citation

See `CITATION.cff`. Please cite both the paper and the archived release you used.
