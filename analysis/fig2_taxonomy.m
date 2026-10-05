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
% This is the correction carried by the v40 manuscript, and it is the one
% thing in this script that is easy to get wrong again. Of the five metrics
% of Section VI-G, only overT compares a load with the correction capacity:
%
%   maxErrCW    = max_s max_k e_k(s)                       no t  -> n-aware
%   overT       = |{s : max_k e_k(s) > t}| / (N - B + 1)   uses t -> (n,t)-aware
%   meanMaxCW   = E_s[ max_k e_k(s) ]                      no t  -> n-aware
%   cvLoad      = E_s[ sigma/mu over loaded codewords ]    no t  -> n-aware
%   giniLoad    = E_s[ G(e(s)) ]                           no t  -> n-aware
%
% A signature of the form M(pi, n, t, B) proves what a function receives, not
% what it uses. Four of the five receive t and never read it, so they belong
% one column to the left. Do not move them back.
%
% TYPE SIZE
% ===========================================================================
% The cell contents are the thing a reader actually reads, and at 7 pt with
% subscripts dropping to about 5 pt they were hard to read on paper. They are
% set at the body size of the figure set (fig_style 'label', 8 pt) and the
% figure is drawn taller to pay for it; the asterisk key, which is read once,
% stays at 7 pt. Every list is broken by hand so that no line exceeds about
% seventeen characters, which is what one cell holds at this width. If a
% metric is renamed, re-break the list: MATLAB does not wrap text in a cell,
% it prints past the border.
%
% This is the only figure in the set with no data behind it, and it is drawn
% in the same toolchain as the rest so that its type, weights and export
% match. A diagram set in a different program is recognisable as one.
%
% Drawn at ONE column width (3.5 in).
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
   y0Crop = 22;   % nothing below this is drawn; the asterisk key sits at 22.5

   % Cell contents, held here as data rather than buried in the drawing
   % code, so the membership can be read and checked in one place. The
   % taxonomy is no longer also a table in the manuscript: one object for one
   % thing, and this figure is it. The count checks below are what a table
   % would otherwise have given for free.
   % The comma before each line break is deliberate: a wrapped list keeps its
   % separator, and the counts below split on commas, so a missing one is both
   % a typographic and an arithmetic error.
   % A superscript asterisk marks a metric introduced in this paper. All five
   % of Section VI-G carry one: overT in the tinted cell, the other four in
   % the a priori n-aware cell beside it. The key is drawn under the grid.
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
      sprintf('\\eta_{sep}, sep_{min},\nadj_{min}, CV_{adj},\nPSR, S_{factor}, LE'), ...
      sprintf('S_{sf}, giniLoad^{*},\nmeanMaxCW^{*},\nmaxErrCW^{*},\ncvLoad^{*}'), ...
      'overT^{*}'; ...
      '(none)', ...
      sprintf('\\eta_{ES}, \\Delta_{BS},\n\\Delta_G'), ...
      sprintf('S_{ECC}, U_{ECC},\nV_{ECC}') };
   tinted = [1 3];                       % the cell no reviewed metric held
   % Row labels are set vertically, so their length is bounded by the row
   % height: the long forms '(no sampled realization)' do not fit and the
   % caption carries them instead.
   rowLab = {{'\bf a priori', '\rm (no realization)'}, ...
             {'\bf a posteriori', '\rm (realization)'}};

   f = fig_style('new', 'single', 2.30);
   ax = axes('Parent', f, 'Position', [0.005 0.005 0.99 0.99]);
   hold(ax, 'on'); axis(ax, 'off');
   xlim(ax, [0 100]); ylim(ax, [y0Crop 100]);

   % x0: room for the vertical row labels, kept as narrow as those labels
   % allow, because every unit taken here comes out of the cells.
   x0 = 9; w = (100 - x0 - 1) / 3;
   % Rows sized to their content: four lines in the widest upper cell, three
   % in the widest lower one. The strip between y0Crop and y0 carries the key.
   yTop = 86; hU = 30; hL = 28; y0 = yTop - hU - hL;     % y0 = 28
   rowY = [yTop - hU, y0]; rowH = [hU, hL];

   for r = 1:2
      for c = 1:3
         X = x0 + (c - 1) * w; Y = rowY(r); h = rowH(r);
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
      text(ax, x0 + (c - 0.5) * w, yTop + 1.5, heads{c}, 'FontName', S.font, ...
           'FontSize', S.label, 'FontWeight', 'bold', ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
   end
   for r = 1:2
      text(ax, x0 - 1.5, rowY(r) + rowH(r)/2, rowLab{r}, 'FontName', S.font, ...
           'FontSize', S.label, 'Rotation', 90, 'Interpreter', 'tex', ...
           'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
   end

   % Key for the asterisk, under the grid and left-aligned with it, so the
   % figure states which metrics are new without relying on the caption.
   % Set from the bottom of the axes so it cannot ride up into the grid line.
   text(ax, x0, y0Crop + 0.5, '^{*} introduced here', 'FontName', S.font, ...
        'FontSize', S.note, 'FontAngle', 'italic', 'Color', [0.35 0.35 0.35], ...
        'Interpreter', 'tex', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'bottom');

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

   if opts.save, fig_style('save', f, 'fig2_taxonomy', opts.outDir); end

   % The figure names every metric in the study, so the counts are checks the
   % script can run rather than things to eyeball. The study scores nineteen
   % metrics and all nineteen are named across the six cells; a figure showing
   % eighteen has lost one silently, which is the failure mode a picture is
   % worst at revealing - and there is no longer a table to catch it. The
   % second and third checks are the ones the v40 correction added: exactly
   % one metric may sit in the a priori, (n,t)-aware cell, and exactly five
   % metrics in the whole figure may carry the marker.
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
   if total ~= 19
      ok = false;
      fprintf(2, ['\n  FIGURE 2 NAMES %d METRICS; THE STUDY SCORES 19. The cell\n' ...
                  '  contents at the top of this file have drifted from the suite.\n'], total);
   end
   if nHi ~= 1
      ok = false;
      fprintf(2, ['\n  THE A PRIORI (n,t)-AWARE CELL HOLDS %d METRICS; ONLY overT USES t.\n' ...
                  '  See the argument sets in the header of this file.\n'], nHi);
   end
   if nNew ~= 5
      ok = false;
      fprintf(2, '\n  %d METRICS CARRY THE NEW-METRIC MARKER; SECTION VI-G DEFINES 5.\n', nNew);
   end
   if ok
      fprintf(['\n  19 metrics across the six cells, 5 marked as new, overT alone\n' ...
               '  in the a priori (n,t)-aware cell.\n\n']);
   else
      fprintf('\n');
   end
end
