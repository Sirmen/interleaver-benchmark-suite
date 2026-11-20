%% code2_run_all.m
% The further campaigns of the metric validation (article, Section 8.9) in
% one go, each step logged to the log folder (campaign_log_dir) and recorded
% in campaign_status.txt there. Stops at the first step that fails.
%
%   >> clear functions; rehash; code2_run_all
%
% Default list: all five, 'code31' 'code24' 'c15t2' 'c15t4' 'c15lo'. Expect
% several hours each. Another list:
%    global TS_CODE2_LIST; TS_CODE2_LIST = {'c15t4'};
%
% For each code: the permutation table (built for a new n, only checked at
% n = 15), the smoke test, the sweeps, the analysis. A step recorded OK in
% campaign_status.txt is skipped, so after a failure this script resumes
% where it stopped.
% To resume a code's sweeps after a crash mid-campaign, set TS_CODE2 and
% TS_CODE2_START (1..8, grids outer, regimes inner) and run run_code2_sweeps,
% then code2_analyze.
%
% R.T. Sirmen harness, 2026-11-17

global TS_CODE2 TS_CODE2_START TS_CODE2_LIST %#ok<GVMIS>
if isempty(TS_CODE2_LIST), C2_LIST = {'code31', 'code24', 'c15t2', 'c15t4', 'c15lo'}; else, C2_LIST = TS_CODE2_LIST; end
TS_CODE2_START = [];
for c2i = 1:numel(C2_LIST)
   TS_CODE2 = C2_LIST{c2i};
   S2run = c2_spec();
   if S2run.newTable
      if ~c2_done([TS_CODE2 '_build_table']), code2_build_table; end
   else
      if ~c2_done([TS_CODE2 '_table_check']), code2_check_table; end
   end
   if ~c2_done([TS_CODE2 '_smoke']),   code2_smoke;      end
   if ~c2_done([TS_CODE2 '_sweeps']),  run_code2_sweeps; end
   if ~c2_done([TS_CODE2 '_analyze']), code2_analyze;    end
end
TS_CODE2 = [];
fprintf('\ncode2_run_all: all steps OK for %s. See %s\n', strjoin(C2_LIST, ', '), ...
        fullfile(campaign_log_dir(), 'campaign_status.txt'));
