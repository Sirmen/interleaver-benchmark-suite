function verify_setup(dataDir_PrimeFactor)
%VERIFY_SETUP  Prove the canonicalised harness is installed and the table is
%              built for the right lengths - BEFORE spending hours on a sweep.
%
%   verify_setup('<tableDir>')
%
% Run this after installing the 2026-08 files and after rebuilding the table.
% It answers, in order, the questions that actually go wrong:
%
%   1. Are the NEW files on the path, or is an old copy shadowing them?
%   2. Does config produce the grid we think it does?
%   3. Does the table cover every length the sweep will ask for?
%   4. Is `arp` present at the eight published lengths and ABSENT elsewhere?
%   5. Is every cached entry a genuine permutation that inverts cleanly?
%
% Any single one of these failing silently costs a full sweep. The old habit
% of finding out afterwards is what this file exists to end.
%
% R.T. Sirmen harness, 2026-08

   if nargin < 1 || isempty(dataDir_PrimeFactor)
      error('verify_setup: give the directory holding table_factors_precomputed.mat');
   end

   fprintf('\n===============================================================\n');
   fprintf('  SETUP VERIFICATION\n');
   fprintf('===============================================================\n');

   nFail = 0;

   %% 1 -- are the new files installed? -------------------------------------
   fprintf('\n[1] FILE VERSIONS\n');
   % Each marker is a string that exists ONLY in the canonicalised version.
   % Case-insensitive on purpose: the first version of this check used a
   % lower-case marker against an upper-case header line and reported the
   % correctly-installed interleaver_arp as OLD. A verifier that cries wolf
   % is worse than no verifier, because the next real failure gets ignored.
   markers = { ...
      'interleaver_arp',            'NO DERIVATION PATH'; ...
      'interleaver_drp',            'THE STRIDE IS NOT GOLDEN'; ...
      'interleaver_multiDim',       'AXIS REVERSAL, NOT AXIS ROTATION'; ...
      'getSizeList',                'The explicit list exists because'; ...
      'interleaver_generic_pc',     'arp''s info carries P0, not P'; ...
      'configure_interleaver_params','PUBLISHED PARAMETERS ONLY'; ...
      'configure_simulation',       'IZGARA SECICI'; ...
      'run_simulations_sci',        'getSizeList'; ...
      'PrecomputeInterleaversGenerator', 'encodedLengthList'};

   for i = 1:size(markers, 1)
      nm = markers{i,1}; mk = markers{i,2};
      p = which(nm);
      if isempty(p)
         fprintf('    %-32s NOT ON PATH\n', nm); nFail = nFail + 1; continue;
      end
      txt = fileread(p);
      if contains(txt, mk, 'IgnoreCase', true)
         fprintf('    %-32s ok\n', nm);
      else
         fprintf('    %-32s OLD VERSION  (%s)\n', nm, p); nFail = nFail + 1;
      end
   end

   %% 2 -- what grid does config actually produce? --------------------------
   fprintf('\n[2] GRID\n');
   [config, params] = configure_simulation();
   [msgSizes, desc] = getSizeList(config);
   lens = unique(ceil(msgSizes / config.FECk) * config.FECn);

   gm = '(legacy)';
   if isfield(config,'gridMode') && ~isempty(config.gridMode), gm = config.gridMode; end
   fprintf('    gridMode        : %s\n', gm);
   fprintf('    burstRegime     : %s\n', config.burstRegime);
   fprintf('    message sizes   : %s\n', desc);
   fprintf('    encoded lengths : %d  (%d..%d)\n', numel(lens), min(lens), max(lens));
   fprintf('    methods         : %d  (%s)\n', numel(params.intMethods), ...
           strjoin(params.intMethods(1:min(4,end)), ', '));
   fprintf('    testRunsMax     : %d\n', config.testRunsMax);
   fprintf('    saveResults     : %d    plotResults : %d\n', ...
           config.saveResults, config.plotResults);

   % The four properties the common grid is supposed to guarantee.
   if strcmp(gm, 'common')
      chk = [all(mod(lens,4)  == 0), ...
             all(mod(lens,60) == 0), ...
             all(mod(msgSizes, config.FECk) == 0)];
      nm  = {'every L divisible by 4 (ARP)', ...
             'every L divisible by 60 (3-way factorisation)', ...
             'zero RS padding (BE = 1 everywhere)'};
      for i = 1:3
         if chk(i), fprintf('    ok   %s\n', nm{i});
         else,      fprintf('    FAIL %s\n', nm{i}); nFail = nFail + 1; end
      end
      if any(strcmp(params.intMethods, 'arp'))
         fprintf('    FAIL arp is in intMethods on the common grid - it will\n');
         fprintf('         fail at 42 of 50 lengths and take S down with it\n');
         nFail = nFail + 1;
      else
         fprintf('    ok   arp excluded from the common grid\n');
      end
   end

   %% 3 -- table coverage ---------------------------------------------------
   fprintf('\n[3] TABLE COVERAGE\n');
   [tpc, erM] = PrecomputedInterleaverLoader(char(dataDir_PrimeFactor));
   if ~isempty(char(erM))
      fprintf('    FAIL loader: %s\n', char(erM));
      local_verdict(nFail + 1); return;
   end

   live = {'random', 'freqRandom'};      % never cached, by design
   pubARP = [120 180 240 480 960 1440 1920 2400];

   fprintf('    %-16s %8s %8s  %s\n', 'method', 'cached', 'missing', 'note');
   for i = 1:numel(config.allIntMethods)
      m = config.allIntMethods{i};
      if any(strcmp(m, live))
         fprintf('    %-16s %8s %8s  live by design\n', m, '-', '-'); continue;
      end
      fld = ['perms_' m];
      if ~isfield(tpc, fld)
         fprintf('    %-16s %8s %8s  FIELD ABSENT\n', m, '-', '-');
         if ~strcmp(m,'arp'), nFail = nFail + 1; end
         continue;
      end
      have = false(1, numel(lens));
      for j = 1:numel(lens)
         have(j) = tpc.(fld).isKey(sprintf('N_%d', lens(j)));
      end
      nMiss = sum(~have);

      if strcmp(m, 'arp')
         % arp is SUPPOSED to be sparse: present exactly on the published set.
         shouldHave = ismember(lens, pubARP);
         wrong = sum(have ~= shouldHave);
         if wrong == 0
            fprintf('    %-16s %8d %8d  ok - published lengths only\n', ...
                    m, sum(have), nMiss);
         else
            fprintf('    %-16s %8d %8d  FAIL %d lengths disagree with the\n', ...
                    m, sum(have), nMiss, wrong);
            fprintf('    %-16s %17s  802.16 table\n', '', '');
            nFail = nFail + 1;
         end
      elseif nMiss == 0
         fprintf('    %-16s %8d %8d  ok\n', m, sum(have), nMiss);
      else
         fprintf('    %-16s %8d %8d  FAIL missing e.g. N=%d\n', ...
                 m, sum(have), nMiss, lens(find(~have,1)));
         nFail = nFail + 1;
      end
   end

   %% 3b -- LDPC readiness: the extra encoded lengths -----------------------
   if isfield(config, 'encodedLengthList') && ~isempty(config.encodedLengthList)
      extra = setdiff(unique(round(config.encodedLengthList(:).')), lens);
      if ~isempty(extra)
         fprintf('\n    LDPC readiness - %d extra encoded lengths (%d..%d)\n', ...
                 numel(extra), min(extra), max(extra));
         nMissAny = 0;
         for i = 1:numel(config.allIntMethods)
            m = config.allIntMethods{i};
            if any(strcmp(m, live)) || strcmp(m, 'arp'), continue; end
            fld = ['perms_' m];
            if ~isfield(tpc, fld), continue; end
            miss = 0;
            for j = 1:numel(extra)
               if ~tpc.(fld).isKey(sprintf('N_%d', extra(j))), miss = miss + 1; end
            end
            if miss > 0
               fprintf('    %-16s %d of %d extra lengths missing\n', m, miss, numel(extra));
               nMissAny = nMissAny + 1;
            end
         end
         if nMissAny == 0
            fprintf('    ok   every method covers them - no rebuild needed for LDPC\n');
         else
            fprintf('    NOTE %d method(s) short. Not fatal now (RS does not use\n', nMissAny);
            fprintf('         these lengths) but rebuild before the LDPC study.\n');
         end
      end
   end

   %% 4 -- are the cached entries real permutations? ------------------------
   fprintf('\n[4] PERMUTATION INTEGRITY  (spot check)\n');
   probe = lens(unique(round(linspace(1, numel(lens), min(6, numel(lens))))));
   badPerm = 0; badInv = 0; nChecked = 0; identityHits = {};

   for i = 1:numel(config.allIntMethods)
      m = config.allIntMethods{i};
      if any(strcmp(m, live)), continue; end
      fld = ['perms_' m];
      if ~isfield(tpc, fld), continue; end
      for j = 1:numel(probe)
         key = sprintf('N_%d', probe(j));
         if ~tpc.(fld).isKey(key), continue; end
         e = tpc.(fld)(key); p = e.perm(:).'; n = numel(p);
         nChecked = nChecked + 1;
         if ~isequal(sort(p), 1:n)
            badPerm = badPerm + 1;
            fprintf('    FAIL %s N=%d is not a permutation\n', m, probe(j));
         else
            % identity is a permutation, and it is what the OLD generator
            % silently stored on failure - so it gets its own check
            if isequal(p, 1:n), identityHits{end+1} = sprintf('%s@%d', m, probe(j)); end %#ok<AGROW>
            if isfield(e, 'invPerm') && ~isempty(e.invPerm)
               q = e.invPerm(:).';
               if ~isequal(p(q), 1:n) && ~isequal(q(p), 1:n)
                  badInv = badInv + 1;
                  fprintf('    FAIL %s N=%d invPerm does not invert perm\n', m, probe(j));
               end
            end
         end
      end
   end
   fprintf('    checked %d entries: %d non-permutations, %d bad inverses\n', ...
           nChecked, badPerm, badInv);
   if ~isempty(identityHits)
      fprintf('    WARNING identity permutation cached at: %s\n', ...
              strjoin(identityHits, ', '));
      fprintf('            the old generator stored the identity on failure -\n');
      fprintf('            check these are genuinely identity by construction\n');
   end
   nFail = nFail + badPerm + badInv;

   %% 5 -- the three canonicalised methods, live ----------------------------
   fprintf('\n[5] CANONICALISED METHODS, LIVE\n');
   Lt = lens(min(3, numel(lens)));
   x  = 1:Lt;

   [~, ~, iA, eA] = interleaver_arp(x);
   if any(Lt == pubARP)
      if isempty(char(eA)), fprintf('    arp      N=%d ok  P0=%d source=%s degenerate=%d\n', ...
                                    Lt, iA.P0, iA.source, iA.degenerate);
      else, fprintf('    arp      N=%d FAIL %s\n', Lt, char(eA)); nFail = nFail + 1; end
   else
      if isempty(char(eA))
         fprintf('    arp      N=%d FAIL accepted a non-published length\n', Lt); nFail = nFail + 1;
      else
         fprintf('    arp      N=%d ok  refused (not a published length)\n', Lt);
      end
   end

   [~, pD, iD, eD] = interleaver_drp(x);
   if isempty(char(eD)) && isequal(sort(pD(:).'), 1:Lt)
      fprintf('    drp      N=%d ok  M=%d p=%d Snew=%d  (bound ~%d)\n', ...
              Lt, iD.M, iD.p, iD.Snew, floor(sqrt(2*Lt)));
      if iD.Snew > floor(sqrt(2*Lt))
         fprintf('    drp      WARNING Snew exceeds Crozier''s bound - the spread\n');
         fprintf('             metric is windowed somewhere it should not be\n');
         nFail = nFail + 1;
      end
   else
      fprintf('    drp      N=%d FAIL %s\n', Lt, char(eD)); nFail = nFail + 1;
   end

   [~, pM, dM, aM, eM2] = interleaver_multiDim(x);
   if isempty(char(eM2)) && isequal(sort(pM(:).'), 1:Lt)
      fprintf('    multiDim N=%d ok  dims=%s axisOrder=%s\n', Lt, mat2str(dM), mat2str(aM));
      if ~isequal(aM, numel(dM):-1:1)
         fprintf('    multiDim FAIL axis order is not the reversal - old file?\n');
         nFail = nFail + 1;
      end
   else
      fprintf('    multiDim N=%d FAIL %s\n', Lt, char(eM2)); nFail = nFail + 1;
   end

   local_verdict(nFail);
end

%% ------------------------------------------------------------------------
function local_verdict(nFail)
   fprintf('\n---------------------------------------------------------------\n');
   if nFail == 0
      fprintf('  ALL CHECKS PASSED - safe to run the smoke test\n');
   else
      fprintf('  %d CHECK(S) FAILED - fix these before running any sweep\n', nFail);
   end
   fprintf('---------------------------------------------------------------\n\n');
end
