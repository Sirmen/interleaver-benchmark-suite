function [KPIsummaryTable, KPIdetailedTable, results, erM] = calcKPIs(results, config, weights)
% Post-Process Analysis
% Computes BE, CR_adj, and RES (weighted Resilience-Efficiency Score)
% To avoid survival bias, applies noise advange to contribution
%  CR_adjusted: adjusted-contribution-ratio
%     CR = 1 - (decErrRate_t.(method) / errRate_woInt)
%     CR_adjusted = CR * noise_advantage
% Applies "Resilience-Efficiency" logic and Z-score normalization
% INPUT: 
%   results - struct containing .stats_all (the raw simulation logs)
%   config  - struct containing .noiseLevels (for target noise reference)
%   weights: [w_cr, w_be] e.g., [0.5, 0.5]. weights should sum to 1.0. e.g.
%     Balanced: [0.5 0.5] (Default)
%     Recovery-Critical:   w_cr=0.8, w_be=0.2 (Deep space, Medical, Safety-critical)
%     Band-Width-Critical: w_cr=0.2, w_be=0.8 (Commercial, 5G, Storage systems)
% OUTPUT:
%   summaryTable - Grouped means and rankings per method
%   fullTable    - The detailed table with computed metrics for every runerM = "";
erM = "";
KPIsummaryTable = table();
KPIdetailedTable = table(); % detailed Table
try
   % retrieve sim stats
   resultsTable = struct2table(results.stats_all);
   
   % Balanced: 0.5 0.5 (Default)
   if nargin < 3, weights = [0.5, 0.5]; end
   
   if sum(weights) ~= 1
      weights(2) = 1 - weights(1);
      fprintf('Weights should sum to 1.0. Corrected weights as:'); disp(weights);
   end
   
   % --- call Core KPI Calculations ---
   [KPIsummaryTable, KPIdetailedTable, erM] = calcKPIs_engine(resultsTable, config, weights);
   if erM ~= ""; fprintf(strcat("\n*** ", erM)); return;  end %%% QUIT..!

   %% --- Integrate KPI Metrics Back into results.stats_all ---
   % This allows ANOVA, correlation, and plotting functions to access KPIs
   % Create a map from (method, run_index) to KPI values
   % Assuming results.stats_all and KPIdetailedTable have same order
   if height(KPIdetailedTable) ~= length(results.stats_all)
       warning('Size mismatch: KPIdetailedTable (%d) vs stats_all (%d)', ...
               height(KPIdetailedTable), length(results.stats_all));
   end
   
   % Add KPI fields to each entry in stats_all
   kpiFields = {'CR', 'CR_z', 'BE', 'BE_z', 'effectiveness', 'RES'};
   
   for i = 1:min(height(KPIdetailedTable), length(results.stats_all))
       for f = 1:length(kpiFields)
           fieldName = kpiFields{f};
           if ismember(fieldName, KPIdetailedTable.Properties.VariableNames)
               results.stats_all(i).(fieldName) = KPIdetailedTable.(fieldName)(i);
           end
       end
   end
   
   % Also store summary for quick access
   results.KPI_summary = KPIsummaryTable;
   results.KPI_weights = weights;
   
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end