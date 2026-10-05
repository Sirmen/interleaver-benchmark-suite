function R = check_clean_region(lens, opts)
%CHECK_CLEAN_REGION  Does C_NN charge back exactly what frame extension saves?
%
%   R = check_clean_region(1200)
%   R = check_clean_region(60:60:3000)          % every length, worst BE per method
%
% WHAT THE HARNESS DOES, read from the code rather than assumed
% ===========================================================================
% configure_burst_parameters takes lenEncoded, so the target error count is
% round(noiseLevel * lenEncoded); genBurstMask returns a mask of that length;
% injectBurstErrors_all zero-extends the mask for any method whose frame is
% longer. Every method therefore takes the SAME number of corrupted
% transmitted positions, only the first lenEncoded positions can be hit, and
% noiseRatio divides by the interleaved length - which is where the density
% dilution C_NN corrects comes from.
%
% THE QUESTION
% ===========================================================================
% Corrupted POSITIONS are equal across methods; corrupted MESSAGE SYMBOLS need
% not be. An extended frame spreads lenEncoded message symbols over L > N
% positions, so a corrupted position carries a message symbol with probability
% about BE = N/L, and the untouched tail carries message symbols that cannot
% be hit. Both effects scale as BE, and C_NN multiplies CR by BE. So the
% correction is the right size exactly when
%
%       msgHit(method) / msgHit(unextended)  ==  BE(method)
%
% and the residual  ratio/BE - 1  is what is left uncharged.
%
% WHY THERE IS NO SAMPLING HERE
% ===========================================================================
% An earlier version drew 200 random masks per method per length. That is both
% approximate and slow: a fifty-length sweep rebuilt 1250 permutations, some
% of which take seconds to construct, and it looked like a hang. The quantity
% is deterministic, so it is computed exactly. For a burst of B starting at s,
% the message symbols hit are the ones in p(s : s+B-1) with index in [1, N],
% and the mean over every admissible start is a sliding window over that
% indicator - one cumulative sum, O(L) per method.
%
% The unextended reference needs no lookup either: a method with BE = 1 has a
% message symbol at every position, so its count is exactly B.
%
% OPTIONS
%   B        burst length                       [8*15]
%   methods  restrict the field                 [every method in the config]
%   quiet    suppress the per-length table      [false when one length]

   if nargin < 1, lens = 1200; end
   if nargin < 2, opts = struct(); end
   emptyLens = isempty(lens);
   % B IS THE CAMPAIGN'S INJECTED COUNT, NOT THE METRIC'S DESIGN PARAMETER.
   % ----------------------------------------------------------------------
   % configure_burst_parameters sets the target to round(noiseLevel*lenEncoded),
   % so the burst is a FRACTION of the frame and scales with it. Fixing B at
   % 8n = 120 asks about a burst the campaign never injects and, at the short
   % lengths where the extension is worst, a burst longer than the frame: at
   % N = 60 the window did not fit, the length was skipped without a word, and
   % the run reported N = 120 as the worst case when the worst case is N = 60.
   % 'auto' uses each configured noise level in turn and keeps the worst
   % residual, which is the quantity the paper needs.
   if ~isfield(opts, 'B'), opts.B = 'auto'; end
   if ~isfield(opts, 'methods'), opts.methods = {}; end
   if ~isfield(opts, 'quiet'),   opts.quiet = numel(lens) > 1; end
   if ~isfield(opts, 'dataDir'), opts.dataDir = ''; end
   if ~isfield(opts, 'dataOnly'), opts.dataOnly = false; end
   % An empty length list must not fall back to a default. It did twice: a
   % stale W from a failed run gave [W.N] = [], the function quietly scored
   % N = 1200, and the output looked like an answer to a question about the
   % worst extension. Refuse instead, and name the likely cause.
   if emptyLens && ~opts.dataOnly
      fprintf(2, 'check_clean_region: the length list is empty. Nothing was scored.\n');
      fprintf(2, 'If it came from [W.N], W is empty - run the locator first:\n');
      fprintf(2, '    W  = check_clean_region([], struct(''dataDir'', dataDir, ''dataOnly'', true));\n');
      fprintf(2, '    Rw = check_clean_region([W.N], struct(''dataDir'', dataDir));\n');
      error('check_clean_region:emptyLengths', 'empty length list');
   end
   if emptyLens, lens = 1200; end

   cfg = configure_simulation();
   if isempty(opts.methods), meths = cfg.allIntMethods; else, meths = opts.methods; end
   % cfg.dataPathPF does not exist. configure_simulation defines dataSavePath
   % and no PF path, so this line always threw and the catch always left the
   % tables empty - a load that never loaded, invisible because it was inside
   % a try. The reconstructed permutations were still checked against the
   % campaign's stored lengths, which is why the results held; the fix is so
   % that a method needing the tables is reported rather than dropped.
   tp = []; tf = [];
   [tdir, erF] = find_table_dir(char(cfg.dataSavePath), true);
   if erF == ""
      [tp, tf, erP] = PrimeFactorLoader(tdir);
      if erP ~= "", fprintf(2, 'PrimeFactorLoader: %s\n', char(erP)); tp = []; tf = []; end
   end

   % THE GEOMETRY MUST BE THE CAMPAIGN'S, NOT A PLAUSIBLE ONE.
   % ----------------------------------------------------------------------
   % run_single_trial shapes every interleaver through paramsInt.L and .K,
   % set from estimate_L_for_size(lenEncoded). A reconstruction that omits
   % them builds a different rectangle: at N = 120 this function first
   % returned an interleaved length of 132 where the campaign recorded 144,
   % so BE was 0.909 instead of 0.833 and every residual described a padding
   % shape the study never ran. The length is therefore taken from the
   % campaign's own tables when they are available, and a reconstruction that
   % does not reproduce it is reported as a mismatch rather than scored.
   trueLen = struct();
   if ~isempty(opts.dataDir)
      if exist(opts.dataDir, 'dir') ~= 7
         fprintf(2, 'dataDir does not exist: %s\n', opts.dataDir);
      end
      d = dir(fullfile(opts.dataDir, 'KPItableDetailed_*.mat'));
      fprintf('dataDir: %s\n  KPItableDetailed_*.mat files found: %d\n', opts.dataDir, numel(d));
      if isempty(d)
         alt = dir(fullfile(opts.dataDir, '*.mat'));
         fprintf(2, '  no KPI tables here. The folder holds %d .mat file(s)', numel(alt));
         if ~isempty(alt), fprintf(2, ', first is %s', alt(1).name); end
         fprintf(2, '\n  Give the folder that holds the sweep output.\n');
      end
      for k = 1:numel(d)
         S = load(fullfile(opts.dataDir, d(k).name));
         T = local_rows(S);
         if isempty(T)
            fprintf(2, '  %s: no usable row set (variables: %s)\n', ...
                    d(k).name, strjoin(fieldnames(S)', ', '));
            continue;
         end
         if ~all(isfield(T, {'method','encodedLen','interleavedLen'}))
            fprintf(2, '  %s: rows lack method/encodedLen/interleavedLen\n', d(k).name);
            continue;
         end
         mm = {T.method}; el = double([T.encodedLen]); il = double([T.interleavedLen]);
         for q = 1:numel(el)
            f = sprintf('%s_%d', regexprep(mm{q}, '[^A-Za-z0-9_]', '_'), el(q));
            trueLen.(f) = il(q);
         end
         fprintf('  %-46s %d rows\n', d(k).name, numel(el));
      end
      fprintf('geometry map: %d (method, length) pairs\n', numel(fieldnames(trueLen)));
   else
      fprintf(2, 'NOTE: no dataDir given, so the reconstructed padding shape is not verified\n');
   end

   % dataOnly answers a prior question: where does each method's worst
   % extension actually occur? Reconstructing permutations to find it invites
   % the geometry error this function already made once. The campaign recorded
   % (encodedLen, interleavedLen) on every row, so the answer is in the data
   % and needs no permutation at all.
   if opts.dataOnly
      R = local_worstFromData(trueLen);
      return;
   end

   fprintf('\n=== DOES C_NN CHARGE BACK WHAT FRAME EXTENSION SAVES? ===\n');
   if ischar(opts.B)
      fprintf('burst: the campaign''s injected count at each length, %d noise level(s)\n', ...
              numel(cfg.noiseLevels));
   else
      fprintf('burst B = %d (fixed)\n', opts.B);
   end
   fprintf('%d length(s), injection confined to the first N positions\n', numel(lens));

   best = struct(); mism = struct();   % per method: smallest BE, and any geometry mismatch
   lens = unique(lens(:)');
   nL = numel(lens); li = 0;
   for N = lens(:)'
      li = li + 1;
      if nL > 1
         fprintf('  [%3d/%3d] N = %-5d\r', li, nL, N);   % never look hung
      end
      if ischar(opts.B)
         lv = cfg.noiseLevels(:)';
         Bs = unique(max(1, round(lv * N)));
      else
         Bs = opts.B;
      end
      for i = 1:numel(meths)
         m = meths{i};
         p = local_perm(m, N, tp, tf, cfg);
         if isempty(p), continue; end
         L = numel(p);
         if L < N, continue; end

         f0 = sprintf('%s_%d', regexprep(m, '[^A-Za-z0-9_]', '_'), N);
         if isfield(trueLen, f0) && trueLen.(f0) ~= L
            mism.(regexprep(m,'[^A-Za-z0-9_]','_')) = ...
               sprintf('%s at N=%d: rebuilt %d, campaign %d', m, N, L, trueLen.(f0));
            continue;                 % do not score a shape the study never ran
         end
         BE = N / L;

         % Exact mean over every admissible burst start, by cumulative sum,
         % for every burst length the campaign actually injects at this N.
         isMsg = double(p >= 1 & p <= N);
         c = [0, cumsum(isMsg(:)')];
         resid = 0; mh = NaN; ratio = NaN; Bused = NaN; devSym = 0; got = false;
         for B = Bs
            nS = N - B + 1;
            if nS < 1
               fprintf(2, '  burst %d does not fit in N = %d - skipped\n', B, N);
               continue;
            end
            sIdx = 1:nS;
            hh = mean(c(sIdx + B) - c(sIdx));
            rr = hh / B;                 % reference count is exactly B
            dd = rr / BE - 1;
            % Absolute deviation, in symbols. A ratio hides the frame size:
            % at N = 60 the burst is twelve symbols, so one symbol IS eight
            % per cent, and a residual of that size is the resolution floor
            % rather than a systematic advantage.
            ds = hh - B * BE;
            if ~got || abs(ds) > abs(devSym)
               resid = dd; mh = hh; ratio = rr; Bused = B; devSym = ds; got = true;
            end
         end
         if ~got, continue; end

         f = regexprep(m, '[^A-Za-z0-9_]', '_');
         if ~isfield(best, f) || BE < best.(f).BE
            best.(f) = struct('method', m, 'N', N, 'L', L, 'BE', BE, 'B', Bused, ...
                              'msgHit', mh, 'ratio', ratio, 'resid', resid, 'devSym', devSym);
         end
      end
   end
   if nL > 1, fprintf('%s\r', repmat(' ', 1, 34)); end

   mf = fieldnames(mism);
   if ~isempty(mf)
      fprintf(2, '\nGEOMETRY MISMATCH - these were not scored:\n');
      for i = 1:numel(mf), fprintf(2, '  %s\n', mism.(mf{i})); end
   end

   fn = fieldnames(best);
   R = struct('method', {}, 'N', {}, 'L', {}, 'BE', {}, 'B', {}, 'msgHit', {}, ...
              'ratio', {}, 'resid', {}, 'devSym', {});
   for i = 1:numel(fn), R(end+1) = best.(fn{i}); end %#ok<AGROW>
   [~, o] = sort([R.BE]); R = R(o);

   fprintf('\n%-14s %8s %6s %7s %5s %9s %9s %8s %9s  %s\n', 'method', 'worst BE', 'at N', ...
           'intLen', 'B', 'msg hit', 'expected', 'dev(sym)', 'dev(%)', 'reading');
   fprintf('%s\n', repmat('-', 1, 116));
   worst = 0; nExt = 0; worstSym = 0;
   for i = 1:numel(R)
      if abs(R(i).BE - 1) < 1e-12
         if ~opts.quiet
            fprintf('%-14s %8.4f %6d %7d %5d %9.3f %9.3f %8.3f %8.1f%%  no extension at any length tested\n', ...
                    R(i).method, R(i).BE, R(i).N, R(i).L, R(i).B, R(i).msgHit, ...
                    R(i).B*R(i).BE, R(i).devSym, 100*R(i).resid);
         end
         continue;
      end
      nExt = nExt + 1; worst = max(worst, abs(R(i).resid));
      worstSym = max(worstSym, abs(R(i).devSym));
      % No hard "exact" verdict. The padding count and the burst are integers,
      % so the residual cannot vanish and a threshold at 1 % turned spiral's
      % exact -0.0100 into a pass by a rounding error in the comparison. The
      % magnitude is printed and the summary line carries the claim.
      if abs(R(i).devSym) < 1
         note = 'agreement to under one symbol';
      elseif R(i).devSym < 0
         note = sprintf('%.2f symbols of credit not charged back', -R(i).devSym);
      else
         note = sprintf('%.2f symbols charged back beyond what was saved', R(i).devSym);
      end
      fprintf('%-14s %8.4f %6d %7d %5d %9.3f %9.3f %8.3f %8.1f%%  %s\n', ...
              R(i).method, R(i).BE, R(i).N, R(i).L, R(i).B, R(i).msgHit, ...
              R(i).B*R(i).BE, R(i).devSym, 100*R(i).resid, note);
   end
   fprintf('%s\n', repmat('-', 1, 116));

   if nExt == 0
      fprintf('No method extends the frame at the lengths tested.\n\n');
   else
      if isempty(fieldnames(trueLen))
         fprintf(2, ['UNVERIFIED GEOMETRY: the map is empty, so the padding shapes below were\n' ...
                     'reconstructed and never checked against the campaign. Do not quote them.\n']);
      end
      fprintf(['%d extending method(s) at their worst bandwidth efficiency.\n' ...
               '  largest disagreement: %.3f symbols  (%.1f %% of the credit)\n' ...
               'The per cent figure is inflated by the frame size at which the worst\n' ...
               'extension occurs - the shortest length in the grid, where the injected\n' ...
               'burst is a dozen symbols and one symbol is already eight per cent. The\n' ...
               'absolute figure is the one that transfers.\n\n'], nExt, worstSym, 100*worst);
   end
end

% =========================================================================
function R = local_worstFromData(trueLen)
% Smallest BE per method, read from the stored lengths alone.
   fn = fieldnames(trueLen);
   acc = struct();
   for i = 1:numel(fn)
      k = fn{i};
      u = find(k == '_', 1, 'last');
      m = k(1:u-1); N = str2double(k(u+1:end));
      L = trueLen.(k);
      BE = N / L;
      if ~isfield(acc, m) || BE < acc.(m).BE
         acc.(m) = struct('method', m, 'N', N, 'L', L, 'BE', BE);
      end
   end
   mm = fieldnames(acc);
   R = struct('method', {}, 'N', {}, 'L', {}, 'BE', {});
   for i = 1:numel(mm), R(end+1) = acc.(mm{i}); end %#ok<AGROW>
   [~, o] = sort([R.BE]); R = R(o);

   fprintf('\n=== WORST FRAME EXTENSION PER METHOD, FROM THE STORED LENGTHS ===\n');
   fprintf('%-16s %9s %8s %9s\n', 'method', 'worst BE', 'at N', 'intLen');
   fprintf('%s\n', repmat('-', 1, 46));
   for i = 1:numel(R)
      if abs(R(i).BE - 1) < 1e-12, continue; end
      fprintf('%-16s %9.4f %8d %9d\n', R(i).method, R(i).BE, R(i).N, R(i).L);
   end
   fprintf('%s\n', repmat('-', 1, 46));
   fprintf(['These are the lengths at which the clean-tail check has to be run.\n' ...
            'Pass them as the length list; a sweep that misses them tests the\n' ...
            'typical extension and reports it as the worst.\n\n']);
end

function rows = local_rows(S)
% A KPI file may hold a struct array, a table, or a scalar struct of column
% arrays. The first version accepted only the struct array, found nothing in a
% file of either other shape, and reported an empty map as if the folder were
% empty. Accept all three and say which was found.
   rows = [];
   fn = fieldnames(S);
   hasTable = exist('istable', 'builtin') || exist('istable', 'file');
   for i = 1:numel(fn)
      v = S.(fn{i});
      if hasTable && istable(v), rows = table2struct(v); return; end
      if isstruct(v) && numel(v) > 1, rows = v; return; end
      if isstruct(v) && numel(v) == 1 && isfield(v, 'method') && numel(v.method) > 1
         % columnar: one struct whose fields are arrays
         f2 = fieldnames(v); n = numel(v.encodedLen);
         blank = cell(1, numel(f2));
         rows = repmat(cell2struct(blank, f2, 2), 1, n);
         for q = 1:numel(f2)
            col = v.(f2{q});
            if numel(col) ~= n, continue; end
            for r = 1:n
               if iscell(col), rows(r).(f2{q}) = col{r}; else, rows(r).(f2{q}) = col(r); end
            end
         end
         return;
      end
   end
end

function p = local_perm(m, N, tp, tf, cfg)
   p = [];
   try
      % Mirror run_single_trial: L from the encoded length, K from the message
      % length that produced it. Without these the rectangle is a different one.
      L = estimate_L_for_size(N);
      kOverN = 1;
      if isfield(cfg, 'FECk') && isfield(cfg, 'FECn'), kOverN = cfg.FECk / cfg.FECn; end
      K = ceil((N * kOverN) / max(L, 1));
      paramsInt = struct('permutationSeed', 1, 'minMultiplier', 2, ...
                         'pairStrategy', 'balanced', 'swapStrategy', 'parity', ...
                         'extensionPercentage', 0.5, 'L', L, 'K', K);
      [~, p] = interleaver_generic_pc(1:N, m, 0, 0.5, [], 1, tp, tf, paramsInt);
   catch
      p = [];
   end
end
