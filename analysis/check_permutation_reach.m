function R = check_permutation_reach(N, opts)
%CHECK_PERMUTATION_REACH  Can each method move a symbol across the frame?
%
%   R = check_permutation_reach(1200)
%   R = check_permutation_reach(1200, struct('methods', {{'freqDeterm','time'}}))
%
% WHY THIS EXISTS
% ===========================================================================
% A benchmark that injects a contiguous time-domain burst is asking one
% question: how far across the frame does the permutation carry the symbols
% the burst destroyed. A method that cannot carry them beyond a fixed window
% cannot answer it, however well it is implemented, and its position at the
% bottom of a ranking says nothing about its quality - only that it was asked
% the wrong question.
%
% freqGridApply is the case that prompted this. It maps
%
%       permutation(tt*Nsc + (1:Nsc)) = tt*Nsc + rot
%
% so the destination block and the source block are always the same OFDM
% symbol: the subcarriers of a symbol are permuted among themselves and no
% symbol exchanges data with any other. That is correct for a frequency
% interleaver, which is meant to be paired with a time interleaver, and it is
% fatal in a benchmark where the only interleaver present is that one.
%
% Nothing in the results table shows it. The method is a valid bijection, it
% produces a permutation at every length, every health check passes, and it
% simply scores near zero. This function is the check that names the cause
% instead of leaving it as a low number.
%
% WHAT IT MEASURES
%   reach       max |perm(i) - i| / N. How far the permutation moves a symbol
%               at the extreme. A full-frame map reaches ~1; a block-local
%               map reaches about the block width.
%   medReach    the median of the same, which is what a typical symbol gets.
%   blocks      how many maximal consecutive ranges the permutation
%               decomposes into, and
%   widest      the width of the largest of them as a fraction of N. The
%               WIDTH is the criterion, not the count: a map that fixes one
%               interior point has two blocks and is not confined at all.
%               A method is confined when its widest block is under a
%               quarter of the frame.
%   spanBurst   the actual quantity the benchmark cares about: for a burst of
%               B contiguous positions, how many FEC codewords it lands in
%               after deinterleaving, and the worst per-codeword load. A
%               method that puts more than t errors in one codeword at a
%               burst length the benchmark uses is being scored on a failure
%               it cannot avoid.
%
% A method whose widest block is a small fraction of the frame is structurally
% confined. That is a property of the design, not a defect, and the right
% response is to declare the scope of the benchmark rather than to quietly
% drop the method.

   if nargin < 1 || isempty(N), N = 1200; end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'n'), opts.n = 15; end
   if ~isfield(opts, 't'), opts.t = 3;  end
   if ~isfield(opts, 'B'), opts.B = 8 * opts.n; end
   if ~isfield(opts, 'methods'), opts.methods = {}; end

   cfg = configure_simulation();
   if isempty(opts.methods)
      meths = cfg.allIntMethods;
   else
      meths = opts.methods;
   end

   fprintf('\n=== PERMUTATION REACH   N = %d, code (n,t) = (%d,%d), burst B = %d ===\n', ...
           N, opts.n, opts.t, opts.B);
   fprintf('%-16s %8s %9s %8s %8s %10s %9s  %s\n', 'method', 'reach', 'medReach', ...
           'blocks', 'widest', 'codewords', 'maxLoad', 'reading');
   fprintf('%s\n', repmat('-', 1, 104));

   R = struct('method', {}, 'reach', {}, 'medReach', {}, 'blocks', {}, ...
              'widestFrac', {}, 'codewords', {}, 'maxLoad', {}, 'confined', {});

   for i = 1:numel(meths)
      m = meths{i};
      p = local_perm(m, N, cfg);
      if isempty(p), fprintf('%-16s   (not available at this length)\n', m); continue; end
      Np = numel(p);

      d = abs(p - (1:Np));
      reach = max(d) / Np;
      medR  = median(d) / Np;
      [nb, widest] = local_blocks(p);

      s = max(1, floor(Np/3));
      hit = p(s : min(Np, s + opts.B - 1));
      hit = hit(hit <= Np);
      cwi = ceil(hit / opts.n);
      ucw = unique(cwi);
      maxLoad = max(accumarray(cwi(:) - min(cwi) + 1, 1));

      % CONFINED is about the WIDEST block, not the block count. A permutation
      % of 1200 positions that happens to fix one interior point decomposes
      % into two blocks, one of them 1199 wide - that is not a confinement,
      % and an earlier version of this function called it one, flagging 19 of
      % 24 methods. What matters is whether the largest range a symbol can be
      % carried within is a small fraction of the frame.
      confined = (widest / Np) < 0.25;

      if confined
         note = sprintf('CONFINED: widest block %d of %d (%.0f%%)', widest, Np, 100*widest/Np);
      elseif maxLoad > opts.t
         note = 'full-frame; exceeds capacity at this B';
      else
         note = 'full-frame; within capacity';
      end
      fprintf('%-16s %8.3f %9.3f %8d %8.2f %10d %9d  %s\n', m, reach, medR, nb, ...
              widest/Np, numel(ucw), maxLoad, note);

      R(end+1) = struct('method', m, 'reach', reach, 'medReach', medR, ...
                        'blocks', nb, 'widestFrac', widest/Np, ...
                        'codewords', numel(ucw), 'maxLoad', maxLoad, ...
                        'confined', confined); %#ok<AGROW>
   end

   nc = sum([R.confined]);
   fprintf('%s\n', repmat('-', 1, 104));
   fprintf(['%d of %d method(s) are structurally confined to a sub-frame block.\n' ...
            'For those, a contiguous burst longer than one block cannot be spread\n' ...
            'no matter how good the permutation inside the block is, so their score\n' ...
            'against a time-domain burst is a statement about the benchmark''s scope\n' ...
            'and not about the method. Declare the scope; do not silently drop them.\n\n'], ...
            nc, numel(R));
