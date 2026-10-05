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
   % NOT: "config.singleBurst yok sayiliyor" demek, GE acikken maske uretiminin
   % singleBurst'u OKUMADIGI anlamina gelir - singleBurst'un GE'yi kapattigi
   % anlamina DEGIL. Ikisi bagimsiz; asagidaki rejim secicisi tek dogru kaynak.
   config.gilbertElliott  = false;
   config.ge_errProbBad   = 1.0;  % 1.0 = solid bursts (matches single/multi);
                                  % 0.7 = fragmented bursts (fading flavour).
   config.ge_meanBurstLen = [];   % [] -> targetNoisyCount / (maxBurstCount*e_B)
   config.ge_maxDraws     = 50;   % redraws before the count is nudged in-band
   config.ge_bandMode     = 'target';  % v2: accept within half a bin of the target
                                       % ('grid' reproduces the v1 campaign)

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
                           'blockCM', 'convCM', ...                   % code-matched classics (v2)
                           'S'};                                      % 26 methods
   % CAMPAIGN v2 (2026-09). Two changes to the method list, both deliberate:
   %  * the method list is exactly the 26 the paper reports.
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

   % ---- REJIM SECICI: tek yerden ayarlayin --------------------------
   % Dort kosu, dort deger. GE acikken singleBurst maskeyi etkilemez, ama
   % save_results / saveCrossCorrelationResults dosya onekini buradan
   % turetilen etikete gore secer - yani rejimler birbirine karismaz.
   %
   %   'multi'   -> config.singleBurst=false, GE kapali        -> dosya oneki 'multi'
   %   'single'  -> config.singleBurst=true,  GE kapali        -> 'single'
   %   'ge1p00'  -> GE acik, e_B = 1.0 (saglam patlamalar)     -> 'ge1p00'
   %   'ge0p70'  -> GE acik, e_B = 0.7 (parcali patlamalar)    -> 'ge0p70'

   burstRegime = 'multi';    % <-- SADECE BURAYI DEGISTIRIN

   % Bir surucu betigin (run_all_sweeps.m) sekiz kosuyu elle duzenleme
   % yapmadan sirayla calistirabilmesi icin global gecersiz kilma. Global
   % bos ise bu dosya tek dogru kaynak olmayi surdurur - yani elle
   % calistirdiginizda hicbir sey degismez.
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
         error('configure_simulation: bilinmeyen burstRegime "%s"', burstRegime);
   end
   config.burstRegime = burstRegime;   % kayitlarda da dursun

   % ---- IZGARA SECICI: tek yerden ayarlayin -------------------------------
   % Uc kosu tipi. Bu secici hem uzunluk listesini hem de metot listesini
   % ayarlar; ikisi birbirine bagli oldugu icin ayri ayri elle degistirmeyin.
   %
   %   'common'     ortak izgara, 23 metot (arp HARIC), 50 uzunluk
   %   'standards'  standart-uyumlu alt kume, 24 metot (arp DAHIL), 8 uzunluk
   %
   % NEDEN 'common' IZGARASI K = 36*m
   % ---------------------------------------------------------------------
   % RS(15,9) altinda K = 36m tam olarak 4m kod sozcugu eder, DOLGU SIFIR, ve
   % kodlanmis uzunluk L = 60m olur. 60'in katlari ayni anda su dort kosulu
   % saglar, ki hicbir aritmetik izgara bunu yapamaz:
   %
   %   L = 0 (mod 4)  standartlastirilmis ARP'nin sarti (ETSI EN 301 790:
   %                  "N is a multiple of 4")
   %   4 | L          DRP'nin en kucuk yayinlanmis dither periyodu boler;
   %                  120'nin katlarinda 8, 240'in katlarinda 16 da boler
   %   60 = 3*4*5     d = 3 kafes serpistiricisi her uzunlukta uc carpana ayrilir
   %   dolgu yok      BE = 1 her metotta, yani bant genisligi verimi artik
   %                  karsilastirmayi bulandirmiyor
   %
   % Ustelik eski 991-uzunluk izgarasindan ~17 kat ucuz: orada ardisik dokuz K
   % ayni kodlanmis uzunluga dusuyordu, yani ayni permutasyon dokuz kez
   % odeniyordu.
   %
   % NEDEN 'standards' AYRI BIR KOSU
   % ---------------------------------------------------------------------
   % interleave_all_pc'deki bloklar "&& (erM == "")" zinciriyle korunuyor: bir
   % metot dustugunde sonrakiler hic calismiyor. Bu DOGRU bir davranis, cunku
   % bir deneme ancak butun metotlar ayni patlama gerceklemesini gordugunde
   % karsilastirilabilir. Ama arp yayinlanmis parametresi olmayan uzunlukta
   % bilerek hata dondurdugu icin - ve arp blogu S blogundan ONCE geldigi icin
   % - arp'i ortak izgarada kosmak her denemede S'i de dusururdu.
   % Cozum dosyayi kurcalamak degil, arp'i kendi uzunluklarinda ayri kosmak.
   %
   % Asagidaki sekiz K, 802.16 tablosunun 15'in kati olan sekiz satirina
   % karsilik gelir: L = 120 180 240 480 960 1440 1920 2400.

   gridMode = 'common';    % <-- SADECE BURAYI DEGISTIRIN

   global TS_GRID_MODE %#ok<GVMIS>
   if ~isempty(TS_GRID_MODE), gridMode = TS_GRID_MODE; end

   switch gridMode
      case 'common'
         config.sizeList   = 36 * (1:50);          % L = 60, 120, ... 3000
         params.intMethods = config.allIntMethods(~strcmp(config.allIntMethods, 'arp'));
      case 'standards'
         config.sizeList   = [72 108 144 288 576 864 1152 1440];
         params.intMethods = config.allIntMethods;  % arp dahil
      case 'legacy'
         config.sizeList   = [];                    % sizeMin:sizeStep:sizeMax
         params.intMethods = config.allIntMethods;
      otherwise
         error('configure_simulation: bilinmeyen gridMode "%s"', gridMode);
   end
   config.gridMode = gridMode;   % kayitlarda da dursun

   % sizeMin/sizeMax'i listeyle tutarli tut: estimate_sweep_time ve bazi
   % basliklar hala bu ikisini okuyor, ve listeyle celisen degerler yaniltir.
   if ~isempty(config.sizeList)
      config.sizeMin = min(config.sizeList);
      config.sizeMax = max(config.sizeList);
   end

   % ---- DUMAN TESTI (v2) ---------------------------------------------------
   % global TS_SMOKE = true yapilirsa: 2 kosu, 4 uzunluk, ayri klasor. Tam
   % kampanyadan once zinciri uc uca denemek icin; sonuclari analizde KULLANMAYIN.
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
   % KAPALI - tam kosu icin. Acmadan once sunu bilin: bu blok IZGARA
   % SECICISINDEN SONRA calisir, yani buradaki her satir yukaridaki secimi
   % ezer. Ozellikle params.intMethods satirini acmayin: izgara secici
   % 'common' modunda arp'i listeden bilerek cikariyor, ve arp'i geri
   % koymak her denemede S'i de dusurur (interleave_all_pc'de arp blogu S
   % blogundan once ve zincir "&& (erM == "")" ile korunuyor).
   % config.sizeMin / config.sizeMax satirlarini da acmayin - sizeList ile
   % celisirler.
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