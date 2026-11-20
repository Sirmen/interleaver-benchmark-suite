# Campaign data for "A Code-Aware Evaluation Framework for Interleavers Under Burst Errors"

Campaign data for:

> Refik Tanju Sirmen, "A Code-Aware Evaluation Framework for Interleavers Under Burst Errors:
> Metric Taxonomy, Validation, and Parameter Provenance," manuscript, 2026.

Version 2.0.0 holds the primary campaign of version 1.0.0, unchanged, and adds the five further
campaigns of Section 8.9 and the Supplementary Material of the article. Together they hold
4.97 million trial records.

**Primary campaign, RS (15, 9).** Eight sweeps: four burst regimes (single, multi, Gilbert–Elliott
e_B = 1.00, Gilbert–Elliott e_B = 0.70) run on each of two length grids (common: 50 lengths;
standards: the eight IEEE 802.16 ARP block sizes). Every sweep visits each length at five noise
targets with 35 Monte Carlo runs per cell: 8 750 trials per method on the common grid and 1 400 on
the standards grid, which is 1.02 million trial records over the four regimes.

**Further campaigns.** Each is a configuration of its own, analysed as the primary one, with the
same 35 runs per cell, five densities and in-scope standardization:

| Campaign | Code | t | Lengths | Conditions | Trial records |
|---|---|---|---|---|---|
| `code31` | RS (31, 21) over GF(2^5) | 5 | 23: N = 124m, m = 1…24 except 15 (124 to 2976) | 4 regimes, one grid; no ARP | 402 500 |
| `code24` | RS (24, 16), RS (31, 23) shortened by 7 | 4 | 28: N = 24c, 144 to 2952 | 4 regimes, one grid; no ARP | 490 000 |
| `c15t2` | RS (15, 11) | 2 | the primary grids | 8 (4 regimes × 2 grids) | 1 020 600 |
| `c15t4` | RS (15, 7) | 4 | the primary grids | 8 | 1 020 600 |
| `c15lo` | RS (15, 9), density band [0.50, 0.90]τ | 3 | the primary grids | 8 | 1 020 600 |

The lengths of `code31` and `code24` share none with another code's grid, because the permutation
table is keyed by length. In `c15t2` and `c15t4` the message length is set so that the encoded
lengths, and with them every permutation, are those of the primary campaign.

The archive contains every method the article reports, and no others.

This record (concept DOI, all versions): https://doi.org/10.5281/zenodo.23136340
Code: https://doi.org/10.5281/zenodo.23170142 (GitHub: https://github.com/Sirmen/interleaver-benchmark-suite)

## Files

### Primary campaign: the files at the top level, as in version 1.0.0

Per sweep `<regime>_<grid>_<date>_<n>`:

| File | Content |
|---|---|
| `KPItableDetailed_*.mat` | one row per (method, length, noise bin, run): CR, BE, RES and its parts, noiseActual, noiseBin, encodedLen, interleavedLen, … (MATLAB table) |
| `KPItableDetailed_*.csv.gz` | the same rows, as CSV, for use without MATLAB |
| `correlation_data_*.mat` | per-trial metric values used by the validation (Section 8) |
| `config_*.mat` | the configuration the sweep ran with (grid, noise levels, regime) |
| `params_*`, `paramsInt_*`, `burstConfig_*` | the simulation, interleaver and burst parameters of the sweep |
| `crossCorrResults_*` | the cross-correlation summaries, as .mat and as text |

And once:

| File | Content |
|---|---|
| `factors.mat` | the precomputed divisor table (235 MB). Optional: the code runs without it, and `PrimeFactorLoader` names the methods that then compute their own values. Put it in `tables/` of the software record to use the cache |
| `standardization_constants.csv` | per condition, the in-scope mean and standard deviation of CR and BE behind CR_z, BE_z and RES |
| `design_cells_all_n15.csv` | new in 2.0.0: the design-time statistics per (method, length) cell, the load statistics, B_guar and esLoad included; read by `cell_checks.py` |
| `design_cells_v2.csv`, `KPI_SCOPE.txt`, `sweep_manifest.txt`, `analysis_*.txt` | the design grid, the scope declaration, which file came from which sweep, and the analysis logs |

### Further campaigns: `campaign_<code>.zip`

Each zip holds one folder, `<code>/`, with the files above for its sweeps (the KPI tables as .mat
and .csv.gz, `correlation_data_*`, `config_*`, `params_*`, `paramsInt_*`, `burstConfig_*`,
`crossCorrResults_*`) and its own `standardization_constants.csv`, `KPI_SCOPE.txt`,
`sweep_manifest_<code>.txt`, `design_cells_all_*.csv`, `design_cells_supplement.csv` and
`scorecard_metrics.csv`.

### `Supplementary_Material.pdf`

The Supplementary Material of the article: the structural screen (S1), the full verdict table
(S2), the sensitivity table (S3), the health-validation procedure (S4), the ARP and DRP audit
details (S5) and the repair of Gilbert–Elliott masks (S6).

The raw per-trial simulation state (`results_*.mat`) is not archived. Every number the article
reports is computed from the files above; the raw state is available from the author on request.

## Things to know before using the data

- **Gilbert–Elliott sweeps.** The realized density follows its target: in every bin of all eight
  primary sweeps, the mean realized density lies within 0.5% of the target (κ from 0.995 to 1.003;
  article, Section 7.2). Version 1.0.0 of this README said that every bin realizes about 0.22.
  That described an earlier, superseded campaign, not the archived one, and is corrected here.
- **Pairing.** Within a trial, every method sees the same burst mask. Pair on the encoded-length
  and trial columns, never on row order.
- **Error values.** In the primary campaign the substituted error values are drawn per method; in
  the further campaigns they are drawn once per trial and shared by every method (article,
  Sections 7.4 and 8.9).
- **Shortened code.** In `code24`, the a posteriori metrics use the delivered 24-symbol codewords
  and t = 4, as the decoder does.
- **In-scope field.** CR_z, BE_z and RES are standardized over the in-scope methods, which is every
  method except freqDeterm and freqRandom. Both are present in the files and are out of scope by
  the structural screen of Section 3.5. `KPI_SCOPE.txt` records the standardization as it was
  applied, and `standardization_constants.csv` gives the constants, so the z-columns can be
  checked without recomputing them.
- **CR is floored at zero** (article, Section 6.2).

## License

CC BY 4.0.

## Reproducing the article

Put the top-level files into `data/results/` of the code repository and unzip each
`campaign_<code>.zip` into `data/campaigns/`, then:

```matlab
setup_paths
reproduce_paper(fullfile(pwd, 'data'))
```

`reproduce_paper` ends by printing the command that runs `analysis/python/cell_checks.py` on the
same folders.