end

% =========================================================================
function [b, widest] = local_blocks(p)
% Decompose the permutation into maximal consecutive ranges that map onto
% themselves, and return BOTH the count and the width of the widest one.
%
% The count alone is misleading: a permutation with a single fixed interior
% point splits into two blocks, one of which is nearly the whole frame. The
% widest block is what bounds how far a symbol can travel, and that is the
% quantity a burst-spreading benchmark depends on.
   Np = numel(p); b = 0; hi = 0; last = 0; widest = 0;
   for i = 1:Np
      hi = max(hi, p(i));
      if hi == i
         b = b + 1;
         widest = max(widest, i - last);
         last = i;
      end
   end
end

function p = local_perm(m, N, cfg)
   p = [];
   % cfg.dataPathPF does not exist - configure_simulation defines no such
   % field - so this load never loaded and the catch quietly left the prime
   % and factor tables empty. Any method reached through those tables then
   % returns no permutation and lands in the table as NaN, which reads as
   % "not computable" rather than as "the tables were never opened".
   tp = []; tf = [];
   [tdir_, erF_] = find_table_dir(char(cfg.dataSavePath), true);
   if erF_ == ""
      [tp, tf, erP_] = PrimeFactorLoader(tdir_);
      if erP_ ~= "", fprintf(2, 'PrimeFactorLoader: %s\n', char(erP_)); tp = []; tf = []; end
   else
      fprintf(2, 'no precomputed tables found; some methods may not build\n');
   end
   try
      paramsInt = struct('permutationSeed', 1, 'minMultiplier', 2, ...
                         'pairStrategy', 'balanced', 'swapStrategy', 'parity', ...
                         'extensionPercentage', 0.5);
      [~, p] = interleaver_generic_pc(1:N, m, 0, 0.5, [], 1, tp, tf, paramsInt);
   catch ME
      fprintf('%-16s   (%s)\n', m, ME.message);
      p = [];
   end
end
