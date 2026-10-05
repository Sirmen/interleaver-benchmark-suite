function out = fig5_c5box(S, opts)
%FIG5_C5BOX  Figure 5: what a mean correlation conceals, drawn per metric.
%
%   S = metric_scorecard([], struct('dataDir', dataDir));
%   out = fig5_c5box(S);
%
% THE CRITERION THIS FIGURE IS
% ===========================================================================
% C5 asks whether a metric's association with recovery is stable across frame
% lengths. The number reported for it is the interquartile range of the
% per-length correlations, and a number is a poor way to carry a claim about
% a distribution: a Fisher-z mean of 0.40 assembled from lengths scattered
% between -0.3 and +0.9 is not the same finding as one assembled from lengths
% all near 0.40, and only the second may be quoted as a single figure.
%
% So the figure is the distribution itself, one box per metric, and the IQR
% of each box IS the C5 column of Table IX. Nothing is summarised twice: the
% table gives the number, the figure gives the shape the number came from.
%
% WHICH METRICS, AND WHY NOT THE STRONGEST
% ===========================================================================
% The first version drew the twelve strongest columns of the scorecard. The
% scorecard carries each design statistic SEVEN TIMES, once per burst length,
% so the twelve strongest were giniLoad and meanMaxCW at five different B
% each - five boxes of the same metric, and half the suite missing. A figure
% of the suite has to be the suite: one entry per metric, each design
% statistic at the B Table X names for it, in the order Table IX reports.
%
% WHY THE AXIS CARRIES |rho| AND THE SIGN IS A MARK
% ===========================================================================
% The load statistics correlate NEGATIVELY with recovery by construction - a
% larger giniLoad is a worse interleaver - so their boxes sit between -0.85
% and -0.90 while the separation metrics sit near +0.85. Drawn on a signed
% axis the figure spends its whole range on a fact that is a definition, and
% the boxes that actually differ are pressed into a tenth of the width and
% cannot be told apart.
%
% The axis therefore carries |rho|, which is the quantity C2 and C5 are
% stated in, and the sign is printed once per row as a symbol. Taking the
% absolute value does not change the interquartile range of a metric whose
% sign is constant across lengths, which C4 requires of every metric drawn
% here; a metric whose sign is NOT constant would have its spread understated
% by the transform, so that case is detected and the row is marked rather
% than quietly folded.
%
% WHY THE WHISKERS REACH THE EXTREMES
% With fifty lengths there is no case for hiding one as an outlier, and a
% length at which a metric reverses sign is the single most informative point
% in its distribution. Trimming it would remove the evidence the criterion
% exists to surface.
%
% OPTIONS
%   metrics   {name, label} rows, overriding the default suite
%   n         code length, for the default B choices           [15]
%   sweep     condition index or name          [pooled over all conditions]
%   thresh    the C5 reporting threshold       [0.15]
%
% R.T. Sirmen harness, 2026

   if nargin < 1 || isempty(S)
      error('fig5_c5box:input', ['pass the struct metric_scorecard returns:\n' ...
            '    S = metric_scorecard([], struct(''dataDir'', dataDir));\n' ...
            '    fig5_c5box(S)']);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'thresh'),  opts.thresh = 0.15; end
   if ~isfield(opts, 'sweep'),   opts.sweep = [];    end
   if ~isfield(opts, 'save'),    opts.save = true;   end
   if ~isfield(opts, 'outDir'),  opts.outDir = '';   end
   if ~isfield(opts, 'n'),       opts.n = 15;        end
   if ~isfield(opts, 'metrics'), opts.metrics = {};  end

   if ~isfield(S, 'perLength')
      error('fig5_c5box:noPerLength', ['this scorecard predates the perLength ' ...
            'field. Re-run metric_scorecard to get it.']);
   end

   St = fig_style('sizes'); C = fig_style('colors');
   names = S.metrics;
   n = opts.n;

   % The suite of Table X, each design statistic at its own burst length,
   % ordered as Table IX orders them. The display labels are the paper's
   % symbols, so the figure and the table name the same things.
   if isempty(opts.metrics)
      want = { ...
         sprintf('giniLoad_B%d',  12*n), 'giniLoad (12n)'  ; ...   % v26: same B as Table IX
         sprintf('meanMaxCW_B%d', 24*n), 'meanMaxCW (24n)' ; ...
         sprintf('maxErrCW_B%d',  24*n), 'maxErrCW (24n)'  ; ...
         sprintf('overT_B%d',     12*n), 'overT (12n)'     ; ...
         sprintf('cvLoad_B%d',    24*n), 'cvLoad (24n)'    ; ...
         'delta_G',   '\Delta_G'   ; ...
         'eta_ES',    '\eta_{ES}'  ; ...
         'S_ECC',     'S_{ECC}'    ; ...
         'delta_BS',  '\Delta_{BS}'; ...
         'eta_sep',   '\eta_{sep}' ; ...
         'sepMin',    'sep_{min}'  ; ...
         'adjCV',     'CV_{adj}'   ; ...
         'PSR',       'PSR'        };
   else
      want = opts.metrics;
   end

   sel = []; lbl = {};
   for i = 1:size(want, 1)
      q = find(strcmp(names, want{i, 1}), 1);
      if isempty(q)
         fprintf(2, '  not in this scorecard, omitted: %s\n', want{i, 1});
         continue;
      end
      sel(end+1) = q; lbl{end+1} = want{i, 2}; %#ok<AGROW>
   end
   if isempty(sel), error('fig5_c5box:none', 'none of the requested metrics is present'); end

   % Pool the per-length correlations over the conditions requested. Pooling
   % is the right operation and averaging is not: C5 is about spread, and
   % averaging the conditions first would remove the between-condition part
   % of exactly the spread the criterion measures.
   if isempty(opts.sweep), ks = 1:numel(S.perLength);
   elseif ischar(opts.sweep)
      ks = find(strcmp(S.sweeps, opts.sweep));
      if isempty(ks), error('fig5_c5box:sweep', 'no sweep named %s', opts.sweep); end
   else, ks = opts.sweep;
   end

   nS = numel(sel);
   vals = cell(1, nS);
   for i = 1:nS
      v = [];
      for k = ks
         P = S.perLength{k};
         if sel(i) <= size(P, 1), v = [v, P(sel(i), isfinite(P(sel(i), :)))]; end %#ok<AGROW>
      end
      vals{i} = v;
   end

   % Row pitch, same reasoning as Figure 1: 9 pt labels need about 0.12 in,
   % and a box needs a little more. 0.16 in keeps the boxes clear and takes
   % a tenth off the height.
   H = 0.16 * nS + 0.52;                  % inches: rows + ticks/label + theta
   f = fig_style('new', 'single', H);
   % Margins in INCHES, converted once, rather than normalized fractions
   % guessed at one figure height. The first version fixed the left margin at
   % 0.34 of the width and clipped "meanMaxCW_B180" to "neanMaxCW_B180" - a
   % figure that silently eats the first letter of a name - and lost the right
   % end of the x label at the same time.
   wide  = max(cellfun(@numel, lbl));
   leftI = min(1.45, max(0.60, 0.062 * wide + 0.22));   % room for the labels
   botI  = 0.38;                                        % ticks and the x label, no more
   ax = axes('Parent', f, 'Units', 'inches', ...
             'Position', [leftI, botI, 3.50 - leftI - 0.12, H - botI - 0.10]);
   set(ax, 'Units', 'normalized');
   hold(ax, 'on');

   % Shading follows the C5 statistic of Table IX: the interquartile range of
   % the per-length correlations within each condition, averaged over the
   % conditions. The boxes pool all conditions, so their width also carries
   % the differences between conditions and can exceed the threshold for a
   % metric that meets C5; shading from the pooled box made the figure
   % disagree with the table.
   qC5 = nan(1, nS);
   for i = 1:nS
      qC5(i) = mean(S.iqrPerLength(sel(i), ks), 'omitnan');
   end
   for i = 1:nS
      q = qC5(i);
      if isfinite(q) && q > opts.thresh
         patch(ax, [-0.06 1.02 1.02 -0.06], i + [-0.45 -0.45 0.45 0.45], ...
               [0.955 0.925 0.895], 'EdgeColor', 'none');
      end
   end
   plot(ax, [0.30 0.30], [0 nS + 1], '-', 'Color', [0.80 0.80 0.80], 'LineWidth', 0.7);

   out = struct('metric', {}, 'label', {}, 'n', {}, 'median', {}, 'iqr', {}, ...
                'min', {}, 'max', {}, 'sign', {}, 'signStable', {});
   for i = 1:nS
      raw = vals{i};
      pos = sum(raw > 0); neg = sum(raw < 0);
      stable = (pos == 0) || (neg == 0);
      if neg > pos, sg = '-'; else, sg = '+'; end
      v = abs(raw);
      qs = quantile_local(v, [0 0.25 0.50 0.75 1]);
      y = i;
      plot(ax, [qs(1) qs(5)], [y y], '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.7);
      plot(ax, [qs(1) qs(1)], y + [-0.13 0.13], '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.7);
      plot(ax, [qs(5) qs(5)], y + [-0.13 0.13], '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.7);
      patch(ax, [qs(2) qs(4) qs(4) qs(2)], y + [-0.25 -0.25 0.25 0.25], ...
            C(2, :), 'FaceAlpha', 0.28, 'EdgeColor', C(2, :), 'LineWidth', 0.7);
      plot(ax, [qs(3) qs(3)], y + [-0.25 0.25], '-', 'Color', C(1, :), 'LineWidth', 1.2);

      % The sign, once, at the left edge of the row. An asterisk marks a
      % metric that reversed at some length, because for that one |rho|
      % understates the spread and the row may not be read as the others are.
      tagS = sg; if ~stable, tagS = [sg '*']; end
      text(ax, -0.035, y, tagS, 'FontName', St.font, 'FontSize', St.note, ...
           'Color', [0.35 0.35 0.35], 'HorizontalAlignment', 'right', ...
           'VerticalAlignment', 'middle');

      out(end+1) = struct('metric', names{sel(i)}, 'label', lbl{i}, 'n', numel(v), ...
                          'median', qs(3), 'iqr', qs(4) - qs(2), ...
                          'min', qs(1), 'max', qs(5), 'sign', sg, ...
                          'signStable', stable); %#ok<AGROW>
   end

   set(ax, 'YTick', 1:nS, 'YTickLabel', lbl, 'YLim', [0.4 nS + 0.6], ...
           'YDir', 'reverse', 'TickLabelInterpreter', 'tex');
   xlim(ax, [-0.06 1.02]);
   set(ax, 'XTick', 0:0.25:1);
   xlabel(ax, '|\rho| with RES, one value per frame length');
   text(ax, 0.30, 0.15, '\theta', 'FontName', St.font, 'FontSize', St.note, ...
        'Color', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');
   fig_style('axes', ax);
   set(ax, 'TickLabelInterpreter', 'tex');

   if opts.save, fig_style('save', f, 'fig5_c5box', opts.outDir); end

   fprintf('\n  C5: spread of the per-length association (IQR), threshold %.2f\n', opts.thresh);
   fprintf('  %-18s %6s %8s %8s %18s  %s\n', 'metric', 'n', 'median', 'IQR', 'range', 'reporting');
   fprintf('  %s\n', repmat('-', 1, 78));
   for i = 1:numel(out)
      if qC5(i) > opts.thresh, rule = 'quote WITH the spread';
      elseif abs(qC5(i) - opts.thresh) < 0.01, rule = 'on the threshold - state it';
      else, rule = 'may be quoted as one number';
      end
      fprintf('  %-18s %6d %8.3f %8.3f  [%6.3f, %6.3f]  %s\n', out(i).metric, ...
              out(i).n, out(i).median, out(i).iqr, out(i).min, out(i).max, rule);
   end
   fprintf(['  A shaded row is a metric whose spread exceeds the threshold, so its\n' ...
            '  single number in Table X is a summary of disagreement.\n\n']);
end

% -------------------------------------------------------------------------
function q = iqr_local(v)
   if numel(v) < 4, q = NaN; return; end
   s = quantile_local(v, [0.25 0.75]); q = s(2) - s(1);
end

function q = quantile_local(v, p)
% MATLAB's prctile definition, written out.
%
% The definition matters and is not a detail. Table IX's C5 column is iqr(v),
% which is prctile(v,75) - prctile(v,25); prctile places the sorted sample at
% the midpoints (i-0.5)/n and interpolates linearly between them, clamping
% outside. The other common convention places them at (i-1)/(n-1) and returns
% a DIFFERENT interquartile range on the same data. A box whose IQR disagreed
% with the number in the table would be read as an error in one of them.
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
