function [vectorInterleaved, permutation, L, K, erM] = interleaver_helicalScan(vectorIn, padSymbol, maxExtensionPercentage)
%INTERLEAVER_HELICALSCAN  Helical-scan interleaver (MATLAB helscanintrlv).
%   Writes the frame row-wise into an L x K grid and reads row r starting at
%   column mod((r-1)*hstep, K), wrapping - a cyclic shift per row.
%
%   CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% KNOWN AND INTENDED: adj_min = 1. DO NOT "FIX" THIS.
% ---------------------------------------------------------------------------
% With hstep = 1 the read within any one row is a cyclic ROTATION of that row.
% A rotation preserves adjacency everywhere except at the single wrap point, so
% consecutive input symbols that share a row come out consecutively: the
% minimum adjacent separation of this interleaver is 1, by construction, for
% every N. Its dispersion is across rows (L apart), not within them.
%
% This is a property of the METHOD, not a defect in this file, and it is the
% reason helical-scan appears in the comparison at all: it is the standard
% example of an interleaver with excellent average separation and worthless
% WORST-CASE separation. When the results table shows adj_min = 1 here while
% mu_adj looks healthy, that is the expected reading, and it is exactly the gap
% that S-Interleaving's min-sum dimensioning is arguing about. Report both
% columns; do not quietly drop the method because one column looks bad.
%
% `spiral` has the same adj_min = 1 signature for the same structural reason.

erM = ""; vectorInterleaved = []; permutation = []; L = 0; K = 0;
try
   if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.34; end
   if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
   
   % % normalize input to column vector
   % if ~isvector(vectorIn)
   %    vectorIn = vectorIn(:);
   % end
   % vectorIn = vectorIn(:);  % ensure column
   % control & correct shape of data to be 1xN
   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed 
      erM = strcat("interleaver_helicalScan: Data shape error: (", num2str(size(vectorIn)), ") Must be (1xN)");
      error(erM)
   end
   
   N0 = numel(vectorIn);
   if N0 == 0
      erM = 'interleaver_helicalScan: Empty input.';
      return;
   end

   %% choose L and K
   % auto choose L near sqrt(N)
   approx = max(1, floor(sqrt(N0)));
   % find a range around approx that yields acceptable extension and balanced shape
   found = false;
   maxN = ceil(N0*(1+maxExtensionPercentage));
   for Lcand = approx:-1:1
      Kcand = ceil(N0 / Lcand);
      if Lcand * Kcand <= maxN
          L = Lcand; K = Kcand; found = true; break;
      end
   end
   if ~found
      % try increasing L
      for Lcand = approx+1:ceil(2*approx)
          Kcand = ceil(N0 / Lcand);
          if Lcand * Kcand <= maxN
              L = Lcand; K = Kcand; found = true; break;
          end
      end
   end
   if ~found
      erM = sprintf('interleaver_helicalScan: Could not find suitable L,K for N=%d within extension %.2f', N0, maxExtensionPercentage);
      return;
   end

   % pad if needed
   Ntarget = L * K;
   if Ntarget > N0
      % vectorIn is 1xN here (controlCorrectShape_1N guarantees it), so the
      % padding is built as a column and transposed back. Kept verbatim rather
      % than simplified: it is correct, and the harness's regression baselines
      % were taken with this exact code path.
      padding = repmat(padSymbol, Ntarget-N0, 1);
      paddedData = [vectorIn, padding'];
   else
      paddedData = vectorIn;
   end
   
   % helscanintrlv(data, nrows, ncols, step); step defaults to 1.
   % hstep = 1 makes each row read a pure cyclic rotation - see the adj_min = 1
   % note in the header before changing this.
   hstep = 1;
   vectorInterleaved = helscanintrlv(paddedData, L, K, hstep);
    
   % Generate permutation by applying same to indices
   indices = (1:Ntarget)';
   permutation_indices = helscanintrlv(indices, L, K, hstep);
   permutation = permutation_indices(:)';
    
   % Verify permutation is valid
   if numel(unique(permutation)) ~= numel(permutation)
      erM = 'interleaver_helicalScan: non-unique permutation generated.';
      return;
   end
   
   % Ensure input is a vector
   if iscolumn(vectorInterleaved); vectorInterleaved = vectorInterleaved'; end
   if iscolumn(permutation);       permutation = permutation';             end

catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end
