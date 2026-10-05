function displayCorrResults(corrResults, pivotVar, topN)
   % Display top correlations for a specific pivot variable
   
   % Set default topN if not provided
   if nargin < 3
      topN = corrResults.validCount; % Default to top 20
   end

   % Get the index of the struct with the desired pivotVariable
   idx = find(strcmp({corrResults.pivotVariable}, pivotVar));
   
   % Check if found and extract
   if isempty(idx)
      fprintf('Pivot variable "%s" not found in corrResults', pivotVar);
      return
   end

   corrResult = corrResults(idx);

   fprintf('\n%s\n', repmat('=', 80, 1));
   
   % Extract nested struct fields
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
   
   % Determine how many results to display
   displayCount = min(topN, length(pearsonVars));
   
   % Display Pearson correlations
   fprintf('TOP %d PEARSON CORRELATIONS with "%s":\n', displayCount, pivotVar);
   fprintf('%-5s %-40s %-10s %-15s\n', 'Rank', 'Variable', 'r-value', 'Strength');
    
   for i = 1:displayCount
      varName = pearsonVars{i};
      if length(varName) > 37
         varName = [varName(1:34) '...'];
      end
      
      rVal = pearsonVals(i);
      absR = abs(rVal);
      
      % Determine strength
      if absR >= 0.7
         strength = 'STRONG';
      elseif absR >= 0.3
         strength = 'MODERATE';
      else
         strength = 'WEAK';
      end
      
      % Add sign indicator
      if rVal > 0
         direction = '+';
      else
         direction = '-';
      end
      
      fprintf('%-5d %-40s %-10.4f %-15s\n', i, varName, rVal, [direction strength]);
   end
        
   % Display Spearman correlations
   fprintf('TOP %d SPEARMAN CORRELATIONS with "%s":\n', displayCount, pivotVar);
   fprintf('%-5s %-40s %-10s %-15s\n', 'Rank', 'Variable', 'ρ-value', 'Strength');
   
   for i = 1:displayCount
      varName = spearmanVars{i};
      if length(varName) > 37
         varName = [varName(1:34) '...'];
      end
      
      rhoVal = spearmanVals(i);
      absRho = abs(rhoVal);
      
      % Determine strength
      if absRho >= 0.7
         strength = 'STRONG';
      elseif absRho >= 0.3
         strength = 'MODERATE';
      else
         strength = 'WEAK';
      end
      
      % Add sign indicator
      if rhoVal > 0
         direction = '+';
      else
         direction = '-';
      end

      fprintf('%-5d %-40s %-10.4f %-15s\n', i, varName, rhoVal, [direction strength]);
   end
      
   if displayCount < length(pearsonVars)
      fprintf('(Showing top %d of %d total correlations)\n', displayCount, length(pearsonVars));
   end
   
   fprintf('\n%s\n\n', repmat('=', 80, 1));
end
