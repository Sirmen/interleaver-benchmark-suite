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
   % leading, so the rest was air.
   %
   % TWO ROW BLOCKS SIDE BY SIDE. The height is the row count times that
   % pitch and nothing else, so widening the figure from 90 to 140 mm did
   % not shorten it by a thousandth - it only lengthened the dot strips,
   % which were never short of room. The 50 mm is spent on a second block
   % instead: ranks 1 to ceil(nM/2) on the left, the rest on the right, each
   % block carrying both panels. At nM = 23 the figure falls from 3.52 in to
   % 2.14 in.
   %
   % WHAT THIS COSTS, stated because it is a real cost. The A1 partition is
   % the reading order of the strip, and split in two the boundary between
   % confined and in-scope methods falls inside one block rather than at the
   % foot of a single list. The gap itself is still visible - it is an order
   % of magnitude on a log axis, and the printout at the end of this file
   % measures it - but a reader asking "where does the partition fall" now
   % has to find which block it falls in.
   %
   % TRANSPOSING instead was measured and rejected. With nM names along a
   % 5.0 in axis the tick pitch is 0.217 in, and a name like 'latinSquare'
   % is about 0.55 in of 8 pt type. Rotated 45 degrees its horizontal
   % footprint is 0.39 in and at 60 degrees 0.28 in, both wider than the
   % pitch, so the labels collide at any angle that stays readable; only
   % about 75 degrees fits, and at 75 degrees the saving is 0.7 in for
   % near-vertical text. The old note here priced this at IEEE's 7.16 in,
   % which is not this paper's width.
   nBlk = 2; if nM < 8, nBlk = 1; end
   kB   = ceil(nM / nBlk);                % rows in the taller block
   H = 0.125 * kB + 0.64;
   f = fig_style('new', 'wide', H);
   % Width comes from the figure, not from a literal repeated here: the two
   % used to be set in different places and a change to one left the other
   % behind, which is how every axes in this file came to be 3.50 in wide
   % inside a 5.51 in figure.
   Wf = get(f, 'Position'); Wf = Wf(3);
   labW = 0.86;                                    % inches for the names
   gap  = 0.16;                                    % between a block's panels
   sepW = 0.12;                                    % between the two blocks
   botI = 0.40;  topPad = 0.22;          % legend inside, one-line titles
   % Each block is [names | criterion panel | gap | load panel]. Four panels
   % share what two used to, so each is about 0.92 in - enough for three log
   % ticks on the left and four linear ones on the right, and the markers
   % never needed more.
   blkW = (Wf - nBlk*labW - (nBlk-1)*sepW - 0.14) / nBlk;
   panW = (blkW - gap) / 2;
   axL = gobjects(1, nBlk); axR = gobjects(1, nBlk);
   for b = 1:nBlk
      x0 = labW + (b-1)*(blkW + sepW + labW);
      axL(b) = axes('Parent', f, 'Units', 'inches', ...
                 'Position', [x0, botI, panW, H - botI - topPad]);
      axR(b) = axes('Parent', f, 'Units', 'inches', ...
                 'Position', [x0 + panW + gap, botI, panW, H - botI - topPad]);
   end
   set([axL axR], 'Units', 'normalized');
   for b = 1:nBlk, hold(axL(b), 'on'); hold(axR(b), 'on'); end
   % Which rows belong to which block, and the row each method occupies
   % WITHIN its block. rowOf is what every plotting loop below indexes with,
   % so none of them has to know the split exists.
   blkOf = zeros(1, nM); rowOf = zeros(1, nM);
   for j = 1:nM
      blkOf(j) = min(nBlk, floor((j-1)/kB) + 1);
      rowOf(j) = j - (blkOf(j)-1)*kB;
   end

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
         for b = 1:nBlk
            if pan == 1, ax = axL(b); val = wv; else, ax = axR(b); val = lv; end
            s1 = (blkOf == b) & ~conf;        % in scope
            s2 = (blkOf == b) &  conf;        % confined, drawn solid
            hh = plot(ax, val(s1), rowOf(s1), mk{min(i, 4)}, 'MarkerSize', mi, ...
                 'LineWidth', 0.9, 'MarkerEdgeColor', ci, 'MarkerFaceColor', 'none');
            % The legend handle must come from a series that actually has
            % points, and from the axes the legend will be attached to:
            % legend() will not take a handle whose parent is another axes.
            % That is block 1's criterion panel, for the reason set out
            % where the legend is built.
            if pan == 1 && b == 1 && any(s1), hLeg(i) = hh; end
            plot(ax, val(s2), rowOf(s2), mk{min(i, 4)}, 'MarkerSize', mi, ...
                 'LineWidth', 0.9, 'MarkerEdgeColor', ci, 'MarkerFaceColor', ci);
         end
      end
   end

   % A faint rule per row, so the eye can carry a method across the gutter.
   % Drawn per method rather than per row of the box, so the shorter block
   % does not get rules under rows that hold nothing.
   for j = 1:nM
      b = blkOf(j); r = rowOf(j);
      plot(axL(b), [1e-3 3], [r r], '-', 'Color', [0.93 0.93 0.93], 'LineWidth', 0.4);
      plot(axR(b), [0 100],  [r r], '-', 'Color', [0.93 0.93 0.93], 'LineWidth', 0.4);
   end
   for b = 1:nBlk
      uistack(findobj(axL(b), 'Type', 'line', 'Color', [0.93 0.93 0.93]), 'bottom');
      uistack(findobj(axR(b), 'Type', 'line', 'Color', [0.93 0.93 0.93]), 'bottom');
      % The A1 rule in EVERY block. Drawn once it would state the criterion
      % for half the methods and leave the other half with no rule to be
      % left or right of, which is the one thing this panel is for.
      plot(axL(b), opts.confTol * [1 1], [0 kB + 1], '-', ...
           'Color', [0.6 0.6 0.6], 'LineWidth', 0.8);
   end
   maxLd = 0;
   for i = 1:nL, maxLd = max(maxLd, max([R{i}.maxLoad])); end

   % One Y range for every block, from kB and not from each block's own row
   % count, so the row pitch is identical in both and the shorter block ends
   % early instead of spreading its rows out.
   set([axL axR], 'YLim', [0.3 kB + 0.7], 'YDir', 'reverse');
   set(axL, 'TickLabelInterpreter', 'none', 'XScale', 'log', ...
            'XTick', [0.01 0.1 1], 'XTickLabel', {'.01', '.1', '1'}, ...
            'XLim', [0.014 2.6]);
   set(axR, 'XTick', [0 5 10 15], 'XLim', [0 maxLd * 1.12]);
   for b = 1:nBlk
      ii = find(blkOf == b);
      set(axL(b), 'YTick', 1:numel(ii), 'YTickLabel', nm(ii), ...
                  'TickLabelInterpreter', 'none');
      % YTick first, then the empty labels: the names belong to the block's
      % own left panel and the load panel sits against them, so a second
      % copy would only repeat them across the gap.
      set(axR(b), 'YTick', 1:numel(ii), 'YTickLabel', {});
      % SHORT LABELS, because four panels share the width two used to. At
      % 0.92 in a panel, 'widest block   (A1 at 0.25)' is half again as wide
      % as its own axes. The quantity goes in the title and the threshold
      % under the axis, where the grey rule is and where a reader looks for
      % it; the criterion itself is named in the caption.
      xlabel(axL(b), 'A1 at 0.25');
      title(axL(b), 'widest block', 'FontWeight', 'normal');
      title(axR(b), 'worst load',   'FontWeight', 'normal');
      fig_style('axes', axL(b)); fig_style('axes', axR(b));
      set(axL(b), 'TickLabelInterpreter', 'none');
   end

   % The threshold is named in the axis label, not as a floating glyph. Set
   % loose in the plot it landed among the tick marks and read as debris.

   % Named handles. Each length draws TWO series per panel, in-scope and
   % confined, and the row rules are lines too - a legend built from labels
   % alone would take the first objects it found, which are neither.
   %
   % OUTSIDE THE AXES, under the method names, because no region INSIDE an
   % axes is wide enough for it.
   %
   % Two placements were tried and both ran over the data. At the bottom of
   % the load panel it crossed the two confined methods, which sit at the
   % extreme right of the bottom rows. Moved to the top left of the
   % criterion panel it crossed the marker column, and that one came of
   % measuring the empty region and not the box: on a log axis from 0.014 to
   % 2.6 the span up to the 0.25 rule is 55 % of a 0.92 in panel, so 0.50 in
   % is free - and the legend is 0.95 in. There is no arrangement of a
   % 0.95 in box inside a 0.92 in panel that avoids the markers.
   %
   % The empty region that IS big enough is outside every axes: the strip
   % under the method-name column, 0.86 in wide and botI = 0.40 in tall.
   % Nothing is drawn there. The names are y tick labels and stop at the
   % axes; the only thing below the axes is the criterion panel's x label,
   % and that is centred under the panel, which starts where this strip
   % ends. The legend is therefore positioned in FIGURE inches rather than
   % located against an axes, and centred in that strip.
   ok = isgraphics(hLeg);
   lbl = arrayfun(@(v) sprintf('N = %d', v), Ns, 'UniformOutput', false);
   lg = legend(axL(1), hLeg(ok), lbl(ok), ...
               'Box', 'off', 'Orientation', 'vertical');
   set(lg, 'FontName', S.font, 'FontSize', S.legend);
   try, lg.ItemTokenSize = [8 6]; catch, end            % R2018a and later
   set(lg, 'Units', 'inches');
   lp = get(lg, 'Position');
   if lp(3) > labW || lp(4) > botI
      % Say so rather than let it creep back under the axes. The strip is
      % fixed by labW and botI, so a legend that outgrows it - another
      % length added to Ns, say - needs one of those raised, not a nudge.
      fprintf(2, ['fig1_screen: the legend is %.2f x %.2f in and the strip under\n' ...
                  '  the names is %.2f x %.2f in. Raise labW or botI; do not move\n' ...
                  '  the legend back inside a panel, where nothing fits.\n'], ...
              lp(3), lp(4), labW, botI);
   end
   set(lg, 'Position', [max(0.02, (labW - lp(3)) / 2), ...
                        max(0.03, (botI - lp(4)) / 2), lp(3), lp(4)]);

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
