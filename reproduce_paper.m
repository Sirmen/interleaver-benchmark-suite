function reproduce_paper(dataDir)
%REPRODUCE_PAPER  Every table and figure of the paper from the archived data.
%
%   setup_paths
%   reproduce_paper(fullfile(pwd, 'data', 'results'))
%
% dataDir holds the eight KPItableDetailed_*.mat, correlation_data_*.mat
% and config_*.mat files of the Zenodo dataset. Nothing is simulated.
% Printed output is what the tables of the paper transcribe; figures go to
% ./figures. The bootstrap is seeded, so intervals reproduce exactly.

   if nargin < 1 || isempty(dataDir)
      dataDir = fullfile(fileparts(mfilename('fullpath')), 'data', 'results');
   end
   if isempty(dir(fullfile(dataDir, 'KPItableDetailed_*.mat')))
      error('reproduce_paper: no campaign tables in %s - unzip the Zenodo dataset there', dataDir);
   end
   t0 = tic;

   % Before any number is produced: no file of this release may be shadowed by
   % a copy elsewhere on the path, and no name may appear twice inside it.
   check_path_shadowing(struct('strict', true));

   fprintf('\n##### Section IX-A: realized noise against its label\n');
   check_noise_fidelity(dataDir);

   fprintf('\n##### Section VIII-G: sensitivity to kappa\n');
   check_kappa_sensitivity(dataDir, struct('write', false));

   fprintf('\n##### Table IX: the metric scorecard (in-scope field)\n');
   S = metric_scorecard(dataDir);

   fprintf('\n##### Section VIII-G: target, field, operating point, leave-one-out\n');
   validation_supplement(dataDir);

   fprintf('\n##### Table VI: structural screen at N = 1200 and N = 1440\n');
   screen_methods(dataDir, struct('N', 1200));
   screen_methods(dataDir, struct('N', 1440));

   fprintf('\n##### Figures 1-7\n');
   fig1_screen(dataDir);
   fig2_taxonomy();
   % save is passed: this one defaults to false where the other six default
   % to true, so Figure 3 was drawn and never written to ./figures.
   fig_cnn_justification(dataDir, struct('save', true));
   fig4_bsweep(S);
   fig5_c5box(S);
   fig6_resdecomp(dataDir);
   fig7_bracket();

   fprintf('\nreproduce_paper: done in %.1f min; figures in %s\n', toc(t0) / 60, ...
           fullfile(pwd, 'figures'));
end
