function s = c2_spec()
%C2_SPEC  Which further campaign (article, Section 8.9) the campaign scripts work on.
%
%   global TS_CODE2; TS_CODE2 = 'c15t2';   % default 'code31'
%
%   code31   RS(31,21) t = 5   one grid  (code31)
%   code24   RS(24,16) t = 4   one grid  (code24)
%   c15t2    RS(15,11) t = 2   two grids (c15t2c common, c15t2s standards)
%   c15t4    RS(15,7)  t = 4   two grids (c15t4c common, c15t4s standards)
%   c15lo    RS(15,9)  t = 3   two grids, density band [0.50 0.90]*tau
%
% s.grid      the campaign label (file names in the log folder, status lines)
% s.grids     the configure_simulation grid modes it sweeps, in order
% s.arpGrids  the grid modes where arp belongs to the field
% s.nCond     conditions = 4 regimes x number of grids
% s.newTable  true when the campaign needs permutations built (n ~= 15);
%             at n = 15 the existing table is used and only checked
% s.dir       the results folder, as configure_simulation sets it
% s.out       the log folder (campaign_log_dir)
%
% THE PATH CHECK. A campaign run with a copy of a harness file from
% elsewhere on the MATLAB path would run, report numbers, and be a different
% campaign. Every function the campaign touches is therefore checked to
% resolve inside this repository, and configure_simulation to define every
% grid mode of the campaign, before anything is run.
%
% R.T. Sirmen, 2026-11

   global TS_CODE2 TS_GRID_MODE %#ok<GVMIS>
   if isempty(TS_CODE2), g = 'code31'; else, g = char(TS_CODE2); end
   switch g
      case 'code31', s = struct('grid', g, 'n', 31, 'k', 21, 't', 5); s.grids = {g}; s.arpGrids = {};
      case 'code24', s = struct('grid', g, 'n', 24, 'k', 16, 't', 4); s.grids = {g}; s.arpGrids = {};
      case 'c15t2',  s = struct('grid', g, 'n', 15, 'k', 11, 't', 2); s.grids = {'c15t2c', 'c15t2s'}; s.arpGrids = {'c15t2s'};
      case 'c15t4',  s = struct('grid', g, 'n', 15, 'k',  7, 't', 4); s.grids = {'c15t4c', 'c15t4s'}; s.arpGrids = {'c15t4s'};
      case 'c15lo',  s = struct('grid', g, 'n', 15, 'k',  9, 't', 3); s.grids = {'c15loc', 'c15los'}; s.arpGrids = {'c15los'};
      otherwise, error('c2_spec: TS_CODE2 = "%s"; use code31, code24, c15t2, c15t4 or c15lo.', g);
   end
   s.nCond = 4 * numel(s.grids);
   % suffix of the design-cell file, so a campaign at n = 15 never
   % overwrites design_cells_all_n15.csv (the primary campaign)
   switch g
      case {'c15t2', 'c15t4'}, s.tag = sprintf('_t%d', s.t);
      case 'c15lo',            s.tag = '_lo';
      otherwise,               s.tag = '';
   end
   s.newTable = (s.n ~= 15);
   s.out = campaign_log_dir();

   root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
   need = {'configure_simulation', 'run_simulations_sci', 'main_simulation_wrapper', ...
           'interleave_all_pc', 'injectBurstErrors_all', 'collectStatistics_x', 'decodeRS_all', ...
           'encoderRS_CW', 'decoderRS_CW', 'configure_FEC_parameters', ...
           'PrecomputeInterleaversGenerator', 'designMetricScore', 'metric_scorecard', ...
           'validation_supplement', 'restandardize_scope', 'health_check', 'find_table_dir', ...
           'check_length_coverage', 'export_design_cells_all', 'add_method_names'};
   bad = {};
   for k = 1:numel(need)
      w = which(need{k});
      if isempty(w) || ~strncmpi(w, root, numel(root))
         bad{end+1} = sprintf('%s -> %s', need{k}, w); %#ok<AGROW>
      end
   end
   if ~isempty(bad)
      error(['c2_spec: these do not resolve inside %s (run setup_paths from the ' ...
             'repository root):\n  %s'], root, strjoin(bad, '\n  '));
   end
   txt = fileread(which('configure_simulation'));
   for k = 1:numel(s.grids)
      if isempty(strfind(txt, ['''' s.grids{k} ''''])) %#ok<STREMP>
         error('c2_spec: %s has no grid mode ''%s''.', which('configure_simulation'), s.grids{k});
      end
   end

   % The results folder is the one configure_simulation sets for the grid.
   oldG = TS_GRID_MODE; TS_GRID_MODE = s.grids{1};
   cfg = configure_simulation();
   TS_GRID_MODE = oldG;
   s.dir = char(cfg.dataSavePath);
end
