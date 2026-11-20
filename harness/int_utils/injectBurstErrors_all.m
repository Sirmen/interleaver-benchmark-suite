function [received_all, noiseRatio_all, erM] = injectBurstErrors_all(...
    interleaved_all, burstMask, config)
%INJECTBURSTERRORS_ALL  One burst realisation, applied identically to every method.
%
%   [received_all, noiseRatio_all, erM] = injectBurstErrors_all(interleaved_all, burstMask, config)
%
% WHAT CHANGED ON 6 NOVEMBER 2026, AND WHY
% ---------------------------------------------------------------------------
% The study rests on one premise:
%
%     "Every trial generates ONE frame and ONE burst realisation, and all
%      methods are given that same realisation ... The design is therefore
%      fully PAIRED."
%
% This function shared the burst MASK, as that premise requires, and then drew
% the replacement symbol INSIDE the per-method loop:
%
%     for pos = errorPositions
%         currentSymbol = interleaved(pos);
%         while attempts < 10
%             newSymbol = randi([0, config.base - 1]);   % <-- per method
%             if newSymbol ~= currentSymbol, received(pos) = newSymbol; ...
%
% The global RNG advances, so the second method saw different values at the
% same positions, and the rejection loop consumed a method-dependent number of
% draws on top. Positions were shared; VALUES were not. Measured with three
% identical frames under three method names in one call:
%
%       base 2  : 0 of 30 positions differ   (safe, by accident)
%       base 16 : 27 of 30 differ
%       base 32 : 28 of 30 differ
%       base 64 : 30 of 30 differ
%
% Only a binary alphabet was safe, because there the rejection loop leaves no
% freedom. Every other campaign compared methods on different realisations.
%
% HOW LOUD IT WAS, AND WHY IT DEPENDS ON t
% ---------------------------------------------------------------------------
% The values can only matter through MISCORRECTION. A codeword within t is
% corrected exactly; one beyond t is returned unchanged, so its residual errors
% are the injected POSITIONS, which were shared. The outcome depends on the
% values only when a codeword beyond t is "corrected" to a wrong codeword, at
% probability of order 1/t!: about 0.5 at t = 2, 0.04 at t = 4, and
% negligible at large t. Two methods that produce the same permutation
% differed, under per-method draws, in a large share of cells at t = 2 and in
% none at large t. So the defect is invisible at high t and dominant at low t.
%
% THE FIX: ONE ADDITIVE ERROR VECTOR PER TRIAL
% ---------------------------------------------------------------------------
% A symmetric symbol channel adds an error value that does not depend on the
% symbol it lands on, which is also the model Reed-Solomon theory assumes: a
% received word is a codeword plus an error vector. So the trial draws ONE
% vector delta over the frame positions, nonzero exactly at the mask positions,
% and every method receives
%
%       received = mod(interleaved + delta, base)
%
% This is not a change of distribution. delta uniform on {1, ..., base-1}
% makes mod(s + delta, base) uniform over the base-1 values DIFFERENT FROM s,
% which is precisely what the rejection loop produced. The marginal law of the
% injected symbol is identical; what changes is that the realisation is now
% shared, and that every mask position is now guaranteed to be an error
% instead of falling back after ten rejections.
%
% WHAT IT COSTS
% ---------------------------------------------------------------------------
% The number of RNG draws per trial changes, so results produced after this
% date do NOT reproduce earlier runs value for value. Earlier runs are not
% wrong in their aggregates - the old term was zero-mean, so the paired tests
% were conservative rather than optimistic - but their per-length numbers
% carried a noise floor of about 0.019 in CR at t = 2. Anything quoted per
% length from a pre-fix run has to be requoted from a post-fix run.
%
% config.errorValueMode = 'legacy' restores the old per-method draw, for
% reproducing results published before 6 November 2026 and for nothing else.
% configure_simulation sets it for the grid modes of the primary campaign
% ('common', 'standards', 'legacy'), which ran that way (article, Section
% 7.4); the further campaigns of Section 8.9 use 'shared'.
% It warns once per session when used.
%
% NOT CHANGED HERE: injectBurstErrors_encoded, which injects into the
% no-interleaving baseline. It is outside the paired comparison - its output
% reaches every method as the single scalar decErrRate_woInt per trial - so
% sharing delta with it would alter CR's denominator without making any
% comparison fairer. Left alone deliberately.
%
% R.T. Sirmen harness, fix 2026-11-06

   erM = "";
   received_all = struct();
   noiseRatio_all = struct();

   try
      methods = fieldnames(interleaved_all);
      if isempty(methods), return; end

      if ~isfield(config, 'base') || isempty(config.base)
         erM = "injectBurstErrors_all: config.base is required";
         return;
      end
      base = double(config.base);
      if base < 2
         erM = sprintf('injectBurstErrors_all: base must be at least 2, got %g', base);
         return;
      end

      mode = 'shared';
      if isfield(config, 'errorValueMode') && ~isempty(config.errorValueMode)
         mode = lower(char(string(config.errorValueMode)));
      end

      switch mode
         case 'shared'
            [received_all, noiseRatio_all, erM] = ...
               local_shared(interleaved_all, methods, burstMask, base);
         case 'legacy'
            local_warnLegacy();
            [received_all, noiseRatio_all, erM] = ...
               local_legacy(interleaved_all, methods, burstMask, base);
         otherwise
            erM = sprintf(['injectBurstErrors_all: unknown errorValueMode "%s". ' ...
                           'Use ''shared'' or ''legacy''.'], mode);
      end

   catch ME
      erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   end
