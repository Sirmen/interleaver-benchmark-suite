function out = fig7_bracket(opts)
%FIG7_BRACKET  Figure 7: how to read a design-metric value, drawn once.
%
%   out = fig7_bracket
%   out = fig7_bracket(struct('N', 1200, 'metric', 'giniLoad', 'candidates', {{'S','drp'}}))
%
% THE PROBLEM THE FIGURE SOLVES
% ===========================================================================
% A design-time metric returns a number, and a number alone licenses nothing.
% giniLoad = 0.61 is neither good nor bad until it is placed against what the
% same metric returns at the same N and B for permutations whose quality is
% not in question. The interpretation guide states that reading as a rule;
% this figure is the rule performed, so a reader applying the suite has a
% template instead of an instruction.
%
% THE BRACKET, AND WHICH WAY IT RUNS
%   identity      the identity permutation: no interleaving at all. A burst
%                 lands whole inside consecutive codewords, so the load
%                 statistic takes its WORST value here. At N = 1200 and
%                 B = 8n the identity returns giniLoad 0.899.
%   random        an ensemble of uniform random permutations, drawn here and
%                 shown as its interquartile range with its extremes. About
%                 0.41 for giniLoad at the same N and B. This is not the
%                 optimum and the figure must not suggest it is: it is what
%                 dispersion with no structure achieves.
%   candidates    the named methods, on the same axis.
%
% All five design statistics measure how much a burst concentrates on a
% codeword, so SMALLER IS BETTER and the bracket runs downward from the
% identity. A candidate sitting in the random band is doing what a coin
% would do; one above it is worse than no design at all; one below every
% random draw has earned its complexity. None of these readings is available
% from the metric value on its own, which is the entire point.
%
% WHY THE BOUNDS ARE COMPUTED AND NOT QUOTED
% Both depend on N, on B, and on the code parameters, so a bracket carried
% over from another study is not a bracket. It is recomputed here at the N
% and B the caller asks for, and the ensemble size is reported so the width
% of the band can be judged.
%
% OPTIONS
%   N           frame length                              [1200]
%   B           burst length                              [8*n]
%   n, t        code length and capacity                  [15, 3]
%   metric      one of overT maxErrCW meanMaxCW cvLoad giniLoad  [giniLoad]
%   candidates  method names to place in the bracket      {'blockCM','convCM','S','drp','goldenRP','block'}
%   nRandom     permutations in the ensemble              [200]
%
% R.T. Sirmen harness, 2026

   if nargin < 1, opts = struct(); end
   if ~isfield(opts, 'N'),          opts.N = 1200;       end
   if ~isfield(opts, 'n'),          opts.n = 15;         end
   if ~isfield(opts, 't'),          opts.t = 3;          end
   if ~isfield(opts, 'B'),          opts.B = 8 * opts.n; end
   if ~isfield(opts, 'metric'),     opts.metric = 'giniLoad'; end
   if ~isfield(opts, 'candidates'), opts.candidates = {'blockCM', 'convCM', 'S', 'drp', 'goldenRP', 'block'}; end
   if ~isfield(opts, 'nRandom'),    opts.nRandom = 200;  end
   if ~isfield(opts, 'seed'),       opts.seed = 20260101; end
   if ~isfield(opts, 'save'),       opts.save = true;    end
   if ~isfield(opts, 'outDir'),     opts.outDir = '';    end

   STATS = {'overT', 'maxErrCW', 'meanMaxCW', 'cvLoad', 'giniLoad'};
   mi = find(strcmp(STATS, opts.metric), 1);
   if isempty(mi)
      error('fig7_bracket:metric', 'metric must be one of: %s', strjoin(STATS, ', '));
   end

   St = fig_style('sizes'); C = fig_style('colors');
   cfg = configure_simulation();
   % configure_simulation has no dataPathPF field, so `PrimeFactorLoader(
   % cfg.dataPathPF)` inside a try/catch loads NOTHING and leaves the prime
   % and factor tables empty - silently, which is the worst way for it to
   % fail: the methods that need those tables then fall out of the bracket
   % with no message. The folder is located instead, and if it cannot be
   % found the caller is told rather than handed a thinner figure.
   tp = []; tf = [];
   [tdir, erF] = find_table_dir(char(cfg.dataSavePath), true);
   if erF == ""
      [tp, tf, erP] = PrimeFactorLoader(tdir);
      if erP ~= ""
         fprintf(2, '  PrimeFactorLoader: %s\n', char(erP)); tp = []; tf = [];
      end
   else
      fprintf(2, ['  no precomputed tables found; methods that need them will\n' ...
                  '  be reported as absent rather than omitted silently.\n']);
   end

   score = @(p) local_pick(p, opts.B, opts.n, opts.t, mi);

   % ---- the two bounds ----------------------------------------------------
   vIdent = score(1:opts.N);

   st = rng; rng(opts.seed, 'twister');       % reproducible band, global stream restored
   vRand = nan(1, opts.nRandom);
   for k = 1:opts.nRandom
      vRand(k) = score(randperm(opts.N));
      if mod(k, 25) == 0, fprintf('  random ensemble %3d/%3d\r', k, opts.nRandom); end
   end
   rng(st);
   fprintf('%s\r', repmat(' ', 1, 34));

   qs = local_q(vRand, [0 0.25 0.5 0.75 1]);

   % ---- the candidates ----------------------------------------------------
   cand = struct('name', {}, 'value', {});
   for i = 1:numel(opts.candidates)
      p = local_perm(opts.candidates{i}, opts.N, tp, tf, cfg);
      % Exactly N, not at least N. A method that pads to a rectangle returns a
      % longer permutation, and its load statistic is then computed over a
      % different number of codewords than every other point on the axis —
      % the bracket would be comparing two frames, not two permutations.
      if isempty(p)
         fprintf(2, '  %s: no permutation at N = %d - omitted\n', opts.candidates{i}, opts.N);
         continue;
      elseif numel(p) ~= opts.N
         fprintf(2, '  %s: extends the frame to %d at N = %d - omitted, the bracket is at fixed N\n', ...
                 opts.candidates{i}, numel(p), opts.N);
         continue;
      end
      cand(end+1) = struct('name', opts.candidates{i}, 'value', score(p(:)')); %#ok<AGROW>
   end

   % ---- draw --------------------------------------------------------------
   % Compact: 1.65 in, bottom margin for ticks and label only, and every
   % vertical offset below tightened to what 8 pt text needs at this scale
   % (about 0.19 y-units per line). The earlier 2.05 in carried air above
   % the arrow and between the label rows.
   f = fig_style('new', 'single', 1.65);
   ax = axes('Parent', f, 'Units', 'inches', ...
             'Position', [0.16, 0.42, 3.50 - 0.28, 1.65 - 0.42 - 0.04]);
   set(ax, 'Units', 'normalized'); hold(ax, 'on');

   % BOTH bounds must see every point. The first version left vIdent out of
   % the upper bound, and for giniLoad the identity is the HIGHEST value in
   % the figure - so the one anchor the bracket is named after was drawn
   % outside the axes and simply did not appear.
   allv = [vIdent, qs(1), qs(5), cand.value];
   lo = min(allv); hi = max(allv);
   pad = 0.12 * max(hi - lo, eps); lo = lo - pad; hi = hi + pad;

   yLine = 1;
   plot(ax, [lo hi], [yLine yLine], '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.6);

   % random: a band on the line, not a cross. The ensemble spread is narrow
   % at this N, so an IQR patch drawn full height with a full-width whisker
   % through it reads as a plus sign rather than as a distribution.
   patch(ax, [qs(2) qs(4) qs(4) qs(2)], yLine + [-0.17 -0.17 0.17 0.17], ...
         C(2, :), 'FaceAlpha', 0.25, 'EdgeColor', C(2, :), 'LineWidth', 0.6);
   plot(ax, [qs(1) qs(5)], [yLine yLine], '-', 'Color', C(2, :), 'LineWidth', 0.9);
   plot(ax, [qs(1) qs(1)], yLine + [-0.10 0.10], '-', 'Color', C(2, :), 'LineWidth', 0.9);
   plot(ax, [qs(5) qs(5)], yLine + [-0.10 0.10], '-', 'Color', C(2, :), 'LineWidth', 0.9);
   text(ax, qs(3), yLine - 0.28, sprintf('random, %d draws', opts.nRandom), ...
        'FontName', St.font, 'FontSize', St.note, 'Color', C(2, :), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');

   plot(ax, [vIdent vIdent], yLine + [-0.22 0.22], '-', 'Color', C(3, :), 'LineWidth', 1.4);
   text(ax, vIdent, yLine - 0.28, sprintf('identity\nno interleaving'), ...
        'FontName', St.font, 'FontSize', St.note, 'Color', C(3, :), ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');

   % Candidate labels on rows assigned greedily: sorted by value, each label
   % goes to the lowest row whose last label ends before this one starts, at
   % an estimated text width. Two alternating rows were not enough once two
   % methods sat within one label width of each other on the same row
   % (blockCM and S printed as one word).
   [~, ordc] = sort([cand.value]);
   chw = 0.020 * (hi - lo);                 % width of one character, data units
   rowEnd = -inf(1, 4);
   rowOf = zeros(1, numel(cand));
   for q = 1:numel(ordc)
      i = ordc(q);
      wl = chw * numel(cand(i).name);
      L = cand(i).value - wl / 2; R = cand(i).value + wl / 2;
      r = find(rowEnd < L - 0.6 * chw, 1);
      if isempty(r), [~, r] = min(rowEnd); end
      rowOf(i) = r; rowEnd(r) = R;
   end
   nRows = max(rowOf);
   % Markers and leader lines first, every label afterwards and on a white
   % ground, so a leader line running up to a higher row passes behind the
   % labels of the rows below it instead of through their letters.
   for q = 1:numel(ordc)
      i = ordc(q);
      plot(ax, cand(i).value, yLine, 'v', 'MarkerSize', St.ms, ...
           'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'k');
      yl = yLine + 0.26 + 0.26 * (rowOf(i) - 1);
      plot(ax, [cand(i).value cand(i).value], [yLine + 0.12, yl - 0.06], '-', ...
           'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
   end
   for q = 1:numel(ordc)
      i = ordc(q);
      yl = yLine + 0.26 + 0.26 * (rowOf(i) - 1);
      text(ax, cand(i).value, yl, cand(i).name, 'FontName', St.font, ...
           'FontSize', St.note, 'Interpreter', 'none', ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
           'BackgroundColor', 'w', 'Margin', 0.5);
   end

   % Which way is better, drawn in DATA coordinates inside the axes.
   % annotation() places in figure coordinates, and at this figure height the
   % arrow landed behind the axes and did not appear at all. Anything that
   % must be positioned relative to the data belongs in the data's own space.
   xa = lo + 0.30 * (hi - lo); xb = lo + 0.05 * (hi - lo);
   % Above every label row.
   ya = yLine + 0.26 * nRows + 0.28;
   plot(ax, [xa xb], [ya ya], '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.9);
   plot(ax, xb + [0.035 0 0.035] * (hi - lo), ya + [0.06 0 -0.06], '-', ...
        'Color', [0.35 0.35 0.35], 'LineWidth', 0.9);
   text(ax, xa + 0.02 * (hi - lo), ya, 'better', 'FontName', St.font, ...
        'FontSize', St.note, 'Color', [0.35 0.35 0.35], ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');

   set(ax, 'YTick', [], 'YColor', 'none');
   ylim(ax, [0.32 ya + 0.13]); xlim(ax, [lo hi]);
   xlabel(ax, sprintf('%s at N = %d, B = %d  (n = %d, t = %d)', ...
                      opts.metric, opts.N, opts.B, opts.n, opts.t));
   fig_style('axes', ax);
   set(ax, 'YColor', 'none');

   if opts.save, fig_style('save', f, 'fig7_bracket', opts.outDir); end

   % ---- the reading, printed, so the figure is not the only record --------
   out = struct('metric', opts.metric, 'N', opts.N, 'B', opts.B, ...
                'identity', vIdent, 'randomQ', qs, 'candidates', cand);
   fprintf('\n  READING %s AT N = %d, B = %d\n', opts.metric, opts.N, opts.B);
   fprintf('    identity (no interleaving)   %8.4f\n', vIdent);
   fprintf('    random ensemble              %8.4f   [%.4f, %.4f] IQR, extremes [%.4f, %.4f]\n', ...
           qs(3), qs(2), qs(4), qs(1), qs(5));
   for i = 1:numel(cand)
      fprintf('    %-28s %8.4f   %s\n', cand(i).name, cand(i).value, ...
              local_verdict(cand(i).value, vIdent, qs));
   end
   fprintf(['  The bracket is recomputed at this N and B. A bracket quoted from\n' ...
            '  another study is not a bracket, both bounds depending on both.\n\n']);
end

% =========================================================================
function v = local_pick(p, B, n, t, mi)
   [a, b, c, d, e] = designMetricScore(p(:)', B, n, t);
   all5 = [a, b, c, d, e]; v = all5(mi);
end

function s = local_verdict(v, vIdent, qs)
% DIRECTION IS NOT OPTIONAL. All five design statistics measure how much a
% burst concentrates on a codeword, so a LARGER value is a WORSE interleaver:
% the identity permutation returns giniLoad 0.899 at N = 1200, B = 8n, while
% a random draw returns about 0.41. A reading written as though larger were
% better would call the worst possible permutation the best in the field.
% The bracket therefore runs downward from the identity, and a candidate
% earns its complexity by sitting BELOW the random band.
% Deliberately not a pass mark. The bracket says where a value sits; whether
% that is good enough is a design decision the metric cannot make.
   if v >= vIdent - 1e-12
      s = 'no better than no interleaving at all';
   elseif v > qs(5)
      s = 'worse than every random draw';
   elseif v > qs(4)
      s = 'in the worse tail of random';
   elseif v >= qs(2)
      s = 'indistinguishable from random';
   elseif v >= qs(1)
      s = 'in the better tail of random';
   else
      s = 'better than every random draw';
   end
end

function q = local_q(v, p)
% prctile convention, matching fig5_c5box and Table X.
   v = sort(v(isfinite(v))); n = numel(v); q = nan(size(p));
   if n == 0, return; end
   if n == 1, q(:) = v; return; end
   pp = ((1:n) - 0.5) / n;
   for i = 1:numel(p)
      if p(i) <= pp(1),       q(i) = v(1);
      elseif p(i) >= pp(end), q(i) = v(end);
      else
         k = find(pp <= p(i), 1, 'last');
         w = (p(i) - pp(k)) / (pp(k + 1) - pp(k));
         q(i) = v(k) + w * (v(k + 1) - v(k));
      end
   end
end

function p = local_perm(m, N, tp, tf, cfg) %#ok<INUSD>
% Same route screen_methods uses, S included: it is built from the settings
% the campaign ran it with, and an absent reference would make the bracket
% useless for the comparison the paper is about.
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
      % Returning it silently is how S came to be missing from this figure.
      if erM ~= "", fprintf(2, '  %s at N = %d: %s\n', m, N, char(erM)); end
   catch
      p = [];
   end
end
