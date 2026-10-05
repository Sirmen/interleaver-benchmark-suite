function R = fig6_resdecomp(dataDir, opts)
%FIG6_RESDECOMP  Figure 6: what the bottom of the ranking is actually paying for.
%
%   R = fig6_resdecomp('<resultsDir>')
%
% THE CLAIM
% ===========================================================================
% RES = w1*CR_z + w2*BE_z identically (Lemma 4), so a method's mean RES splits
% into two additive parts with nothing estimated. The split says why three
% methods sit at the foot of the composite: about four fifths of their deficit
% is in the term charging for frame extension, not in the term that measures
% burst spreading. On the recovery term alone those three stand above five
% methods drawn higher up.
%
% A stacked bar is the right form and a grouped bar is not. The two parts sum
% to the composite exactly, and a stack shows a sum; a grouped pair invites
% the reader to compare a recovery score against a rate score, which means
% nothing. The bars are ordered by the composite, so the vertical order IS the
% ranking the paper reports and the rate term is seen to grow as it falls.
%
% THE TABLE THIS SCRIPT ALSO PRINTS
% The reordering - which method would rise how far if the rate were not
% charged - is the half a bar chart shows badly, because it asks the reader to
% compare segment lengths across twenty-two rows. It is not in the manuscript;
% it is printed below, with the ranks computed rather than transcribed, so the
% claim in the text can be checked against it in one look.
%
% OPTIONS
%   N               frame length passed to the screen        [1200]
%   dropOutOfScope  omit the methods P1 confines             [true]
%   draw            draw the bar chart                       [true]
%   save            write the files through fig_style        [true]
%
% R.T. Sirmen harness, 2026

   if nargin < 1 || isempty(dataDir)
      c = configure_simulation(); dataDir = char(c.dataSavePath);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'N'),        opts.N = 1200;  end
   if ~isfield(opts, 'save'),     opts.save = true; end
   if ~isfield(opts, 'outDir'),   opts.outDir = ''; end
   if ~isfield(opts, 'dropOutOfScope'), opts.dropOutOfScope = true; end
   if ~isfield(opts, 'draw'),     opts.draw = true; end

   S = fig_style('sizes'); C = fig_style('colors');
   R = screen_methods(dataDir, struct('N', opts.N));

   keep = true(1, numel(R));
   if opts.dropOutOfScope
      for j = 1:numel(R)
         keep(j) = ~any(strcmp(R(j).flags, 'CONFINED'));
      end
   end
   R = R(keep);
   [~, o] = sort([R.meanRES], 'ascend');      % worst at the bottom of the axis
   R = R(o);

   cr = [R.CRterm]; be = [R.BEterm]; nm = {R.method}; n = numel(R);

   if opts.draw
   % Height: rows plus the x axis only. The legend used to sit below the
   % axes and cost 0.3 in; it now sits top left, over the negative half of
   % the top rows, which is empty because the leaders gain on both terms.
   Hf = 0.13 * n + 0.50;
   f = fig_style('new', 'single', Hf);
   ax = axes('Parent', f, 'Units', 'inches', ...
             'Position', [1.02, 0.38, 3.50 - 1.02 - 0.10, Hf - 0.38 - 0.04]);
   set(ax, 'Units', 'normalized'); hold(ax, 'on');
   plot(ax, [0 0], [0 n + 1], '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.6);

   % Both terms are signed, and a stacked bar handles that correctly: two
   % negative segments extend the bar rather than overlap, so the bar's end
   % is the composite and each segment's length is its share of it. The
   % printout below checks that the two segments really do sum to mean RES.
   hb = barh(ax, 1:n, [cr(:) be(:)], 'stacked', 'BarWidth', 0.68);
   set(hb(1), 'FaceColor', C(2, :), 'EdgeColor', 'none');
   set(hb(2), 'FaceColor', C(3, :), 'EdgeColor', 'none');

   set(ax, 'YTick', 1:n, 'YTickLabel', nm, 'YLim', [0.4 n + 0.6], ...
           'TickLabelInterpreter', 'none');
   xlabel(ax, 'contribution to mean RES');
   % Name the handles. legend() with labels alone attaches them to the axes'
   % children in order, and the zero reference line drawn first took the
   % first label: the printed legend showed a grey LINE for the recovery
   % term and the blue patch for the rate term, both wrong.
   fig_style('axes', ax);
   lg = legend(ax, hb, {'recovery  w_1CR_z', 'rate  w_2BE_z'}, ...
               'Orientation', 'vertical', 'Box', 'off');
   set(lg, 'FontName', S.font, 'FontSize', S.legend);
   try, lg.ItemTokenSize = [12 8]; catch, end            % R2018a and later
   % PLACED, NOT LOCATED. 'northwest' put the legend where it fitted the
   % axes, and its text ran across the zero line onto the positive bars of
   % the leading rows. The legend must end left of zero: measure it, place
   % its right edge just left of the zero line, and if it does not fit there
   % widen the negative side of the axis until it does.
   set(lg, 'Units', 'normalized'); set(ax, 'Units', 'normalized');
   for pass = 1:3
      xl = xlim(ax); ap = get(ax, 'Position'); lp = get(lg, 'Position');
      zeroX = ap(1) + ap(3) * (0 - xl(1)) / (xl(2) - xl(1));
      room  = zeroX - 0.012 - ap(1) - 0.005;
      if room >= lp(3), break; end
      % grow the left limit so that the space left of zero holds the legend
      need = lp(3) + 0.017;                       % figure-normalized width
      frac = need / ap(3);                        % share of the axis width
      xOld = xl(1);
      xl(1) = -frac * xl(2) / max(1 - frac, 0.05);
      xlim(ax, [min(xl(1), xOld) xl(2)]);
   end
   xl = xlim(ax); ap = get(ax, 'Position'); lp = get(lg, 'Position');
   zeroX = ap(1) + ap(3) * (0 - xl(1)) / (xl(2) - xl(1));
   set(lg, 'Position', [zeroX - 0.012 - lp(3), ap(2) + ap(4) - lp(4) - 0.004, lp(3), lp(4)]);

   if opts.save, fig_style('save', f, 'fig6_resdecomp', opts.outDir); end
   end

   % The identity is what licenses the figure, so it is checked, not assumed.
   % cfg_weights is a local function of screen_methods and deliberately not
   % duplicated here: two copies of a weight is how the two halves of a sum
   % come to disagree. The residual below is zero only if the weights the
   % screen used are the ones that built the bars.
   fprintf('\n  Lemma 4 check: max |RES - (CRterm + BEterm)| = %.3e\n', ...
           max(abs([R.meanRES] - (cr + be))));
   fprintf('  rate share of the deficit, the three lowest:\n');
   for j = 1:min(3, n)
      tot = abs(cr(j)) + abs(be(j));
      fprintf('    %-14s %5.1f %% of the deficit is rate\n', nm{j}, 100 * abs(be(j)) / max(tot, eps));
   end
   % ---- the table the manuscript carries -------------------------------
   % Ranks computed here, not transcribed. A rank column copied by hand into
   % a manuscript is a rank column that disagrees with the data by one.
   [~, oR] = sort([R.meanRES], 'descend'); rkR = zeros(1, n); rkR(oR) = 1:n;
   [~, oC] = sort(cr, 'descend');          rkC = zeros(1, n); rkC(oC) = 1:n;
   fprintf('\n  THE REORDERING, for checking the claim in Section IX\n');
   fprintf('  %-15s %9s %9s %9s %7s %7s %7s\n', 'Method', 'mean RES', ...
          'recovery', 'rate', 'rk RES', 'rk rec', 'gained');
   fprintf('  %s\n', repmat('-', 1, 70));
   for q = oR
      d = rkR(q) - rkC(q);
      if d == 0, dt = '-'; elseif d > 0, dt = sprintf('+%d', d); else, dt = sprintf('%d', d); end
      fprintf('  %-15s %9.3f %9.3f %9.3f %7d %7d %7s\n', nm{q}, ...
              R(q).meanRES, cr(q), be(q), rkR(q), rkC(q), dt);
   end
   fprintf(['  The last column is the position a method would hold if the rate\n' ...
           '  were not charged, minus the position it holds in the composite.\n\n']);
end
