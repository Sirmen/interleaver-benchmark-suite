function [vectorInterleaved, permutation, L, K, erM] = interleaver_matrix(vectorIn, padSymbol, maxExtensionPercentage)
%INTERLEAVER_MATRIX  Classic matrix (row-write / column-read) interleaver.
%   Equivalent to MATLAB's matintrlv with an L x K grid, but with the grid
%   dimensions chosen automatically by choose_balanced_factors so that L*K
%   exceeds N by no more than maxExtensionPercentage.
%
%   Outputs L (rows) and K (columns). Adjacent input symbols land K apart, so
%   K - the ROW LENGTH - is the guaranteed adjacent separation.
%
%   CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% DOCUMENTATION CORRECTED 2026. Two comments below described the opposite of
% what the code does:
%   * "Fill matrix by rows (L rows x K columns)" sat above
%     reshape(inDataPaddad, L, K), which fills COLUMN-major. That variable (M)
%     is never read, so nothing was computed wrongly - but a reader comparing
%     this file against the manuscript would conclude the row/column
%     convention here is the reverse of what it is.
%   * The permutation itself is built on line ~38 from a SEPARATE reshape
%     that transposes, and that one genuinely is row-major. The two lines look
%     like they do the same thing and do not.
% Behaviour is unchanged; only the comments and the dead variable are labelled.
erM = ""; vectorInterleaved = []; permutation = []; L=0; K=0;
try
   if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.34; end
   if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
   
   % Ensure 1xN
   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed
      erM = sprintf('interleaver_matrix: Data shape error: (%s) Must be (1xN)', mat2str(size(vectorIn)));
      return;
   end

   N = numel(vectorIn);

   % choose K, L
   [L, K, Npad] = choose_balanced_factors(N, maxExtensionPercentage);
   adjustedN = L * K;

   % extension check
   if adjustedN > floor(N * (1 + maxExtensionPercentage))
       erM = sprintf('interleaver_matrix: Size-adjusted-N error: (N=%d, adjusted=%d, maxExt=%.2f)', N, adjustedN, maxExtensionPercentage);
       return;
   end

   % pad
   if adjustedN > N
       inDataPaddad = [vectorIn, repmat(padSymbol, 1, adjustedN - N)];
   else
       inDataPaddad = vectorIn;
   end

   % NOTE: this reshape is COLUMN-major (L rows x K columns), and M is never
   % read again. It is NOT the layout the permutation is built from - see below.
   M = reshape(inDataPaddad, L, K);                                        %#ok<NASGU>

   % The permutation. reshape(1:adjustedN, K, []) is K x L filled column-major;
   % the transpose makes it L x K filled ROW-major, i.e. row r holds
   % (r-1)*K+1 : r*K. Reading it with (:) then walks column-wise. Row-write /
   % column-read - the matintrlv convention.
   linearIdx = reshape(1:adjustedN, K, [])';
   perm = linearIdx(:)'; % 1 x adjustedN (MATLAB 1-based indices)
   
   % Validate permutation
   if numel(unique(perm)) ~= numel(perm) || any(perm < 1) || any(perm > adjustedN)
      erM = sprintf('interleaver_matrix: invalid permutation generated for N=%d', N);
      return;
   end
   
   % Apply. perm gathers from the padded input: output position j takes input
   % position perm(j).
   vectorInterleaved = inDataPaddad(perm);
   
   % outputs
   permutation = perm;

   if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
   if iscolumn(permutation), permutation = permutation'; end

catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end
