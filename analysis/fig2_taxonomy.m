function fig2_taxonomy(opts)
%FIG2_TAXONOMY  Figure 2: the metric suite on the two information axes.
%
%   fig2_taxonomy
%   fig2_taxonomy(struct('save', false))
%
% WHAT THE FIGURE IS FOR
% ===========================================================================
% The taxonomy is the paper's most quotable object, and it is a grid: a table
% of six cells asks the reader to rebuild that grid in their head, which a
% grid drawn as a grid does not. The two axes are the two questions that bound
% what a metric can possibly discriminate:
%
%   rows     does the metric need a sampled channel realization?
%   columns  does it need to know the code - its length n, and then its
%            correction capacity t?
%
% The cell that matters is the a priori, (n,t)-aware one: a metric available
% before transmission that nonetheless knows how much damage the code can
% absorb. No metric among those reviewed occupies it, and overT is introduced
% for it. The cell is tinted and nothing else is, so the emphasis needs no
% caption inside the drawing: the tint says which cell, the caption says why,
% and the asterisk key says which metrics are new.
%
% CELL MEMBERSHIP FOLLOWS THE ARGUMENT SET THAT IS USED, NOT THE SIGNATURE.
% ===========================================================================
% This is the one thing in this script that is easy to get wrong again. Of
% the six load statistics of Section 6.7, only overT compares a load with the
% correction capacity; the five designMetricScore returns are:
%
%   maxErrCW    = max_s max_k e_k(s)                       no t  -> n-aware
%   overT       = |{s : max_k e_k(s) > t}| / (N - B + 1)   uses t -> (n,t)-aware
%   meanMaxCW   = E_s[ max_k e_k(s) ]                      no t  -> n-aware
%   cvLoad      = E_s[ sigma/mu over loaded codewords ]    no t  -> n-aware
%   giniLoad    = E_s[ G(e(s)) ]                           no t  -> n-aware
%
% A signature of the form M(pi, n, t, B) proves what a function receives, not
% what it uses. Four of these five receive t and never read it, so they belong
% one column to the left. Do not move them back.
%
% TYPE SIZE
% ===========================================================================
% The cell contents are the thing a reader actually reads, and at 7 pt with
% subscripts dropping to about 5 pt they were hard to read on paper. They are
% set at the body size of the figure set (fig_style 'label', 8 pt) and the
% figure is drawn taller to pay for it; the asterisk key, which is read once,
% stays at 7 pt. Every list is broken by hand, and the break is the layout:
% MATLAB does not wrap text in a cell, it prints past the border, so a list
% occupies exactly as many lines as it carries newlines. The widest column
% is about 1.92 in at this figure width, which holds roughly thirty-five
% characters of 9 pt type; at 90 mm it held about seventeen, which is why
% the old breaks were tighter than they need to be now. If a metric is
% renamed or added, re-break the list by hand - nothing will do it for you.
%
% This is the only figure in the set with no data behind it, and it is drawn
% in the same toolchain as the rest so that its type, weights and export
% match. A diagram set in a different program is recognisable as one.
%
% Drawn at 140 mm, the width this journal's single-column text block wants.
%
% OPTIONS
%   save     write the files through fig_style     [true]
%   outDir   where to write                        [<pwd>/figures]
%
% R.T. Sirmen harness, 2026

   if nargin < 1, opts = struct(); end
   if ~isfield(opts, 'save'),   opts.save = true; end
   if ~isfield(opts, 'outDir'), opts.outDir = ''; end

   S = fig_style('sizes'); C = fig_style('colors');
   % ROW LABELS: HORIZONTAL OR ROTATED.
   % Rotated, a label's length runs along the ROW HEIGHT, so the lower row
   % could never be shorter than the 0.70 in of 'a posteriori' however few
   % lines its cells held - which is why making the label two lines does
   % nothing: it already is two lines, and the binding dimension is the
   % longest line's length, not the count. Horizontal, that length is spent on
   % WIDTH instead, which 140 mm has and 90 mm did not. The lower row is then
   % bound by its cells, as the upper row already was.
   %
   % Flip this to false to get the old geometry back in one edit; the numbers
   % for both are below.
   horizLabels = true;
   if horizLabels
      x0 = 16; hL = 14;    % width for 'a priori'/'(no realization)' stacked
   else
      x0 = 9;  hL = 24;    % the rotated label's own 0.70 in
   end

   % THE GRID GEOMETRY, SET ONCE AND BEFORE THE FIGURE.
   % ----------------------------------------------------------------------
   % These four numbers used to be split: hL and the crop were chosen up
   % here, hU and y0 a hundred lines down, and the crop was a literal that
   % had to be edited in step with an hU it could not see. It drifted, as
   % such pairs do - the rotated branch carried y0Crop = 31 against a y0 of
   % 28, so flipping horizLabels to false would have cropped three units
   % into the lower row and clipped it. The crop is now derived, one unit
   % below the bottom of the grid, and both branches are right by
   % construction.
   yTop = 86;
   hU   = 24;             % upper row: three lines of 9 pt, see below
   y0   = yTop - hU - hL;
   y0Crop = y0 - 1;

   % Cell contents, held here as data rather than buried in the drawing
   % code, so the membership can be read and checked in one place. The
   % taxonomy is no longer also a table in the manuscript: one object for one
   % thing, and this figure is it. The count checks below are what a table
   % would otherwise have given for free.
   % The comma before each line break is deliberate: a wrapped list keeps its
   % separator, and the counts below split on commas, so a missing one is both
   % a typographic and an arithmetic error.
   % A superscript asterisk marks a metric introduced in this paper. TEN
   % carry one: the five of Section 6.7, with overT in the tinted cell and the
   % other four in the a priori n-aware cell beside it; esLoad in that same
   % cell; and in the a priori code-agnostic cell sep_{min} and adj_{CV}, the
   % worst-case and dispersion counterparts of eta_{sep} and adj_{min}, with
   % S_{ach} and adj_{gamma}.
   % THREE join WITHOUT a marker, because they are taken from the literature
   % rather than stated here: S_{new} [13], gamma [14], and B_{guar}, which
   % returns the classical Ramsey-Forney guarantee - for the block interleaver
   % it evaluates to exactly t*K - so the quantity is [3], [4] and only its
   % use as a per-permutation metric is new. Marking it would have claimed
   % the guarantee. The marker is defined in the
   % manuscript caption and no longer keyed inside the drawing: the key cost a
   % line of height and said what the caption already says.
   % The Section 8 verdict is deliberately NOT drawn. Provenance and outcome
   % are orthogonal, the figure argues the taxonomy, and the verdict has three
   % objects of its own (Tables 10 and 11, Fig. 5). Do not add a second mark.
   % The marker is '*' and not '\dagger' on purpose: the dagger is not in the
   % TeX subset MATLAB's text interpreter accepts, and an unsupported command
   % is printed verbatim rather than raising an error.
   % The lower-left cell reads '(none)', not '(vacant)': it is empty for a
   % different reason from the tinted one and must not share its word.
   %
   % NO COMMENT LINES INSIDE THE LITERAL. A line that is only a comment ends
   % the continuation the '...' above it opened, so its newline becomes a row
   % separator and the second row came out one cell long: 'vertcat -
   % dimensions not consistent' at run time. The block-balance checker cannot
   % see this, so the rule is written here where the next edit will meet it.
   cell_txt = { ...
      sprintf('\\eta_{sep}, sep_{min}^{*}, adj_{min}, adj_{CV}^{*},\nAPSR, S_{factor}, LE,\nS_{new}, \\gamma, S_{ach}^{*}, adj_{\\gamma}^{*}'), ...
      sprintf('S_{sf}, giniLoad^{*},\nmeanMaxCW^{*}, maxErrCW^{*},\ncvLoad^{*}, esLoad^{*}'), ...
      sprintf('overT^{*},\nB_{guar}'); ...
      '(none)', ...
      sprintf('\\eta_{ES}, \\Delta_{BS},\n\\Delta_G'), ...
      sprintf('S_{ECC}, U_{ECC},\nV_{ECC}') };
   tinted = [1 3];                       % the cell no reviewed metric held
   % Row labels are set vertically, so their length is bounded by the row
   % height: the long forms '(no sampled realization)' do not fit and the
   % caption carries them instead.
   rowLab = {{'\bf a priori', '\rm (no realization)'}, ...
             {'\bf a posteriori', '\rm (realization)'}};

   % WIDTH AND HEIGHT. Eleven metrics sit in the a priori code-agnostic cell,
   % and making the figure taller to hold them was the wrong lever: five
   % lines at 90 mm, hU = 42 units, 2.50 in overall. Elsevier
   % allows 140 mm as well as 90, the extra 56 % of width goes almost
   % entirely to that one cell, and lines come out instead of inches going in.
   %
   % At 140 mm the cell should take four lines rather than five, so hU drops
   % from 42 to 34. With the horizontal labels above, the lower row drops with
   % it, from 24 units to 12, and the drawn span becomes 34 + 12 + 1 = 47
   % below yTop = 86. At 0.0309 in per unit - the value the 8 pt type was set
   % against - the 61 drawn units give about 1.88 in, from 2.50.
   %
   % THE LINE COUNT IS NOT A RENDERING OUTCOME. This block used to say that
   % whether the cell "reflows to four lines or to three depends on how the
   % text interpreter breaks it". It does not. MATLAB does not wrap text in a
   % cell - it prints past the border, which the header above already says -
   % so the number of lines is exactly the number of newlines in the literal
   % and nothing else. The cell came out at five lines for a widening that
   % was supposed to buy four because the literal still held five, and no
   % amount of width was ever going to change that. The literal is now broken
   % at four: the two deliberate pairs keep a line each (eta_sep with its
   % worst-case counterpart sep_min, adj_min with its dispersion counterpart
   % adj_CV), and the two taken from the literature join the two new ones on
   % the last line, where the asterisk already tells them apart.
   %
   % Column 1 is 0.42 of the drawable width, about 1.92 in, and the longest
   % of the four lines is roughly 1.0 in of 9 pt type, so the break has room
   % either side.
   %
   % hU AND hL ARE NOW SET FROM A MEASURED LINE HEIGHT: 0.179 in.
   % ----------------------------------------------------------------------
   % That number was read off the 600 dpi export - four lines of the
   % code-agnostic cell occupied 0.717 in - and it is 20 % more than the
   % 0.15 in that 9 pt type with 1.2 leading would suggest. The difference
   % is the markup: every line here carries a subscript and most carry a
   % raised asterisk, and MATLAB's tex renderer grows the line box for both.
   % Estimating that leading is what produced hU = 26 for four lines, where
   % the box was 0.788 in against 0.717 in of text and the last line sat
   % 0.025 in - under two points - off the bottom border. It did not clip,
   % and it was not readable either.
   %
   % THE FIX IS A LINE FEWER, NOT A LARGER BOX. The cells had width to
   % spare and no height to spare, so the two upper cells are broken at
   % three lines and the column shares move the slack to where the names are
   % (see wFrac below). Three lines need 0.537 in; hU = 24 gives 0.742 in,
   % which is 0.10 in of clearance a side instead of 0.025.
   %
   % hL goes the other way, 12 to 14. The lower row was never mentioned but
   % it measured worse than the upper one in proportion: 0.360 in of box for
   % 0.277 in of text, 0.038 in of clearance. 14 units is 0.433 in and
   % 0.078 in a side. The two changes cancel in the total, so the figure
   % stays at about 1.64 in and both rows become legible - the height was
   % never the thing to buy here.
   %
   % IF A CELL CLIPS AFTER THIS, the number to change is hU or hL and
   % nothing else; measure the export rather than estimating the leading,
   % which is the mistake this block exists to record.
   % Height follows the crop rather than being typed beside it: the two
   % geometries differ by 12 units and a literal would have to be edited in
   % step with the switch above, which is exactly the kind of pair that drifts.
   f = fig_style('new', 'wide', (100 - y0Crop) * 0.0309);
   ax = axes('Parent', f, 'Position', [0.005 0.005 0.99 0.99]);
   hold(ax, 'on'); axis(ax, 'off');
   xlim(ax, [0 100]); ylim(ax, [y0Crop 100]);

   % x0: room for the vertical row labels, kept as narrow as those labels
   % allow, because every unit taken here comes out of the cells.
   % COLUMNS ARE NOT EQUAL THIRDS. The code-agnostic cell holds eleven
   % metrics, the n-aware six and the (n,t)-aware two, so equal thirds crowd
   % the first and waste the last. The weights below are the share of the
   % drawable width each column gets; they must sum to 1.
   wTot = 100 - x0 - 1;
   % MEASURED OFF THE RENDER, not estimated. At [0.42 0.34 0.24] the three
   % cells came out 1.89, 1.52 and 1.06 in while their widest lines were
   % 0.95, 0.91 and 0.61 in, so column 3 was carrying almost half an inch it
   % had no use for and column 2 - whose names are the long ones - was the
   % one short of room. The shares below move that slack to where the text
   % is, which is what lets both upper cells hold three lines instead of
   % four. Column 3 keeps 0.90 in against a 0.61 in line.
   wFrac = [0.40 0.40 0.20];
   assert(abs(sum(wFrac) - 1) < 1e-12, 'fig2_taxonomy: column widths must sum to 1');
   wCol = wTot * wFrac;
   xCol = x0 + [0, cumsum(wCol(1:2))];
   % Rows sized to their content. Which content depends on the labels: set
   % horizontally they cost width and the lower row is bound by its cells,
   % which at 140 mm should be one line each; rotated, the row could never be
   % shorter than the 0.70 in of 'a posteriori', because a rotated label's
   % length runs along the row height and cannot be shorter than its longest
   % line. Adding lines to that label does not help - it is already two - and
   % dropping the parenthetical buys 0.06 in while costing the distinction the
   % caption leans on. Measured on the rotated export: hL = 24 leaves
   % about 0.05 in of slack and hL = 22 clips.
   % yTop, hU, hL and y0 are set above, before the figure, so that the crop
   % can be derived from them rather than typed twice.
   rowY = [yTop - hU, y0]; rowH = [hU, hL];

   for r = 1:2
      for c = 1:3
         X = xCol(c); w = wCol(c); Y = rowY(r); h = rowH(r);
         if r == tinted(1) && c == tinted(2)
            patch(ax, [X X+w X+w X], [Y Y Y+h Y+h], [0.88 0.93 0.97], ...
                  'EdgeColor', C(2, :), 'LineWidth', 1.2);
         else
            patch(ax, [X X+w X+w X], [Y Y Y+h Y+h], 'w', ...
                  'EdgeColor', [0.65 0.65 0.65], 'LineWidth', 0.6);
         end
         % Every cell is set the same way. The tinted one used to carry a
         % two-line note above its names; the tint and the caption say the
         % same thing, and the note cost the cell half its height.
         text(ax, X + w/2, Y + h/2, cell_txt{r, c}, 'FontName', S.font, ...
              'FontSize', S.label, 'Interpreter', 'tex', ...
              'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
      end
   end

   heads = {'code-agnostic', 'n-aware', '(n,t)-aware'};
   for c = 1:3
      text(ax, xCol(c) + wCol(c) / 2, yTop + 1.5, heads{c}, 'FontName', S.font, ...
           'FontSize', S.label, 'FontWeight', 'bold', ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
   end
   for r = 1:2
      if horizLabels
         text(ax, x0 - 1.0, rowY(r) + rowH(r)/2, rowLab{r}, 'FontName', S.font, ...
              'FontSize', S.label, 'Interpreter', 'tex', ...
              'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
      else
         text(ax, x0 - 1.5, rowY(r) + rowH(r)/2, rowLab{r}, 'FontName', S.font, ...
              'FontSize', S.label, 'Rotation', 90, 'Interpreter', 'tex', ...
              'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
      end
   end

   % The axes are ordered, and the order is the claim: knowing more about the
   % code cannot reduce what a metric can discriminate. The arrow is an
   % annotation, so its endpoints are figure units; both are computed from the
   % data coordinates above rather than typed, since the crop moved.
   d2nx = @(x) 0.005 + 0.99 * x / 100;
   d2ny = @(y) 0.005 + 0.99 * (y - y0Crop) / (100 - y0Crop);
   annotation(f, 'arrow', [d2nx(x0 + 2) d2nx(99)], [d2ny(95.5) d2ny(95.5)], ...
              'Color', [0.5 0.5 0.5], 'HeadLength', 4, 'HeadWidth', 4);
   text(ax, 55, 99, 'increasing code knowledge', 'FontName', S.font, ...
        'FontSize', S.note, 'FontAngle', 'italic', 'Color', [0.45 0.45 0.45], ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'w', 'Margin', 0.5);

   % Say where the files went. fig_style returns the paths it wrote and this
   % script used to drop them, which left the caller guessing between
   % <pwd>/figures, PAPER_FIG_DIR and whatever outDir was passed.
   if opts.save
      files = fig_style('save', f, 'fig2_taxonomy', opts.outDir);
      if ~isempty(files)
         fprintf('\n  written to %s\n', fileparts(files{1}));
      end
   end

   % The figure names every metric in the study, so the counts are checks the
   % script can run rather than things to eyeball. The study scores twenty-five
   % metrics and all twenty-five are named across the six cells; a figure showing
   % twenty-four has lost one silently, which is the failure mode a picture is
   % worst at revealing - and there is no longer a table to catch it. The
   % second and third checks are the cell and marker counts: exactly two
   % metrics may sit in the a priori, (n,t)-aware cell, and exactly ten
   % metrics in the whole figure may carry the marker - B_{guar} shares that
   % cell but not the marker.
   total = 0;
   for r = 1:2
      for c = 1:3
         t = cell_txt{r, c};
         % Skip the empty cell by its marker. The marker was renamed from
         % '(vacant)' to '(none)', and a skip still keyed on the old word would
         % have counted '(none)' as a twentieth metric and raised a false alarm.
         if strcmp(strtrim(t), '(none)'), continue; end
         total = total + numel(regexp(t, ',', 'split'));
      end
   end
   nHi  = numel(regexp(cell_txt{tinted(1), tinted(2)}, ',', 'split'));
   nNew = numel(strfind([cell_txt{:}], '^{*}'));
   ok = true;
   if total ~= 25
      ok = false;
      fprintf(2, ['\n  FIGURE 2 NAMES %d METRICS; THE STUDY SCORES 25. The cell\n' ...
                  '  contents at the top of this file have drifted from the suite.\n'], total);
   end
   if nHi ~= 2
      ok = false;
      fprintf(2, ['\n  THE A PRIORI (n,t)-AWARE CELL HOLDS %d METRICS; overT AND B_guar\n' ...
                  '  USE t. See the argument sets in the header of this file.\n'], nHi);
   end
   if nNew ~= 10
      ok = false;
      fprintf(2, ['\n  %d METRICS CARRY THE NEW-METRIC MARKER; THIS PAPER STATES 10\n' ...
                  '  FIRST: the 5 of Section 6.7, sep_min, adj_CV, esLoad, S_ach\n' ...
                  '  and adj_gamma. S_new, gamma and B_guar are NOT marked.\n'], nNew);
   end
   if ok
      fprintf(['\n  25 metrics across the six cells, 10 marked as new, overT and\n' ...
               '  B_guar in the a priori (n,t)-aware cell.\n\n']);
   else
      fprintf('\n');
   end
end
