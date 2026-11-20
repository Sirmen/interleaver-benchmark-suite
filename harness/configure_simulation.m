function [config, params] = configure_simulation()
% Initialize all configuration parameters with a focus on consolidated core metrics

   config = struct();
   params = struct();
   
   % Basic parameters
   config.version = "40.0";
   config.base = 10;
   config.Dim = 1; % data dimension
   config.padSymbol = config.base - 1;
   config.alpha = 0.05; 
   
   % Size range parameters
   % These three describe the LEGACY arithmetic grid. They are still honoured
   % whenever config.sizeList is empty. The grid selector near the end of this
   % file normally sets sizeList instead - see there for why.
   config.sizeMin = 10;   % corresponds to encoded len 30
   config.sizeMax = 1000; % corresponds to encoded len 1680
   config.sizeStep = 1;
   config.sizeTestMode = 'range';

   % Explicit message-length list. Empty -> sizeMin:sizeStep:sizeMax.
   % Set by the grid selector below; getSizeList is the single reader, shared
   % by run_simulations_sci and PrecomputeInterleaversGenerator so the sweep
   % can never ask the table for a length the table was not built for.
   config.sizeList = [];

   % Extra ENCODED lengths the permutation table must carry, on top of
   % whatever the current FEC produces from sizeList.
   %
   % The table is keyed by encoded length, not by message length, so changing
   % the FEC moves every key: RS(15,9) sends K = 36m to L = 60m, while an
   % LDPC(n,k) sends the same K to ceil(K/k)*n. A table built for one code has
   % none of the other code's lengths, and the sweep then either regenerates
   % live or fails, method by method.
   %
   % Building an extra length costs generator time once and costs the sweep
   % nothing, so the union is built now rather than after the LDPC decision.
   % The values below are the IEEE 802.16e LDPC block lengths (576..2304 in
   % steps of 96). Three of them - 960, 1440 and 1920 - are simultaneously
   % multiples of 60 (so they sit on the common grid) AND rows of the 802.16
   % ARP table, which makes them the natural anchors for a standard-compliant
   % LDPC + ARP comparison.
   config.encodedLengthList = 576:96:2304;

   % FEC parameters
   config.eccMin = 1/7;                   % desired Min Err correction capability (e.g., ~14%)
   fecConfig = configure_FEC_parameters(config.base, config.eccMin);

   config.eccReal = fecConfig.eccReal;    % actual Err correction capability (e.g., 14%)
   config.FECn = fecConfig.n;                   % Codeword length (symbols)
   config.FECk = fecConfig.k;                   % Message length (symbols)
   config.FECp = fecConfig.p;                   % Parity symbols
   config.FECt_correct = fecConfig.t_correct;   % Correctable symbols per codeword
   config.FECoverhead = fecConfig.overhead;     % Fractional overhead
   % SHORTENED CODEWORD LENGTH, [] for the natural 2^m - 1 code. A grid mode
   % that wants a shortened code sets it and recomputes the FEC block; the
   % verification after the switch reads it, so a mode cannot set it and
   % forget to recompute.
   config.FECnShort = [];
   
   % Simulation parameters
   % FULL RUN. 35 gives 35 independent observations per (method, length,
   % noise) cell - the threshold you set for the statistics. It is affordable
   % now: the 60-multiple grid made a regime take ~2 minutes instead of hours,
   % so the binding constraint is disk, not time (see the note by saveResults).
   config.testRunsMax = 35;
   config.dataGenTryMax = 60;
   config.maxExtensionPercentage = 0.5; 
   config.extensionPercentage_S = 0.0; 
   
   % burst noise parameters
   config.singleBurst = true; %  false;
   config.noiseTryMax = 60;
   % THE BAND AS MULTIPLES OF tau = t/n, declared once. Every grid mode uses
   % [0.90 1.34] except the low-band modes 'c15loc'/'c15los', which set
   % [0.50 0.90]; the checks after the grid selector read this field, so a
   % mode cannot move the band without declaring it here.
   config.bandFactor = [0.90 1.34];
   config.noisyRateMin = config.eccReal * 0.90;
   config.noisyRateMax = config.eccReal * 1.34;
   config.noiseBins = 5; % set 3 for quick test
   config.noiseLevels = linspace(config.noisyRateMin, config.noisyRateMax, config.noiseBins);
   %  
   config.maxBurstCount = 3; % Maximum number of bursts in multi-burst mode

   % --- Gilbert-Elliott two-state Markov burst channel (journal version) ---
   % Set true to REPLACE the single/multi generator with a Markov chain, so
   % burst count, burst lengths and gaps are drawn rather than dictated. This
   % turns Sec. 2.2.3's "memoryless between bursts" ASSUMPTION into a tested
   % claim. config.singleBurst is ignored while this is on.
   % NOTE: "config.singleBurst is ignored" means that while GE is on, mask
   % generation does not READ singleBurst. It does NOT mean that singleBurst
   % turns GE off. The two are independent, and the regime selector below is
   % the single source of truth.
   config.gilbertElliott  = false;
   config.ge_errProbBad   = 1.0;  % 1.0 = solid bursts (matches single/multi);
                                  % 0.7 = fragmented bursts (fading flavour).
   config.ge_meanBurstLen = [];   % [] -> targetNoisyCount / (maxBurstCount*e_B)
   config.ge_maxDraws     = 50;   % redraws before the count is nudged in-band
   config.ge_bandMode     = 'target';  % accept within half a bin of the bin's
                                       % own target. 'grid' accepts anywhere in
                                       % the whole noise grid, which is what the
                                       % archived campaign did - see
                                       % configure_burst_parameters

   %%% --- METRICS ---
   config.KPImetrics = { ... % KPI metrics - Primary Performance (End-to-End Success)
     'RES', 'CR', 'effectiveness', ... % 'eta_ER', 'BE', ...
   };
   config.intMetrics = { ...
... % 1. ECC-Aware & Burst Distribution (Predictors of Collapse)
     'eta_ES', 'delta_BS', 'S_ECC', 'S_sf', ...
...  % 'eccViolations', 'eccUtilization', ...
     'V_ECC', 'U_ECC', ...
... % 2. Dispersion & Spreading (Geometric Quality)
     'S_factor', 'adjMin', 'sepMin', 'eta_sep', ...
... % 3. Structural Disorder (Spectral Integrity)
     'PSR', 'laplacianEnergy', 'delta_G', 'adjCV' ...     
   }; 
   config.distance2plot = union(config.KPImetrics, config.intMetrics);   

   % --- Correlation Parameters ---
   config.correlationVariables = config.intMetrics;
   config.pivotVariables = config.KPImetrics; % KPI metrics
   config.corr = true; 
   config.excludeZero = true;
   config.correlation = struct(...
     'corrType', 'both', ...
     'removeOutliers', false, ...
     'removeZeroPivot', false, ...
     'lvlSignificance', 0.01, ...
     'lvlConfidence', config.alpha, ...
     'lvlSignificanceOutliers', config.alpha ...
   );
    
   % --- Methods & Output ---
   % 'cross' renamed to 'snake': what the file implements is a boustrophedon
   % block interleaver, not the Ramsey/Forney convolutional cross interleaver
   % that the name denotes in coding theory.
   config.allIntMethods = {'random', 'matrix', 'helical', 'helicalScan', 'snake', ...
                           'spiral', 'diagonal', 'hierarchical', 'multiDim', 'latinSquare', ...
                           'time', 'freqRandom', 'freqDeterm', 'chaotic', 'prime', ...
                           'block', 'algebraic', 'turbo', 'convolutional', ...
                           'srandom', 'goldenRP', 'drp', 'arp', ...   % high-spread references
                           'blockCM', 'convCM', ...                   % code-matched classics
                           'S'};                                      % 26 methods
   % THE METHOD LIST. Two deliberate choices:
   %  * the list is exactly the 26 methods the paper reports.
   %  * 'blockCM' and 'convCM' are IN: the classical interleavers matched to
   %    the code, which a reviewer rightly asked for.
   %      blockCM  row-column block interleaver whose rows are the codewords
   %               (row length n = FECn), read column-wise: Forney's depth-I
   %               block interleaver with I = number of codewords in the frame.
   %               No free parameter once the code is fixed.
   %      convCM   the cyclic Ramsey/Forney convolutional interleaver of
   %               interleaver_convolutional with M = n branches and delay
   %               increment D = max(1, floor(K/n)), K = N/n codewords, so the n
   %               symbols of a codeword are spread over the whole frame. D is
   %               OUR declared rule (BD in the paper), not a published value.
   params.intMethods = config.allIntMethods;  
   params.topN = 10; % number of top performing methods

   % Where the sweeps write. Set SINT_RESULTS to put them somewhere else;
   % without it they land in data\results of this repository.
   dataSavePath = string(getenv('SINT_RESULTS'));
   if dataSavePath == "" || ismissing(dataSavePath)
      dataSavePath = string(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data', 'results'));
   end

   config.dataSavePath = dataSavePath;
   if ~exist(char(dataSavePath), 'dir'), mkdir(char(dataSavePath)); end

   % Where the further campaigns of Section 8.9 write, one folder per
   % campaign: under SINT_CAMPAIGNS if it is set, otherwise in a campaigns
   % folder beside the results folder (data/campaigns in this repository,
   % which is the layout reproduce_paper reads).
   campaignRoot = string(getenv('SINT_CAMPAIGNS'));
   if campaignRoot == "" || ismissing(campaignRoot)
      campaignRoot = string(fullfile(fileparts(char(dataSavePath)), 'campaigns'));
   end

   % The error VALUE at a corrupted position. 'legacy' draws it per method,
   % as the primary campaign did (article, Section 7.4); 'shared' draws one
   % additive error vector per trial for every method, as the further
   % campaigns did. The primary grid modes keep 'legacy' so that they
   % reproduce the archived campaign; the further-campaign modes set
   % 'shared' below. See injectBurstErrors_all.
   config.errorValueMode = 'legacy';

   config.saveResults = true;

   % PLOTTING OFF FOR THE SWEEP - ON PURPOSE, NOT AN OVERSIGHT.
   % The MATLAB crash on 2026-08-26 happened inside plot_all_results, which
   % main_simulation_wrapper runs AFTER save_results. Results survived; the
   % figures did not. Generating 20+ figure sets while a multi-GB results
   % struct is still resident is what exhausts memory, and none of it is part
   % of the sweep. Run the sweeps with this false, then produce figures in a
   % clean session from the saved tables.
   config.plotResults = false;

   % DISK BUDGET, so it is not a surprise afterwards:
   % results.stats_all holds one record per (method, length, noise, run), so
   % the common grid at testRunsMax = 35 is 23 x 50 x 5 x 35 = 201k records,
   % roughly 8 GB per regime and ~34 GB for four. If that is too much, drop
   % testRunsMax to 20 - twenty observations per cell is still ample and the
   % files halve. Most of that volume is redundant: the separation metrics
   % depend only on (method, length), so they are stored 175 times over.
   % Splitting permutation-only from trial-dependent statistics would cut it
   % by an order of magnitude, but that is a refactor for after the results
   % are in hand, not before.
   
   config.trackMethodCompatibility = false; % true;
   config.requireAllMethodsWork = true; 

   % PDFs
   config.allPDFs = {
     'Uniform', 'Gaussian', 'Exponential', 'Weibull', 'Rayleigh', ...
     'Gamma', 'Beta', 'Poisson', 'StudentsT', 'Logistic', 'LogLogistic', ...
     'Ushape', 'Zeta', 'Geometric', 'Bernoulli', 'Laplace', ...
     'Pareto', 'Triangular', 'LogNormal', 'Nakagami'
   };
   
   % Selected PDFs for this simulation
   params.dPDF = {'Uniform'}; % config.allPDFs

   % ---- REGIME SELECTOR: set it in one place only --------------------
   % Four runs, four values. While GE is on, singleBurst does not affect the
   % mask, but save_results and saveCrossCorrelationResults take the file
   % prefix from the tag derived here, so the regimes cannot run into each
   % other.
   %
   %   'multi'   -> config.singleBurst=false, GE off           -> prefix 'multi'
   %   'single'  -> config.singleBurst=true,  GE off           -> 'single'
   %   'ge1p00'  -> GE on, e_B = 1.0 (solid bursts)            -> 'ge1p00'
   %   'ge0p70'  -> GE on, e_B = 0.7 (fragmented bursts)       -> 'ge0p70'

   burstRegime = 'multi';    % <-- CHANGE THIS LINE AND NOTHING ELSE

   % A global override, so that a driver script (run_all_sweeps.m) can run the
   % eight sweeps in turn without editing this file. While the global is empty
   % this file remains the single source of truth: running it by hand changes
   % nothing.
   global TS_BURST_REGIME %#ok<GVMIS>
   if ~isempty(TS_BURST_REGIME), burstRegime = TS_BURST_REGIME; end

   switch burstRegime
      case 'single'
         config.singleBurst = true;  config.gilbertElliott = false;
      case 'multi'
         config.singleBurst = false; config.gilbertElliott = false;
      case 'ge1p00'
         config.singleBurst = false; config.gilbertElliott = true;
         config.ge_errProbBad = 1.0;
      case 'ge0p70'
         config.singleBurst = false; config.gilbertElliott = true;
         config.ge_errProbBad = 0.7;
      otherwise
         error('configure_simulation: unknown burstRegime "%s"', burstRegime);
   end
   config.burstRegime = burstRegime;   % kept on the record as well

   % ---- GRID SELECTOR: set it in one place only --------------------------
   % Three kinds of run. This selector sets the length list AND the method
   % list; the two are tied together, so do not change either of them by hand
   % on its own.
   %
   %   'common'     the common grid, 25 methods (arp EXCLUDED), 50 lengths
   %   'standards'  the standards-compliant subset, 26 methods (arp
   %                INCLUDED), 8 lengths
   %
   % The further campaigns of Section 8.9 (see the cases below):
   %   'code31'     the full common field on RS(31,21), 23 lengths
   %   'code24'     the full common field on the shortened RS(24,16), 28
   %                lengths
   %   'c15t2c' 'c15t2s' 'c15t4c' 'c15t4s'
   %                n = 15 with t = 2 or 4, on the common (c) or standards
   %                (s) grid, the same encoded lengths and permutations as
   %                'common' and 'standards'
   %   'c15loc' 'c15los'
   %                RS(15,9) on the common / standards grid with the density
   %                band at [0.50 0.90]*tau instead of [0.90 1.34]*tau
   % They are driven by the scripts in harness/campaigns (code2_run_all).
   %
   % WHY THE 'common' GRID IS K = 36*m
   % ---------------------------------------------------------------------
   % Under RS(15,9), K = 36m is exactly 4m codewords with ZERO PADDING, and
   % the encoded length is L = 60m. Multiples of 60 satisfy all four of the
   % following at once, which no arithmetic grid does:
   %
   %   L = 0 (mod 4)  the condition standardized ARP requires (ETSI EN 301
   %                  790: "N is a multiple of 4")
   %   4 | L          divides DRP's smallest published dither period; at
   %                  multiples of 120 it also divides 8, and 16 at
   %                  multiples of 240
   %   60 = 3*4*5     the three-dimensional lattice interleaver factors into
   %                  three dimensions at every length
   %   no padding     BE = 1 for every method, so bandwidth efficiency no
   %                  longer clouds the comparison
   %
   % It is also about 17 times cheaper than the old 991-length arithmetic
   % grid, where nine consecutive K fell on the same encoded length and the
   % same permutation was therefore paid for nine times.
   %
   % WHY 'standards' IS A RUN OF ITS OWN
   % ---------------------------------------------------------------------
   % The blocks in interleave_all_pc are guarded by an "&& (erM == "")"
   % chain: once one method fails, none of the later ones runs at all. That
   % is the CORRECT behaviour, because a trial is comparable only when every
   % method has seen the same burst realization. But arp returns an error by
   % design at any length where its parameters are not published - and the
   % arp block comes BEFORE the S block - so running arp on the common grid
   % would take S down with it in every trial. The answer is not to meddle
   % with the chain but to run arp separately, at its own lengths.
   %
   % The eight K below are the eight rows of the 802.16 table that are
   % multiples of 15, giving L = 120 180 240 480 960 1440 1920 2400.

   gridMode = 'common';    % <-- CHANGE THIS LINE AND NOTHING ELSE

   global TS_GRID_MODE %#ok<GVMIS>
   if ~isempty(TS_GRID_MODE), gridMode = TS_GRID_MODE; end

   switch gridMode
      case 'common'
         config.sizeList   = 36 * (1:50);          % L = 60, 120, ... 3000
         params.intMethods = config.allIntMethods(~strcmp(config.allIntMethods, 'arp'));
      case 'standards'
         config.sizeList   = [72 108 144 288 576 864 1152 1440];
         params.intMethods = config.allIntMethods;  % arp included
      case 'code31'
         % A SECOND CODE FOR THE METRIC VALIDATION, added 17 November 2026.
         % RS(31,21) over GF(32), t = 5, derived from eccMin = 1/7 on GF(32).
         % It carries the FULL common field: a metric is validated by how it
         % orders METHODS.
         %
         % THE GRID: K = 84*j message symbols, j = 1..24 except j = 15.
         %   84 = 4*21     four codewords, ZERO padding, encoded L = 124*j
         %   4 | L         drp is admissible at every length (its dither
         %                 period steps down 16 -> 8 -> 4 until one divides L)
         %   no padding    BE = 1 for every method that does not extend
         %   L <= 2976     the same range as the common grid (60..3000)
         %
         % j = 15 IS LEFT OUT ON PURPOSE. L = 1860 = 31*60 is also a length of
         % the RS(15,9) common grid, and the permutation table is keyed by the
         % encoded length ALONE. blockCM and convCM depend on n, so an entry
         % built here for n = 31 would collide with the n = 15 entry the
         % published campaign used. No other 124*j up to 2976 is a multiple of
         % 60, so no other key is shared with the published grids, and
         % code2_build_table refuses to merge if any shared key holds a
         % different permutation.
         config.base      = 32;                  % RS(31,21) over GF(32)
         config.padSymbol = config.base - 1;     % 31, a valid GF(32) element
         fec31 = configure_FEC_parameters(config.base, config.eccMin);
         config.eccReal      = fec31.eccReal;        % 5/31 = 0.16129
         config.FECn         = fec31.n;              % 31
         config.FECk         = fec31.k;              % 21
         config.FECp         = fec31.p;              % 10
         config.FECt_correct = fec31.t_correct;      % 5
         config.FECoverhead  = fec31.overhead;
         config.noisyRateMin = config.eccReal * 0.90;
         config.noisyRateMax = config.eccReal * 1.34;
         config.sizeList     = 84 * setdiff(1:24, 15);

         % NO EXTRA TABLE LENGTHS. The union list set near the top of this
         % file is for RS(15,9); building it here would build blockCM and
         % convCM at those lengths for n = 31.
         config.encodedLengthList = [];

         % The common field: every method except arp, which has published
         % parameters at none of these lengths and would abort every trial
         % (the && (erM == "") chain in interleave_all_pc).
         params.intMethods = config.allIntMethods(~strcmp(config.allIntMethods, 'arp'));

         config.saveRawResults = false;      % no results_*.mat (18 Nov 2026: disk)
         config.errorValueMode = 'shared';   % one error vector per trial (Section 8.9)
         config.dataSavePath = string(fullfile(char(campaignRoot), 'code31'));
         if ~exist(char(config.dataSavePath), 'dir')
            mkdir(char(config.dataSavePath));
         end

      case 'code24'
         % A THIRD CODE FOR THE METRIC VALIDATION, added 17 November 2026.
         % RS(24,16): RS(31,23) over GF(32) shortened by 7, t = 4. Against
         % RS(15,9) and RS(31,21) it changes the PARITY of n (even), the
         % construction (shortened) and t (4). The full common field, as in
         % 'code31'.
         %
         % THE GRID: K = 16*c message symbols, c codewords, ZERO padding,
         % encoded L = 24*c, 28 values of c from 6 to 123 (L = 144..2952), 23
         % of them above the common support N > 24n = 576. 8 | L, so drp is
         % admissible everywhere. c is NOT an arithmetic progression: every
         % value is chosen so that L shares no key of the permutation table
         % with another code's grid, because the table is keyed by L alone and
         % blockCM / convCM depend on n:
         %   c not a multiple of 5        L not a multiple of 60 (RS(15,9) grids)
         %   no c = 0 (mod 4), 24..96     L not in 576:96:2304 (the RS(15,9)
         %                                union list of encodedLengthList)
         %   c not a multiple of 31       L not a multiple of 124 ('code31')
         % code2_build_table refuses to merge if any shared key still holds a
         % different permutation.
         config.base      = 32;          % GF(32), mother RS(31,23)
         config.FECnShort = 24;
         config.eccMin    = 0.15;        % -> t = 4 at n = 24
         config.padSymbol = config.base - 1;
         fecS = configure_FEC_parameters(config.base, config.eccMin, config.FECnShort);
         config.eccReal      = fecS.eccReal;         % 4/24 = 0.16667
         config.FECn         = fecS.n;               % 24
         config.FECk         = fecS.k;               % 16
         config.FECp         = fecS.p;
         config.FECt_correct = fecS.t_correct;       % 4
         config.FECoverhead  = fecS.overhead;
         config.noisyRateMin = config.eccReal * 0.90;
         config.noisyRateMax = config.eccReal * 1.34;
         c24 = [6 11 14 19 23 27 33 37 41 46 49 54 58 63 67 71 74 79 83 89 ...
                94 97 101 106 109 114 119 123];
         config.sizeList          = 16 * c24;
         config.encodedLengthList = [];
         params.intMethods = config.allIntMethods(~strcmp(config.allIntMethods, 'arp'));
         config.saveRawResults = false;      % no results_*.mat (18 Nov 2026: disk)
         config.errorValueMode = 'shared';   % one error vector per trial (Section 8.9)
         config.dataSavePath = string(fullfile(char(campaignRoot), 'code24'));
         if ~exist(char(config.dataSavePath), 'dir')
            mkdir(char(config.dataSavePath));
         end

      case {'c15t2c', 'c15t2s', 'c15t4c', 'c15t4s'}
         % n = 15 HELD FIXED, t CHANGED, added 17 November 2026: the codes of
         % the metric validation so far change n and t together (RS(15,9),
         % RS(31,21), RS(24,16)), so a verdict that moves cannot be laid on
         % either. Here n stays 15 and only t moves, to 2 (RS(15,11)) and to
         % 4 (RS(15,7)), on both published grids.
         %
         %   c15t2c / c15t4c   the 'common' grid, 25 methods (arp excluded)
         %   c15t2s / c15t4s   the 'standards' grid, 26 methods (arp included)
         %
         % THE SAME ENCODED LENGTHS AS THE PUBLISHED CAMPAIGN. The message is
         % 4*k symbols per four codewords (44 at t = 2, 28 at t = 4), so the
         % common grid is again L = 60m and the standards grid again the eight
         % 802.16 rows L = 120 ... 2400, with zero padding. The permutation
         % table is keyed by L, and no method of the field reads t , so every permutation is the one
         % the published RS(15,9) campaign used: NOTHING is built for these
         % modes, and code2_check_table verifies the keys instead.
         %
         % base stays 10, as for RS(15,9): the same message alphabet and the
         % same padSymbol 9, so the only thing that differs from the published
         % campaign is the code.
         %
         % eccMin IS CHOSEN AWAY FROM A BOUNDARY. t = ceil(15*eccMin), and
         % 15*(2/15) may land a hair above 2 in binary (see the note in
         % configure_FEC_parameters), so 0.13 (15*0.13 = 1.95 -> t = 2) and
         % 0.25 (3.75 -> t = 4) are used, never 2/15 or 4/15. The checks after
         % the switch re-derive the code from eccMin and rebuild the band.
         c15t = str2double(gridMode(5));
         if c15t == 2, config.eccMin = 0.13; else, config.eccMin = 0.25; end
         fec15 = configure_FEC_parameters(config.base, config.eccMin);
         if fec15.n ~= 15 || fec15.t_correct ~= c15t
            error('configure_simulation: %s derived RS(%d,%d) t=%d, expected n = 15, t = %d.', ...
                  gridMode, fec15.n, fec15.k, fec15.t_correct, c15t);
         end
         config.eccReal      = fec15.eccReal;        % 2/15 = 0.1333 or 4/15 = 0.2667
         config.FECn         = fec15.n;              % 15
         config.FECk         = fec15.k;              % 11 or 7
         config.FECp         = fec15.p;
         config.FECt_correct = fec15.t_correct;      % 2 or 4
         config.FECoverhead  = fec15.overhead;
         config.noisyRateMin = config.eccReal * 0.90;
         config.noisyRateMax = config.eccReal * 1.34;
         if gridMode(end) == 'c'
            config.sizeList   = 4 * fec15.k * (1:50);                      % L = 60m, as 'common'
            params.intMethods = config.allIntMethods(~strcmp(config.allIntMethods, 'arp'));
         else
            config.sizeList   = fec15.k * [8 12 16 32 64 96 128 160];      % L as 'standards'
            params.intMethods = config.allIntMethods;                      % arp included
         end
         config.encodedLengthList = [];      % nothing is built in these modes
         % No results_*.mat: 9-11 GB per common-grid sweep, read by no analysis
         % step; the first c15t2 run filled the disk writing it (18 Nov 2026).
         config.saveRawResults = false;
         config.errorValueMode = 'shared';   % one error vector per trial (Section 8.9)
         config.dataSavePath = string(fullfile(char(campaignRoot), sprintf('c15t%d', c15t)));
         if ~exist(char(config.dataSavePath), 'dir')
            mkdir(char(config.dataSavePath));
         end

      case {'c15loc', 'c15los'}
         % BELOW CAPACITY, added 18 November 2026. The published RS(15,9)
         % configuration exactly - base 10, eccMin 1/7, the 'common' and
         % 'standards' grids and their fields, so the same permutations - with
         % the density band moved from [0.90 1.34]*tau to [0.50 0.90]*tau:
         % mean load per codeword n*nu = 1.5 to 2.7 against t = 3, the
         % guarantee side of t that the published band reaches only at its
         % lowest bin. Table 7 lists the burst scale as an attribute whose
         % change requires the verdicts to be re-measured; this measures it.
         config.bandFactor   = [0.50 0.90];
         config.noisyRateMin = config.eccReal * config.bandFactor(1);   % 0.100
         config.noisyRateMax = config.eccReal * config.bandFactor(2);   % 0.180
         if config.FECn ~= 15 || config.FECt_correct ~= 3
            error('configure_simulation: %s expects the default RS(15,9).', gridMode);
         end
         if gridMode(end) == 'c'
            config.sizeList   = 36 * (1:50);                               % as 'common'
            params.intMethods = config.allIntMethods(~strcmp(config.allIntMethods, 'arp'));
         else
            config.sizeList   = [72 108 144 288 576 864 1152 1440];        % as 'standards'
            params.intMethods = config.allIntMethods;                      % arp included
         end
         config.encodedLengthList = [];
         config.saveRawResults = false;
         config.errorValueMode = 'shared';   % one error vector per trial (Section 8.9)
         config.dataSavePath = string(fullfile(char(campaignRoot), 'c15lo'));
         if ~exist(char(config.dataSavePath), 'dir')
            mkdir(char(config.dataSavePath));
         end

      case 'legacy'
         config.sizeList   = [];                    % sizeMin:sizeStep:sizeMax
         params.intMethods = config.allIntMethods;
      otherwise
         error('configure_simulation: unknown gridMode "%s"', gridMode);
   end
   config.gridMode = gridMode;   % kept on the record as well

   % ---- REBUILD EVERYTHING DERIVED FROM THE BAND, AFTER THE SWITCH ---------
   % config.noiseLevels is built near the top of this file from the band that
   % existed THEN. A grid mode that changes config.base changes eccReal and
   % therefore the band, and the array built earlier is stale from that moment
   % on - but nothing reads the band at run time, so nothing notices:
   % run_simulations_sci reads config.noiseLevels and only that. A test run
   % at RS(31,21) once drew its bursts from the RS(15,9) levels this way, a
   % top of band 1.24 times too high, and was discarded.
   %
   % The verification below checks the array the simulation READS, not only
   % the fields the switch SETS. The array is
   % now rebuilt here, unconditionally, from the final band: for every mode
   % that does not touch base this reproduces the same values exactly, so it
   % is free, and no future mode can get it wrong by forgetting a line.
   config.noiseLevels = linspace(config.noisyRateMin, config.noisyRateMax, ...
                                 config.noiseBins);

   % ---- THE CODE PARAMETERS MUST STILL AGREE WITH THE CODE -----------------
   % A grid mode is allowed to change config.base, and 'code31' does. Every
   % quantity derived from it then has to be recomputed, and a recompute that
   % misses a field produces a campaign that runs, reports numbers, and scores
   % bursts against the wrong code. Nothing downstream would object: the noise
   % band would simply be set for a code that is not being used.
   %
   % So the derivation is checked here against the same function, after the
   % switch, whatever the mode. This is cheap and it closes the one hole the
   % "derive, never re-enter" rule cannot close by itself - a derivation that
   % was correct when written and went stale when something above it moved.
   fecChk = configure_FEC_parameters(config.base, config.eccMin, config.FECnShort);
   if config.FECn ~= fecChk.n || config.FECk ~= fecChk.k || ...
      config.FECt_correct ~= fecChk.t_correct || ...
      abs(config.eccReal - fecChk.eccReal) > 1e-12
      error(['configure_simulation: gridMode "%s" left the FEC fields out of ' ...
             'step with base = %d, eccMin = %.6g. Config says RS(%d,%d) t=%d ' ...
             'eccReal=%.6g; the code says RS(%d,%d) t=%d eccReal=%.6g. ' ...
             'A mode that changes base must recompute every FEC field.'], ...
             gridMode, config.base, config.eccMin, ...
             config.FECn, config.FECk, config.FECt_correct, config.eccReal, ...
             fecChk.n, fecChk.k, fecChk.t_correct, fecChk.eccReal);
   end
   bfC = config.bandFactor;
   if abs(config.noisyRateMin - config.eccReal*bfC(1)) > 1e-12 || ...
      abs(config.noisyRateMax - config.eccReal*bfC(2)) > 1e-12
      error(['configure_simulation: gridMode "%s" left the noise band on the ' ...
             'old eccReal. Band is [%.6g %.6g]; eccReal = %.6g wants ' ...
             '[%.6g %.6g]. The burst lengths would be drawn for a different ' ...
             'code than the one being decoded.'], ...
             gridMode, config.noisyRateMin, config.noisyRateMax, config.eccReal, ...
             config.eccReal*bfC(1), config.eccReal*bfC(2));
   end
   % And the array the simulation actually reads, which is the thing that
   % matters and the thing the check above was missing.
   if numel(config.noiseLevels) ~= config.noiseBins || ...
      abs(config.noiseLevels(1)   - config.eccReal*bfC(1)) > 1e-12 || ...
      abs(config.noiseLevels(end) - config.eccReal*bfC(2)) > 1e-12
      error(['configure_simulation: config.noiseLevels does not match the code. ' ...
             'Levels run [%.6g .. %.6g] over %d bins; eccReal = %.6g (RS(%d,%d)) ' ...
             'wants [%.6g .. %.6g] over %d. Bursts would be drawn for a ' ...
             'different code than the one being encoded.'], ...
             config.noiseLevels(1), config.noiseLevels(end), numel(config.noiseLevels), ...
             config.eccReal, config.FECn, config.FECk, ...
             config.eccReal*bfC(1), config.eccReal*bfC(2), config.noiseBins);
   end

   % Keep sizeMin/sizeMax consistent with the list: estimate_sweep_time and
   % some banners still read those two, and values that contradict the list
   % mislead.
   if ~isempty(config.sizeList)
      config.sizeMin = min(config.sizeList);
      config.sizeMax = max(config.sizeList);
   end

   % ---- SMOKE TEST ---------------------------------------------------------
   % With the global TS_SMOKE = true: 2 runs, 4 lengths, a folder of its own.
   % For exercising the chain end to end before a full campaign; DO NOT use
   % its results in any analysis.
   global TS_SMOKE %#ok<GVMIS>
   if ~isempty(TS_SMOKE) && TS_SMOKE
      config.testRunsMax = 2;
      if strcmp(gridMode, 'common')
         config.sizeList = 36 * [1 5 10 20];
      else
         config.sizeList = config.sizeList([1 4 8]);
      end
      config.sizeMin = min(config.sizeList); config.sizeMax = max(config.sizeList);
      config.dataSavePath = dataSavePath + "_smoke";
      if ~exist(char(config.dataSavePath), 'dir'), mkdir(char(config.dataSavePath)); end
   end

   % % % % % --- Simulation Overrides (uncomment below For Quick Test) ---
   % OFF - this is a full run. Before uncommenting any of it, know that this
   % block executes AFTER the grid selector, so every line here overrides the
   % choice made above. In particular do not uncomment the params.intMethods
   % line: in 'common' mode the grid selector removes arp from the list on
   % purpose, and putting arp back takes S down in every trial as well (in
   % interleave_all_pc the arp block comes before the S block, and the chain
   % is guarded by "&& (erM == "")"). Do not uncomment the config.sizeMin /
   % config.sizeMax lines either - they contradict sizeList.
   %
%       config.testRunsMax = 5;
%    %    config.dataGenTryMax = 15;
%    %    config.noiseTryMax = 27;
%    %    config.corr = true;
%    %    config.saveResults = false;
%    %    config.plotResults = false;
% gridMode = 'common';    
% burstRegime = 'multi';
   % % % % %

end