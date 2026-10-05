clear all;

% original_matrix = [1, 2, 3; 4, 5, 6; 7, 8, 9];
% [reordered_matrix, max_Sep] = findMaxSepPermutation_hybrid(original_matrix);
% 
% disp(['Reordered matrix with maximum Sep:']);
% disp(reordered_matrix);
% disp(['Maximum Sep: ', num2str(max_Sep)]);

N=9; minAdj=3; 

distAll = findBestPerm_N(N, minAdj);

perms(:) = [distAll.perm];
perms = reshape(perms, N,[])';

avgSeps = [distAll.avgSep];
avgSepMax = max(avgSeps);
ndx_avgSepMax = find(avgSeps == avgSepMax);
perms_avgSepMax = perms(ndx_avgSepMax,:);

maxSeps = [distAll.maxSep];
maxSepsMax = max(maxSeps);
ndx_maxSepMax = find(maxSeps == maxSepsMax);
perms_maxSepMax = perms(ndx_maxSepMax,:);

varSeps = [distAll.varSep];
varSepsMax = max(varSeps);
ndx_varSepsMax = find(varSeps == varSepsMax);
perms_varSepMax = perms(ndx_varSepsMax,:);

minAdjs = [distAll.minAdj];
minAdjMax = max(minAdjs);
ndx_minAdjMax = find(minAdjs == minAdjMax);
perms_minAdjMax = perms(ndx_minAdjMax,:);

avgAdjs = [distAll.avgAdj];
avgAdjMax = max(avgAdjs);
ndx_avgAdjMax = find(avgAdjs == avgAdjMax);
perms_avgAdjMax = perms(ndx_avgAdjMax,:);

varAdjs = [distAll.varAdj];
varAdjMax = max(varAdjs);
ndx_varAdjMax = find(varAdjs == varAdjMax);
perms_varAdjMax = perms(ndx_varAdjMax,:);

% find intersections
perms_sep_avg_max_max = intersect(perms_maxSepMax,perms_avgSepMax, 'rows');
perms_sep_max_var_max = intersect(perms_varSepMax,perms_maxSepMax, 'rows');
   perms_sep_avg_var_max = intersect(perms_varSepMax,perms_avgSepMax, 'rows'); %%% 0
      perms_sep_avg_max_var_max = intersect(perms_sep_avg_max_max,perms_sep_max_var_max, 'rows'); %%% 0

perms_adj_avg_min_max = intersect(perms_minAdjMax,perms_avgAdjMax, 'rows');
   perms_adj_min_var_max = intersect(perms_varAdjMax,perms_minAdjMax, 'rows'); %%% 0
   perms_adj_avg_var_max = intersect(perms_varAdjMax,perms_avgAdjMax, 'rows'); %%% 0 

perms_sep_avg_max_max_adj_avg_min_max = intersect(perms_sep_avg_max_max,perms_adj_avg_min_max, 'rows');   
perms_sep_max_var_max_adj_avg_min_max = intersect(perms_sep_max_var_max,perms_adj_avg_min_max, 'rows');   

x=1;


%%%%%

function distAll = findBestPerm_N(N, minAdj)
   excludeZero = true;
   d = 1; 
   % generate all possible block permutations of L digit CodeWords
   A = 1:N;
   perms_all = perms(A);
   permCount = length(perms_all);
   for p=1:permCount
      perm = perms_all(p,:);
      distAdjs = abs(diff(perm));
      distAdjsMin = min(distAdjs);
      if distAdjsMin >= minAdj
         dist.perm = perm;
         dist.minAdj = distAdjsMin;
         dist.avgAdj = mean(distAdjs);
         dist.varAdj = var(distAdjs);
         [dist.minSep, dist.maxSep, dist.avgSep, ~, dist.varSep] = intraVectorSeparations(perm, excludeZero);
         distAll(d) = dist; d=d+1;
         fprintf(".")
      end
   end
end

