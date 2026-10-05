function [vectorInterleaved, permutation, Nsc, Nsym, Q, R, erM] = ...
    interleaver_freqDeterm(vectorIn, padSymbol, maxExtensionPercentage, stride)
%INTERLEAVER_FREQDETERM  Deterministic OFDM frequency interleaver.
%   Permutes the SUBCARRIER index inside each OFDM symbol with a fixed,
%   coprime stride. Time (symbol) index untouched.
%
%   Signature matches what interleaver_generic_pc expects in the live
%   interleave_all_pc path:
%       [~, perm, L, K, Q, R, erM] = interleaver_freqDeterm(data, pad, maxExt)
%
% WHY THIS FILE EXISTS SEPARATELY
% ------------------------------
% freqRandom and freqDeterm are two distinct METHODS in the benchmark, and the
% live path (interleave_all_pc -> interleaver_generic_pc) calls them as two
% separate FILES. An earlier revision folded both into interleaver_frequency.m
% with a mode switch; that matches interleave_all.m, which is the dead path.
% Two files it is.
%
% WHAT WAS WRONG BEFORE
% The old implementation was not a frequency interleaver: `L` ("number of
% subcarriers") entered only through totalSymbols = ceil(N/L)*L, i.e. purely as
% padding, so two different L that divide N produced the IDENTICAL permutation
% (verified at N = 255 for L = 5, 15, 17). The permutation itself was a
% stride-3/5/7/11 decimation of the WHOLE frame - over N = 30..510 the stride
% took exactly four values, so burst dispersion never grew with N. It was also
% bit-identical to interleaver_multiDim at N = 30, 37..42.
%
% THE FIX
% The frame is given the 2-D structure the method needs, Nsc x Nsym, and the
% permutation acts on the subcarrier axis only:
%
%       grid(s, t)  ->  grid( basePerm(s) rotated by t , t )
%
% The rotation by the symbol index decorrelates successive OFDM symbols, which
% is what real frequency interleavers do. This makes it the exact complement of
% interleaver_time (symbol axis at fixed subcarrier) - the pair DVB-T, DVB-T2
% and LTE each specify separately.
%
% EXPECT A LOW eta_sep, AND REPORT IT
% A frequency interleaver disperses WITHIN an OFDM symbol, not across time, so
% it is weak against time-domain bursts by construction. That is not a defect:
% it is precisely why the standards pair it with a time interleaver. Report it
% next to `time`.
%
% CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% R.T. Sirmen harness, corrected 2026

   erM = ""; vectorInterleaved = []; permutation = [];
   Nsc = 0; Nsym = 0; Q = 1; R = 1;
   try
      if nargin < 2 || isempty(padSymbol), padSymbol = 0; end
      if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.1; end
      if nargin < 4, stride = []; end

      [N, vectorPadded, Nsc, Nsym, erM] = freqGridSetup(vectorIn, padSymbol, maxExtensionPercentage, 'freqDeterm');
      if ~isempty(char(erM)), return; end

      if isempty(stride), stride = local_coprimeStride(Nsc); end
      if stride < 1 || stride >= Nsc || gcd(stride, Nsc) ~= 1
         erM = sprintf('interleaver_freqDeterm: stride must be in 1..%d and coprime to Nsc=%d', Nsc-1, Nsc);
         return;
      end

      basePerm = mod((0:Nsc-1) * stride, Nsc) + 1;
      permutation = freqGridApply(basePerm, Nsc, Nsym);

      if numel(unique(permutation)) ~= N
         erM = sprintf('interleaver_freqDeterm: not a permutation (N=%d Nsc=%d Nsym=%d)', N, Nsc, Nsym);
         permutation = []; return;
      end

      vectorInterleaved = vectorPadded(permutation);
      Q = stride; R = Nsym;
      if iscolumn(vectorInterleaved), vectorInterleaved = vectorInterleaved'; end
      if iscolumn(permutation),       permutation       = permutation';       end

   catch ME
      erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   end
end

%% ------------------------------------------------------------------------
function stride = local_coprimeStride(Nsc)
%LOCAL_COPRIMESTRIDE  SMALLEST stride >= 2 coprime to Nsc. Not optimised.
%
%   This used to start from round(Nsc/phi) - Crozier's golden relative prime
%   rule - and walk to the nearest coprime value. That is a published
%   high-spread DESIGN, and it is already in the comparison under its own
%   name (`goldenRP`). Using it inside a method called "frequency
%   interleaver" put the same idea in the table twice.
%
%   The smallest coprime stride uses no design freedom: it is the first
%   value that makes the map a bijection, chosen by an arbitrary rule that
%   nobody would claim optimises anything. That is what a baseline should be.
%
%   NOTE FOR THE PAPER: this is a generic deterministic frequency
%   interleaver, NOT the DVB-T/T2 frequency interleaver, which is defined by
%   a standard-specified address generator. Describe it as what it is.
   stride = 1;
   for c = 2:max(2, Nsc - 1)
      if gcd(c, Nsc) == 1, stride = c; return; end
   end
end
