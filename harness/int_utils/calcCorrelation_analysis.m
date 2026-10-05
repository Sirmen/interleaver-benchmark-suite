function [corrResults, corrData, erM] = calcCorrelation_analysis(results, config, verbose)
% Calculates correlations of metrics vs all pivot KPIs
erM = "";  corrResults = struct(); corrData = NaN;
try

   %% Prepare flattened correlation data
   corrData = prepare_correlation_data(results, config);
   if isempty(fieldnames(corrData))
      erM = ('No correlation data available');
      return;
   end

   %% run corr analysis for every pivot var
   pivotVariables = config.pivotVariables;

   for i = 1:length(pivotVariables)
      pivotVar = pivotVariables{i};

      if ~isfield(corrData, pivotVar)
         fprintf('⚠ Pivot variable "%s" not found - skipping\n', pivotVar);
         continue;
      end

      % Perform the math
      [corP, corS, corPsorted, corSsorted, cMaxP, cMaxS, N, sortedVarNames] = ...
               calcCorrelations_pivot(corrData, config.correlationVariables, ...
                                      pivotVar, config.correlation);

      % Store everything in a structured format
      corrResults(i).pivotVariable = pivotVar;
      corrResults(i).N = N;
      corrResults(i).cMaxP = cMaxP;
      corrResults(i).cMaxS = cMaxS;
      corrResults(i).corPsorted = corPsorted;
      corrResults(i).corSsorted = corSsorted;
      corrResults(i).sortedVarNames = sortedVarNames;
      corrResults(i).validCount = sum(~isnan(corP));

      % print sorted results
      % to display only top N results for every KPI, set topN  
      topN = corrResults(i).validCount; % 10;
      if verbose; displayCorrResults(corrResults, pivotVar, topN); end
   end
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%% % calcCorrelations_pivot
function [corP, corS, corPsorted, corSsorted, cMaxP, cMaxS, N, sortedVarNames] = ...
    calcCorrelations_pivot(correlation_data, correlationVariables, pivotVariable, corrParameters)
% Calculate correlations between pivot variable and all other variables
    
    % Get pivot data
    if ~isfield(correlation_data, pivotVariable)
        error('Pivot variable "%s" not found in correlation data', pivotVariable);
    end
    
    pivotData = correlation_data.(pivotVariable);
    N = length(pivotData);
    
    % Initialize correlation arrays
    numVars = length(correlationVariables);
    corP = NaN(1, numVars);
    corS = NaN(1, numVars);
    
    % Calculate correlations for each variable
    for i = 1:numVars
        varName = correlationVariables{i};
        
        % Skip if this is the pivot variable itself
        if strcmp(varName, pivotVariable)
            continue;
        end
        
        % Check if variable exists in correlation data
        if ~isfield(correlation_data, varName)
            continue;
        end
        
        varData = correlation_data.(varName);
        
        % Ensure same length as pivot data
        if length(varData) ~= N
            fprintf('  ⚠ Length mismatch for %s: pivot=%d, var=%d\n', ...
                    varName, N, length(varData));
            continue;
        end
        
        % Find valid (non-NaN, non-Inf) data points
        validMask = ~isnan(pivotData) & ~isnan(varData) & ...
                   isfinite(pivotData) & isfinite(varData);
        
        % Remove zero pivot values if requested
        if isfield(corrParameters, 'removeZeroPivot') && corrParameters.removeZeroPivot
            validMask = validMask & (pivotData ~= 0);
        end
        
        numValid = sum(validMask);
        
        if numValid < 3
            continue; % Need at least 3 points for correlation
        end
        
        try
            % Calculate Pearson correlation
            if strcmpi(corrParameters.corrType, 'pearson') || ...
               strcmpi(corrParameters.corrType, 'both')
                corP(i) = corr(pivotData(validMask)', varData(validMask)', ...
                              'type', 'Pearson');
            end
            
            % Calculate Spearman correlation
            if strcmpi(corrParameters.corrType, 'spearman') || ...
               strcmpi(corrParameters.corrType, 'both')
                corS(i) = corr(pivotData(validMask)', varData(validMask)', ...
                              'type', 'Spearman');
            end
        catch ME
            fprintf('  ⚠ Error calculating correlation for %s: %s\n', ...
                    varName, ME.message);
        end
    end
    
    % Sort correlations by absolute value (descending)
    [~, idxP] = sort(abs(corP), 'descend', 'MissingPlacement', 'last');
    [~, idxS] = sort(abs(corS), 'descend', 'MissingPlacement', 'last');
    
    % Extract sorted values and variable names
    corPsorted = corP(idxP);
    corSsorted = corS(idxS);
    
    sortedVarNames.pearson = correlationVariables(idxP);
    sortedVarNames.spearman = correlationVariables(idxS);
    
    % Remove NaN entries from sorted results
    validPearson = ~isnan(corPsorted);
    validSpearman = ~isnan(corSsorted);
    
    corPsorted = corPsorted(validPearson);
    corSsorted = corSsorted(validSpearman);
    sortedVarNames.pearson = sortedVarNames.pearson(validPearson);
    sortedVarNames.spearman = sortedVarNames.spearman(validSpearman);
    
    % Get maximum absolute correlations
    if any(~isnan(corP))
        cMaxP = max(abs(corP(~isnan(corP))));
    else
        cMaxP = 0;
    end
    
    if any(~isnan(corS))
        cMaxS = max(abs(corS(~isnan(corS))));
    else
        cMaxS = 0;
    end
end

%% % displayCorrResults
function displayCorrResults_old(corrResult, pivotVar)
    % Display correlation results in a formatted way
    
    fprintf('CORRELATION ANALYSIS RESULTS for "%s: ========="\n', pivotVar);
    
    fprintf('N: %d, Variables: %d\n\n', corrResult.N, corrResult.validCount);
    
    % extract nested struct fields
    try
        pearsonVars = getfield(corrResult, 'sortedVarNames', 'pearson');
        spearmanVars = getfield(corrResult, 'sortedVarNames', 'spearman');
    catch
        % Alternative if getfield doesn't work
        temp = corrResult.sortedVarNames;
        if isstruct(temp)
            pearsonVars = temp(1).pearson;
            spearmanVars = temp(1).spearman;
        else
            error('Cannot extract variable names from sortedVarNames');
        end
    end
    
    pearsonVals = corrResult.corPsorted;
    spearmanVals = corrResult.corSsorted;
    
    % display
    % topN = min(20, length(pearsonVars));
    topN = length(pearsonVars); % display all

    fprintf('TOP %d PEARSON CORRELATIONS:\n', topN);
    fprintf('%-5s %-40s %-10s\n', 'Rank', 'Variable', 'r-value');
    for i = 1:topN
        varName = pearsonVars{i};
        if length(varName) > 37
            varName = [varName(1:34) '...'];
        end
        fprintf('%-5d %-40s %-10.4f\n', i, varName, pearsonVals(i));
    end
    
    fprintf('TOP %d SPEARMAN CORRELATIONS:\n', topN);
    fprintf('%-5s %-40s %-10s\n', 'Rank', 'Variable', 'ρ-value');
    for i = 1:topN
        varName = spearmanVars{i};
        if length(varName) > 37
            varName = [varName(1:34) '...'];
        end
        fprintf('%-5d %-40s %-10.4f\n', i, varName, spearmanVals(i));
    end
    
    fprintf('%s\n\n', repmat('=', 80, 1));
end

