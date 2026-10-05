# Campaign data for "Code-Aware Interleaver Metrics on Burst-Error Channels"

Campaign data for:

> R. T. Sirmen, "Code-Aware Interleaver Metrics on Burst-Error Channels: Reed–Solomon Benchmark
> Validation and Parameter Provenance," 2026.

Eight sweeps: four burst regimes (single, multi, Gilbert–Elliott e_B = 1.00, Gilbert–Elliott
e_B = 0.70) run on each of two length grids (common: 50 lengths; standards: the eight IEEE 802.16
ARP block sizes). Every sweep visits each length at five noise targets with 35 Monte Carlo runs per
cell: 8 750 trials per method on the common grid and 1 400 on the standards grid, which is
1.02 million trial records over the four regimes, of which 0.94 million are in the scope of the
validation.

The archive contains every method the paper reports, and no others.

This record: https://doi.org/10.5281/zenodo.23136341
Code: https://doi.org/10.5281/zenodo.XXXXXXX (GitHub: [URL])

## Files, per sweep `<regime>_<grid>_<date>_<n>`

| File | Content |
|---|---|
| `KPItableDetailed_*.mat` | one row per (method, length, noise bin, run): CR, BE, RES and its parts, noiseActual, noiseBin, encodedLen, interleavedLen, … (MATLAB table) |
| `KPItableDetailed_*.csv.gz` | the same rows, as CSV, for use without MATLAB |
| `correlation_data_*.mat` | per-trial metric values used by the validation (Section VIII) |
| `config_*.mat` | the configuration the sweep ran with (grid, noiseLevels, regime) |
| `params_*`, `paramsInt_*`, `burstConfig_*` | the simulation, interleaver and burst parameters of the sweep |
| `crossCorrResults_*` | the cross-correlation summaries, as .mat and as text |
| `standardization_constants.csv` | per condition, the in-scope mean and standard deviation of CR and BE behind CR_z, BE_z and RES |
| `design_cells_v2.csv`, `KPI_SCOPE.txt`, `sweep_manifest.txt`, `analysis_*.txt` | the design grid, the scope declaration, which file came from which sweep, and the analysis logs |

The raw per-trial simulation state (`results_*.mat`, 43 GB) is not archived. Every number the paper
reports is computed from the KPI tables above; the raw state is available from the author on
request.

## Things to know before using the data

- **Gilbert–Elliott sweeps.** The five noise targets do not set the realized density: every bin
  realizes about 0.22 (paper, Section IX-A). Treat the bins there as replicates at one density.
- **Pairing.** Within a trial, every method sees the same burst mask. Pair on the encoded-length
  and trial columns, never on row order.
- **In-scope field.** CR_z, BE_z and RES are standardized over the in-scope methods, which is every
  method except freqDeterm and freqRandom: 23 of the 25 on the common grid and 24 of the 26 on the
  standards grid. Both are present in the files and are out of scope by the screen of Section III-I.
  `KPI_SCOPE.txt` records the standardization as it was applied, and
  `standardization_constants.csv` gives the constants, so the z-columns can be checked without
  recomputing them.
- **CR is clamped at zero** (paper, Section X-H).

## License

CC BY 4.0.

## Reproducing the paper

Unzip into `data/results/` of the code repository, then:

```matlab
setup_paths
reproduce_paper(fullfile(pwd, 'data', 'results'))
```
