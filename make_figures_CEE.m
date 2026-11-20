function make_figures_CEE(dataDir, outDir)
%MAKE_FIGURES_CEE  Regenerate the article's six figures and their upload copies.
%   (The name is kept from release 1.0.x.)
%
%   make_figures_CEE                                   % uses the defaults below
%   make_figures_CEE('<resultsDir>', '<outDir>')
%
% The results folder can be named once per machine rather than on every call:
%
%    setenv('PAPER_DATA_DIR', 'D:\somewhere\results_v2')
%
% Apply the EPS patch to fig_style.m first (fig_style_eps.patch.txt); without
% it this still writes the cropped vector PDF, which most publishers accept.
%
% Run it from the repository root, after setup_paths.
%
% Each script keeps its own option names: fig_cnn_justification takes figPath
% and stem where the others take outDir, and its save flag defaults to false.
% Figures 4 and 5 read the scorecard, so it is computed once and passed to both.

   % DEFAULTS. The convention is reproduce_paper's: locate the data relative to this
   % file, where the Zenodo dataset is unzipped, and write beside the working
   % directory. No drive letters, which is also what check_hardcoded_paths
   % exists to enforce.
   %
   % That default serves a Zenodo reader and nobody else: anyone working from
   % a results folder of their own was left naming it on every call.
   % PAPER_DATA_DIR answers that the way PAPER_FIG_DIR answers it for the
   % output folder in fig_style - set once in startup.m, read here. An
   % explicit argument still wins over it.
   root = fileparts(mfilename('fullpath'));
   if nargin < 1 || isempty(dataDir)
      dataDir = getenv('PAPER_DATA_DIR');
      if isempty(dataDir), dataDir = fullfile(root, 'data', 'results'); end
   end
   if nargin < 2 || isempty(outDir),  outDir  = fullfile(pwd, 'figures');          end

   % Checked by content, not by existence: an empty or wrong folder passes
   % exist(.,'dir') and then fails deep inside metric_scorecard, where the
   % message does not say that the data is missing.
   if exist(dataDir, 'dir') ~= 7
      error(['make_figures_CEE: results folder not found: %s\n' ...
             'Pass the folder holding the campaign .mat files, set ' ...
             'PAPER_DATA_DIR to it, or unzip the dataset into ' ...
             '<repo>/data/results.'], dataDir);
   end
   if isempty(dir(fullfile(dataDir, 'correlation_data_*.mat')))
      error(['make_figures_CEE: no correlation_data_*.mat in %s\n' ...
             'This is not a campaign results folder.'], dataDir);
   end
   if exist(outDir, 'dir') ~= 7, mkdir(outDir); end

   opts  = struct('save', true, 'outDir',  outDir);
   opts3 = struct('save', true, 'figPath', outDir, 'stem', 'fig3_cnn');

   fprintf('\n== scorecard (feeds figures 4 and 5)\n');
   S = metric_scorecard([], struct('dataDir', dataDir));

   fprintf('\n== figure 1\n');  fig1_screen(dataDir, opts);
   fprintf('\n== figure 2\n');  fig2_taxonomy(opts);
   fprintf('\n== figure 3\n');  fig_cnn_justification(dataDir, opts3);
   fprintf('\n== figure 4\n');  fig4_bsweep(S, opts);
   fprintf('\n== figure 5\n');  fig5_c5box(S, opts);
   fprintf('\n== figure 6\n');  fig7_bracket(opts);
   % The RES decomposition of Section 10.2 is reported in the text and has
   % no figure; reproduce_paper prints its table.

   % Upload names. A journal asks for one file per figure, numbered as the text
   % numbers them, so the stems are copied rather than renamed: the repository
   % keeps its own names and the submission gets Figure_1 ... Figure_6.
   stems = {'fig1_screen', 'fig2_taxonomy', 'fig3_cnn', 'fig4_bsweep', ...
            'fig5_c5box', 'fig7_bracket'};
   upDir = fullfile(outDir, 'upload');
   if exist(upDir, 'dir') ~= 7, mkdir(upDir); end
   % Clear the old upload set first. Release 1.0.x wrote Figure_1 ... Figure_7,
   % and a Figure_7 or an old Figure_6 left beside the new set would be sent
   % with it.
   old = dir(fullfile(upDir, 'Figure_*.*'));
   for i = 1:numel(old), delete(fullfile(upDir, old(i).name)); end

   fprintf('\n== upload set\n');
   missing = {};
   for k = 1:numel(stems)
      got = false;
      for ext = {'.eps', '.pdf'}
         src = fullfile(outDir, [stems{k} ext{1}]);
         if exist(src, 'file') == 2
            copyfile(src, fullfile(upDir, sprintf('Figure_%d%s', k, ext{1})));
            fprintf('  Figure_%d%-5s  <-  %s\n', k, ext{1}, [stems{k} ext{1}]);
            got = true;
         end
      end
      if ~got, missing{end+1} = stems{k}; end %#ok<AGROW>
   end

   if isempty(missing)
      fprintf('\n  six figures written to %s\n', upDir);
   else
      fprintf(2, '\n  NO FILE for: %s\n', strjoin(missing, ', '));
   end

   d = dir(fullfile(upDir, '*.*'));
   fprintf('\n  %-20s %10s\n', 'file', 'kB');
   for i = 1:numel(d)
      if ~d(i).isdir
         fprintf('  %-20s %10.0f\n', d(i).name, d(i).bytes/1024);
      end
   end
end
