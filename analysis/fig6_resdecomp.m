function R = fig6_resdecomp(dataDir, opts)
%FIG6_RESDECOMP  Figure 6: what the bottom of the ranking is actually paying for.
%
%   R = fig6_resdecomp('<resultsDir>')
%
% THE CLAIM
% ===========================================================================
% RES = w1*CR_z + w2*BE_z identically (equation (4)), so a method's mean RES splits
% into two additive parts with nothing estimated. The split says why three
% methods sit at the foot of the composite: about four fifths of their deficit
% is in the term charging for frame extension, not in the term that measures
% burst spreading. On the recovery term alone those three stand above five
% methods drawn higher up.
%
% A stacked bar is the right form and a grouped bar is not. The two parts sum
% to the composite exactly, and a stack shows a sum; a grouped pair invites
% the reader to compare a recovery score against a rate score, which means
% nothing. The bars are ordered by the composite, so the reading order IS the
% ranking the paper reports and the rate term is seen to grow as it falls:
% down the left block from the leader, then down the right block to the foot.
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
   % TWO ROW BLOCKS SIDE BY SIDE, NOT ONE TALL STRIP.
   % ----------------------------------------------------------------------
   % This was one column of n rows, and its height was n times the row pitch
   % - 0.13 in, which is what a 9 pt name needs and not a tenth more. Going
   % from 90 to 140 mm bought nothing here: the bars got longer and the
   % height did not move, because the height was never set by the width. The
   % extra 50 mm is therefore spent on a SECOND COLUMN, the way a long list
   % is set in print. At n = 23 the figure falls from 3.49 in to 2.06 in.
   %
   % THREE THINGS KEEP THE COLUMNS COMPARABLE, and each is a way the split
   % could have lied about the data:
   %   - one x-axis range for both, so a segment of a given length means the
   %     same contribution in either column;
   %   - one row pitch for both, set by the LARGER block, so the shorter
   %     column ends early instead of stretching its rows to fill the box;
   %   - rank 1 at the top of the left column and rank n at the bottom of
   %     the right, with both axes reversed, so the reading order is the
   %     ranking continued and not a snake.
   %
   % Below six rows the split saves nothing worth two label columns, so it
   % falls back to the single strip.
   crD = cr(end:-1:1); beD = be(end:-1:1); nmD = nm(end:-1:1);  % best first
   if n >= 6, nCol = 2; else, nCol = 1; end
   kL  = ceil(n / nCol);              % rows in the taller block
   idx = cell(1, nCol);
   for p = 1:nCol
      idx{p} = (1 + (p-1)*kL) : min(p*kL, n);
   end

   Hf = 0.13 * kL + 0.50;
   f = fig_style('new', 'wide', Hf);
   % Width comes from the figure, not from a literal repeated here: the two
   % used to be set in different places and a change to one left the other
   % behind, which is how every axes in this file came to be 3.50 in wide
   % inside a 5.51 in figure.
   Wf = get(f, 'Position'); Wf = Wf(3);
   % Horizontal budget. Each block needs 1.02 in to its LEFT for the method
   % names - tick labels, not whitespace, which is why the gutter between
   % the blocks is not symmetric. sepW separates the left block's longest
   % bar from the right block's names; rmW keeps the last x tick label
   % inside the figure.
   labW = 1.02; sepW = 0.10; rmW = 0.10;
   Wax  = (Wf - nCol*labW - (nCol-1)*sepW - rmW) / nCol;
   axs  = gobjects(1, nCol);
   for p = 1:nCol
      axs(p) = axes('Parent', f, 'Units', 'inches', ...
                    'Position', [labW + (p-1)*(Wax + sepW + labW), 0.38, ...
                                 Wax, Hf - 0.38 - 0.04]);
      set(axs(p), 'Units', 'normalized'); hold(axs(p), 'on');
   end

   % Both terms are signed, and a stacked bar handles that correctly: two
   % negative segments extend the bar rather than overlap, so the bar's end
   % is the composite and each segment's length is its share of it. The
   % printout below checks that the two segments really do sum to mean RES.
   hb = gobjects(1, 2);
   for p = 1:nCol
      ii = idx{p}; ax = axs(p);
      plot(ax, [0 0], [0 kL + 1], '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.6);
      hbp = barh(ax, 1:numel(ii), [crD(ii).' beD(ii).'], 'stacked', 'BarWidth', 0.68);
      set(hbp(1), 'FaceColor', C(2, :), 'EdgeColor', 'none');
      set(hbp(2), 'FaceColor', C(3, :), 'EdgeColor', 'none');
      if p == 1, hb = hbp; end
      % YLim from kL and not from numel(ii): the right block has one row
      % fewer at odd n, and fitting its own limits to its own rows would
      % make its bars thicker than the left block's for no reason a reader
      % could guess at.
      set(ax, 'YTick', 1:numel(ii), 'YTickLabel', nmD(ii), ...
              'YLim', [0.4 kL + 0.6], 'YDir', 'reverse', ...
              'TickLabelInterpreter', 'none');
      xlabel(ax, 'contribution to mean RES');
      fig_style('axes', ax);
   end

   % ONE X RANGE FOR BOTH, computed rather than left to each axes. A stacked
   % segment runs 0 to cr and then cr to cr+be, so those three values bound
   % the bars. Letting MATLAB pick per panel would give the two columns
   % different scales, and a reader comparing a bar on the left with one on
   % the right would be comparing nothing.
   ext = [0, crD, crD + beD];
   pad = 0.06 * max(max(ext) - min(ext), eps);
   set(axs, 'XLim', [min(ext) - pad, max(ext) + pad]);

   % Name the handles. legend() with labels alone attaches them to the axes'
   % children in order, and the zero reference line drawn first took the
   % first label: the printed legend showed a grey LINE for the recovery
   % term and the blue patch for the rate term, both wrong.
   % It goes in the LEFT block, whose top rows are the leaders: they gain on
   % both terms, so the negative side there is empty. That was true of the
   % single strip's top rows and is still true of the left block's.
   ax = axs(1);
   % SYMBOLS, NOT WORDS. 'recovery  w_1CR_z' measured 1.21 in with its
   % marker token, against a panel 1.64 in wide - three quarters of the
   % panel for a key. The two terms are named in equation (4) and glossed in the
   % caption, so the legend carries the symbols alone and the words go where
   % there is room for them. The entries are about 0.38 in now.
   lg = legend(ax, hb, {'w_1CR_z', 'w_2BE_z'}, ...
               'Orientation', 'vertical', 'Box', 'off');
   set(lg, 'FontName', S.font, 'FontSize', S.legend);
   try, lg.ItemTokenSize = [10 6]; catch, end            % R2018a and later
   % PLACED, NOT LOCATED, AND THE AXIS WIDENED BY A COMPUTED AMOUNT.
   % ----------------------------------------------------------------------
   % 'northwest' put the legend where it fitted the axes, and its text ran
   % across the zero line onto the positive bars of the leading rows, so it
   % is placed by hand: right edge just left of the zero line, top of axes.
   %
   % WHETHER THERE IS ROOM LEFT OF ZERO IS A QUESTION WITH AN ANSWER, and
   % the version that iterated towards it got it badly wrong. It grew the
   % left limit by frac/(1 - frac) of the right limit, which is stable while
   % the axes is most of the figure and runs away when it is not. Side by
   % side the axes is about 1.64 in rather than 4.4, frac reached roughly
   % 0.8, and the limit went out to -1.75 against data that stops near -0.8.
   % Both columns share one range, so both inherited it, and every bar in
   % the figure was squeezed into the right third of its panel. The rendered
   % figure is what showed this; the arithmetic had looked fine.
   %
   % Solved rather than iterated. With the axes W inches wide and limits
   % [-a, b], the room left of zero is W*a/(a + b), so a legend of width L
   % fits exactly when
   %
   %        a  >=  L*b / (W - L)
   %
   % and that is the SMALLEST left limit that works.
   %
   % THE FORMULA WAS RIGHT AND THE NUMBER PUT INTO IT WAS NOT. The first
   % attempt at this reasoned that the legend was about 0.86 in, which needs
   % a = 0.69 against data that already reach 0.85, so nothing would be
   % widened. The render still came out at -1.75, because the legend with
   % 'recovery  w_1CR_z' on it is 1.21 in, and a = L*b/(W - L) blows up as L
   % approaches W: 0.86 in asks for 0.69, 1.05 in asks for 1.11, and 1.21 in
   % asks for 1.77. The labels are symbols now for exactly that reason.
   %
   % AND THE WIDENING IS CAPPED, because a key is never worth the data. A
   % legend that cannot fit in a quarter of the panel's width does not get
   % the panel stretched for it; the figure says so and leaves the bars
   % alone. Without the cap this quantity is unbounded in L, which is how a
   % sound formula produced an axis three times the data range.
   set(lg, 'Units', 'inches'); set(axs, 'Units', 'inches');
   lp = get(lg, 'Position'); ap = get(ax, 'Position');
   Lw = lp(3) + 0.05;                     % legend plus a margin at the zero line
   xl = xlim(ax);
   aCap = -xl(1) + 0.25 * (xl(2) - xl(1));
   if xl(2) > 0 && Lw < ap(3) - 0.05
      aNeed = Lw * xl(2) / (ap(3) - Lw);
      if aNeed > aCap
         fprintf(2, ['fig6_resdecomp: the legend (%.2f in) would need the left\n' ...
                     '  limit at %.2f against data reaching %.2f. Not widening -\n' ...
                     '  shorten the labels or move the key to the caption.\n'], ...
                 lp(3), -aNeed, xl(1));
      elseif -xl(1) < aNeed
         % One range for every block: a limit grown for a legend box must
         % reach the other column too, or the two go onto different scales -
         % the failure the shared XLim above exists to prevent.
         set(axs, 'XLim', [-aNeed, xl(2)]);
      end
   elseif xl(2) > 0
      fprintf(2, ['fig6_resdecomp: the legend is %.2f in and the panel %.2f in,\n' ...
                  '  so it cannot sit left of zero. Shorten the labels or widen\n' ...
                  '  the figure; do not let it cover the bars.\n'], lp(3), ap(3));
   end
   set(lg, 'Units', 'normalized'); set(axs, 'Units', 'normalized');
   xl = xlim(ax); ap = get(ax, 'Position'); lp = get(lg, 'Position');
   zeroX = ap(1) + ap(3) * (0 - xl(1)) / (xl(2) - xl(1));
   set(lg, 'Position', [max(ap(1) + 0.004, zeroX - 0.010 - lp(3)), ...
                        ap(2) + ap(4) - lp(4) - 0.004, lp(3), lp(4)]);

   if opts.save, fig_style('save', f, 'fig6_resdecomp', opts.outDir); end
   end

   % The identity is what licenses the figure, so it is checked, not assumed.
   % cfg_weights is a local function of screen_methods and deliberately not
   % duplicated here: two copies of a weight is how the two halves of a sum
   % come to disagree. The residual below is zero only if the weights the
   % screen used are the ones that built the bars.
   fprintf('\n  equation (4) check: max |RES - (CRterm + BEterm)| = %.3e\n', ...
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
   fprintf('\n  THE REORDERING, for checking the claim in Section 9\n');
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
