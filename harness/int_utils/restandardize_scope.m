function report = restandardize_scope(dataDir, opts)
% RESTANDARDIZE_SCOPE  Put CR_z, BE_z and RES on the in-scope standardization
%                      set the manuscript declares, in the small campaign files.
%
%   report = restandardize_scope('<resultsDir>')                  % dry run
%   report = restandardize_scope('<resultsDir>', struct('apply', true))
%
% calcKPIs_engine standardizes CR and BE over every row of a sweep. The paper
% standardizes on the in-scope methods only and scores the out-of-scope ones
% against that scale (Sections III-I and X-H). rebuild_kpis does this, but it
% also rewrites and backs up the results_*.mat files, which are 1.4-11 GB each
% in this campaign; that needs about as much free disk again as the campaign.
% This function touches only what the analysis reads:
%
%   KPItableDetailed_*.mat   CR_z, BE_z, RES rewritten
%   correlation_data_*.mat   CR_z, BE_z, RES rewritten
%
% CR, BE and effectiveness do not depend on the standardization set and are
% checked to be unchanged. results_*.mat, anovaResults_* and crossCorrResults_*
% keep the all-rows standardization of the simulation run; a note file
% KPI_SCOPE.txt says so. The paper's numbers are computed from the two files
% above only.
%
% Checks before anything is written, per sweep:
%   1. self-test: the KPI formula with every row as reference reproduces the
%      stored CR and RES to 1e-9 (the formula is rebuild_kpis's local_kpi);
%   2. correlation_data row i is KPI row i: encodedLen and noiseActual equal,
%      stored RES equal to 1e-9;
%   3. CR, BE, effectiveness unchanged by the new reference set.
% Originals are copied to <dataDir>/backup_scope once and never overwritten.
%
% R. Tanju Sirmen study.

   if nargin < 1 || isempty(dataDir), dataDir = pwd; end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'apply'),      opts.apply = false; end
   if ~isfield(opts, 'outOfScope'), opts.outOfScope = {'freqDeterm', 'freqRandom'}; end
   if ~isfield(opts, 'weights'),    opts.weights = [0.5 0.5]; end
   if ~isfield(opts, 'backupDir'),  opts.backupDir = fullfile(dataDir, 'backup_scope'); end
   w = opts.weights(:).';

   d = dir(fullfile(dataDir, 'KPItableDetailed_*.mat'));
   if isempty(d), error('restandardize_scope: no KPItableDetailed_*.mat in %s', dataDir); end
   fprintf('\n=== RESTANDARDIZE ON THE IN-SCOPE SET (%s) ===\n', local_ifelse(opts.apply, 'APPLY', 'dry run'));
   fprintf('out of scope (scored, not standardized on): %s\n', strjoin(opts.outOfScope, ', '));

   report = struct('sweep', {}, 'ok', {}, 'selfTest', {}, 'maxShift', {}, 'moves', {}, 'note', {});
   for i = 1:numel(d)
      tag = regexprep(d(i).name, '^KPItableDetailed_|\.mat$', '');
      kf  = fullfile(dataDir, d(i).name);
      cf  = fullfile(dataDir, ['correlation_data_' tag '.mat']);
      gf  = fullfile(dataDir, ['config_' tag '.mat']);
      if exist(cf, 'file') ~= 2 || exist(gf, 'file') ~= 2
         report(end+1) = local_r(tag, false, NaN, NaN, 0, 'correlation_data or config missing'); continue; %#ok<AGROW>
      end
      SK = load(kf); kv = fieldnames(SK); kv = kv{1}; T = SK.(kv);
      if ~istable(T), T = struct2table(T); end
      G = load(gf); gv = fieldnames(G); cfg = G.(gv{1});
      SC = load(cf); cv = fieldnames(SC); cv = cv{1}; C = SC.(cv);

      % 1. self-test with every row as reference
      K0 = local_kpi(T, cfg.noiseLevels, w, true(height(T), 1));
      e0 = max([max(abs(K0.CR - T.CR)), max(abs(K0.RES - T.RES))]);
      if ~(e0 < 1e-9)
         report(end+1) = local_r(tag, false, e0, NaN, 0, 'SELF-TEST FAILED - formula does not reproduce stored KPIs'); continue; %#ok<AGROW>
      end
      % 2. row alignment with correlation_data
      okA = numel(C.RES) == height(T) && isequal(double(C.encodedLen(:)), double(T.encodedLen)) && ...
            max(abs(double(C.noiseActual(:)) - double(T.noiseActual))) < 1e-12 && ...
            max(abs(double(C.RES(:)) - double(T.RES))) < 1e-9;
      if ~okA
         report(end+1) = local_r(tag, false, e0, NaN, 0, 'correlation_data rows do not align with the KPI table'); continue; %#ok<AGROW>
      end
      % new reference set
      meth = string(T.method);
      ref  = ~ismember(meth, string(opts.outOfScope));
      K1 = local_kpi(T, cfg.noiseLevels, w, ref);
      % 3. invariants
      okI = max(abs(K1.CR - T.CR)) < 1e-12 && max(abs(K1.BE - T.BE)) < 1e-12 && ...
            max(abs(K1.effectiveness - T.effectiveness)) < 1e-12;
      if ~okI
         report(end+1) = local_r(tag, false, e0, NaN, 0, 'CR/BE/effectiveness would change - refused'); continue; %#ok<AGROW>
      end
      [moves, maxShift, txt] = local_compare(meth, T.RES, K1.RES);
      note = sprintf('%d rows, %d out of scope; max |mean RES shift| %.4f; %s', ...
                     height(T), sum(~ref), maxShift, txt);
      if opts.apply
         if ~exist(opts.backupDir, 'dir'), mkdir(opts.backupDir); end
         local_backup(kf, opts.backupDir); local_backup(cf, opts.backupDir);
         T.CR_z = K1.CR_z; T.BE_z = K1.BE_z; T.RES = K1.RES;
         SK.(kv) = T; save(kf, '-struct', 'SK', '-v7.3');
         C.CR_z = reshape(K1.CR_z, size(C.CR_z)); C.BE_z = reshape(K1.BE_z, size(C.BE_z));
         C.RES  = reshape(K1.RES,  size(C.RES));
         C.standardizedOn = cellstr(unique(meth(ref)));
         SC.(cv) = C; save(cf, '-struct', 'SC', '-v7.3');
         note = [note ' - WRITTEN'];
      end
      report(end+1) = local_r(tag, true, e0, maxShift, moves, note); %#ok<AGROW>
   end

   for i = 1:numel(report)
      fprintf('  %-28s %-4s self-test %.1e  %s\n', report(i).sweep, local_ifelse(report(i).ok, 'OK', 'FAIL'), ...
              report(i).selfTest, report(i).note);
   end
   if opts.apply && all([report.ok])
      fid = fopen(fullfile(dataDir, 'KPI_SCOPE.txt'), 'w');
      fprintf(fid, ['CR_z, BE_z and RES in KPItableDetailed_* and correlation_data_* are standardized\n' ...
                    'on the in-scope methods (all except %s) and applied to every row.\n' ...
                    'results_*, anovaResults_* and crossCorrResults_* keep the all-rows standardization\n' ...
                    'of the simulation run and are not used for any number in the paper.\n' ...
                    'Written by restandardize_scope on %s. Originals in backup_scope.\n'], ...
              strjoin(opts.outOfScope, ', '), datestr(now));
      fclose(fid);
   elseif ~opts.apply && all([report.ok])
      fprintf('\nAll sweeps pass. Run again with struct(''apply'', true) to write.\n');
   end
