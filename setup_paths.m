function root = setup_paths()
%SETUP_PATHS  Put the repository, and nothing else, on the MATLAB path.
%
%   setup_paths            % from the repository root
%
% Everything the paper needs lives under this folder. Nothing is taken from
% the MATLAB path the user already has: run this in a fresh session, or
% call `restoredefaultpath` first, so that an older copy of a file elsewhere
% on the path cannot shadow the released one. The folders go in front of the
% existing path, so the repository's own copy of a name wins over an installed
% toolbox's. Shadowing produced a wrong figure once during this project; see
% analysis/FIGURES_README.md.

   root = fileparts(mfilename('fullpath'));
   parts = {'harness', 'interleavers', 'metrics', 'tables', 'health', ...
            'analysis', 'common', 'plotting'};

   % Added with '-begin', so the repository sits in front of the installed
   % toolboxes; see the note below the loop for the three names this matters
   % for. The loop runs backwards so that the folders keep the order above
   % once each has been pushed to the front.
   for i = numel(parts):-1:1
      p = fullfile(root, parts{i});
      if exist(p, 'dir') == 7
         addpath(genpath(p), '-begin');
      else
         fprintf(2, 'setup_paths: %s is missing\n', p);
      end
   end
   addpath(root, '-begin');

   % Three names in the repository also exist in installed toolboxes, and the
   % repository's copies are the ones the campaign ran with:
   %   divisors      common/octave_compat/   also in Symbolic Math
   %   distance      common/                 also in Mapping
   %   calculateSNR  common/                 also in the Mixed-Signal Blockset
   % They must stay in front, which is what '-begin' above is for. octave_compat
   % is therefore on the path under MATLAB as well, not only under Octave.
   for nm = {'divisors', 'distance', 'calculateSNR'}
      w = which(nm{1});
      if ~isempty(w) && ~strncmpi(w, root, numel(root))
         fprintf(2, 'setup_paths: %s resolves outside the repository: %s\n', nm{1}, w);
      end
   end

   % NOTHING MAY RUN FROM A QUARANTINE OR ARCHIVE FOLDER.
   %
   % Files withdrawn from the release are moved to a sibling _quarantine tree
   % rather than deleted, so that a file withdrawn in error can be restored
   % with its history. That is the right way to withdraw a file and the wrong
   % thing to have on the path: a quarantined copy is by definition the copy
   % that was judged unfit, and if it shadows the kept one the run is wrong
   % while every file name in the log looks correct. The loop above cannot
   % prevent it, because the quarantine sits OUTSIDE this repository and gets
   % onto the path from a saved pathdef or an addpath in a user startup file.
   %
   % This is reported as a blocking condition, not a warning: the message
   % names the folder so it can be removed with rmpath, and a run whose
   % provenance is in doubt is not worth the hours it takes.
   MARK = {'_quarantine', '_attic', '_superseded'};
   pe = strsplit(path, pathsep);
   qbad = {};
   for i = 1:numel(pe)
      if isempty(pe{i}), continue; end
      for j = 1:numel(MARK)
         if ~isempty(strfind(lower(pe{i}), MARK{j}))  %#ok<STREMP>
            qbad{end+1} = pe{i};  %#ok<AGROW>
            break;
         end
      end
   end
   if ~isempty(qbad)
      fprintf(2, ['\nsetup_paths: QUARANTINE ON THE PATH - %d folder(s). Withdrawn\n' ...
                  '  files can shadow released ones and the log will not show it.\n' ...
                  '  Remove them before running anything:\n'], numel(qbad));
      for i = 1:numel(qbad), fprintf(2, '    rmpath(''%s'')\n', qbad{i}); end
      fprintf(2, '\n');
   end

   % Report any function that exists twice on the path, AND SAY WHERE.
   % "found 2 times" on its own cannot be acted on: the question is always
   % whether the winning copy is this repository's, and that needs the paths.
   % The winner is the first entry which('-all') returns.
   %
   % EVERY FIGURE SCRIPT IS PROBED, not just fig_style. These files exist in
   % two trees by design - this repository and the working tree they are
   % developed in - so a stale copy winning is not a remote possibility here,
   % it is the normal failure. It happened: fig1_screen.m was corrected in
   % both trees and the next run still drew the old legend, and the only
   % explanation left once the files were checked byte for byte was that
   % MATLAB had resolved a third copy. fig_style alone could not catch it,
   % because fig_style was not the file that had changed.
   probe = {'fig_style', 'metric_scorecard', 'screen_methods', 'configure_simulation', ...
            'getSizeList', 'interleave_all_pc', 'PrecomputedInterleaverLoader', ...
            'designMetricScore', 'validation_supplement', 'PrimeFactorLoader', ...
            'dump_table13_ntcell', ...
            'fig1_screen', 'fig2_taxonomy', 'fig_cnn_justification', ...
            'fig4_bsweep', 'fig5_c5box', 'fig6_resdecomp', 'fig7_bracket', ...
            'make_figures_CEE'};
   for i = 1:numel(probe)
      w = which(probe{i}, '-all');
      if ischar(w), w = {w}; end
      if numel(w) > 1
         inRepo = strncmpi(w{1}, root, numel(root));
         if inRepo
            fprintf(2, 'setup_paths: %s found %d times; this repository wins\n', ...
                    probe{i}, numel(w));
         else
            fprintf(2, ['setup_paths: %s found %d times and THE WINNER IS NOT THIS\n' ...
                        '  REPOSITORY: %s\n'], probe{i}, numel(w), w{1});
         end
         for k = 2:numel(w)
            fprintf(2, '    also: %s\n', w{k});
         end
      end
   end
   fprintf('setup_paths: repository at %s\n', root);
end
