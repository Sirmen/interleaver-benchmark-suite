function ok = health_selftest(workDir)
%HEALTH_SELFTEST  Prove that every blocking check in health_check can fail.
%
%   ok = health_selftest            % uses a temporary folder
%   ok = health_selftest(dir)
%
% WHY THIS EXISTS
% ===========================================================================
% The package this replaces reported "12/13, GOOD, reliable" on essentially
% any input, because four of its checks could not fail and one could not
% pass. Nobody noticed, because a health check is only ever read when it
% agrees with what the reader already believes. The defence against that is
% not care. It is a test that damages the data on purpose, once per check,
% and asserts that the check named for that damage is the one that objects.
%
% A blocking check with no entry in this file is not trustworthy and should
% be treated as decoration until it has one.
%
% WHAT IT DOES
%   1. builds a small but structurally faithful campaign: 8 conditions,
%      methods x lengths x noise bins x runs, paired, with CR/BE/RES computed
%      by the same formula calcKPIs_engine uses;
%   2. runs health_check on it and requires the verdict QUOTABLE;
%   3. for each blocking check, corrupts the data in the one way that check
%      exists to detect, re-runs, and requires that check to FAIL;
%   4. also requires that the corruption does NOT trip unrelated checks more
%      than necessary, so that a failure points at its cause.
%
% Output: ok is true only if every case behaved as required.

   if nargin < 1 || isempty(workDir), workDir = fullfile(tempdir, 'health_selftest'); end
   fprintf('\n=== HEALTH CHECK SELF-TEST ===\n%s\n', workDir);

   cases = { ...
     'clean',       'no corruption',                                    '',              true; ...
     'B0_conditions','one condition file deleted',                      'B0_conditions', false; ...
     'B1_occupancy','one cell short of its replicates',                 'B1_occupancy',  false; ...
     'B2_pairing',  'one method''s rows shuffled out of trial order',   'B2_pairing',    false; ...
     'B3_resolution','all lengths collapsed to four distinct values',   'B3_resolution', false; ...
     'B4_integrity','1 % of RES set to NaN',                            'B4_integrity',  false; ...
     'B5_kpi',      'RES rescaled as if standardized over another field','B5_kpi',       false; ...
   };

   ok = true;
   for c = 1:size(cases, 1)
      tag = cases{c,1}; what = cases{c,2}; want = cases{c,3}; wantPass = cases{c,4};
      dd = fullfile(workDir, tag);
      local_build(dd);
      local_corrupt(dd, tag);

      evalc('H = health_check(dd, struct(''expectConditions'', 8, ''runsPerCell'', 10, ''verbose'', false));');

      if wantPass
         good = strcmp(H.verdict, 'QUOTABLE');
         fprintf('  %-15s %-46s verdict %-22s %s\n', tag, what, H.verdict, local_mark(good));
         if ~good
            fprintf(2, '      the UNCORRUPTED campaign did not pass, so every case below is\n');
            fprintf(2, '      measured against a baseline that is already objecting.\n');
            if ~isempty(H.failures), fprintf(2, '      blocking: %s\n', strjoin(H.failures, '; ')); end
            if ~isempty(H.cautions), fprintf(2, '      advisory: %s\n', strjoin(H.cautions, '; ')); end
         end
      else
         hit  = ~H.blocking.(want).pass;
         nOther = 0; bf = fieldnames(H.blocking);
         for k = 1:numel(bf)
            if ~strcmp(bf{k}, want) && ~H.blocking.(bf{k}).pass, nOther = nOther + 1; end
         end
         good = hit;
         fprintf('  %-15s %-46s %s caught=%d, collateral=%d %s\n', ...
                 tag, what, want, hit, nOther, local_mark(good));
         if ~hit
            fprintf(2, '      %s DID NOT FAIL on data corrupted specifically for it.\n', want);
            fprintf(2, '      That check cannot be trusted and must not be reported.\n');
         end
      end
      ok = ok && good;
   end

   fprintf('\n  %s\n\n', local_verdict(ok));
end

