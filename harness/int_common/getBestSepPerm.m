function [perm, erM] = getBestSepPerm(N, criterion)
% returns the best permutation of 1:N 
%  that gives the max separation in terms of criterion
% criterion:
%  a: average separation
%  x: max separation
%  m: min separation
try
   erM = ""; perm=[];
   %%% check parameters:
   maxN = 14; 
   criterion = lower(criterion);
   if ~ismember(criterion,["a" "x" "m"]); erM = strcat("criterion '",criterion,"' is unknown"); return; end
   %%%

   % if N > maxN; erM = strcat("best permutation of 1:'",num2str(N),"' is unknown"); return; end
   % if N > maxN
      % % when finding 2 greatest common divisiors GCD2
      % minMultiplier = 0; % set 0 for no limit
      % uniqueMultiplierPairs = findUniqueMultiplierPairs(N,minMultiplier);
   % end
   [dFactor, multiple, remaining] = factorIt(N, maxN);
   perm_f = selectBestPerm(dFactor, criterion);
   perm_a = [];
   for m=1:multiple
      perm_fm = perm_f + (dFactor * (m-1));
      perm_a = [perm_a perm_fm];
   end
   % add the remaining part
   if remaining > 0 
      perm_r = selectBestPerm(remaining, criterion);
      perm_rm = perm_r + (dFactor * m);
      perm_a = [perm_a perm_rm];
   end

[repeating_elements, indices] = findRepeatingElements_1D(perm_a);
if ~isempty(repeating_elements)
   fprintf("\nhooop... repeating_elements in getBestSepPerm...!\n");
end

   %%%
   perm = perm_a;
catch errgbp
   erM = strcat("Error in getBestSepPerm:\n", errgbp.message);
   % rethrow(errgbp);
end % catch
end

%%%%%
function [dFactor, multiple, remaining] = factorIt(N, maxN)
   modList = [];
   dBgn = 4; 
   for i=dBgn:maxN
      dMod = mod(N, i);
      modList = [modList dMod];
   end
   modMin = min(modList);
   ndx = find(modList == modMin);
   dFactor = max(ndx) + dBgn - 1;
   multiple = floor(N / dFactor);
   % remaining = N - (multiple * dFactor);
   remaining = modList(max(ndx));
end
%%

function perm = selectBestPerm(N, criterion)
   switch N
   case 1
      perm = [1];
   case 2
      perm = [2,1];
   case 3
      perm = [2,3,1];
   case 4
      switch lower(criterion)
      case "a"; perm = [2,4,1,3]; % [3,1,4,2];
      case "x"; perm = [1,3,4,2];
      case "m"; perm = [2,4,1,3];
      end
   case 5
      switch lower(criterion)
      case "a"; perm = [2,4,1,5,3]; % [4,2,5,1,3];
      case "x"; perm = [1,3,4,5,2];
      case "m"; perm = [2,4,1,5,3];
      end
   case 6
      switch lower(criterion)
      case "a"; perm = [2 4 6 1 3 5]; % [3, 5, 1, 6, 4, 2];
      case "x"; perm = [1,3,4,5,6,2];
      case "m"; perm = [2,4,6,1,3,5];
      end
   case 7
      switch lower(criterion)
      case "a"; perm = [3 6 1 4 7 2 5]; % [6, 4, 2, 7, 1, 3, 5];
      case "x"; perm = [1,3,4,5,6,7,2];
      case "m"; perm = [1,3,5,7,2,4,6];
      end
   case 8
      switch lower(criterion)
      case "a"; perm = [2 4 6 8 1 3 5 7]; % [7, 5, 3, 1, 8, 4, 2, 6];
      case "x"; perm = [1,3,4,5,6,7,8,2];
      case "m"; perm = [2,4,6,8,1,3,5,7];
      end
   case 9
      switch lower(criterion)
      case "a"; perm = [2 8 6 4 1 9 7 5 3]; % [8, 2, 4, 6, 9, 1, 3, 5, 7];
      case "x"; perm = [1,3,4,5,6,7,8,9,2];
      case "m"; perm = [1,3,5,7,9,2,4,6,8];
      end
   case 10
      switch lower(criterion)
      case "a"; perm = [2 4 6 8 10 1 3 5 7 9]; % [3, 9, 5, 7, 1, 10, 4, 8, 6, 2];
      case "x"; perm = [1,3,4,5,6,7,8,9,10,2];
      case "m"; perm = [2,4,6,8,10,1,3,5,7,9];
      end
   case 11
      switch lower(criterion)
      case "a"; perm = [5, 10, 3, 8, 1, 6, 11, 4, 9, 2, 7]; % [5, 10, 4, 9, 3, 8, 2, 7, 1, 11, 6];
      case "x"; perm = [1,3,4,5,6,7,8,9,10,11,2];
      case "m"; perm = [1,3,5,7,9,11,2,4,6,8,10];
      end
   case 12
      switch lower(criterion)
      case "a"; perm = [2, 4, 6, 8, 10, 12, 1, 3, 5, 7, 9, 11]; % [2,4,6,8,10,12,1,3,5,7,9,11];
      case "x"; perm = [1,3,4,5,6,7,8,9,10,11,12,2];
      case "m"; perm = [2,4,6,8,10,12,1,3,5,7,9,11];
      end
   case 13
      switch lower(criterion)
      case "a"; perm = [2, 12, 10, 8, 6, 4, 1, 13, 11, 9, 7, 5, 3]; % [2,4,6,8,10,12,1,13,11,3,5,7,9];
      case "x"; perm = [1,3,5,7,9,11,13,4,6,8,10,12,2];
      case "m"; perm = [2,4,6,8,10,12,1,13,11,3,5,7,9];
      end
   case 14
      switch lower(criterion)
      case "a"; perm = [2, 4, 6, 8, 10, 12, 14, 1, 3, 5, 7, 9, 11, 13];
      case "x"; perm = [2, 4, 6, 8, 10, 12, 14, 1, 3, 5, 7, 9, 11, 13];
      case "m"; perm = [2, 4, 6, 8, 10, 12, 14, 1, 3, 5, 7, 9, 11, 13];
      end
   end
end
