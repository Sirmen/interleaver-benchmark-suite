function [fData, erM] = extractDistanceData(distAll, intMethod, desiredFields)
try
   erM = "";
   % 1. Vectorized Filtering: Faster than string conversion
   isTarget = strcmp({distAll.method}, intMethod);
   
   if ~any(isTarget)
       fData = NaN(length(desiredFields), 1);
       return;
   end
   
   filteredData = distAll(isTarget);
   nFields = length(desiredFields);
   fData = NaN(nFields, 1);
   
   for f = 1:nFields
      path = desiredFields{f};
      
      % Handle flat fields using vectorized access [filteredData.field]
      if ~contains(path, '.')
          if isfield(filteredData, path)
              % Extract all values into a cell array at once (highly optimized in MATLAB)
              allVals = {filteredData.(path)};
              % Filter numeric non-empty values using logical indexing
              isNumericVal = cellfun(@(x) isnumeric(x) && ~isempty(x), allVals);
              if any(isNumericVal)
                  fData(f) = mean([allVals{isNumericVal}], 'omitnan');
              end
          end
          continue;
      end
      
      % Nested fields using vectorized drill-down
      parts = strsplit(path, '.');
      currentLevel = filteredData;
      validPath = true;
      
      for p = 1:length(parts)
          pName = parts{p};
          if isfield(currentLevel, pName)
              next = {currentLevel.(pName)};
              keep = ~cellfun(@isempty, next);
              if ~any(keep), validPath = false; break; end
              try
                  currentLevel = [next{keep}]; % Flatten for next level
              catch
                  validPath = false; break;
              end
          else
              validPath = false; break;
          end
      end
      
      if validPath && isnumeric(currentLevel)
          fData(f) = mean(currentLevel, 'omitnan');
      end
   end
   
catch erred
   erM = sprintf("Error in extractDistanceData: %s", erred.message);
   fData = [];
end
end
