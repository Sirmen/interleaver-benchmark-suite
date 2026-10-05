function out = fig4_bsweep(S, opts)
%FIG4_BSWEEP  Figure 4: where each design-time statistic should be read.
%
%   S = metric_scorecard([], struct('dataDir', dataDir));
%   out = fig4_bsweep(S);
%
% WHY THIS FIGURE IS NOT DECORATION
% ===========================================================================
% Each design-time statistic takes a burst length B as a parameter, and the
% paper has to say which B to use. A number chosen because it scored best is
% a number fitted to the data. The defensible choice is a PLATEAU: a range
% over which the statistic's association with recovery does not depend on the
% parameter, so the reported value is not a selection. This figure is the
% evidence that a plateau exists, and where.
%
% It also carries the finding that the plateau is NOT common to the suite.
% giniLoad rises to about 8n and is flat above it; overT peaks near 12n and
% falls as the threshold saturates; the two codeword-load statistics keep
% climbing to 24n. A protocol prescribing one B for all five reads two of
% them off their own plateau, which is why Section XI-A sends the reader to
% the per-metric column of Table X instead.
%
% One further thing the figure must show honestly: cvLoad is not monotone in
% its own parameter. A metric whose value rises, falls and rises again as the
% parameter sweeps has no plateau to select from, and no reported value for
% it is a property of the interleaver rather than of the choice of B. The
% curve is drawn rather than described.
%
% INPUT
%   S     the struct metric_scorecard returns. Passing it in rather than
%         re-running the sweep matters: the figure and Table IX then come from
%         one computation, and cannot disagree.
%
% OPTIONS
%   sweep   which condition to draw, by index or by name  [mean over all]
%   stats   statistics to draw            [overT maxErrCW meanMaxCW cvLoad giniLoad]
%   n       code length, for the B axis labels           [15]
%
% R.T. Sirmen harness, 2026

   if nargin < 1 || isempty(S)
      error('fig4_bsweep:input', ['pass the struct metric_scorecard returns:\n' ...
            '    S = metric_scorecard([], struct(''dataDir'', dataDir));\n' ...
            '    fig4_bsweep(S)']);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'stats')
      opts.stats = {'giniLoad', 'meanMaxCW', 'maxErrCW', 'overT', 'cvLoad'};
   end
   if ~isfield(opts, 'n'),      opts.n = 15;      end
   if ~isfield(opts, 'save'),   opts.save = true; end
   if ~isfield(opts, 'outDir'), opts.outDir = ''; end
   if ~isfield(opts, 'sweep'),  opts.sweep = [];  end

   St = fig_style('sizes'); C = fig_style('colors'); M = fig_style('markers');
   names = S.metrics;

   % One column of correlations: a named condition, or the mean over all of
   % them. The mean is the default because the paper's B selection is made
   % across conditions, not within one.
   if isempty(opts.sweep)
      rho = mean(abs(S.rho), 2, 'omitnan'); tag = 'mean over the eight conditions';
   else
      if ischar(opts.sweep)
         k = find(strcmp(S.sweeps, opts.sweep), 1);
         if isempty(k), error('fig4_bsweep:sweep', 'no sweep named %s', opts.sweep); end
      else
         k = opts.sweep;
      end
      rho = abs(S.rho(:, k)); tag = S.sweeps{k};
   end

   % LEGEND INSIDE, TOP LEFT. Below the axes it cost a third of the figure
   % height. Top left is empty by construction: at B below 2n every
   % statistic sits under 0.3, and the axis is fixed at [0 1], so a vertical
   % legend there covers no curve - the author's v18 layout, now in code.
   f = fig_style('new', 'single', 2.0);
   ax = axes('Parent', f, 'Units', 'inches', ...
             'Position', [0.44, 0.38, 3.50 - 0.52, 2.0 - 0.38 - 0.05]);
   set(ax, 'Units', 'normalized'); hold(ax, 'on');

   out = struct('stat', {}, 'B', {}, 'rho', {}, 'plateauFrom', {});
   h = gobjects(1, numel(opts.stats)); lbl = cell(1, numel(opts.stats));

   for i = 1:numel(opts.stats)
      st = opts.stats{i};
      idx = find(strncmp(names, [st '_B'], numel(st) + 2));
      if isempty(idx)
         fprintf(2, '  %s: no _B columns in the scorecard - skipped\n', st);
         continue;
      end
      B = zeros(1, numel(idx));
      for q = 1:numel(idx)
         B(q) = str2double(names{idx(q)}(numel(st) + 3:end));
      end
      [B, o] = sort(B); v = rho(idx(o))';

      h(i) = plot(ax, B, v, '-', 'Color', C(mod(i, 7) + 1, :), ...
                  'LineWidth', St.lw, 'Marker', M{mod(i - 1, 7) + 1}, ...
                  'MarkerSize', St.ms - 1, 'MarkerFaceColor', 'w');
      lbl{i} = st;

      % Where the curve stops moving: the first B from which every later
      % value is within 0.02 of the maximum. Reported, not drawn, because a
      % second set of marks on five curves is unreadable at 3.5 inches.
      pf = NaN;
      for q = 1:numel(B)
         if all(abs(v(q:end) - max(v)) <= 0.02), pf = B(q); break; end
      end
      out(end+1) = struct('stat', st, 'B', B, 'rho', v, 'plateauFrom', pf); %#ok<AGROW>
   end

   ok = isgraphics(h);
   % 12n, 16n and 24n are close together on a log axis and their labels
   % collided. The tick stays at 16n - the point is plotted there - and only
   % its label is dropped, which is the honest way to thin a crowded axis.
   set(ax, 'XScale', 'log', 'XTick', opts.n * [1 2 4 8 12 16 24], ...
           'XTickLabel', {'n','2n','4n','8n','12n','','24n'});
   xlim(ax, opts.n * [0.85 28]);
   xlabel(ax, 'burst length B');
   ylabel(ax, '|\rho| with RES, within length');
   ylim(ax, [0 1]);
   lg = legend(ax, h(ok), lbl(ok), 'Box', 'off', 'Orientation', 'vertical', ...
               'Location', 'northwest');
   set(lg, 'FontName', St.font, 'FontSize', St.legend, 'Interpreter', 'none');
   fig_style('axes', ax);

   if opts.save, fig_style('save', f, 'fig4_bsweep', opts.outDir); end

   fprintf('\n  B sweep, %s\n', tag);
   fprintf('  %-12s %10s %10s  %s\n', 'statistic', 'best B', 'plateau', 'shape');
   fprintf('  %s\n', repmat('-', 1, 52));
   for i = 1:numel(out)
      [~, bi] = max(out(i).rho);
      % THE TEST IS THE LARGEST FALL BEFORE THE PEAK, not strict monotonicity.
      % Strict monotonicity flagged all five: a 0.005 dip inside giniLoad's
      % plateau counts as a violation, which made the line contradict the
      % manuscript and say nothing. What distinguishes cvLoad is that its
      % curve falls hard on the way UP - a swing in the middle of the sweep,
      % so no burst length reads a property of the permutation rather than of
      % the parameter. A curve that rises and then falls past its peak, as
      % overT does, is a different thing entirely and a reported finding.
      dr = diff(out(i).rho(1:bi));
      preFall = 0; if ~isempty(dr), preFall = max(0, -min(dr)); end
      postFall = max(out(i).rho) - out(i).rho(end);
      if isnan(out(i).plateauFrom), pf = 'none'; else, pf = sprintf('from %d', out(i).plateauFrom); end
      if preFall > 0.10
         note = sprintf('SWINGS: falls %.2f before its own peak', preFall);
      elseif postFall > 0.10
         note = sprintf('peaks then falls %.2f - saturation, not a defect', postFall);
      else
         note = 'rises to a plateau and stays';
      end
      fprintf('  %-12s %10d %10s  %s\n', out(i).stat, out(i).B(bi), pf, note);
   end
   fprintf(['  A statistic that swings before its own peak has no B at which its\n' ...
            '  value is a property of the permutation rather than of the parameter,\n' ...
            '  and Section VIII-E declines to recommend it at any B.\n\n']);
end
