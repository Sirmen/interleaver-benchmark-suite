function out = check_uecc_invariance(dataPath)
%CHECK_UECC_INVARIANCE  Can U_ECC vary with the permutation at all?
%
%   out = check_uecc_invariance('<resultsDir>')
%
% WHY VERSION 1 OF THIS TEST WAS WRONG
% ---------------------------------------------------------------------------
% The first version compared U_ECC across every row of a (length, noise)
% block. A block holds 35 independent trials, so that comparison mixed
% variation across REALIZATIONS into a question about METHODS. Under fixed
% bursts the injected error count is the same in every trial and the mixture
% is harmless, so the test returned exactly zero and looked decisive. Under
% Gilbert-Elliott the burst lengths are geometrically distributed, the error
% count moves from trial to trial, U_ECC moves with it, and the test reported
% a spread of 0.4 as though the metric depended on the permutation. It does
% not follow, and the printed verdict was wrong.
%
% The give-away was in the output: "666 methods each" in a study with 23
% methods. A block was being counted as its rows rather than its methods.
%
% WHAT THIS VERSION DOES INSTEAD
% ---------------------------------------------------------------------------
% The design is paired: within one trial every method sees the identical burst
% mask. So the comparison that isolates the permutation is WITHIN A TRIAL, and
% the paired layout makes it available - each method's rows appear in the same
% trial order, which is the same property paired_method_analysis relies on and
% verifies against encodedLen.
%
%   T1  Reshape U_ECC to trials x methods. For each trial, take the spread
%       across the non-padding methods. If U_ECC cannot see the permutation,
%       that spread is zero in every trial of every regime, Gilbert-Elliott
%       included. This is the test version 1 should have run.
%
%   T2  Count the distinct values U_ECC takes across methods within a trial.
%       The prediction is two: one for the methods that pad and one for the
%       methods that do not.
%
%   T3  If T1 holds, ask what the reported correlation with RES is made of.
%       Compare the within-length rank correlation of U_ECC against RES with
%       the same correlation computed after removing the padding split, by
%       correlating within the non-padding group alone. If the association is
%       the binary contrast, it collapses.
%
% T1 is the claim. T2 and T3 are about the mechanism and are reported as
% evidence, not as conclusions.

   if nargin < 1 || isempty(dataPath)
      c = configure_simulation(); dataPath = char(c.dataSavePath);
   end
   d = dir(fullfile(dataPath, 'KPItableDetailed_*.mat'));
   if isempty(d), error('check_uecc_invariance: no KPItableDetailed_*.mat in %s', dataPath); end

   fprintf('\n=== U_ECC: CAN IT SEE THE PERMUTATION? ===\n%s\n', dataPath);
   fprintf('paired comparison, within trial\n\n');
   out = struct('file', {}, 'maxSpread', {}, 'nDistinct', {}, 'rhoAll', {}, 'rhoNoPad', {});

   for k = 1:numel(d)
      f = fullfile(dataPath, d(k).name);
      T = local_rows(load(f));
      if ~all(ismember({'method','encodedLen','interleavedLen'}, fieldnames(T)))
         fprintf('  %s: missing columns - skipped\n', d(k).name); continue;
      end
      u = local_uecc(T, dataPath, d(k).name);
      if isempty(u), fprintf('  %s: no U_ECC column - skipped\n', d(k).name); continue; end

      meth = {T.method}.';
      elen = double([T.encodedLen]).';
      ilen = double([T.interleavedLen]).';
      res  = local_col(T, 'RES');
      BE   = elen ./ ilen;

      uM = unique(meth);
      cnt = cellfun(@(m) sum(strcmp(meth, m)), uM);
      if numel(unique(cnt)) ~= 1
         fprintf(2, '  %s: methods have %d..%d rows - not paired, SKIPPED\n', ...
                 d(k).name, min(cnt), max(cnt));
         continue;
      end
      nT = cnt(1);

      % trials x methods, each column a method in its own row order
      U = zeros(nT, numel(uM)); B = zeros(1, numel(uM)); Lm = zeros(nT, numel(uM));
      for j = 1:numel(uM)
         at = strcmp(meth, uM{j});
         U(:, j) = u(at); Lm(:, j) = elen(at);
         % A method pads if it extends the frame at ANY length. Taking the BE of
         % the first row classifies a method by whichever length happens to sit
         % there: prime and helicalScan have BE = 1 at most lengths and 0.9524
         % at their worst, so a single-row test files them as non-padding and
         % the T1 and T3 restrictions are then computed on a set that still
         % contains the very contrast they exist to remove.
         b = BE(at); B(j) = min(b);
      end
      if max(max(abs(Lm - Lm(:,1)))) > 0
         fprintf(2, '  %s: the length column is not aligned across methods - SKIPPED\n', d(k).name);
         continue;
      end

      noPad = abs(B - 1) < 1e-12;   % B is now the minimum over lengths

      % ---- T1 ------------------------------------------------------------
      sp = max(U(:, noPad), [], 2) - min(U(:, noPad), [], 2);
      lev = mean(abs(U(:, noPad)), 2);
      rel = max(sp ./ max(lev, eps));

      % ---- T2 ------------------------------------------------------------
      nd = zeros(nT, 1);
      for i = 1:nT, nd(i) = numel(uniquetol(U(i, :), 1e-12)); end

      % ---- T3 ------------------------------------------------------------
      uL = unique(elen); rA = nan(numel(uL),1); rN = nan(numel(uL),1);
      if ~isempty(res)
         R = zeros(nT, numel(uM));
         for j = 1:numel(uM), R(:, j) = res(strcmp(meth, uM{j})); end
         for i = 1:numel(uL)
            at = Lm(:,1) == uL(i);
            uu = mean(U(at, :), 1).'; rr = mean(R(at, :), 1).';
            if numel(unique(uu)) > 1, rA(i) = corr(uu, rr, 'type', 'Spearman'); end
            uu2 = uu(noPad); rr2 = rr(noPad);
            if numel(unique(uu2)) > 1, rN(i) = corr(uu2, rr2, 'type', 'Spearman'); end
         end
      end

      fprintf('  %s\n', d(k).name);
      fprintf('     %d methods (%d without padding), %d trials each\n', numel(uM), sum(noPad), nT);
      fprintf('     T1  max relative spread of U_ECC across non-padding methods,\n');
      fprintf('         WITHIN a trial: %.3e\n', rel);
      if rel < 1e-9
         fprintf('         => U_ECC is identical for %d different permutations. It cannot\n', sum(noPad));
         fprintf('            see the permutation, in this regime, under the paired design.\n');
      else
         fprintf(2, '         => NOT invariant: U_ECC does vary across methods within a trial.\n');
         fprintf(2, '            The argument in Section VIII-G is wrong and must be withdrawn.\n');
      end
      fprintf('     T2  distinct U_ECC values across methods within a trial: %d..%d (predicted 2)\n', ...
              min(nd), max(nd));
      if ~isempty(res) && any(isfinite(rA))
         fprintf('     T3  within-length rho(U_ECC, RES) over all methods : %+.3f\n', median(rA,'omitnan'));
         if any(isfinite(rN))
            fprintf('         same, restricted to the non-padding methods    : %+.3f\n', median(rN,'omitnan'));
         else
            fprintf('         restricted to non-padding methods: undefined - U_ECC is constant\n');
            fprintf('         there, which is itself the answer: the association is the split.\n');
         end
      end
      fprintf('\n');
      out(end+1) = struct('file', d(k).name, 'maxSpread', rel, ...
                          'nDistinct', [min(nd) max(nd)], ...
                          'rhoAll', median(rA,'omitnan'), 'rhoNoPad', median(rN,'omitnan')); %#ok<AGROW>
   end
   fprintf('=== END ===\n\n');
end

% =========================================================================
function v = local_col(T, nm)
   v = [];
   if isfield(T, nm), v = double([T.(nm)]).'; end
end

function u = local_uecc(T, dataPath, kpiName)
   u = [];
   for nm = {'U_ECC', 'after_eccUtilization', 'eccUtilization'}
      if isfield(T, nm{1}), u = double([T.(nm{1})]).'; return; end
   end
   cf = fullfile(dataPath, strrep(kpiName, 'KPItableDetailed_', 'correlation_data_'));
   if ~exist(cf, 'file'), return; end
   S = load(cf); fn = fieldnames(S);
   for i = 1:numel(fn)
      C = S.(fn{i});
      if ~isstruct(C) || ~isscalar(C), continue; end
      for nm = {'U_ECC', 'after_eccUtilization', 'eccUtilization'}
         if isfield(C, nm{1})
            v = double(C.(nm{1})(:));
            if numel(v) == numel(T), u = v; return; end
         end
      end
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
