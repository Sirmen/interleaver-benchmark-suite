function R = check_le_uecc(dataDir)
%CHECK_LE_UECC  Is laplacianEnergy in correlation_data what it claims to be?
%
%   R = check_le_uecc('<resultsDir>')
%
% WHY THIS EXISTS
% ===========================================================================
% Two measurements of ours disagree and both cannot be right.
%
%   1. The cross-correlation matrix returns rho(laplacianEnergy, U_ECC) = 1.00
%      at cell level within length, averaged over all eight conditions. A rank
%      correlation of exactly one between an a priori spectral property of the
%      permutation and an a posteriori utilization statistic is not credible:
%      U_ECC was proved invariant to the permutation, LE is a function of it.
%
%   2. With the five frame-extending methods removed, BOTH columns go
%      constant. U_ECC doing so is expected and already proved. LE doing so is
%      impossible if the column holds a spectral function of pi, because
%      sixteen different permutations cannot share one Laplacian energy.
%
%   3. Yet the scorecard reports different length-mean behaviour for the two,
%      "between" of 0.592 for LE against 0.098 for U_ECC, which rules out the
%      simplest explanation that the two fields hold identical data.
%
% Three observations, no two of which sit together. This function settles it
% by looking at the stored columns directly rather than at statistics of them.
%
% WHAT IT REPORTS, per condition file
%   identical      max |LE - U_ECC| over every row, and whether it is zero
%   distinct       how many distinct values each column takes, overall
%   perLength      distinct values within one frame length, where a spectral
%                  metric must still separate methods and U_ECC must not
%   nonPadding     distinct values within one length across the methods that
%                  do not extend the frame - the case that produced the
%                  constant column
%   corrWithLen    Spearman of each column against N, since a quantity that
%                  is a function of the frame length alone will show it here
%
% A metric that cannot separate methods at a fixed length is not measuring the
% permutation, whatever its name in the file.

   if nargin < 1 || isempty(dataDir)
      c = configure_simulation(); dataDir = char(c.dataSavePath);
   end
   PAD = {'helical','matrix','spiral','helicalScan','prime'};
   OUT = {'freqDeterm','freqRandom'};

   d = dir(fullfile(dataDir, 'correlation_data_*.mat'));
   if isempty(d), error('check_le_uecc: no correlation_data_*.mat in %s', dataDir); end

   fprintf('\n=== IS laplacianEnergy THE LAPLACIAN ENERGY? ===\n%s\n\n', dataDir);
   fprintf('%-30s %10s %8s %8s %8s %8s %8s\n', 'file', 'max|LE-U|', ...
           'nLE', 'nU', 'LE/len', 'U/len', 'LEvsN');
   fprintf('%s\n', repmat('-', 1, 88));

   R = struct('file', {}, 'maxDiff', {}, 'nLE', {}, 'nU', {}, ...
              'leePerLen', {}, 'uPerLen', {}, 'leeNonPad', {}, 'rhoLElen', {});

   for k = 1:numel(d)
      S = load(fullfile(dataDir, d(k).name));
      fn = fieldnames(S); D = [];
      for i = 1:numel(fn), if isstruct(S.(fn{i})), D = S.(fn{i}); break; end, end
      if isempty(D) || ~isfield(D, 'laplacianEnergy') || ~isfield(D, 'U_ECC')
         fprintf('%-30s   (a field is absent)\n', d(k).name); continue;
      end
      LE = double(D.laplacianEnergy(:));
      UE = double(D.U_ECC(:));
      len = double(D.encodedLen(:));
      if isfield(D, 'methodNames') && isfield(D, 'methodID')
         nl = cellstr(D.methodNames(:)); meth = nl(double(D.methodID(:)));
      else
         meth = repmat({'?'}, size(len));
      end

      ok = isfinite(LE) & isfinite(UE);
      md = max(abs(LE(ok) - UE(ok)));
      nLE = numel(unique(round(LE(ok) * 1e12) / 1e12));
      nU  = numel(unique(round(UE(ok) * 1e12) / 1e12));

      % Within ONE length, taken as the most populated one, so the count is
      % not diluted by lengths where few methods ran.
      uL = unique(len); cnt = zeros(size(uL));
      for i = 1:numel(uL), cnt(i) = sum(len == uL(i)); end
      [~, bi] = max(cnt); Lpick = uL(bi);
      at = (len == Lpick);
      nLEl = numel(unique(round(LE(at) * 1e12) / 1e12));
      nUl  = numel(unique(round(UE(at) * 1e12) / 1e12));

      atNP = at & ~ismember(meth, [PAD, OUT]);
      nLEnp = numel(unique(round(LE(atNP) * 1e12) / 1e12));

      rho = local_spear2(LE(ok), len(ok));

      fprintf('%-30s %10.3g %8d %8d %8d %8d %8.3f\n', ...
              local_tag(d(k).name), md, nLE, nU, nLEl, nUl, rho);

      R(end+1) = struct('file', d(k).name, 'maxDiff', md, 'nLE', nLE, 'nU', nU, ...
                        'leePerLen', nLEl, 'uPerLen', nUl, 'leeNonPad', nLEnp, ...
                        'rhoLElen', rho); %#ok<AGROW>
   end

   fprintf('%s\n', repmat('-', 1, 88));
   if isempty(R), return; end
   fprintf('at the most populated length, across the methods that do NOT extend\n');
   fprintf('the frame, laplacianEnergy takes %s distinct value(s).\n\n', ...
           mat2str(unique([R.leeNonPad])));
   if all([R.maxDiff] == 0)
      fprintf(2, ['VERDICT: the two columns are IDENTICAL. laplacianEnergy in\n' ...
                  'correlation_data does not hold a Laplacian energy, and every\n' ...
                  'number reported for LE from this source is a number about\n' ...
                  'U_ECC. Recompute LE from the permutations before quoting it.\n\n']);
   elseif all([R.leeNonPad] <= 1)
      fprintf(2, ['VERDICT: laplacianEnergy is CONSTANT across methods at a fixed\n' ...
                  'length. Whatever it holds, it cannot separate permutations, so\n' ...
                  'it cannot be the spectral quantity the metric is defined as.\n\n']);
   elseif all([R.leePerLen] > 2)
      fprintf(['VERDICT: laplacianEnergy separates methods at a fixed length, so\n' ...
               'the column is plausible and the correlation of 1.00 with U_ECC is\n' ...
               'a tie artefact of U_ECC taking few distinct values. Report it as\n' ...
               'such and do not quote the pair.\n\n']);
   else
      fprintf(['VERDICT: mixed across conditions - read the per-file columns above\n' ...
               'before concluding anything.\n\n']);
   end
end

% =========================================================================
function r = local_spear2(a, b)
   n = numel(a); if n < 3, r = NaN; return; end
   ra = local_tr(a); rb = local_tr(b);
   ra = ra - mean(ra); rb = rb - mean(rb);
   da = sqrt(sum(ra.^2)); db = sqrt(sum(rb.^2));
   if da == 0 || db == 0, r = NaN; return; end
   r = sum(ra .* rb) / (da * db);
end

function r = local_tr(v)
   [~, i] = sort(v); r = zeros(size(v)); r(i) = 1:numel(v);
   [u, ~, g] = unique(v);
   for k = 1:numel(u)
      at = (g == k);
      if sum(at) > 1, r(at) = mean(r(at)); end
   end
end

function t = local_tag(n)
   t = regexprep(n, '^correlation_data_|\.mat$', '');
end