end

function K = local_kpi(T, noiseLevels, w, ref)
% calcKPIs_engine's KPI layer (as reproduced in rebuild_kpis), with the
% z-score scale taken from the rows in ref and applied to every row.
   ref = logical(ref(:));
   K.BE = double(T.encodedLen) ./ double(T.interleavedLen);
   nb = double(T.noiseBin);
   tn = nan(size(nb)); ok = nb >= 1 & nb <= numel(noiseLevels);
   tn(ok) = noiseLevels(nb(ok));
   C_NN = double(T.noiseActual) ./ (tn + eps);
   CR_raw = max(0, 1 - (double(T.decodeErrRate) ./ (double(T.decErrRate_woInt) + eps)));
   K.CR = CR_raw .* C_NN;
   K.effectiveness = K.CR .* K.BE;
   K.CR_z = (K.CR - mean(K.CR(ref))) / (std(K.CR(ref)) + eps);
   K.BE_z = (K.BE - mean(K.BE(ref))) / (std(K.BE(ref)) + eps);
   K.RES  = w(1) * K.CR_z + w(2) * K.BE_z;
end

function [moves, maxShift, txt] = local_compare(meth, before, after)
   um = unique(meth); b = zeros(numel(um), 1); a = b;
   for k = 1:numel(um)
      at = meth == um(k); b(k) = mean(before(at)); a(k) = mean(after(at));
   end
   maxShift = max(abs(a - b));
   [~, o0] = sort(b, 'descend'); [~, o1] = sort(a, 'descend');
   r0 = zeros(size(b)); r0(o0) = 1:numel(b); r1 = zeros(size(a)); r1(o1) = 1:numel(a);
   mv = find(r0 ~= r1); moves = numel(mv);
   if moves == 0
      txt = 'ranking unchanged';
   else
      parts = arrayfun(@(k) sprintf('%s %d->%d', um(k), r0(k), r1(k)), mv, 'UniformOutput', false);
      txt = ['moves: ' strjoin(cellstr(parts), ', ')];
   end
end

function local_backup(f, bdir)
   [~, nm, ex] = fileparts(f); dst = fullfile(bdir, [nm ex]);
   if exist(dst, 'file') ~= 2, copyfile(f, dst); end
end

function r = local_r(s, ok, e0, ms, mv, note)
   r = struct('sweep', s, 'ok', ok, 'selfTest', e0, 'maxShift', ms, 'moves', mv, 'note', note);
end

function s = local_ifelse(c, a, b)
   if c, s = a; else, s = b; end
end
