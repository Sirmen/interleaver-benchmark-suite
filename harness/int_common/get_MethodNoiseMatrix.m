% function [avgDataRaw, summaryTable, erM] = get_primaryMetrics_summary(results, methods)
% erM = "";
% noiseMatrix = struct(); % To store Method x Noise bin averages
% try
% 
%    % We need the noise category for every run
%    % Assuming results.noiseCat contains the bin index (1-5) for each run
%    noiseCats = results.noiseCat; 
% 
%    for i = 1:nMethods
%        method = methods{i};
%        crData = [results.avContribution_all.(method)];
% 
%        for bin = 1:nBins
%            % Logical index for this method's performance in THIS noise bin
%            binIdx = (noiseCats == bin);
%            noiseMatrix.CR(i, bin) = mean(crData(binIdx), 'omitnan');
%            noiseMatrix.Count(i, bin) = sum(binIdx); % Track sampling density
%        end
%    end
% catch ME
%    erM = sprintf('*** %s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
% end
% end
% 


function [avgDataRaw, summaryTable] = get_primaryMetrics_summary(results, methods)
   nMethods = length(methods);
   nBins = 5; % Your 5 noise categories
   
   % Pre-allocate
   weighted_CR = zeros(nMethods, 1);
   weighted_Eff = zeros(nMethods, 1);
   bin5_CR = zeros(nMethods, 1); % Specifically for Bin 5 performance

   for i = 1:nMethods
       method = methods{i};
       
       % Extract the 2D matrix [Score, Bin]
       data_CR = results.avContribution_all.(method);
       
       % Calculate means per bin
       binMeans = NaN(1, nBins);
       for b = 1:nBins
           % Find scores belonging to bin 'b'
           binScores = data_CR(data_CR(:, 2) == b, 1);
           if ~isempty(binScores)
               binMeans(b) = mean(binScores, 'omitnan');
           end
       end
       
       % WEIGHTED AVERAGE: Mean of the bin-means
       % This removes the sampling bias!
       weighted_CR(i) = mean(binMeans, 'omitnan');
       bin5_CR(i) = binMeans(5); % This is your "Stress Test" KPI
   end
   
   % Create Table with the corrected rankings
   summaryTable = table(categorical(methods(:)), weighted_CR, bin5_CR, ...
      'VariableNames', {'Method', 'Weighted_CR', 'StressTest_CR'});
   
   % Sort by Weighted performance, not the biased simple average
   summaryTable = sortrows(summaryTable, 'Weighted_CR', 'descend');
end