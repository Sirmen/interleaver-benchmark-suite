function reproduce_paper(dataRoot, opts)
%REPRODUCE_PAPER  The tables, figures and campaign numbers of the paper from the archived data.
%
%   setup_paths
%   reproduce_paper(fullfile(pwd, 'data'))
%
% dataRoot is the unzipped campaign-data record:
%   dataRoot/results/              the eight sweeps of the primary configuration
%                                  (KPItableDetailed_*, correlation_data_*, config_*)
%   dataRoot/campaigns/<code>/     the five further campaigns of Section 8.9,
%                                  code = c15lo, c15t2, c15t4, code31, code24
% A folder holding the primary KPItableDetailed_*.mat files directly is also
% accepted, as in release 1.0.x; the further campaigns are then looked for in
% opts.campaignRoot, and skipped with a note if it is not given.
%
% Nothing is simulated. Printed output is what the tables of the paper
% transcribe; figures go to ./figures. The bootstrap is seeded, so the
% intervals reproduce exactly.
%
% OPTIONS
%   campaignRoot   folder of the further campaigns (default dataRoot/campaigns)
%   tableDir       permutation table folder (default: find_table_dir)
%   figures        true (default): draw Figures 1-6
%   campaigns      true (default): Table 6 and Section 8.9
%
% Section, table and figure numbers follow the article (Tables 1-8, Figures
% 1-6) and its Supplementary Material (Tables S1-S3, Section S4).
%
% The checks of Sections 8.1, 8.7, 8.8 and 8.9 that work on cell matrices
% (null calibration of theta, Kendall's tau, method families left out,
% between-metric and partial association, C5 against the number of lengths
% and of codewords) are in analysis/python/cell_checks.py; the command that
% runs it on the same data is printed at the end.

   if nargin < 2, opts = struct(); end
   here = fileparts(mfilename('fullpath'));
   if nargin < 1 || isempty(dataRoot), dataRoot = fullfile(here, 'data'); end
   dataRoot = char(dataRoot);
   if ~isempty(dir(fullfile(dataRoot, 'KPItableDetailed_*.mat')))
      dataDir = dataRoot;                                   % 1.0.x layout
      campaignRoot = local_opt(opts, 'campaignRoot', '');
   else
      dataDir = fullfile(dataRoot, 'results');
      campaignRoot = local_opt(opts, 'campaignRoot', fullfile(dataRoot, 'campaigns'));
   end
   if isempty(dir(fullfile(dataDir, 'KPItableDetailed_*.mat')))
      error('reproduce_paper: no campaign tables in %s - unzip the Zenodo dataset there', dataDir);
   end
   tableDir = local_opt(opts, 'tableDir', '');
   doFig = local_opt(opts, 'figures', true);
   doCamp = local_opt(opts, 'campaigns', true);
   t0 = tic;

   % Before any number is produced: no file of this release may be shadowed by
   % a copy elsewhere on the path, and no name may appear twice inside it.
   check_path_shadowing(struct('strict', true));

   fprintf('\n##### Section 7.2: realized noise against its label\n');
   check_noise_fidelity(dataDir);

   fprintf('\n##### Section 8.7: sensitivity to kappa\n');
   check_kappa_sensitivity(dataDir, struct('write', false));

   fprintf('\n##### Table 4 (and Table S2, its full form): the metric scorecard, in-scope field\n');
   S = metric_scorecard(dataDir, struct('tableDir', tableDir));

   fprintf('\n##### Table S3 and Section 8.7: target, field, operating point, one method left out\n');
   validation_supplement(dataDir, struct('tableDir', tableDir));
   fprintf('\n##### Table S3 and Section 8.7: CR alone and the decoded error rate as targets\n');
   % Its own log and csv go to campaign_logs (or SINT_LOGS), not the repository root.
   target_sensitivity(dataDir, struct('tableDir', tableDir, 'outDir', campaign_log_dir()));
   % It writes its table through a diary of its own, which suspends this
   % session's diary meanwhile; the table is echoed here so that one log
   % holds every number.
   tsLog = dir(fullfile(campaign_log_dir(), 'target_sensitivity_*.txt'));
   if ~isempty(tsLog)
      [~, k] = max([tsLog.datenum]);
      type(fullfile(tsLog(k).folder, tsLog(k).name));
   end

   fprintf('\n##### Table S1: structural screen at N = 1200 and N = 1440\n');
   screen_methods(dataDir, struct('N', 1200));
   screen_methods(dataDir, struct('N', 1440));

   if doCamp
      if ~isempty(campaignRoot) && exist(campaignRoot, 'dir') == 7
         fprintf('\n##### Table 6 and Section 8.9: five further campaigns\n');
         further_campaigns(campaignRoot, struct('tableDir', tableDir));
      else
         fprintf('\n##### Table 6: skipped - no campaign folder (opts.campaignRoot or dataRoot/campaigns)\n');
      end
   end

   if doFig
      % Script names predate the article's numbering: fig7_bracket draws
      % Figure 6. fig6_resdecomp prints the RES decomposition that Section
      % 10.2 reports in the text; the article has no figure of it, so it is
      % not drawn and nothing is written for it.
      fprintf('\n##### Figures 1-6, and the RES decomposition of Section 10.2\n');
      fig1_screen(dataDir);                                     % Figure 1
      fig2_taxonomy();                                          % Figure 2
      % save is passed: this one defaults to false where the others default
      % to true, so Figure 3 was drawn and never written to ./figures.
      fig_cnn_justification(dataDir, struct('save', true));     % Figure 3
      fig4_bsweep(S);                                           % Figure 4
      fig5_c5box(S);                                            % Figure 5
      fig7_bracket();                                           % Figure 6
      fig6_resdecomp(dataDir, struct('draw', false));           % Section 10.2, table only
   end

   py = fullfile(here, 'analysis', 'python', 'cell_checks.py');
   des = fullfile(dataDir, 'design_cells_all_n15.csv');
   fprintf('\n##### Sections 8.1, 8.7, 8.8, 8.9: cell-level checks (Python 3, NumPy, SciPy, h5py)\n');
   cmd = sprintf('python "%s" --primary "%s" --design "%s"', py, dataDir, des);
   if ~isempty(campaignRoot)
      for c = {'code31', 'code24'}
         f = local_campaign(campaignRoot, c{1});
         if ~isempty(f), cmd = sprintf('%s --%s "%s"', cmd, c{1}, f); end
      end
   end
   fprintf('  %s\n', cmd);

   fprintf('\nreproduce_paper: done in %.1f min; figures in %s\n', toc(t0) / 60, ...
           fullfile(pwd, 'figures'));
end

function f = local_campaign(root, code)
   f = '';
   for c = {fullfile(root, code), fullfile(root, ['results_' code])}
      if exist(c{1}, 'dir') == 7, f = c{1}; return; end
   end
end

function v = local_opt(s, f, dflt)
   if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end
