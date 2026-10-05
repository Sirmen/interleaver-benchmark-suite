function [vectorInterleaved, permutation, L, K, Q, R, erM, info] = ...
    interleaver_generic_pc(vectorIn, method, padSymbol, maxExtensionPercentage, ...
                           table_precomputed, seedOrExtra, table_primes, table_factors, paramsInt)
%INTERLEAVER_GENERIC_PC  Table-first dispatcher for every interleaving method.
%
%   [interleaved, permutation, L, K, Q, R, erM, info] = interleaver_generic_pc( ...
%        data, method, padSymbol, maxExt, table_precomputed [, seed] ...
%        [, table_primes, table_factors, paramsInt])
%
% Looks the permutation up in table_precomputed.perms_<method> and applies it;
% falls back to a live call when the length is not cached.
%
% WHY THIS FILE WAS REWRITTEN
% ---------------------------
% Ten of the interleavers were rewritten and several changed their OUTPUT
% LISTS - interleaver_prime now returns (y, perm, P, g, erM) where it used to
% return (y, perm, erM); interleaver_multiDim returns (y, perm, dims,
% axisOrder, erM) where it returned (y, perm, L, K, erM). MATLAB does not warn
% when a caller asks for fewer outputs than a function provides: a stale
% `[a, b, c] = interleaver_prime(...)` would silently bind the PRIME MODULUS to
% the variable the caller treats as erM, and `if erM == ""` would then take the
% wrong branch. Every per-method call now lives in the switch below, so there
% is exactly one place where a signature can go stale, and it is the same
% shape as PrecomputeInterleaversGenerator/local_build.
%
% TWO METHODS MUST NEVER BE SERVED FROM THE TABLE
% `random` and `freqRandom` are redrawn per frame by construction. Serving them
% from a lookup table gives every Monte-Carlo trial at a given N the identical
% permutation - the exact defect that was just removed from those two files
% (they used to call rng(2106) internally). They are forced down the live path
% here regardless of what the table contains, so a stale table cannot
% reintroduce it.
%
% L, K, Q, R
% Carried through for the caller's bookkeeping. Their meaning is per method
% (matrix dimensions, lattice dims, grid axes, chain parameters); they are
% descriptive only and nothing downstream computes with them.
%
% R.T. Sirmen harness, written 2026

   LIVE_ONLY = {'random', 'freqRandom'};

   erM = ""; vectorInterleaved = []; permutation = [];
   L = 0; K = 0; Q = 1; R = 1; info = struct();

   try
      if nargin < 3 || isempty(padSymbol), padSymbol = 0; end
      if nargin < 4 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end
      if nargin < 5, table_precomputed = []; end
      if nargin < 6, seedOrExtra = 2106; end
      if nargin < 7, table_primes = []; end
      if nargin < 8, table_factors = struct(); end
      if nargin < 9, paramsInt = struct(); end
      if isempty(seedOrExtra), seedOrExtra = 2106; end

      [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
      if failed
         erM = sprintf('interleaver_generic_pc: Data shape error (%s). Must be (1xN)', method);
         return;
      end
      N = length(vectorIn);

      % ---- table first, unless the method must be redrawn -----------------
      if ~any(strcmp(LIVE_ONLY, method)) && ~isempty(table_precomputed) && isstruct(table_precomputed)
         fld = sprintf('perms_%s', method);
         if isfield(table_precomputed, fld)
            M = table_precomputed.(fld);
            key = sprintf('N_%d', N);
            if isa(M, 'containers.Map') && M.isKey(key)
               e = M(key);
               permutation = e.perm;
               adjN = numel(permutation);
               if adjN > N
                  vectorPadded = [vectorIn, repmat(padSymbol, 1, adjN - N)];
               else
                  vectorPadded = vectorIn;
               end
               vectorInterleaved = vectorPadded(permutation);
               if isfield(e, 'L'), L = e.L; end
               if isfield(e, 'K'), K = e.K; end
               if isfield(e, 'Q'), Q = e.Q; end
               if isfield(e, 'R'), R = e.R; end
               if isfield(e, 'info') && isstruct(e.info), info = e.info; end
               [vectorInterleaved, permutation] = local_row(vectorInterleaved, permutation);
               return;
            end
         end
      end

      % ---- live fallback ---------------------------------------------------
      [vectorInterleaved, permutation, L, K, Q, R, erM, info] = ...
         local_live(method, vectorIn, padSymbol, maxExtensionPercentage, ...
                    seedOrExtra, table_primes, table_factors, paramsInt);

      [vectorInterleaved, permutation] = local_row(vectorInterleaved, permutation);

   catch ME
      erM = sprintf('interleaver_generic_pc(%s): Error line %d: %s', method, ME.stack(1).line, ME.message);
   end
end

%% ------------------------------------------------------------------------
function [y, p] = local_row(y, p)
   if iscolumn(y), y = y'; end
   if iscolumn(p), p = p'; end
end

function v = local_get(s, f, dflt)
   if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end

function L = local_estimateL(N)
   L = 1;
   for a = floor(sqrt(N)):-1:2
      if mod(N, a) == 0, L = a; break; end
   end
   if L == 1, L = 2; end
end

function [y, p, L, K, Q, R, erM, info] = local_live(m, x, pad, mx, seed, tp, tf, P)
% One switch, every signature. Mirrors PrecomputeInterleaversGenerator so the
% cached and the live path can never build different permutations.
   y = []; p = []; L = 0; K = 0; Q = 1; R = 1; erM = ""; info = struct();
   N  = length(x);
   Le = local_estimateL(N);

   switch m
      case 'block'
         [y, p, erM] = interleaver_block(x, Le, pad, mx);              L = Le; K = ceil(N/Le);
      case 'matrix'
         [y, p, L, K, erM] = interleaver_matrix(x, pad, mx);
      case 'helical'
         [y, p, L, K, erM] = interleaver_helical(x, pad, mx);
      case 'helicalScan'
         [y, p, L, K, erM] = interleaver_helicalScan(x, pad, mx);
      case 'diagonal'
         % R,C omitted -> interleaver_diagonal dimensions itself (and pads),
         % like matrix/helical/spiral. Passing Le and N/Le rejected every prime
         % N outright, because N/Le is not an integer there.
         [y, p, erM, L, K] = interleaver_diagonal(x, [], [], pad, mx);
      case 'spiral'
         [y, p, L, K, erM] = interleaver_spiral(x, pad, mx);
      case 'snake'
         [y, p, L, K, erM] = interleaver_snake(x, pad, mx, tp, tf);
      case 'time'
         [y, p, L, K, erM] = interleaver_time(x, pad, mx);             % L=Nsc, K=Nsym
      case 'freqDeterm'
         [y, p, L, K, Q, R, erM] = interleaver_freqDeterm(x, pad, mx);
      case 'freqRandom'
         [y, p, L, K, Q, R, erM] = interleaver_freqRandom(x, pad, mx, seed);
      case 'hierarchical'
         [y, p, L, K, Q, R, erM] = interleaver_hierarchical(x, pad, mx);
      case 'multiDim'
         [y, p, dims, ax, erM] = interleaver_multiDim(x, pad, mx, local_get(P,'multiDim_nDims',3));
         if ~isempty(dims), L = dims(1); K = dims(end); Q = numel(dims); end
      case 'latinSquare'
         [y, p, L, K, erM] = interleaver_latinSquare(x, mx);
      case 'chaotic'
         [y, p, erM] = interleaver_chaotic(x, local_get(P,'rChaotic',3.9), local_get(P,'xChaotic',0.37));
      case 'prime'
         [y, p, L, K, erM] = interleaver_prime(x, pad, mx, tp);        % L=P, K=g
      case 'algebraic'
         [y, p, L, K, info, erM] = interleaver_algebraic(x, pad, mx, tp, tf, local_get(P,'algOpts',struct()));
         if isstruct(info) && isfield(info,'f1'), Q = info.f1; R = info.f2; end
      case 'turbo'
         [y, p, info, erM] = interleaver_turbo(x, Le, pad, mx);
         if isstruct(info) && isfield(info,'f1'), Q = info.f1; R = info.f2; end
      case 'convolutional'
         [y, p, L, K, erM] = interleaver_convolutional(x, [], [], pad, mx);   % L=M, K=D
      case 'blockCM'
         % v2: rows are the codewords (row length n), read column-wise
         nC = local_get(P, 'FECn', 15);
         [y, p, erM] = interleaver_block(x, nC, pad, mx);              L = nC; K = ceil(N/nC);
      case 'convCM'
         % v2: M = n branches, D = max(1, floor(K/n)) with K = N/n (declared)
         nC = local_get(P, 'FECn', 15);
         Dc = max(1, floor((N / nC) / nC));
         [y, p, L, K, erM] = interleaver_convolutional(x, nC, Dc, pad, mx);  % L=M, K=D
      case 'random'
         [y, p, erM] = interleaver_random(x, Le, seed, pad, mx);
      case 'srandom'
         [y, p, info, erM] = interleaver_srandom(x, local_get(P,'srandom_spreadS',[]), local_get(P,'srandom_seed',seed));
         if isstruct(info) && isfield(info,'S_achieved'), Q = info.S_achieved; end
      case 'goldenRP'
         [y, p, info, erM] = interleaver_goldenRP(x, local_get(P,'goldenRP_offset',0));
         if isstruct(info) && isfield(info,'P'), Q = info.P; end
      % 2026-08 canonicalisation changed both signatures. The old calls were
      % wrong in three ways and one of them threw on every success:
      %   * drp's 3rd argument used to be a seed; it is the STRIDE now, and
      %     handing 2106 to it as a stride is not something the interleaver
      %     can detect as a mistake.
      %   * drp's info fields are M and p, no longer W and P.
      %   * arp's info carries P0, not P - so "Q = info.P" raised
      %     "Unrecognized field name" whenever isfield(info,'C') was true,
      %     which is every successful call.
      case 'drp'
         [y, p, info, erM] = interleaver_drp(x, local_get(P,'drp_ditherM',[]), ...
                                                local_get(P,'drp_strideP',[]));
         if isstruct(info) && isfield(info,'M'), L = info.M; Q = info.p; end
      case 'arp'
         % Argument 2 is ignored by the canonical file: C is fixed at 4, the
         % standardised value, and any other C is refused rather than honoured.
         [y, p, info, erM] = interleaver_arp(x, [], ...
                                             local_get(P,'arp_strideP',[]), local_get(P,'arp_offsetsQ',[]));
         if isstruct(info) && isfield(info,'C'), L = info.C; Q = info.P0; end
      case 'S'
         [y, p, L, K, erM] = interleaver_S(x, pad, local_get(P,'extensionPercentage',0.0), ...
                                           local_get(P,'minMultiplier',3), tp, tf, ...
                                           local_get(P,'pairStrategy',"minSum"), ...
                                           local_get(P,'swapStrategy',"oddOnly"));
      otherwise
         erM = sprintf('interleaver_generic_pc: unknown method "%s"', m);
   end
end
