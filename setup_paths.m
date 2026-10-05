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

   % Report any function that exists twice on the path: the second copy is
   % the one that silently wins or loses depending on order.
   probe = {'fig_style', 'metric_scorecard', 'screen_methods', 'configure_simulation', ...
            'getSizeList', 'interleave_all_pc', 'PrecomputedInterleaverLoader'};
   for i = 1:numel(probe)
      w = which(probe{i}, '-all');
      if numel(w) > 1
         fprintf(2, 'setup_paths: %s found %d times on the path\n', probe{i}, numel(w));
      end
   end
   fprintf('setup_paths: repository at %s\n', root);
end
