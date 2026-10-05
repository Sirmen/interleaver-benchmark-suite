function [vectorInterleaved, permutation, info, erM] = ...
    interleaver_srandom(vectorIn, spreadS, seed, maxRestarts)
% S-Random (semi-random / spread) interleaver.   Divsalar & Pollara, 1995.
%
% Indices are drawn at random and a candidate is accepted only if it is
% farther than S from each of the S most recently accepted values, so the
% result is a permutation with guaranteed spread S:
%
%     |i - j| <= S   ==>   |permutation(i) - permutation(j)| > S
%
% CONVENTION: same as every other method in this harness -
%     vectorInterleaved = vectorIn(permutation)      (gather index)
% so deinterleaver_universal inverts it with no extra parameters.
%
% NO PADDING: operates at the exact input length, so BE = 1.0 always.
%
% INPUTS
%   vectorIn     1xN data
%   spreadS      requested spread. [] -> floor(sqrt(N/2))-1, the largest value
%                for which the greedy search converges reliably
%   seed         RNG seed (reproducibility). Default 0
%   maxRestarts  restarts before S is decremented. Default 5
%
% OUTPUTS
%   info.S_requested / info.S_achieved / info.seed
%
% PERFORMANCE: generation is O(N^2). Results are cached per (N, S, seed) in a
% persistent map, so the 341-size x 5-bin x 35-run sweep pays the cost once
% per length instead of ~60k times. Clear with:  clear interleaver_srandom
%
% WHY IT IS IN THE BENCHMARK: S-random is the reference point for every
% "high spread" claim in the interleaver literature. Its absence from a
% separation-optimised study is the most likely reviewer objection.
%
% R.T. Sirmen harness integration, 2026

persistent permCache
if isempty(permCache), permCache = containers.Map('KeyType','char','ValueType','any'); end

erM = ""; vectorInterleaved = []; permutation = []; info = struct();
try
   [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
   if failed
      erM = "interleaver_srandom: Data shape error. Must be (1xN)"; return;
   end
   N = length(vectorIn);
   if N < 4, erM = "interleaver_srandom: N must be >= 4"; return; end

   if nargin < 2 || isempty(spreadS),    spreadS    = max(1, floor(sqrt(N/2)) - 1); end
   if nargin < 3 || isempty(seed),       seed       = 0; end
   if nargin < 4 || isempty(maxRestarts),maxRestarts= 5; end

   key = sprintf('N%d_S%d_s%d', N, spreadS, seed);
   if permCache.isKey(key)
      c = permCache(key);
      permutation = c.perm;  info = c.info;
   else
      [permutation, info] = local_build(N, spreadS, seed, maxRestarts);
      permCache(key) = struct('perm', permutation, 'info', info);
   end

   vectorInterleaved = vectorIn(permutation);
   if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
   if iscolumn(permutation),       permutation       = permutation';       end

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%% ------------------------------------------------------------------------
function [perm, info] = local_build(N, Sreq, seed, maxRestarts)
   rng(seed, 'twister');
   S = Sreq;
   while S >= 1
      for attempt = 1:maxRestarts
         perm = zeros(1, N);
         used = false(1, N);
         fail = false;
         for i = 1:N
            av = find(~used);
            lo = max(1, i - S);
            if i > lo
               prev = perm(lo:i-1);
               keep = all(abs(bsxfun(@minus, av(:), prev(:).')) > S, 2).';
               av   = av(keep);
            end
            if isempty(av), fail = true; break; end
            v = av(randi(numel(av)));
            perm(i) = v;  used(v) = true;
         end
         if ~fail
            info = struct('S_requested', Sreq, 'S_achieved', local_spread(perm, S), 'seed', seed);
            return;
         end
      end
      S = S - 1;
   end
   perm = randperm(N);                                  % should not happen
   info = struct('S_requested', Sreq, 'S_achieved', local_spread(perm, 1), 'seed', seed);
end

function s = local_spread(perm, Sw)
   s = 0;
   for cand = 1:(Sw + 2)
      good = true;
      for d = 1:cand
         if any(abs(perm(1+d:end) - perm(1:end-d)) <= cand), good = false; break; end
      end
      if good, s = cand; else, break; end
   end
end
