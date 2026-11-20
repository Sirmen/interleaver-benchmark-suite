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
      % THE GRID THIS METHOD ACTUALLY USED, when the run recorded it.
      % L and K below are paramsInt.L / paramsInt.K - the harness's own
      % estimate_L_for_size guess, the SAME number for every method. They are
      % passed on unchanged for backward compatibility; gridL and gridK are
      % the per-method grid and are NaN when the run did not record one.
      [gridL, gridK] = local_grid(paramsInt, methodName);
      [stats, erM] = collectStatistics_x( ...
                                  config, methodName, dataRow, L, K, lenEncoded, noiseBin, ...
                                  permutation_all.(methodName), interleaved_all.(methodName), ...
                                  decoded_all.(methodName), burstConfig, noiseLocations, decErrRate_woInt, ...
                                  gridL, gridK);
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

% ---------------------------------------------------------------------------
function [gL, gK] = local_grid(paramsInt, method)
%LOCAL_GRID  The (L,K) interleave_all_pc recorded for this method.
%   NaN when absent, never another method's value: a missing grid has to look
%   missing. Runs produced before 6 November 2026 have no gridLK field at all
%   and legitimately come back NaN.
   gL = NaN; gK = NaN;
   if isfield(paramsInt, 'gridLK') && isstruct(paramsInt.gridLK) ...
         && isfield(paramsInt.gridLK, method)
      v = paramsInt.gridLK.(method);
      if numel(v) >= 2, gL = v(1); gK = v(2); end
   end
end