end

% ---------------------------------------------------------------------------
function [received_all, noiseRatio_all, erM] = local_shared(interleaved_all, methods, burstMask, base)
%LOCAL_SHARED  One delta vector for the trial, the same for every method.
   erM = "";
   received_all = struct();
   noiseRatio_all = struct();

   % The frame the delta has to span. Methods may differ in length when the
   % frame is padded, so the vector is drawn over the longest and sliced per
   % method - which keeps position p meaning the p-th transmitted symbol for
   % everyone, the only reading under which "the same realisation" is true.
   lenMax = 0;
   for i = 1:numel(methods)
      lenMax = max(lenMax, numel(interleaved_all.(methods{i})));
   end
   if lenMax == 0, return; end

   mask = burstMask(:).';
   if numel(mask) > lenMax
      mask = mask(1:lenMax);
   elseif numel(mask) < lenMax
      mask = [mask, zeros(1, lenMax - numel(mask))];
   end

   % THE MODULUS IS THE FIELD SIZE, NOT THE MESSAGE ALPHABET (fix 18 Nov 2026).
   % The transmitted symbols are elements of GF(q), q = 2^ceil(log2(base)):
   % message symbols lie in 0..base-1, but parity symbols take every value in
   % 0..q-1. With mod(x + d, base) and base < q (base 10 for the RS(15,k)
   % codes over GF(16)), every parity symbol >= base was changed EVEN WHERE
   % d = 0, i.e. outside the burst: about 6/16 of the parity symbols became
   % errors in every codeword. That silently removed the correction capacity
   % (RS(15,11): 1.5 extra errors per word against t = 2) and voided the
   % first c15t2/c15t4 campaigns. It was harmless wherever base = q (32 for
   % RS(31,21) and RS(24,16)); there mod(., q) and mod(., base) are the same
   % operation.
   q = 2 ^ ceil(log2(base));
   pos = find(mask);
   delta = zeros(1, lenMax);
   if ~isempty(pos)
      % Uniform on {1, ..., q-1}: nonzero, so every mask position is an
      % error, and mod(s + delta, q) is uniform over the q-1 field elements
      % other than s.
      delta(pos) = randi([1, q - 1], 1, numel(pos));
   end

   for i = 1:numel(methods)
      m = methods{i};
      x = interleaved_all.(m);
      n = numel(x);

      d = delta(1:min(n, lenMax));
      if numel(d) < n, d = [d, zeros(1, n - numel(d))]; end %#ok<AGROW>
      if iscolumn(x), d = d(:); end

      r = mod(x + d, q);
      % Guard: a symbol changes exactly where the mask says so. This is the
      % check that would have caught the base < q defect on the first trial.
      if any(r(d == 0) ~= x(d == 0)) || any(r(d ~= 0) == x(d ~= 0))
         erM = sprintf(['injectBurstErrors_all: method %s - symbols changed outside ' ...
                        'the burst mask or unchanged inside it (base %g, q %g).'], m, base, q);
         return;
      end
      received_all.(m) = r;
      noiseRatio_all.(m) = sum(d ~= 0) / n;
   end
end

% ---------------------------------------------------------------------------
function [received_all, noiseRatio_all, erM] = local_legacy(interleaved_all, methods, burstMask, base)
%LOCAL_LEGACY  The pre-6-November behaviour, kept verbatim for reproduction.
%   Draws the replacement symbol per method, so two methods do not see the
%   same realisation. Do not use for new work.
   erM = "";
   received_all = struct();
   noiseRatio_all = struct();

   for i = 1:numel(methods)
      method = methods{i};
      interleaved = interleaved_all.(method);
      received = interleaved;

      if length(interleaved) > length(burstMask)
         effectiveMask = [burstMask, zeros(1, length(interleaved) - length(burstMask))];
      else
         effectiveMask = burstMask(1:length(interleaved));
      end

      errorPositions = find(effectiveMask);
      errorCount = 0;

      for pos = errorPositions
         currentSymbol = interleaved(pos);
         attempts = 0;
         while attempts < 10
            newSymbol = randi([0, base - 1]);
            if newSymbol ~= currentSymbol
               received(pos) = newSymbol;
               errorCount = errorCount + 1;
               break;
            end
            attempts = attempts + 1;
         end
         if attempts >= 10
            received(pos) = mod(currentSymbol + 1, base);
            errorCount = errorCount + 1;
         end
      end

      received_all.(method) = received;
      noiseRatio_all.(method) = errorCount / length(interleaved);
   end
end

function local_warnLegacy()
   persistent said
   if isempty(said)
      warning(['injectBurstErrors_all: errorValueMode = ''legacy''. The error ' ...
               'VALUES are drawn per method, so the methods do not see the same ' ...
               'channel realisation. This exists only to reproduce results ' ...
               'published before 6 November 2026.']);
      said = true;
   end
end