function distAll = findBestPerm_chunk(perms_chunk, minAdj, excludeZero)
   d = 1;
   permCount = length(perms_chunk);
   for p=1:permCount
      perm = perms_chunk(p,:);
      distAdjs = abs(diff(perm));
      distAdjsMin = min(distAdjs);
      if distAdjsMin >= minAdj
         dist.perm = perm;
         dist.minAdj = distAdjsMin;
         dist.avgAdj = mean(distAdjs);
         dist.varAdj = var(distAdjs);
         [dist.minSep, dist.maxSep, dist.avgSep, ~, dist.varSep] = intraVectorSeparations(perm, excludeZero);
         distAll(d) = dist; d=d+1;
         fprintf(".")
      end
   end
end

function [reordered_matrix, max_Sep] = findMaxSepPermutation_dp(matrix)
  % Get matrix size
  L = size(matrix, 1);

  % Initialize DP table (stores minimum Sep for sub-matrices)
  dp = zeros(L, L);

  % Base cases (Sep between single elements is 0)
  for i = 1:L
    dp(i, i) = 0;
  end

  % Fill the DP table iteratively
  for width = 2:L
    for i = 1:L - width + 1
      for j = i + 1:i + width - 1
        current_diff = abs(matrix(i, i) - matrix(i + width - 1, j));
        % Select max sep from adjacent sub-matrices or current diff
        dp(i, j) = max([dp(i, j - 1), dp(i + 1, j), current_diff]);  
      end
    end
  end

  % Find the starting position (maximum Sep for full matrix)
  max_Sep = max(dp(1, L));
  [start_row, ~] = find(dp == max_Sep, 1, 'first');  % Find first occurrence of max Sep

  % Reconstruct the reordered matrix based on DP table (backtracking)
  reordered_matrix = zeros(L);
  reconstructed = 0;  % Track elements filled in reordered_matrix

  % Backtracking logic (implementation details might vary slightly)
  i = start_row;
  j = L;
  while reconstructed < L^2
    reordered_matrix(i, j) = matrix(i, i);
    reconstructed = reconstructed + 1;

    % Choose the sub-matrix with the maximum Sep from adjacent possibilities
    if i > 1 && dp(i - 1, j) == max_Sep
      i = i - 1;
    elseif j > i + 1 && dp(i, j - 1) == max_Sep
      j = j - 1;
    else
      i = i + 1;
    end
  end

  return;
end

function [reordered_matrix, max_Sep] = findMaxSepPermutation_hybrid(matrix)
  % Get matrix size
  L = size(matrix, 1);

  % Call the DP function to find optimal Sep
  [dp_matrix, max_Sep] = findMaxSepPermutation_dp(matrix);

  % Initialize reordered matrix
  reordered_matrix = zeros(L);

  % Fill elements based on DP results
  filled = 0;
  for i = 1:L
    for j = 1:L
      if dp_matrix(i, j) == max_Sep
        reordered_matrix(i, j) = matrix(i, i);
        filled = filled + 1;
      end
    end
  end

  % Handle unfilled elements (place diagonally for even L, corners for odd L)
  if mod(L, 2) == 0
    % Place unfilled elements diagonally with corrected modulo
    for i = filled + 1:L^2
      index = mod(i - L - 1, L) + 1;
      if index <= L
        reordered_matrix(i, index) = matrix(i, mod(i - 1, L) + 1);
      else
        reordered_matrix(i - L, index) = matrix(i - L, mod(i - L - 1, L) + 1);
      end
    end
  else
    % Place unfilled elements in corners with corrected loop iteration and modulo
    for i = filled + 1:L*(L - 1) - filled  % Iterate up to remaining elements
      if i <= ceil(L/2)  % Top right corner (unchanged)
        index = mod(i - 2, L) + 1;
        reordered_matrix(i, index) = matrix(i, L - i + 1);
      elseif i <= L  % Bottom left corner (corrected logic)
        % Use L - (i - ceil(L/2)) to ensure positive index for row
        reordered_matrix(L - (i - ceil(L/2)), index) = matrix(i, mod(i - L - 1, L) + 1);
      else  % Bottom right corner (corrected modulo)
        index = mod(i - L - 1, L) + 1;
        % Ensure index is within bounds (1 to L) using min function
        index = min(index, L);
        reordered_matrix(L, index) = matrix(i, mod(i - L - 1, L) + 1);
      end
    end
  end
  return;
end
