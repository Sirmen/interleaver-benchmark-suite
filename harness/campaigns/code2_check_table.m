%% code2_check_table.m
% For the n = 15 campaigns (TS_CODE2 'c15t2' or 'c15t4', see c2_spec): checks,
% WITHOUT WRITING ANYTHING, that the permutation table already holds every
% permutation the campaign will ask for. Nothing is built for these codes:
% their encoded lengths are those of the published 'common' and 'standards'
% grids, and no method of the field reads t.
%
%   >> global TS_CODE2; TS_CODE2 = 'c15t2';
%   >> clear functions; rehash; code2_check_table
%
% For each grid mode of the campaign:
%   1. the encoded lengths equal those of the published grid (60m, m = 1..50;
%      or 120 180 240 480 960 1440 1920 2400), so the table entries used are
%      the ones the published RS(15,9) campaign used
%   2. every tabulated method has a key N_<L> at every length, holding a
%      permutation of 1..M with M >= L. M > L is the frame extension of the
%      methods that need a rectangle or a prime (matrix, helical, spiral,
%      prime, ...): the published campaign used the same extended entries,
%      and CNN charges the extension (Lemma 1). Those are counted, not failed.
% random and freqRandom are redrawn per frame and are not tabulated. A method
% with no table field at all is listed and left to the smoke test, which
% fails if it cannot be generated live.
%
% R.T. Sirmen harness, 2026-11-17

clc;
global TS_GRID_MODE TS_SMOKE TS_CODE2 %#ok<GVMIS>
if isempty(TS_CODE2), c2g = 'c15t2'; else, c2g = char(TS_CODE2); end
c31Out = campaign_log_dir();
c31Log = fullfile(c31Out, sprintf('%s_table_check_%s.txt', c2g, datestr(now, 'yymmdd_HHMM')));
diary(c31Log); diary on;
try
   S2 = c2_spec();
   if S2.newTable
      error('code2_check_table: %s needs its own permutations; run code2_build_table instead.', S2.grid);
   end
   if ~isempty(TS_SMOKE) && TS_SMOKE
      error('code2_check_table: TS_SMOKE is set. Clear it: TS_SMOKE = [];');
   end
   [tableDir, erD] = find_table_dir();
   if isempty(tableDir), error('code2_check_table: %s', erD); end
   [tpc, erT] = PrecomputedInterleaverLoader(char(tableDir));
   if erT ~= "", error('code2_check_table: %s', erT); end
   PUB = struct('c', 60 * (1:50), 's', [120 180 240 480 960 1440 1920 2400]);
   LIVE = {'random', 'freqRandom'};
   nBad = 0; nOK = 0; nExt = 0; noField = {}; extInfo = {};
   for gi = 1:numel(S2.grids)
      g = S2.grids{gi};
      TS_GRID_MODE = g;
      [cfg, par] = configure_simulation();
      TS_GRID_MODE = [];
      if cfg.FECn ~= S2.n || cfg.FECk ~= S2.k || cfg.FECt_correct ~= S2.t
         error('code2_check_table: %s gives RS(%d,%d) t=%d, expected RS(%d,%d) t=%d.', ...
               g, cfg.FECn, cfg.FECk, cfg.FECt_correct, S2.n, S2.k, S2.t);
      end
      L = unique(ceil(cfg.sizeList / cfg.FECk) * cfg.FECn);
      want = PUB.(g(end));
      if ~isequal(L, want)
         error('code2_check_table: %s encodes to %s, not the published grid %s.', g, mat2str(L), mat2str(want));
      end
      if any(mod(cfg.sizeList, cfg.FECk) ~= 0)
         error('code2_check_table: %s has a message length that is not a whole number of codewords (padding).', g);
      end
      arpIn = any(strcmp(par.intMethods, 'arp'));
      if arpIn ~= any(strcmp(S2.arpGrids, g))
         error('code2_check_table: arp presence in the field of %s (%d) contradicts c2_spec.', g, arpIn);
      end
      fprintf('\n%s: RS(%d,%d) t=%d, %d lengths %d..%d, %d methods, band [%.4f %.4f]\n', g, cfg.FECn, ...
              cfg.FECk, cfg.FECt_correct, numel(L), L(1), L(end), numel(par.intMethods), ...
              cfg.noiseLevels(1), cfg.noiseLevels(end));
      for mi = 1:numel(par.intMethods)
         m = par.intMethods{mi};
         if any(strcmp(LIVE, m)), continue; end
         fld = ['perms_' m];
         if ~isfield(tpc, fld)
            noField{end+1} = sprintf('%s (%s)', m, g); %#ok<SAGROW>
            continue;
         end
         M = tpc.(fld); miss = []; nExtM = 0;
         for li = 1:numel(L)
            key = sprintf('N_%d', L(li));
            ok = isa(M, 'containers.Map') && isKey(M, key);
            if ok
               e = M(key);
               ok = isstruct(e) && isfield(e, 'perm');
               if ok
                  pv = double(e.perm(:)).'; Mp = numel(pv);
                  ok = Mp >= L(li) && isequal(sort(pv), 1:Mp);
                  if ok && Mp > L(li), nExt = nExt + 1; nExtM = nExtM + 1; end
               end
            end
            if ok, nOK = nOK + 1; else, miss(end+1) = L(li); end %#ok<SAGROW>
         end
         if nExtM > 0, extInfo{end+1} = sprintf('%s %d', m, nExtM); end %#ok<SAGROW>
         if ~isempty(miss)
            nBad = nBad + numel(miss);
            fprintf(2, '  %-14s missing or invalid at %s\n', m, mat2str(miss));
         end
      end
   end
   fprintf('\n%d (method, length) entries present and valid permutations\n', nOK);
   fprintf('of them %d frame-extended (perm longer than L, as in the published campaign): %s\n', nExt, strjoin(extInfo, ', '));
   if ~isempty(noField)
      fprintf('no table field (generated live; the smoke test checks them): %s\n', strjoin(noField, ', '));
   end
   if nBad > 0
      error('code2_check_table: %d entries missing or invalid. Do not start the campaign.', nBad);
   end
   fprintf('\nTABLE CHECK PASSED. NEXT: clear functions; rehash; code2_smoke\n');

c31_status([c2g '_table_check'], 'OK', c31Log);
catch c31ME
   fprintf(2, '\n*** code2_check_table FAILED ***\n%s\n', getReport(c31ME, 'extended', 'hyperlinks', 'off'));
   c31_status([c2g '_table_check'], 'FAILED', c31Log);
   diary off;
   rethrow(c31ME);
end
diary off;
