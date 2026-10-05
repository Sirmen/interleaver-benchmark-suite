function [stats_d, erM] = ...
   collectStatistics_all(config, intMethods, A, paramsInt, burstConfig, noiseBin, ...
                         permutation_all, interleaved_all, ...
                         decoded_all, noiseLocations, decErrRate_woInt)
try 
   erM="";  
   % stats_d = [];
   %%%
   if iscolumn(A)
      dataRow = A.';
   else
      dataRow = A;
   end
   %
   base = paramsInt.base;
   L = paramsInt.L;
   K = paramsInt.K;
   lenEncoded = length(paramsInt.encoded);
   d = 0;

   for i = 1:length(intMethods)
      methodName = intMethods{i};
      [stats, erM] = collectStatistics_x( ...
                                  config, methodName, dataRow, L, K, lenEncoded, noiseBin, ...
                                  permutation_all.(methodName), interleaved_all.(methodName), ...
                                  decoded_all.(methodName), burstConfig, noiseLocations, decErrRate_woInt);
      if (erM == "")
         d = d + 1;
         stats_d(d) = stats; 
      else
         stats_d=[]; 
         return
      end
   end

   % if no data collecteded then
   if ~exist('stats_d', 'var')
      erM = "stats_d none..";
      stats_d=[]; 
   end   
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   stats_d=[];
end
end
