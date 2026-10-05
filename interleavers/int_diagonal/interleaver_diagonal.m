function [vectorInterleaved, permutation, erM, R, C] = interleaver_diagonal(vectorIn, R, C, pad_symbol, maxExtensionPercentage)
%INTERLEAVER_DIAGONAL  Diagonal interleaver.
%   Writes row-by-row into an R x C matrix and reads out along ANTI-diagonals.
%
%   CONVENTION: vectorInterleaved(k) = vectorInPadded(permutation(k))  (gather).
%   (The old header called this 'output_to_input_map'; the variable has been
%   named `permutation` for a long time. Same object.)
%
% TWO CORRECTIONS, 2026
% ---------------------
% 1. GUARD (behaviour change, one character). The validation read `R < 1`.
%    R = 1 passes that test and produces a 1 x C matrix whose single
%    anti-diagonal read is the IDENTITY permutation - an interleaver that does
%    not interleave, reported silently as a valid result. The guard is now
%    R < 2. C = 1 is the transposed degenerate case and is guarded the same way.
%    This does not arise for the sweep's current dimensioning (R is chosen near
%    sqrt(N)), so no published number changes - but it was one edit away.
%
% 3. R,C ARE NOW OPTIONAL (new capability, old calls unchanged).
%    Every other matrix-shaped method in this harness (matrix, helical,
%    spiral) dimensions ITSELF through choose_balanced_factors and pads to fit.
%    diagonal did not: it demanded R*C == N exactly from the caller. Callers
%    supply R = largest divisor <= sqrt(N), so for PRIME N there is no valid
%    pair at all and the method was rejected outright - 87 of 481 lengths in
%    the standalone sweep, every one of them prime. That is a caller/callee
%    mismatch, not a property of diagonal interleaving.
%    (This predates the R < 2 guard above: the old code rejected the same 87
%    lengths through floor(C) ~= C, just with a less informative message.
%    Verified by running the pre-2026 file over the same primes.)
%    Passing R = [] and C = [] (or omitting them) now dimensions the frame the
%    same way matrix/helical/spiral do. Explicit R,C behave exactly as before.
%    NOTE: the sweep's own encoded lengths are multiples of the codeword length
%    and therefore never prime, so no published figure changes - this only
%    affects the per-method test harness.
%
% 2. DIAGONAL DIRECTION (comment only). The code groups cells by
%    diag_id = r + c, which is constant along ANTI-diagonals (running up-right,
%    which is what MATLAB's fliplr/anti-diagonal convention calls them). The
%    comment claimed r+c is constant for main diagonals; for those the
%    invariant is r - c. The code is right and the comment was wrong, so the
%    method being benchmarked is the anti-diagonal read. Named correctly now so
%    the manuscript and the code agree.

erM = ""; vectorInterleaved = []; permutation = [];
if nargin < 2, R = []; end
if nargin < 3, C = []; end

try
   %% --- Input validation ---
   % if ~isvector(vectorIn)
   %    erM = "interleaver_diagonal: Input must be a vector."; return;
   % end
   % if iscolumn(vectorIn), vectorIn = vectorIn.'; end
   % control & correct shape of data to be 1xN
   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed 
      erM = strcat("interleaver_diagonal: Data shape error: (", num2str(size(vectorIn)), ") Must be (1xN)");
      error(erM)
   end
   
   N = numel(vectorIn);
   if nargin < 4 || isempty(pad_symbol), pad_symbol = 0; end
   if nargin < 5 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.34; end

   % Self-dimension when the caller does not insist. See correction 3.
   if nargin < 2 || isempty(R) || nargin < 3 || isempty(C)
      [R, C] = local_autoDims(N, maxExtensionPercentage);
      if isempty(R)
         erM = sprintf("interleaver_diagonal: no R,C >= 2 with R*C in [%d, %d]", ...
                       N, floor(N*(1+maxExtensionPercentage)));
         return;
      end
   end

   % R,C >= 2: at R = 1 (or C = 1) the anti-diagonal read degenerates to the
   % identity permutation. See correction 1 in the header.
   if any([~isscalar(R), ~isscalar(C), R < 2, C < 2, floor(R)~=R, floor(C)~=C])
      erM = "interleaver_diagonal: R and C must be integers >= 2 (R=1 or C=1 gives the identity permutation)."; return;
   end

   required_length = R * C;

   %% --- Padding check ---
   if required_length > N
      N_allowed = N * (1 + maxExtensionPercentage);
      if required_length > N_allowed
         erM = sprintf("interleaver_diagonal: Required size exceeds extension limit. Required=%d, Allowed=%.2f", required_length, N_allowed);
         return;
      end
      vectorInPadded = [vectorIn, repmat(pad_symbol, 1, required_length - N)];
   elseif required_length < N
      erM = sprintf("interleaver_diagonal: Input size mismatch. N=%d, Required=%d", N, required_length);
      return;
   else
      vectorInPadded = vectorIn;
   end

   %% --- Matrix form (row-major write) ---
   % reshape is column-major into C x R, transposed to R x C, so the result is
   % filled ROW-major - the write order the method calls for. matrixIn itself
   % is never read; the permutation is built from coordinates below.
   matrixIn = reshape(vectorInPadded, C, R).'; % RxC                       %#ok<NASGU>
   
   %% --- Compute diagonal read order (vectorized) ---
   % Build all (r,c) coordinate pairs
   [Cgrid, Rgrid] = meshgrid(1:C, 1:R);

   % Anti-diagonal ID: r + c is constant along ANTI-diagonals (up-right).
   % Main diagonals would be r - c. See correction 2 in the header.
   diag_id = Rgrid + Cgrid;
   
   % Convert to linear indices
   linear_idx = (Rgrid - 1) * C + Cgrid;
   
   % Flatten and sort by diagonal ID, then by column within each diagonal
   temp = [diag_id(:), Cgrid(:), linear_idx(:)];
   temp = sortrows(temp, [1 2]);  % first by diag ID, then by column
   permutation = temp(:,3).';  % row vector
   
   %% --- Read diagonally using the precomputed map ---
   vectorInterleaved = vectorInPadded(permutation);
   
   % Ensure input is a vector
   if iscolumn(vectorInterleaved); vectorInterleaved = vectorInterleaved'; end
   if iscolumn(permutation);       permutation = permutation';             end

catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%% ------------------------------------------------------------------------
function [R, C] = local_autoDims(N, maxExt)
%LOCAL_AUTODIMS  Most balanced R x C >= 2 with R*C in [N, N*(1+maxExt)].
%   Walks lengths upward from N and takes the first that factors into two
%   factors of at least 2, preferring the most square shape. Balanced
%   dimensions are what the anti-diagonal read wants: the read groups cells by
%   r + c, so a long thin grid gives most diagonals only one or two cells and
%   the permutation collapses toward the identity.
   R = []; C = [];
   for M = N:floor(N * (1 + maxExt))
      best = 0;
      for a = floor(sqrt(M)):-1:2
         if mod(M, a) == 0, best = a; break; end
      end
      if best >= 2 && M / best >= 2
         R = best; C = M / best; return;
      end
   end
end
