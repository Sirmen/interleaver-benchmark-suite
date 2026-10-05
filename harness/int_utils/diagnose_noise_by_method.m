function diag = diagnose_noise_by_method(stats_all, opts)
% diagnose_noise_by_method
% ------------------------------------------------------------
% Inspects noise data consistency across methods BEFORE ANOVA
%
% Inputs:
%   stats_all : struct array (results.stats_all)
%   opts.K    : number of noise bins (default = 7)
%   opts.doPlot : true/false (default = true)
%
% Output:
%   diag : struct with tables and flags for programmatic checks
%
% usage:
%  diag = diagnose_noise_by_method(results.stats_all, struct('K',7,'doPlot',true));
% ------------------------------------------------------------

   if nargin < 2, opts = struct(); end
   if ~isfield(opts,'K'), opts.K = 7; end
   if ~isfield(opts,'doPlot'), opts.doPlot = true; end

   K = opts.K;

   % ----------------------------
   % Convert struct → table
   % ----------------------------
   % T = struct2table(stats_all, 'VariableNamingRule','preserve');
   warning('off','MATLAB:table:ModifiedAndSavedVarnames');
   T = struct2table(stats_all);
   warning('on','MATLAB:table:ModifiedAndSavedVarnames');

   % Basic validity mask
   valid = ~isnan(T.noise) & ~isnan(T.cont) & ~isnan(T.effectiveness);

   T.valid = valid;

   methods = unique(T.method, 'stable');
   nM = numel(methods);

   % ----------------------------
   % Global noise bins (FROZEN)
   % ----------------------------
   noiseMin = min(T.noise(valid));
   noiseMax = max(T.noise(valid));
   edges = linspace(noiseMin, noiseMax, K+1);

   T.noiseCat = discretize(T.noise, edges);

   % ----------------------------
   % Summary per method
   % ----------------------------
   perMethod = table('Size',[nM 8], ...
      'VariableTypes',{'string','double','double','double','double','double','double','double'}, ...
      'VariableNames',{'method','N_total','N_valid','noise_min','noise_max','noise_mean','noise_median','valid_ratio'});

   for i = 1:nM
      m = methods{i};
      idx = strcmp(T.method,m);

      perMethod.method(i)        = string(m);
      perMethod.N_total(i)       = sum(idx);
      perMethod.N_valid(i)       = sum(idx & valid);
      perMethod.noise_min(i)     = min(T.noise(idx & valid));
      perMethod.noise_max(i)     = max(T.noise(idx & valid));
      perMethod.noise_mean(i)    = mean(T.noise(idx & valid));
      perMethod.noise_median(i)  = median(T.noise(idx & valid));
      perMethod.valid_ratio(i)   = perMethod.N_valid(i) / max(perMethod.N_total(i),1);
   end

   % ----------------------------
   % Noise bin counts
   % ----------------------------
   binCounts = grpstats(T(valid,:), {'method','noiseCat'}, 'numel', 'DataVars','noise');
   binCounts.Properties.VariableNames{'GroupCount'} = 'N';

   binMatrix = unstack(binCounts, 'N', 'noiseCat');

   % ----------------------------
   % Flags
   % ----------------------------
   diag.flags.missingNoiseBins = any(any(ismissing(binMatrix(:,2:end))));
   diag.flags.unequalCounts   = any(diff(table2array(binMatrix(:,2:end)),1,1),'all');

   % ----------------------------
   % Optional plots
   % ----------------------------
   if opts.doPlot
      figure('Name','Noise Diagnosis'); % ,'Position',[100 100 1200 450]);
   
      % Histogram overlay
      subplot(1,2,1); hold on;
      for i = 1:nM
         idx = strcmp(T.method,methods{i}) & valid;
         histogram(T.noise(idx), 60, 'DisplayStyle','stairs');
      end
      xlabel('Noise'); ylabel('Count');
      title('Noise Distribution by Method');
      grid on;
   
      % --------
      subplot(1,2,2);
      
      C = table2array(binMatrix(:,2:end))';   % noiseCat × method
      imagesc(C);
      
      colormap(parula);
      colorbar;
      
      set(gca,'XTick',1:numel(binMatrix.method), ...
              'XTickLabel',binMatrix.method, ...
              'XTickLabelRotation',45);
      
      set(gca,'YTick',1:size(C,1), ...
              'YTickLabel',binMatrix.Properties.VariableNames(2:end));
      
      xlabel('Method');
      ylabel('Noise Regime');
      title('Sample Count per Method × Noise Regime');
      
      axis tight;
   end

   % ----------------------------
   % Outputs
   % ----------------------------
   diag.table_perMethod = perMethod;
   diag.table_binCounts = binMatrix;
   diag.noiseEdges      = edges;
   diag.noiseBins       = K;

   % ----------------------------
   % Console summary
   % ----------------------------
   fprintf('\n=== NOISE DIAGNOSTIC SUMMARY ===\n');
   fprintf('Methods: %d | Total rows: %d\n', nM, height(T));
   fprintf('Noise range: [%.4g , %.4g]\n', noiseMin, noiseMax);
   fprintf('Missing bins: %d | Unequal counts: %d\n', ...
           diag.flags.missingNoiseBins, diag.flags.unequalCounts);

   if diag.flags.missingNoiseBins || diag.flags.unequalCounts
      warning('Noise integrity issues detected — ANOVA may be unreliable.');
   else
      fprintf('Noise integrity OK — safe to proceed with ANOVA.\n');
   end
end
