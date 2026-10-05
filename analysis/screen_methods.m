function R = screen_methods(dataDir, opts)
%SCREEN_METHODS  Declared admissibility and pathology screen over the field.
%
%   R = screen_methods('<resultsDir>')
%   R = screen_methods(dataDir, struct('N', 1200, 'baseline', 'S'))
%
% WHAT THIS ANSWERS
% ===========================================================================
% Two methods were removed from scope on a structural criterion. The obvious
% question is whether the criterion was chosen to remove those two, and the
% only answer that carries any weight is a screen that applies every criterion
% to every method at once, with the thresholds fixed before the table is read.
% That is what this is. It is not a search for reasons to exclude; four of its
% five verdicts keep a method in the comparison.
%
% THE FIVE CONDITIONS, AND WHY EACH IS SEPARATE
% ===========================================================================
%   P1  CONFINED           widest closed block < 1/4 of the frame (criterion A1 in the manuscript).
%                          The permutation cannot carry a symbol across the
%                          frame, so a contiguous burst cannot be spread at
%                          all. Out of scope: the benchmark's question is
%                          unanswerable for the method.
%
%   P3  CENSORED           more than 20 % of the method's trials have CR
%                          exactly 0. CR is clamped at zero, so once a method
%                          is at the floor in a fifth of its trials the
%                          differences among such methods are compressed and
%                          its reported spread is a lower bound. In scope,
%                          but no ordering may be claimed at the bottom.
%
%   P4  RATE-LIMITED       the method's RES deficit is carried by the BE term
%                          rather than the CR term. RES = w1 CR_z + w2 BE_z
%                          exactly, so the split is arithmetic and not a
%                          model: a method whose deficit is mostly BE_z is
%                          not failing to spread the burst, it is paying for
%                          extending the frame. In scope, and the reading of
%                          its position changes completely.
%
%   P5  CAPACITY-EXCEEDED  a burst of B overloads some codeword beyond t at
%                          more than half of all start positions, while the
%                          permutation still spans the frame. The fraction is
%                          taken over EVERY start position, because the load a
%                          burst produces depends on where it lands and a
%                          single window supports no claim at all.
%                          This is the condition that must NOT be treated
%                          like P1. A confined method cannot answer the
%                          question; a full-frame method that overloads a
%                          codeword answered it badly. Keeping the two apart
%                          is what makes the scope claim of Section III-I
%                          something other than a way of deleting the
%                          methods at the bottom of the table.
%
%   P6  DEGENERATE         more than half the positions are fixed points, or
%                          the permutation is the identity at some length.
%                          A permutation that barely moves anything is a
%                          configuration failure, not a design.
%
% A method may satisfy several. The verdict column names every one it meets,
% because a method that is both rate-limited and capacity-exceeded is a
% different case from one that is only the second.
%
% OPTIONS
%   N          frame length for the structural columns   [1200]
%   baseline   method whose paired difference is shown   ['S']
%   n, t       code parameters                           [15, 3]
%   B          burst length for the capacity column      [8*n]
%   censorTol  P3 threshold, fraction of trials with CR = 0  [0.20]
%   overTol    P5 threshold, fraction of start positions    [0.50]
%   confTol    P1 threshold, widest block as a fraction     [0.25]
%   fixedTol   P6 threshold, fraction of fixed points       [0.50]
%   nDraw      draws averaged for the two methods that redraw   [15]
%
% COLUMNS
%   CRterm, BEterm   the exact additive parts of mean RES
%   over%            start positions where the burst overloads a codeword
%   wstLd            worst codeword load over all start positions

   if nargin < 1 || isempty(dataDir)
      c = configure_simulation(); dataDir = char(c.dataSavePath);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'N'),         opts.N = 1200;        end
   if ~isfield(opts, 'baseline'),  opts.baseline = 'S';  end
   if ~isfield(opts, 'n'),         opts.n = 15;          end
   if ~isfield(opts, 't'),         opts.t = 3;           end
   if ~isfield(opts, 'B'),         opts.B = 8 * opts.n;  end
   if ~isfield(opts, 'censorTol'), opts.censorTol = 0.20; end
   if ~isfield(opts, 'fixedTol'),  opts.fixedTol  = 0.50; end
   if ~isfield(opts, 'confTol'),   opts.confTol   = 0.25; end
   if ~isfield(opts, 'overTol'),   opts.overTol   = 0.50; end
   % Draws used for the two methods that redraw their permutation each call.
   if ~isfield(opts, 'nDraw'),     opts.nDraw     = 15;   end

   cfg = configure_simulation();

   % ---- data side: pooled over every sweep, per method ---------------------
   d = dir(fullfile(dataDir, 'KPItableDetailed_*.mat'));
   if isempty(d), error('screen_methods: no KPItableDetailed_*.mat in %s', dataDir); end

   names = {}; nRow = []; sCR = []; sBEz = []; sCRz = []; sRES = []; sBE = []; nZero = [];
   for i = 1:numel(d)
      T = local_rows(load(fullfile(dataDir, d(i).name)));
      if isempty(T), continue; end
      m = {T.method}';
      CR = double([T.CR]'); RES = double([T.RES]');
      BE = double([T.encodedLen]') ./ double([T.interleavedLen]');
      CRz = double([T.CR_z]'); BEz = double([T.BE_z]');
      u = unique(m);
      for j = 1:numel(u)
         at = strcmp(m, u{j});
         k = find(strcmp(names, u{j}), 1);
         if isempty(k)
            names{end+1} = u{j}; k = numel(names); %#ok<AGROW>
            nRow(k) = 0; sCR(k) = 0; sBEz(k) = 0; sCRz(k) = 0; sRES(k) = 0; sBE(k) = 0; nZero(k) = 0;
         end
         nRow(k)  = nRow(k)  + sum(at);
         sCR(k)   = sCR(k)   + sum(CR(at));
         sBE(k)   = sBE(k)   + sum(BE(at));
         sCRz(k)  = sCRz(k)  + sum(CRz(at));
         sBEz(k)  = sBEz(k)  + sum(BEz(at));
         sRES(k)  = sRES(k)  + sum(RES(at));
         nZero(k) = nZero(k) + sum(CR(at) == 0);
      end
   end
   mCR = sCR ./ nRow;  mBE = sBE ./ nRow;
   mCRz = sCRz ./ nRow; mBEz = sBEz ./ nRow; mRES = sRES ./ nRow;
   fZero = nZero ./ nRow;

   % ---- structure side: from the permutation, no simulation ---------------
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
   % TWO METHODS REDRAW THEIR PERMUTATION ON EVERY CALL, and a structural
   % table computed from one draw reports that draw, not the method. Three
   % runs of this screen returned reach = 0.953, 0.973 and 0.990 for 'random'
   % at the same N - a spread of four per cent in a column the paper quotes.
   % The ensemble methods are therefore averaged over draws and their spread
   % is reported below the table, so a reader can see which rows are a
   % measurement and which are a sample. The deterministic methods are
   % unaffected: one draw is the method.
   ENSEMBLE = {'random', 'freqRandom'};
   nM = numel(names);
   widestF = nan(1,nM); reach = nan(1,nM); fixedF = nan(1,nM); maxLoad = nan(1,nM); fracOver = nan(1,nM);
   sdReach = nan(1,nM); nDrawn = ones(1,nM);
   for j = 1:nM
      nd = 1;
      if any(strcmpi(ENSEMBLE, names{j})), nd = opts.nDraw; end
      accW = []; accR = []; accF = []; accO = []; accL = [];
      for dr = 1:nd
         p = local_perm(names{j}, opts.N, tp, tf);
         if isempty(p), continue; end
         [w_, r_, f_, o_, l_] = local_structStats(p, opts);
         accW(end+1) = w_; accR(end+1) = r_; accF(end+1) = f_; %#ok<AGROW>
         accO(end+1) = o_; accL(end+1) = l_;                   %#ok<AGROW>
      end
      if isempty(accW), continue; end
      widestF(j) = mean(accW); reach(j) = mean(accR); fixedF(j) = mean(accF);
      fracOver(j) = mean(accO); maxLoad(j) = max(accL);
      nDrawn(j) = numel(accW);
      if numel(accR) > 1, sdReach(j) = std(accR); end
   end

   % ---- verdicts, thresholds fixed above ----------------------------------
   fprintf('\n=== METHOD SCREEN   N = %d, code (n,t) = (%d,%d), B = %d ===\n', ...
           opts.N, opts.n, opts.t, opts.B);
   fprintf('thresholds declared in the header: confined < %.2f frame, censored > %.0f %% of trials,\n', ...
           opts.confTol, 100*opts.censorTol);
   fprintf('rate-limited when the BE term carries more of the deficit than the CR term.\n');
   % The permutation each structural column is read from is built here, not
   % taken from the campaign, so the settings it is built with belong in the
   % output beside the numbers. Only the S family reads the four strategy
   % fields; srandom is one seeded draw, and random and freqRandom redraw on
   % every call, so their structural columns describe a draw, not the method.
   fprintf(['permutations built here: seed 1, minMultiplier 2, pairStrategy balanced, ' ...
            'swapStrategy parity,\nextension 0.5 - except S, built with the settings ' ...
            'its file accepts and the campaign used\n(minSum, oddOnly, minMultiplier 3, ' ...
            'no extension). srandom is one seeded draw; random and\nfreqRandom redraw ' ...
            'per call.\n\n']);
   fprintf('%-15s %7s %7s %7s %7s %7s %8s %8s %7s %7s  %s\n', 'method', 'meanRES', ...
           'CRterm', 'BEterm', 'meanBE', 'CR=0%', 'widest', 'reach', 'over%', 'wstLd', 'verdict');
   fprintf('%s\n', repmat('-', 1, 118));

   [~, ord] = sort(mRES, 'descend');
   R = struct('method', {}, 'meanRES', {}, 'CRterm', {}, 'BEterm', {}, 'meanBE', {}, ...
              'censorFrac', {}, 'widestFrac', {}, 'reach', {}, 'fracOver', {}, 'maxLoad', {}, 'flags', {});
   for j = ord
      w = cfg_weights();
      crT = w(1) * mCRz(j);        % exact additive parts of mean RES
      beT = w(2) * mBEz(j);

      fl = {};
      if isfinite(widestF(j)) && widestF(j) < opts.confTol, fl{end+1} = 'CONFINED'; end %#ok<AGROW>
      if fZero(j) > opts.censorTol,                          fl{end+1} = 'CENSORED'; end %#ok<AGROW>
      if mRES(j) < 0 && beT < 0 && abs(beT) > abs(crT),      fl{end+1} = 'RATE-LIMITED'; end %#ok<AGROW>
      if isfinite(fracOver(j)) && fracOver(j) > opts.overTol && ...
         isfinite(widestF(j)) && widestF(j) >= opts.confTol, fl{end+1} = 'CAPACITY-EXCEEDED'; end %#ok<AGROW>
      if isfinite(fixedF(j)) && fixedF(j) > opts.fixedTol,   fl{end+1} = 'DEGENERATE'; end %#ok<AGROW>
      % A method with no permutation at this N has not passed the screen; it
      % has not been screened. ARP at N = 1200 is the case: its parameters are
      % published only at the standards lengths, so every structural column is
      % NaN and the row would otherwise read "in scope, ranked on merit" —
      % a clean bill of health from a test that never ran.
      if ~isfinite(widestF(j))
         v = 'NOT SCREENED: no permutation at this length';
      elseif isempty(fl)
         v = 'in scope, ranked on merit';
      else
         v = strjoin(fl, ' + ');
      end

      fprintf('%-15s %7.3f %7.3f %7.3f %7.4f %6.1f%% %8.3f %8.3f %6.1f%% %7d  %s\n', ...
              names{j}, mRES(j), crT, beT, mBE(j), 100*fZero(j), ...
              widestF(j), reach(j), 100*fracOver(j), maxLoad(j), v);

      R(end+1) = struct('method', names{j}, 'meanRES', mRES(j), 'CRterm', crT, ...
                        'BEterm', beT, 'meanBE', mBE(j), 'censorFrac', fZero(j), ...
                        'widestFrac', widestF(j), 'reach', reach(j), ...
                        'fracOver', fracOver(j), 'maxLoad', maxLoad(j), 'flags', {fl}); %#ok<AGROW>
   end

   fprintf('%s\n', repmat('-', 1, 118));
   % Which rows are a measurement and which are a sample, said plainly.
   ens = find(nDrawn > 1);
   if ~isempty(ens)
      fprintf('Averaged over %d draws, because these methods redraw their permutation\n', opts.nDraw);
      fprintf('on every call and one draw would report the draw and not the method:\n');
      for j = ens
         fprintf('  %-14s reach %.3f, s.d. %.3f over the draws\n', ...
                 names{j}, reach(j), sdReach(j));
      end
      fprintf('\n');
   end

   fprintf(['CRterm and BEterm are the exact additive parts of mean RES, since\n' ...
            'RES = w1 CR_z + w2 BE_z identically. A method whose deficit sits in\n' ...
            'BEterm is paying for extending the frame, not failing to spread the\n' ...
            'burst, and its position in Table X must be read that way.\n\n' ...
            'CONFINED is the only flag that removes a method from scope. CENSORED\n' ...
            'bounds what may be claimed about the bottom of the ranking.\n' ...
            'RATE-LIMITED and CAPACITY-EXCEEDED change the reading of a position\n' ...
            'without changing whether it counts: a method that overloads a\n' ...
            'codeword while spanning the frame was asked the right question and\n' ...
            'answered it badly, which is a result and not an exclusion.\n\n']);
