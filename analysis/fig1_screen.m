function R = fig1_screen(dataDir, opts)
%FIG1_SCREEN  Figure 1: the structural screen, and why reach is the criterion.
%
%   R = fig1_screen('<resultsDir>')
%
% THE ARGUMENT THE FIGURE HAS TO CARRY
% ===========================================================================
% Section III-I removes two methods from scope on ONE criterion, reach, and
% the objection is that the criterion was picked to remove those two. The
% answer has two halves and the figure must show both:
%
%   left panel    widest closed block per method, log axis. The field falls
%                 into two groups an order of magnitude apart with nothing
%                 between them, and the same split appears at both lengths.
%   right panel   worst codeword load per method, same rows. The two confined
%                 methods sit among the full-frame ones, so the load cannot
%                 separate a method that answered the question badly from one
%                 that could not be asked it.
%
% WHY ONE ROW PER METHOD AND NOT A SCATTER
% ===========================================================================
% Two earlier forms failed on the same fact. Reach takes two values in this
% field, about 0.03 and about 1.0, so as a coordinate it carries almost no
% resolution: with reach on the horizontal axis the field collapsed into two
% vertical stacks, and with reach on the vertical axis twenty-two methods
% landed on one horizontal line, separated only by an integer load that
% several of them share - so the markers sat on top of each other and the
% reader could not tell which method was which, or how many were there.
%
% Giving each method its own row removes the overlap by construction. Nothing
% can coincide with anything, the count is visible, and the two panels are
% read across rather than teased apart. The cost is height; it buys a figure
% in which every method can be named.
%
% RETURNS
%   R   one cell per length, each holding the screen_methods row set for it.
%
% OPTIONS
%   lengths   frame lengths to screen                [1200 1440]
%   save      write the files through fig_style      [true]
%
% R.T. Sirmen harness, 2026

   if nargin < 1 || isempty(dataDir)
      c = configure_simulation(); dataDir = char(c.dataSavePath);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'lengths'), opts.lengths = [1200 1440]; end
   if ~isfield(opts, 'save'),    opts.save    = true;        end
   if ~isfield(opts, 'outDir'),  opts.outDir  = '';          end
   if ~isfield(opts, 'confTol'), opts.confTol = 0.25;        end

   S = fig_style('sizes'); C = fig_style('colors');
   nL = numel(opts.lengths); Ns = opts.lengths;
   mk = {'o', 's', '^', 'd'};

   R = cell(1, nL);
   for i = 1:nL
      fprintf('screening at N = %d\n', Ns(i));
      R{i} = screen_methods(dataDir, struct('N', Ns(i), 'confTol', opts.confTol));
   end

   % One row set of method names, ordered by the criterion under test so the
   % partition is the reading order and not something to hunt for. Methods
   % absent at one length keep their row and simply carry no marker there.
   nm = {};
   for i = 1:nL, nm = union(nm, {R{i}.method}); end
   key = nan(1, numel(nm));
   for j = 1:numel(nm)
      v = [];
      for i = 1:nL
         k = find(strcmp({R{i}.method}, nm{j}), 1);
         if ~isempty(k) && isfinite(R{i}(k).widestFrac), v(end+1) = R{i}(k).widestFrac; end %#ok<AGROW>
      end
      if ~isempty(v), key(j) = mean(v); end
   end
   % MissingPlacement needs R2017a. Pushing the missing keys down by hand
   % works everywhere and says what it does.
   k2 = key; k2(~isfinite(k2)) = -Inf;
   [~, o] = sort(k2, 'descend');
   nm = nm(o); nM = numel(nm);

   % Row pitch. 0.155 in was generous: a 9 pt name needs about 0.12 in of
   % leading, so the rest was air. At twenty-four methods the figure drops
   % from 4.67 in to 3.95 in, which in a two-column layout is about a sixth
   % of a page height back. Turning the figure on its side would have cost
   % page space rather than saved it: twenty-four rotated names need the
   % full 7.16 in width and roughly 3.9 in of page height, against 2.33 in
   % for the tall single-column form.
   H = 0.125 * nM + 0.64;
   f = fig_style('new', 'single', H);
   labW = 0.86;                                    % inches for the names
   gap  = 0.16;
   panW = (3.50 - labW - gap - 0.14) / 2;
   botI = 0.40;  topPad = 0.18;          % legend now inside, not below

   axL = axes('Parent', f, 'Units', 'inches', ...
              'Position', [labW, botI, panW, H - botI - topPad]);
   axR = axes('Parent', f, 'Units', 'inches', ...
              'Position', [labW + panW + gap, botI, panW, H - botI - topPad]);
   set([axL axR], 'Units', 'normalized');
   hold(axL, 'on'); hold(axR, 'on');

   hLeg = gobjects(1, nL);
   % ONE COLOUR PER LENGTH, AND NESTED SIZES. The two lengths used to share a
   % colour and differ only in marker shape, so wherever a method scored the
   % same at both - which is most rows - the square sat exactly on the circle
   % and one length vanished. Colour now carries the length (blue for the
   % first, bluish green for the second) and the circle is drawn larger than
   % the square, so a coinciding pair reads as a square inside a ring: both
   % visible, and the coincidence itself visible. Confinement, which colour
   % used to carry, is carried by the fill: confined methods are drawn solid.
   % It is also carried by position, left of the A1 rule, so nothing is lost.
   colOf = [C(2, :); C(4, :); C(3, :); C(5, :)];
   msOf  = S.ms + [0.9, -0.9, 0.3, -0.3];
   for i = 1:nL
      wv = nan(1, nM); lv = nan(1, nM);
      for j = 1:nM
         k = find(strcmp({R{i}.method}, nm{j}), 1);
         if isempty(k), continue; end
         wv(j) = R{i}(k).widestFrac; lv(j) = R{i}(k).maxLoad;
      end
      conf = isfinite(wv) & (wv < opts.confTol);
      ci = colOf(min(i, 4), :); mi = msOf(min(i, 4));
      for pan = 1:2
         if pan == 1, ax = axL; val = wv; else, ax = axR; val = lv; end
         hh = plot(ax, val(~conf), find(~conf), mk{min(i, 4)}, 'MarkerSize', mi, ...
              'LineWidth', 0.9, 'MarkerEdgeColor', ci, 'MarkerFaceColor', 'none');
         if pan == 2, hLeg(i) = hh; end
         plot(ax, val(conf), find(conf), mk{min(i, 4)}, 'MarkerSize', mi, ...
              'LineWidth', 0.9, 'MarkerEdgeColor', ci, 'MarkerFaceColor', ci);
      end
   end

   % A faint rule per row, so the eye can carry a method across the gutter.
   for j = 1:nM
      plot(axL, [1e-3 3], [j j], '-', 'Color', [0.93 0.93 0.93], 'LineWidth', 0.4);
      plot(axR, [0 100],  [j j], '-', 'Color', [0.93 0.93 0.93], 'LineWidth', 0.4);
   end
   uistack(findobj(axL, 'Type', 'line', 'Color', [0.93 0.93 0.93]), 'bottom');
   uistack(findobj(axR, 'Type', 'line', 'Color', [0.93 0.93 0.93]), 'bottom');

   plot(axL, opts.confTol * [1 1], [0 nM + 1], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8);
   maxLd = 0;
   for i = 1:nL, maxLd = max(maxLd, max([R{i}.maxLoad])); end

   set([axL axR], 'YTick', 1:nM, 'YLim', [0.3 nM + 0.7], 'YDir', 'reverse');
   set(axL, 'YTickLabel', nm, 'TickLabelInterpreter', 'none', 'XScale', 'log', ...
            'XTick', [0.01 0.1 1], 'XTickLabel', {'.01', '.1', '1'});
   set(axR, 'YTickLabel', {}, 'XTick', [0 5 10 15]);
   xlim(axL, [0.014 2.6]); xlim(axR, [0 maxLd * 1.12]);

   xlabel(axL, 'widest block   (A1 at 0.25)');
   xlabel(axR, 'worst load');
   title(axL, 'A1: the criterion', 'FontWeight', 'normal');
   title(axR, 'the load', 'FontWeight', 'normal');
   fig_style('axes', axL); fig_style('axes', axR);
   set(axL, 'TickLabelInterpreter', 'none');

   % The threshold is named in the axis label, not as a floating glyph. Set
   % loose in the plot it landed among the tick marks and read as debris.

   % Named handles. Each length draws TWO series per panel, in-scope and
   % confined, and the row rules are lines too - a legend built from labels
   % alone would take the first objects it found, which are neither.
   % Inside the right panel, bottom centre: the last three rows hold only
   % the extreme loads (2 for multiDim, 15 for the two confined methods), so
   % the middle of the panel there is empty.
   lg = legend(axR, hLeg, arrayfun(@(v) sprintf('N = %d', v), Ns, 'UniformOutput', false), ...
               'Box', 'off', 'Orientation', 'vertical', 'Location', 'south');
   set(lg, 'FontName', S.font, 'FontSize', S.legend);

   if opts.save, fig_style('save', f, 'fig1_screen', opts.outDir); end

   fprintf('\n  the gap the partition rests on:\n');
   for i = 1:nL
      y = [R{i}.widestFrac]; y = y(isfinite(y));
      lo = y(y < opts.confTol); hi = y(y >= opts.confTol);
      fprintf('    N = %4d   confined: %s   |   rest: %.3f to %.3f   (%d methods)\n', ...
              Ns(i), mat2str(round(lo, 3)), min(hi), max(hi), numel(y));
   end
   fprintf(['  A partition whose groups lie an order of magnitude apart was not\n' ...
            '  chosen to produce the partition. If the two ranges ever meet, the\n' ...
            '  scope argument of Section III-I fails and the figure will show it.\n\n']);
end
