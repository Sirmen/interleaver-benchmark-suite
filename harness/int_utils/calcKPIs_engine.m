function [KPIsummaryTable, KPIdetailedTable, erM] = calcKPIs_engine(statsTable, config, weights, methods)
% Post-Process Analysis
% Computes BE, CR_adj, and RES (weighted Resilience-Efficiency Score)
% Filters data to process only requested 'methods'
% To avoid survival bias, applies noise advange to contribution
%  CR_adjusted: adjusted-contribution-ratio
%     CR = 1 - (decErrRate_t.(method) / errRate_woInt)
%     CR_adjusted = CR * noise_advantage
% Applies "Resilience-Efficiency" logic and Z-score normalization
% INPUT: 
%   resultsTable - table containing .stats_all (the raw simulation logs)
%   config  - struct containing .noiseLevels (for target noise reference)
%   weights: [w_cr, w_be] e.g., [0.5, 0.5]. weights should sum to 1.0. e.g.
%     Balanced: 0.5 0.5 (Default)
%     Recovery-Critical:   w_cr=0.8, w_be=0.2 (Deep space, Medical, Safety-critical)
%     Band-Width-Critical: w_cr=0.2, w_be=0.8 (Commercial, 5G, Storage systems)
% OUTPUT:
%   KPIsummaryTable  - Aggregated means and rankings per method, includes Z-scores
%   KPIdetailedTable - The detailed table with with only KPI-relevant fields per run

erM = "";  
KPIsummaryTable = table();
KPIdetailedTable = table();

try   
   % --- Filter statsTable to include only requested methods ---
   % This ensures Z-scores and means are only calculated relative to the chosen set
   if nargin > 3 && ~isempty(methods)
       % Convert methods to cellstr if it is a string array for compatibility
       targetMethods = cellstr(methods);
       % Logical index of rows matching the requested methods
       isTarget = ismember(statsTable.method, targetMethods);
       statsTable = statsTable(isTarget, :);
       
       if isempty(statsTable)
           erM = "No data found for the specified methods.";
           return;
       end
   end

   % Copy fields necessary for KPI computations
   KPIdetailedTable.method = statsTable.method;
   KPIdetailedTable.noiseBin = statsTable.noiseBin;
   KPIdetailedTable.encodedLen = statsTable.encodedLen;
   KPIdetailedTable.interleavedLen = statsTable.interleavedLen;
   KPIdetailedTable.noiseActual = statsTable.noiseActual;
   KPIdetailedTable.decodeErrRate = statsTable.decodeErrRate;
   KPIdetailedTable.decErrRate_woInt = statsTable.decErrRate_woInt;
    
   % --- Core Calculations ---
   [KPIcore, erM] = calcKPI_core(statsTable, config);
   if erM ~= ""; fprintf(strcat("\n*** ", erM)); return;  end
   
   KPIdetailedTable.CR = KPIcore.CR;
   KPIdetailedTable.CR_z = KPIcore.CR_z;
   KPIdetailedTable.BE = KPIcore.BE;
   KPIdetailedTable.BE_z = KPIcore.BE_z;
   KPIdetailedTable.effectiveness = KPIcore.effectiveness;

   % --- Calc RES - Main Performance Score ---
   KPIdetailedTable.RES = weights(1) * KPIcore.CR_z + ...
                          weights(2) * KPIcore.BE_z;
   
   % --- Summary Aggregation ---
   KPIsummaryTable = groupsummary(KPIdetailedTable, 'method', 'mean', ...
        {'RES', 'CR', 'BE', 'effectiveness', 'CR_z', 'BE_z'});
   
   % Cleanup table names
   KPIsummaryTable.Properties.VariableNames = strrep(KPIsummaryTable.Properties.VariableNames, 'mean_', '');
   KPIsummaryTable = sortrows(KPIsummaryTable, 'RES', 'descend');
   
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

% (Keep the calcKPI_core helper function as it was)

%%
function [KPIcore, erM] = calcKPI_core(statsTable, config)
% C_NN - coefficient of noise normalization is used as honesty factor to mitigate survivor's bias.
erM = "";  KPIcore = table();
try   
   % Bandwidth Efficiency - Higher is better. represents (1 - interleaver's size overhead),
   %     i.e info rate of the interleaved message
   KPIcore.BE = statsTable.encodedLen ./ statsTable.interleavedLen; 

   % Target noise for this noise bin
   targetNoise = arrayfun(@(b) config.noiseLevels(b), statsTable.noiseBin);

   % Contribution Ratio (CR) - Raw recovery
   CR_raw = max(0, 1 - (statsTable.decodeErrRate ./ (statsTable.decErrRate_woInt + eps)));

   % C_NN - Honesty factor (survivor's bias detection)
   C_NN = statsTable.noiseActual ./ (targetNoise + eps);
   
   % Adjusted Recovery Contribution (Survival Bias Avoidance)
   KPIcore.CR = CR_raw .* C_NN;
   
   % Effectiveness
   KPIcore.effectiveness = KPIcore.CR .* KPIcore.BE;
   
   % --- Z-Score Normalization - Puts CR_adj and BE on same scale (standard deviations from mean),
   %     i.e. ensures fair weighting despite different variances preventing domination of either metric
   CR_adj_mu = mean(KPIcore.CR);
   CR_adj_sigma = std(KPIcore.CR);
   BE_mu = mean(KPIcore.BE);
   BE_sigma = std(KPIcore.BE);

   KPIcore.CR_z = (KPIcore.CR - CR_adj_mu) / (CR_adj_sigma + eps);
   KPIcore.BE_z = (KPIcore.BE - BE_mu) / (BE_sigma + eps);
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end