end

% =========================================================================
function w = cfg_weights()
   w = [0.5 0.5];
end

function [widestF, reach, fixedF, fracOver, maxLoad] = local_structStats(p, opts)
% The four structural quantities and the worst load, for ONE permutation.
% Pulled out of the loop so that a method drawn repeatedly is scored by the
% same code as one drawn once - two copies of this arithmetic is how the
% ensemble rows would come to mean something different from the rest.
   p = p(:).'; Np = numel(p);
   reach   = max(abs(p - (1:Np))) / Np;
   fixedF  = sum(p == (1:Np)) / Np;
   widestF = local_widest(p) / Np;
   % EVERY start position, not one. A single window says nothing: the load a
   % burst produces depends on where it lands, and a method can be within
   % capacity at one offset and far past it at the next.
   K  = ceil(Np / opts.n);
   nS = Np - opts.B + 1;
   over = 0; maxLoad = 0;
   for st = 1:nS
      cwi = ceil(p(st : st + opts.B - 1) / opts.n);
      ld  = accumarray(cwi(:), 1, [K 1]);
      mx  = max(ld);
      maxLoad = max(maxLoad, mx);
      if mx > opts.t, over = over + 1; end
   end
   fracOver = over / nS;
end

function widest = local_widest(p)
   Np = numel(p); hi = 0; last = 0; widest = 0;
   for i = 1:Np
      hi = max(hi, p(i));
      if hi == i, widest = max(widest, i - last); last = i; end
   end
