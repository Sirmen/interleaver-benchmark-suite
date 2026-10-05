function [vectorInterleaved, permutation, dims, axisOrder, erM] = ...
    interleaver_multiDim(vectorIn, padSymbol, maxExtensionPercentage, nDims)
%INTERLEAVER_MULTIDIM  d-dimensional block interleaver.  Label: multi-D block.
%   The direct generalisation of the classical two-dimensional block
%   interleaver (write along one axis, read along another) to d axes, in the
%   Ramsey (1970) / Forney (1971) block-interleaving lineage.
%
%   NOT Blaum-Bruck-Vardy. The previous header cited M. Blaum, J. Bruck,
%   A. Vardy, "Interleaving schemes for multidimensional cluster errors",
%   IEEE Trans. Inf. Theory 44(2), 1998. That paper is about correcting
%   cluster errors in two-dimensional ARRAYS with Lee-metric constructions;
%   it is not the construction implemented here, and the citation was wrong.
%   This method is a family generalisation with no single originating paper,
%   so the paper must present it as such and state the two declared choices
%   below (d = 3, balanced dimensions) in the provenance table.
%
% WHY THIS FILE WAS REWRITTEN
% ---------------------------
% The previous version was not multi-dimensional at all. Line 64 read
%
%     permutation = mod((0:adjustedN-1) * stride, adjustedN) + 1;
%
% a 1-D congruential (helical) map - the same construction as
% interleaver_freqDeterm, with which it was bit-identical at N = 30, 37..42.
% Its own header admitted it ("helical/congruential interleaving based on
% Ramsey (1970) and Forney (1971)"), so the method name contradicted the code.
% L and K were computed by choose_balanced_factors and reported as "matrix
% dimensions" but entered the permutation only through adjustedN = L*K, i.e.
% purely as padding - which cost up to 24% bandwidth (BE 0.762 worst case) for
% no algorithmic purpose. Two of the three stride-selection strategies were
% unreachable dead code (they tested gcd(K, L*K) == 1, which is never true).
%
% THE CONSTRUCTION: AXIS REVERSAL, NOT AXIS ROTATION
% Symbols are placed on a d-dimensional lattice d1 x d2 x ... x dd = N and read
% out with the axis order REVERSED. In mixed-radix terms, for d = 3:
%
%     input  i-1 = a1 + a2*d1 + a3*d1*d2            (axis order 1,2,3)
%     output     = a3 + a2*d3 + a1*d3*d2            (axis order 3,2,1)
%
% WHY REVERSAL AND NOT THE CYCLIC ROTATION THE PREVIOUS VERSION USED. The
% two-dimensional block interleaver IS the matrix transpose. The transpose is
% the reversal of the axis order, so the d-dimensional generalisation of a
% block interleaver is reversal, and nothing else. The cyclic rotation
% (1,2,...,d) -> (2,3,...,d,1) also reduces to the transpose at d = 2 - which
% is why it looked equally natural - but at d >= 3 it is a different map that
% does not generalise the method the family is named after. Rotation was my
% choice, not a published one, and it is replaced here on that ground.
%
% Either way the mechanism is the same: a burst that is contiguous in the
% channel is compact along ONE lattice axis, and permuting the axes sends that
% axis to a slowly-varying output coordinate, so the burst is torn apart by
% N/d1 positions - separation O(N^((d-1)/d)) instead of the O(sqrt(N)) of a
% 2-D block interleaver. That is the point of going multi-dimensional, and it
% is what the pre-2026 version (a 1-D congruential map, see above) did not do.
%
% TWO DECLARED CHOICES, BOTH OURS, BOTH REPORTED IN THE PROVENANCE TABLE:
%   d = 3           the lattice order (d = 2 is already in the benchmark)
%   balanced dims   each dimension as close to N^(1/d) as the factorisation
%                   allows, via local_balancedFactors
% No published source fixes either, so they are stated rather than implied.
%
% Dimensions are chosen as balanced as possible (each near N^(1/d)); the length
% is padded only as far as needed to admit a d-way factorisation.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% INPUTS
%   nDims  lattice order. Default 3. d = 2 degenerates to a block interleaver
%          and is rejected, since that is already in the benchmark.
%
% OUTPUTS
%   dims       1 x d vector of lattice dimensions actually used
%   axisOrder  the axis permutation applied (cyclic rotation)
%
% R.T. Sirmen harness, corrected 2026

   erM = ""; vectorInterleaved = []; permutation = []; dims = []; axisOrder = [];
   try
      if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
      if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end
      if nargin < 4 || isempty(nDims), nDims = 3; end

      if nDims < 3
         erM = "interleaver_multiDim: nDims must be >= 3 (d = 2 is the block interleaver)";
         return;
      end

      [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
      if failed
         erM = "interleaver_multiDim: Data shape error. Must be (1xN)"; return;
      end
      N0 = length(vectorIn);
      if N0 < 2^nDims
         erM = sprintf('interleaver_multiDim: N must be >= %d for a %d-D lattice', 2^nDims, nDims);
         return;
      end

      % ---- smallest length >= N0 that factors into nDims factors, all >= 2
      maxN = floor(N0 * (1 + maxExtensionPercentage));
      N = 0;
      for cand = N0:maxN
         d = local_balancedFactors(cand, nDims);
         if ~isempty(d), N = cand; dims = d; break; end
      end
      if N == 0
         erM = sprintf('interleaver_multiDim: no %d-way factorisation for N=%d within %.0f%% extension', ...
                       nDims, N0, maxExtensionPercentage*100);
         return;
      end

      if N > N0
         vectorPadded = [vectorIn, repmat(padSymbol, 1, N - N0)];
      else
         vectorPadded = vectorIn;
      end

      % ---- axis reversal: (1,2,...,d) -> (d,...,2,1)
      %      The d-dimensional generalisation of the matrix transpose, which
      %      is what a 2-D block interleaver is. See the header.
      axisOrder = nDims:-1:1;

      % mixed-radix decode of the input index on the natural axis order
      i0 = 0:N-1;
      a = zeros(nDims, N);
      rem_ = i0;
      for k = 1:nDims
         a(k, :) = mod(rem_, dims(k));
         rem_ = floor(rem_ / dims(k));
      end

      % mixed-radix encode on the rotated axis order
      od = dims(axisOrder);
      out = zeros(1, N);
      mult = 1;
      for k = 1:nDims
         out = out + a(axisOrder(k), :) * mult;
         mult = mult * od(k);
      end

      % gather index: permutation(outputSlot) = sourceIndex
      permutation = zeros(1, N);
      permutation(out + 1) = i0 + 1;

      if numel(unique(permutation)) ~= N
         erM = sprintf('interleaver_multiDim: not a permutation (N=%d dims=%s)', N, mat2str(dims));
         permutation = []; return;
      end

      vectorInterleaved = vectorPadded(permutation);
      if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
      if iscolumn(permutation),       permutation       = permutation';       end

   catch ME
      erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   end
end

%% ------------------------------------------------------------------------
function d = local_balancedFactors(n, k)
% Factor n into exactly k factors, each >= 2, as balanced as possible.
% Returns [] if n has fewer than k prime factors (with multiplicity).
   d = [];
   f = local_primeFactors(n);
   if numel(f) < k, return; end

   % greedy: start from the k largest prime factors, fold the rest into the
   % currently smallest bucket so the dimensions stay near n^(1/k)
   f = sort(f, 'descend');
   d = f(1:k);
   for i = k+1:numel(f)
      [~, j] = min(d);
      d(j) = d(j) * f(i);
   end
   d = sort(d);
end

function f = local_primeFactors(n)
   f = []; m = n; p = 2;
   while p * p <= m
      while mod(m, p) == 0
         f(end+1) = p; m = m / p;
      end
      p = p + 1;
   end
   if m > 1, f(end+1) = m; end
end