% =========================================================================
function local_build(dd)
% A faithful miniature: paired across methods, 8 conditions, KPIs by the
% engine's own formula so that the reconstruction check has something true
% to reproduce.
   if exist(dd, 'dir'), rmdir(dd, 's'); end
   mkdir(dd);
   % Sized to clear every advisory floor and no larger: 22 distinct lengths
   % (bootstrap-block floor is 20) and 10 replicates per cell (the quartile
   % floor). A self-test nobody waits for is a self-test nobody runs.
   methods = {'S','block','drp','goldenRP'};
   lens    = 60 * (2:23);           % 22 distinct lengths
   noiseLevels = [0.02 0.06 0.10];
   runs = 10;
   regimes = {'single','multi','ge1p00','ge0p70'};
   grids   = {'common','standards'};

   for r = 1:numel(regimes)
      for g = 1:numel(grids)
         % Preallocated, not grown: appending to a struct array reallocates
         % the whole array every time, so building it element by element is
         % quadratic and this fixture stalls at a few thousand rows.
         nRow = numel(lens) * numel(noiseLevels) * runs * numel(methods);
         blank = struct('method', '', 'noiseBin', 0, 'encodedLen', 0, ...
                        'interleavedLen', 0, 'noiseActual', 0, ...
                        'decErrRate_woInt', 0, 'decodeErrRate', 0);
         rows = repmat(blank, 1, nRow); q = 0;
         for L = lens
            for nb = 1:numel(noiseLevels)
               for t = 1:runs
                  woInt = 0.30 + 0.05*rand;
                  for i = 1:numel(methods)
                     m = methods{i};
                     if any(strcmp(m, {'block','random'})), iLen = round(L*1.012); else, iLen = L; end
                     q = q + 1;
                     rows(q).method           = m;
                     rows(q).noiseBin         = nb;
                     rows(q).encodedLen       = L;
                     rows(q).interleavedLen   = iLen;
                     rows(q).noiseActual      = round(noiseLevels(nb)*L) / iLen;
                     rows(q).decErrRate_woInt = woInt;
                     rows(q).decodeErrRate    = woInt * (0.10 + 0.40*rand);
                  end
               end
            end
         end
         rows = local_kpi(rows, noiseLevels);
         KPItableDetailed = rows; %#ok<NASGU>
         % sizeList is what B3 compares the realized lengths against, so the
         % fixture must carry it or the collapse case cannot be detected.
         config = struct('noiseLevels', noiseLevels, 'testRunsMax', runs, ...
                         'sizeList', lens); %#ok<NASGU>
         base = sprintf('_%s_%s_260904_1.mat', regimes{r}, grids{g});
         save(fullfile(dd, ['KPItableDetailed' base]), 'KPItableDetailed');
         save(fullfile(dd, ['config' base]), 'config');
      end
   end
end

function rows = local_kpi(rows, noiseLevels)
   BE = [rows.encodedLen] ./ [rows.interleavedLen];
   tgt = noiseLevels([rows.noiseBin]);
   CRraw = max(0, 1 - ([rows.decodeErrRate] ./ ([rows.decErrRate_woInt] + eps)));
   CR = CRraw .* ([rows.noiseActual] ./ (tgt + eps));
   CRz = (CR - mean(CR)) / (std(CR) + eps);
   BEz = (BE - mean(BE)) / (std(BE) + eps);
   RES = 0.5*CRz + 0.5*BEz;
   for i = 1:numel(rows)
      rows(i).CR = CR(i); rows(i).BE = BE(i);
      rows(i).CR_z = CRz(i); rows(i).BE_z = BEz(i);
      rows(i).effectiveness = CR(i)*BE(i); rows(i).RES = RES(i);
   end
end

% =========================================================================
function local_corrupt(dd, tag)
   d = dir(fullfile(dd, 'KPItableDetailed_*.mat'));
   f = fullfile(dd, d(1).name);

   switch tag
      case 'clean'
         return;

      case 'B0_conditions'
         % A condition silently missing. The sign test counts conditions, so
         % this changes its p-value directly and must never be silent.
         delete(f);

      case 'B1_occupancy'
         S = load(f); R = S.KPItableDetailed;
         R(1) = [];                       % one cell now one replicate short
         S.KPItableDetailed = R; save(f, '-struct', 'S');

      case 'B2_pairing'
         % One method's rows rotated: totals unchanged, every count still
         % equal, but row i is no longer trial i for that method. This is
         % the failure a count-based check cannot see.
         S = load(f); R = S.KPItableDetailed;
         at = find(strcmp({R.method}, 'drp'));
         R(at) = R(at([2:end 1]));
         S.KPItableDetailed = R; save(f, '-struct', 'S');

      case 'B3_resolution'
         % Distinct lengths collapse, as an arithmetic grid does under a
         % block code. Counts stay perfect; the bootstrap loses its domain.
         S = load(f); R = S.KPItableDetailed;
         L = [R.encodedLen]; uL = unique(L); map = uL(mod(0:numel(uL)-1, 4) + 1);
         for i = 1:numel(R), R(i).encodedLen = map(uL == R(i).encodedLen); end
         S.KPItableDetailed = R; save(f, '-struct', 'S');

      case 'B4_integrity'
         S = load(f); R = S.KPItableDetailed;
         k = round(numel(R)/100);
         for i = 1:k, R(i).RES = NaN; end
         S.KPItableDetailed = R; save(f, '-struct', 'S');

      case 'B5_kpi'
         % RES rescaled, as it would be if the file had been standardized
         % over a different set of methods. Nothing else about the file
         % changes, and no count-based or completeness check can see it.
         S = load(f); R = S.KPItableDetailed;
         for i = 1:numel(R), R(i).RES = R(i).RES * 1.05 + 0.01; end
         S.KPItableDetailed = R; save(f, '-struct', 'S');
   end
end

function s = local_mark(ok)
   if ok, s = 'OK'; else, s = '<<< PROBLEM'; end
end

function s = local_verdict(ok)
   if ok
      s = 'every blocking check failed on data corrupted for it. The instrument moves.';
   else
      s = 'AT LEAST ONE CHECK DID NOT RESPOND. Do not report its result.';
   end
end
