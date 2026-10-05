function out = fig_cnn_justification(dataPath, opts)
%FIG_CNN_JUSTIFICATION  The survivorship effect C_NN corrects, drawn from data.
%
%   out = fig_cnn_justification('<resultsDir>')
%   out = fig_cnn_justification(path, struct('condition','single_common','save',true))
%
% WHAT THE FIGURE ARGUES
% ===========================================================================
% Section VI-B claims three things about C_NN, and each panel is one of them.
%
%   (a) Methods that extend the frame receive a LOWER error density. The burst
%       mask is generated at the encoded length and zero-extended, so every
%       method takes the same absolute number of corrupted symbols while the
%       denominator grows. Panel (a) plots the realized noiseActual against
%       the target for every method, so the extending methods separate
%       downward from the line the others sit on.
%
%   (b) The separation is exactly the frame extension and nothing else. Panel
%       (b) plots each method's mean noiseActual against its BE. If the
%       mechanism is dilution, the points lie on noiseActual = target x BE,
%       which is drawn as a line rather than fitted.
%
%   (c) The correction is what removes the advantage. Panel (c) shows each
%       method's mean CR before and after C_NN. The extending methods lose
%       exactly the credit the dilution gave them; the others do not move.
%
% Panel (b) is the load-bearing one. It is the difference between asserting a
% mechanism and showing it: a fitted line through those points would prove
% only that something is monotone, whereas the drawn line is the prediction
% C_NN is derived from, with no free parameter.
%
% WHY IT IS SEPARATE FROM THE HEALTH CHECK
% ===========================================================================
% health_check reports the within-trial spread of noiseActual across methods
% as an advisory, because a spread larger than the frame extension explains
% would mean the masks were not shared. That is a pass/fail question. This is
% the same quantity drawn rather than thresholded, for the manuscript.
%
% OPTIONS
%   condition   which sweep to draw, as regime_grid, e.g. 'single_common'.
%               Default: 'multi_common'. NOT a Gilbert-Elliott sweep:
%               check_noise_fidelity showed those realize about 0.22 in
%               every bin, so their five "noise levels" are one level and a
%               panel drawn per bin from them would claim a range it does
%               not have. single and multi honour their labels exactly.
%   save        true to write a PNG and an EPS beside the data. Default false.
%   figPath     where to write. Default: the same ./figures folder as every
%               other figure, through fig_style.
%   stem        file name without extension. Default 'fig3_cnn', the name
%               the manuscript uses; the condition drawn is printed, not
%               encoded in the name, so the seven files sit side by side.

   if nargin < 1 || isempty(dataPath)
      c = configure_simulation(); dataPath = char(c.dataSavePath);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'condition'), opts.condition = 'multi_common'; end
   if ~isfield(opts, 'save'),      opts.save = false;   end
   % Empty means fig_style's folder, ./figures, where the other six land.
   % It was <dataPath>/figs, so Figure 3 was the one figure written somewhere
   % else, under a name carrying the sweep tag, and looked as if it had not
   % been produced at all.
   if ~isfield(opts, 'figPath'),   opts.figPath = ''; end
   if ~isfield(opts, 'stem'),      opts.stem = 'fig3_cnn'; end

   d = dir(fullfile(dataPath, 'KPItableDetailed_*.mat'));
   if isempty(d), error('fig_cnn_justification: no KPItableDetailed_*.mat in %s', dataPath); end
   pick = 1;
   for i = 1:numel(d)
      if ~isempty(opts.condition) && ~isempty(strfind(d(i).name, opts.condition)), pick = i; break; end
      if isempty(opts.condition) && ~isempty(strfind(d(i).name, '_common_')), pick = i; break; end
   end
   f = fullfile(dataPath, d(pick).name);
   T = local_rows(load(f));
   cfg = local_config(dataPath, d(pick).name);
   if isempty(cfg) || ~isfield(cfg, 'noiseLevels')
      error('fig_cnn_justification: config.noiseLevels is needed for the target density');
   end
   tagRaw = regexprep(d(pick).name, '^KPItableDetailed_|\.mat$', '');
   tag = strrep(tagRaw, '_', ' ');

   meth = {T.method}.';
   elen = double([T.encodedLen]).';
   ilen = double([T.interleavedLen]).';
   nact = double([T.noiseActual]).';
   nbin = double([T.noiseBin]).';
   CR   = double([T.CR]).';
   tgt  = cfg.noiseLevels(nbin).';
   BE   = elen ./ ilen;

   uM = sort(unique(meth));
   nM = numel(uM);

   % Everything below is at (method, length) granularity. BE varies with
   % length - a matrix interleaver pads to a rectangle, so its extension at
   % one length is not its extension at another - and an average over lengths
   % does not factor through the correction. Quantities that are exact per
   % trial become approximate the moment they are averaged over lengths, and
   % the whole point of panels (b) and (c) is that they are exact.
   uL = sort(unique(elen));
   nL = numel(uL);

   % A REFERENCE METHOD, and why the panels use ratios to it.
   % ----------------------------------------------------------------------
   % The tempting comparison is realized density against TARGET density. It
   % is not exact: the injected count is round(target x encodedLen), so
   % C_NN / BE = round(target.L)/(target.L), which departs from 1 by up to
   % 1/(2.target.L) - about 6 % at the lowest noise bin and the shortest
   % frame. Points would scatter off the predicted line for a reason that
   % has nothing to do with the mechanism being shown.
   %
   % Against a method that does not extend the frame, the same statement is
   % exact and rounding drops out entirely. With one shared count E per
   % trial, noiseActual_j = E / interleavedLen_j, so for any method j and a
   % reference r with BE_r = 1,
   %
   %       noiseActual_j / noiseActual_r = encodedLen / interleavedLen_j = BE_j
   %
   % with no approximation at all. That identity is what panels (b) and (c)
   % test, and it has no free parameter and no fitted line.
   gBE = nan(nM, nL); gRT = nan(nM, nL); gDT = nan(nM, nL);
   for j = 1:nM
      for k = 1:nL
         at = strcmp(meth, uM{j}) & elen == uL(k);
         if ~any(at), continue; end
         gBE(j,k) = mean(elen(at) ./ ilen(at));
         gDT(j,k) = mean(nact(at) ./ tgt(at));
      end
   end
   mBE = mean(gBE, 2, 'omitnan');
   pads = mBE < 1 - 1e-9;
   refIdx = find(~pads & all(abs(gBE - 1) < 1e-12 | isnan(gBE), 2), 1);
   if isempty(refIdx)
      warning('fig_cnn_justification: no method has BE = 1 at every length; panels (b) and (c) fall back on the target and will show integer-rounding scatter.');
      refIdx = find(~pads, 1);
   end
   for j = 1:nM
      for k = 1:nL
         atJ = strcmp(meth, uM{j})       & elen == uL(k);
         atR = strcmp(meth, uM{refIdx})  & elen == uL(k);
         if ~any(atJ) || ~any(atR), continue; end
         gRT(j,k) = mean(nact(atJ)) / mean(nact(atR));
      end
   end
   gLoss = 1 - gRT;

   mCR = zeros(nM,1); mCRraw = zeros(nM,1);
   for j = 1:nM
      at = strcmp(meth, uM{j});
      mCR(j)    = mean(CR(at));
      mCRraw(j) = mean(CR(at) ./ (nact(at) ./ (tgt(at) + eps) + eps));
   end

   out = struct('condition', tagRaw, 'methods', {uM}, 'BE', mBE, ...
                'reference', uM{refIdx}, 'densityRatio', mean(gDT,2,'omitnan'), ...
                'CR_corrected', mCR, 'CR_raw', mCRraw, 'padding', pads, ...
                'BE_byLength', gBE, 'ratioToRef_byLength', gRT);

   ok = isfinite(gBE) & isfinite(gRT);
   resid   = max(abs(gRT(ok) - gBE(ok)));
   residTgt = max(abs(gDT(isfinite(gDT)) - gBE(isfinite(gDT))));

   fprintf('\n  C_NN JUSTIFICATION  -  %s\n', tag);
   fprintf('  reference method (BE = 1 at every length): %s\n\n', uM{refIdx});
   fprintf('  %-16s %8s %8s %10s %9s %9s\n', 'method', 'BE min', 'BE mean', 'C_NN mean', 'CR raw', 'CR adj');
   [~, ord] = sort(mBE);
   for k = ord.'
      fprintf('  %-16s %8.4f %8.4f %10.4f %9.4f %9.4f\n', uM{k}, ...
              min(gBE(k,:)), mBE(k), mean(gDT(k,:), 'omitnan'), mCRraw(k), mCR(k));
   end
   fprintf(['\n  Density ratio to %s equals BE at every (method, length) to %.2e.\n' ...
            '  Against the TARGET instead, the same identity holds only to %.2e,\n' ...
            '  and the difference is integer rounding of the injected error count,\n' ...
            '  not a defect in the mechanism. Panel (a) plots that ratio per noise bin.\n\n'], ...
            uM{refIdx}, resid, residTgt);

   % ---- what the correction actually changes -----------------------------
   [~, o0] = sort(mCRraw, 'descend'); [~, o1] = sort(mCR, 'descend');
   r0 = zeros(nM,1); r0(o0) = 1:nM;  r1 = zeros(nM,1); r1(o1) = 1:nM;
   moved = find(r0 ~= r1);
   fprintf('  Rank by CR, before and after the correction:\n');
   if isempty(moved)
      fprintf('    no method changes rank; the correction shifts levels only.\n\n');
   else
      for i = moved(:).'
         fprintf('    %-16s %2d -> %2d  (CR %.4f -> %.4f)\n', uM{i}, r0(i), r1(i), mCRraw(i), mCR(i));
      end
      fprintf('\n');
   end
   out.rankBefore = r0; out.rankAfter = r1; out.moved = uM(moved);

   % ---- panel (a): the ratio TO THE UNEXTENDED REFERENCE, per noise bin ---
   % The first version plotted realized density over TARGET density. That
   % ratio carries a large effect common to every method: the injected count
   % is round(noiseLevel * len), and how far that integer lands from the
   % target swings the ratio from about 1.22 in the lowest bin to 0.83 in the
   % highest. The panel's subject - the one to two per cent by which the
   % extending methods sit below the rest - is twenty times smaller than that
   % swing, so all five curves drew on top of one another and the figure
   % showed a property of the noise grid instead of a property of the frame.
   %
   % Dividing by the unextended methods bin for bin cancels the common term.
   % What is left is exactly the quantity Lemma 1 names: the realized density
   % of method j relative to a reference with BE = 1, which equals BE_j. Each
   % extending method becomes a flat line at its own bandwidth efficiency,
   % the reference is flat at 1, and the separation the panel exists to show
   % is the whole height of the axis rather than a hundredth of it.
   uB = sort(unique(nbin)); nB = numel(uB);
   raw = nan(nM, nB);
   for j = 1:nM
      for k = 1:nB
         at = strcmp(meth, uM{j}) & nbin == uB(k);
         if any(at), raw(j,k) = mean(nact(at) ./ tgt(at)); end
      end
   end
   refRow = mean(raw(~pads(:), :), 1, 'omitnan');
   if ~any(isfinite(refRow))
      error('fig_cnn_justification:noRef', ...
            ['no unextended method in this condition, so there is no ' ...
             'BE = 1 reference to take the ratio against.']);
   end
   bCNN = raw ./ repmat(refRow, nM, 1);
   out.densityRatio = bCNN; out.densityVsTarget = raw;

   % ---------------------------------------------------------------- figure
   % TWO panels, not three. An earlier version put the mechanism in a middle
   % panel: realized density against BE with the identity drawn. The identity
   % holds to 2e-15, and a scatter cannot show that - it would look the same
   % at 1e-3. The number states it far more precisely than the picture, so
   % the number goes in the caption and the panel goes away. What is left is
   % the effect and its consequence, which are things a reader can only get
   % from a figure.
   % Drawn at final size through the shared style, so this figure carries the
   % same type and weights as the other six. It was previously created at
   % 1020 by 440 pixels with 12 pt text and scaled on insertion, which scales
   % the text with it: the point sizes below then mean nothing.
   % ONE COLUMN, PANELS STACKED. Side by side the figure spanned both columns
   % at 2.6 in, i.e. 5.2 column-inches plus a full-width caption and two
   % section breaks. Stacked at 3.5 in wide it is about 3.6 in in one column:
   % roughly 1.8 column-inches (about eleven lines of text) fewer, and no
   % section break to unbalance the columns.
   fig = fig_style('new', 'single', 3.66);
   set(fig, 'Name', ['C_NN justification - ' tag]);
   cPad = [0.80 0.15 0.15]; cNo = [0.38 0.43 0.50];
   padPal = [0.80 0.15 0.15; 0.90 0.50 0.10; 0.55 0.10 0.55; 0.10 0.45 0.70; 0.20 0.55 0.25];
   Sty = fig_style('sizes');
   FS = Sty.tick; FSt = Sty.title; FSl = Sty.legend;

   % (a) THE EFFECT, per noise bin. Plotted as realized/target rather than as
   %     the two densities: on an absolute axis the whole story is a one to
   %     four per cent gap on a value of 0.2 and nothing is visible. The
   %     normalized form also makes a second point the absolute one hides -
   %     the dilution is flat across noise level, so it belongs to the frame
   %     and not to the channel.
   axA = subplot(1,2,1); hold on; box on;

   % COLOUR BY CURVE, NOT BY METHOD.
   % ----------------------------------------------------------------------
   % The previous version assigned one colour per extending method and only
   % afterwards folded the coinciding ones into a single legend entry. Methods
   % whose frames extend by the same fraction draw the SAME curve, so the one
   % plotted last covered the others completely: the legend advertised a red
   % "helical, matrix" while no red was anywhere on the axes, and the reader
   % had no way to locate two of the five methods.
   %
   % Curves are therefore clustered first. One colour per cluster, every
   % member drawn in it, and the legend entry names all of them - so a hidden
   % curve is hidden underneath its own colour, which is the honest way to
   % show that two methods are indistinguishable at this resolution.
   padIdx = find(pads(:)).';
   grpOf = zeros(1, numel(padIdx)); repAt = []; ng = 0;
   for i = 1:numel(padIdx)
      for g = 1:ng
         if max(abs(bCNN(padIdx(i),:) - bCNN(padIdx(repAt(g)),:))) < 1e-6
            grpOf(i) = g; break;
         end
      end
      if grpOf(i) == 0, ng = ng + 1; grpOf(i) = ng; repAt(ng) = i; end %#ok<AGROW>
   end
   gLev = arrayfun(@(g) mean(bCNN(padIdx(repAt(g)),:)), 1:ng);
   [~, gOrd] = sort(gLev, 'descend');           % top curve gets the first colour
   colOfGrp = zeros(1, ng);
   for k = 1:ng, colOfGrp(gOrd(k)) = mod(k-1, size(padPal,1)) + 1; end

   % The unextended methods first and THICK: this is the reference the whole
   % panel is read against, and at 0.9 pt against a grid it disappeared.
   hNo = [];
   for j = find(~pads(:)).'
      h = plot(1:nB, bCNN(j,:), '-', 'Color', cNo, 'LineWidth', 2.4);
      if isempty(hNo), hNo = h; end
   end
   hRef = plot([0.5 nB+0.5], [1 1], 'k--', 'LineWidth', 1.0);

   hPad = zeros(1, ng); lbl = cell(1, ng);
   for i = 1:numel(padIdx)
      g = grpOf(i); c = padPal(colOfGrp(g), :);
      h = plot(1:nB, bCNN(padIdx(i),:), '-o', 'Color', c, 'MarkerSize', 6, ...
               'MarkerFaceColor', c, 'LineWidth', 2.0);
      if hPad(g) == 0
         hPad(g) = h; lbl{g} = uM{padIdx(i)};
      else
         lbl{g} = [lbl{g} ', ' uM{padIdx(i)}];
      end
   end
   hPad = hPad(gOrd); lbl = lbl(gOrd);

   % NO LEGEND HERE, AND A TIGHT AXIS. The curves are flat lines at the
   % methods' bandwidth efficiencies - 1.000, about 0.995, 0.992 and 0.983 -
   % so the whole finding lives inside two per cent of the axis. A legend
   % placed above the data needed headroom, and headroom crushed that two
   % per cent into a sliver in which no two curves could be told apart. The
   % axis is therefore fitted to the data and each cluster is named at its
   % own right-hand end, which separates the curves AND removes the legend.
   allv = bCNN(isfinite(bCNN));
   v0 = min(allv(:)); v1 = max([allv(:); 1]);
   m  = max(0.06 * (v1 - v0), 0.0015);
   ylim([v0 - m, v1 + m]);
   xlim([0.5, nB + 0.5 + max(2.2, 0.45 * nB)]);
   xr = nB + 0.62;
   text(xr, 1, sprintf('no extension\nBE = 1'), 'Color', cNo, ...
        'FontSize', FSl, 'FontName', Sty.font, 'VerticalAlignment', 'middle');
   for g = 1:ng
      k = gOrd(g); c = padPal(colOfGrp(k), :);
      lev = gLev(k);
      nmTxt = strrep(lbl{g}, ', ', sprintf(',\n'));
      text(xr, lev, sprintf('%s\nBE = %.3f', nmTxt, lev), 'Color', c, ...
           'FontSize', FSl, 'FontName', Sty.font, 'VerticalAlignment', 'middle');
   end
   set(gca, 'XTick', 1:nB, 'XTickLabel', arrayfun(@(t) sprintf('%.3g', t), ...
            cfg.noiseLevels(uB), 'UniformOutput', false), 'FontSize', FS);
   xlabel('target noise density', 'FontSize', FS);
   ylabel({'realized density,'; 'relative to BE = 1'}, 'FontSize', FS);   % two lines: the axis is 1.3 in tall
   title('(a) an extended frame dilutes the burst by exactly BE', 'FontSize', FSt);
   % The xlim set above leaves room on the right for the direct labels. A
   % second xlim here used to reset it to the data range, which pushed every
   % label out of its own axes and on top of panel (b)'s method names.
   grid on;

   % (c) THE CONSEQUENCE. Drawn as the credit removed rather than as CR
   %     before and after: those differ by half a per cent to four per cent of
   %     a value spanning 0 to 0.5, so on a shared axis the two markers
   %     coincide and the panel says nothing. The difference is the quantity
   %     of interest, so the difference is what is plotted.
   axB = subplot(1,2,2); hold on; box on;
   lost = 100 * (mCRraw - mCR) ./ max(mCRraw, eps);
   show = find(lost > 0.10);                            % below 0.1 % is rounding
   [~, sc] = sort(lost(show)); show = show(sc);
   for i = 1:numel(show)
      j = show(i);
      barh(i, lost(j), 0.6, 'FaceColor', cPad, 'EdgeColor', 'none');
      lbl = sprintf('  %.2f%%', lost(j));
      if r0(j) ~= r1(j)
         lbl = sprintf('  %.2f%%   rank %d to %d', lost(j), r0(j), r1(j));
      end
      text(lost(j), i, lbl, 'FontSize', FSl, 'FontName', Sty.font, 'VerticalAlignment', 'middle');
   end
   set(gca, 'YTick', 1:numel(show), 'YTickLabel', uM(show), 'FontSize', FS, ...
            'TickLabelInterpreter', 'none');
   xlim([0 max(lost(show))*1.9 + 0.1]); ylim([0 numel(show)+1]);
   title('(b) the CR credit C_{NN} takes back, per method', 'FontSize', FSt);
   grid on;
   xlabel('CR credit removed (%)', 'FontSize', FS);
   xl = xlim;
   text(xl(2), 0.4, sprintf('all other methods < 0.1 %%   '), ...
        'FontSize', FSl, 'FontName', Sty.font, 'HorizontalAlignment', 'right', 'Color', [0.35 0.35 0.35]);

   % Both panels through the shared axis style, then the shared exporter, so
   % this figure and the other six leave in the same formats at the same size.
   for a = findobj(fig, 'Type', 'axes')', fig_style('axes', a); end
   % Positions in inches. subplot's defaults leave about 0.3 in under the
   % tick labels and a wide gutter; the manuscript wants the lines back.
   % Panel (a) keeps room on its right for the direct labels (inside its own
   % x-limits); panel (b) needs about 0.85 in for the method names.
   % Stacked: (a) on top with its direct labels inside its own x-limits,
   % (b) below with about 0.85 in for the method names. Vertical budget in
   % inches: (b) axes 0.40-1.48, its title to about 1.66; (a) ticks and label
   % need about 0.40 under its axes, so (a) starts at 2.12 and its one-line
   % title ends near 3.64. The two-line y label needs 0.74 in on the left.
   set([axA axB], 'Units', 'inches');
   set(axA, 'Position', [0.74, 2.12, 3.50 - 0.74 - 0.06, 1.34]);
   set(axB, 'Position', [0.86, 0.40, 3.50 - 0.86 - 0.08, 1.08]);
   set([axA axB], 'Units', 'normalized');
   if opts.save
      files = fig_style('save', fig, opts.stem, opts.figPath);
      fprintf('  Figure 3 drawn from condition %s\n', tagRaw);
      if ~isempty(files), out.file = files{1}; end
   end
end

% =========================================================================
function cfg = local_config(dataPath, kpiName)
   cfg = [];
   fp = fullfile(dataPath, regexprep(kpiName, '^KPItableDetailed', 'config'));
   if ~exist(fp, 'file'), return; end
   S = load(fp); fn = fieldnames(S);
   for i = 1:numel(fn)
      v = S.(fn{i});
      if isstruct(v) && isscalar(v) && isfield(v, 'noiseLevels'), cfg = v; return; end
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
