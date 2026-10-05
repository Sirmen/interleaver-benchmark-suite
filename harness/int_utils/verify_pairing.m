function ok = verify_pairing(resultsFile)
%VERIFY_PAIRING  Prove that row i of every method is the SAME trial.
%
%   ok = verify_pairing('<resultsDir>\results_multi_<tag>.mat')
%
% WHY THIS IS NOT OPTIONAL
% ---------------------------------------------------------------------------
% paired_method_analysis pairs methods BY ROW POSITION, because
% KPItableDetailed carries no length or noise column to match on. It says so,
% loudly, on every run - and an assumption that is announced is still an
% assumption. Every paired p-value, every dz and every win-rate in that report
% rests on this one property:
%
%     the i-th record of method A and the i-th record of method B
%     come from the same trial - the same frame, the same burst realisation.
%
% If that fails, the differences are pairings of unrelated trials. The MEAN
% difference would survive (it equals the difference of the means whatever the
% order - that is an algebraic identity, so it proves nothing), but the
% VARIANCE would inflate, dz would shrink, and every p-value would be wrong in
% a direction nobody could predict.
%
% The good news: results_*.mat DOES carry the length per record, in
% stats_all.encodedLen. This function loads one results file and compares the
% per-method sequences directly. Run it ONCE per grid - the row order is a
% property of run_simulations_sci, not of the regime, so one common-grid file
% and one standards-grid file settle it for all eight sweeps.
%
% Cost: these files are 1.3 GB (standards) to 8 GB (common). One load each.
%
% R.T. Sirmen harness, 2026-08

   ok = false;
   fprintf('\n=== PAIRING VERIFICATION ===\n%s\n', resultsFile);

   S = load(resultsFile);
   fn = fieldnames(S);
   R = [];
   for i = 1:numel(fn)
      if isstruct(S.(fn{i})) && isfield(S.(fn{i}), 'stats_all')
         R = S.(fn{i}); break;
      end
   end
   if isempty(R)
      fprintf(2, '  no struct with stats_all found\n'); return;
   end

   st = R.stats_all;
   if ~isfield(st, 'method')
      fprintf(2, '  stats_all has no .method field\n'); return;
   end

   m = string({st.method});
   uM = unique(m, 'stable');
   fprintf('  records: %d   methods: %d\n', numel(st), numel(uM));

   % The blocking variable. encodedLen is the one every record carries.
   key = '';
   for c = {'encodedLen', 'N', 'size'}
      if isfield(st, c{1}), key = c{1}; break; end
   end
   if isempty(key)
      fprintf(2, '  no length field in stats_all - cannot verify\n'); return;
   end
   fprintf('  matching on stats_all.%s\n', key);

   ref = []; refName = '';
   bad = {};
   for j = 1:numel(uM)
      idx = (m == uM(j));
      v = [st(idx).(key)];
      v = v(:).';
      if isempty(ref)
         ref = v; refName = char(uM(j));
      elseif ~isequal(size(ref), size(v))
         bad{end+1} = sprintf('%s (length %d vs %d)', uM(j), numel(v), numel(ref)); %#ok<AGROW>
      elseif ~isequal(ref, v)
         nDiff = sum(ref ~= v);
         bad{end+1} = sprintf('%s (%d of %d positions differ)', uM(j), nDiff, numel(v)); %#ok<AGROW>
      end
   end

   fprintf('  reference method: %s  (%d records)\n', refName, numel(ref));

   if isempty(bad)
      ok = true;
      fprintf('\n  PAIRING VERIFIED - every method sees the same trial sequence.\n');
      fprintf('  The paired analysis is sound; the warning it prints is a\n');
      fprintf('  statement about what the KPI table lacks, not about the data.\n');

      % Bonus: does the derived cell structure line up with the real lengths?
      % paired_method_analysis assumes consecutive blocks of testRunsMax share
      % a cell. If that is right, the length must be constant inside each block.
      runsPerCell = local_guess(numel(ref));
      if runsPerCell > 1
         nCell = numel(ref) / runsPerCell;
         blocks = reshape(ref, runsPerCell, nCell);
         constant = all(all(blocks == blocks(1,:), 1));
         if constant
            fprintf('  CELL BLOCKS VERIFIED - length is constant within each\n');
            fprintf('  block of %d, so the derived %d cells are real cells.\n', ...
                    runsPerCell, nCell);
         else
            fprintf(2, '  WARNING: length is NOT constant within blocks of %d.\n', runsPerCell);
            fprintf(2, '  The derived cell structure is wrong - quote p(trial),\n');
            fprintf(2, '  not p(cell), until this is sorted out.\n');
            ok = false;
         end
      end
   else
      fprintf(2, '\n  PAIRING FAILED for %d method(s):\n', numel(bad));
      for i = 1:numel(bad), fprintf(2, '    %s\n', bad{i}); end
      fprintf(2, '  Do NOT use the paired results until this is understood.\n');
   end
   fprintf('============================\n\n');
end

function r = local_guess(nTrial)
   r = 0;
   for nLen = [50 8]
      for bins = [5 3]
         if mod(nTrial, nLen * bins) == 0
            c = nTrial / (nLen * bins);
            if c >= 2 && c <= 1000, r = c; return; end
         end
      end
   end
end