end

function p = local_perm(m, N, tp, tf)
% The reference interleaver must not be the one row of this table that is
% blank. S is built from the settings the campaign ran it with, which are the
% ones its own file accepts; the struct below is this screen's declared
% setting for every other method and names two strategies S does not define.
   p = [];
   if strcmpi(m, 'S')
      pS = struct('permutationSeed', 2106, 'minMultiplier', 3, ...
                  'pairStrategy', "minSum", 'swapStrategy', "oddOnly", ...
                  'extensionPercentage', 0);
      try
         [~, p, ~, ~, ~, ~, erS] = interleaver_generic_pc(1:N, 'S', 0, 0.5, [], 1, tp, tf, pS);
         if erS ~= "", fprintf(2, '  S at N = %d: %s\n', N, char(erS)); end
         if numel(p) == N, return; else, p = []; end
      catch e
         fprintf(2, '  S at N = %d: %s\n', N, e.message);
         p = [];
      end
   end
   try
      paramsInt = struct('permutationSeed', 1, 'minMultiplier', 2, ...
                         'pairStrategy', 'balanced', 'swapStrategy', 'parity', ...
                         'extensionPercentage', 0.5);
      [~, p, ~, ~, ~, ~, erM] = interleaver_generic_pc(1:N, m, 0, 0.5, [], 1, tp, tf, paramsInt);
      % An empty permutation with a message is a failure, not an absence.
      % Returning it silently is how S came to be missing from this table.
      if erM ~= "", fprintf(2, '  %s at N = %d: %s\n', m, N, char(erM)); end
   catch
      p = [];
   end
end

function rows = local_rows(S)
   rows = [];
   fn = fieldnames(S);
   hasTable = exist('istable', 'builtin') || exist('istable', 'file');
   for i = 1:numel(fn)
      v = S.(fn{i});
      if hasTable && istable(v), rows = table2struct(v); return; end
      if isstruct(v) && numel(v) > 1, rows = v; return; end
   end
end
