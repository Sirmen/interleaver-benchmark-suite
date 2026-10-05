function verStr = save_results(config, varargin)
%SAVE_RESULTS  Aligned wrapper for simulation data saving.
%   Uses saveVars_YMD as the core engine; date and versioning are handled
%   entirely there.
%
%   File name:   <varName>_<regime>_<grid>_<YYMMDD>_<n>.mat
%   e.g.         KPItableDetailed_multi_common_260828_1.mat
%
% WHY THE GRID TAG WAS ADDED (2026-08)
% -------------------------------------------------------------------------
% The name used to be <varName>_<regime>_<date>_<n>.mat. burstRegimeTag knows
% only the burst regime, so a common-grid run and a standards-grid run of the
% same regime on the same day produced names differing ONLY by the trailing
% counter. Which file came from which grid was unrecoverable from the name.
%
% The analysis worked around this by guessing from content -
% paired_method_analysis inferred "standards" from the presence of 'arp' in
% the method list - and that guess is not safe: once the common grid was
% widened to lengths where arp is defined, arp appears in BOTH grids, and in
% a reduced method set it appears in neither. A guess that is wrong in both
% directions is worse than no guess, because it is silent.
%
% config already carries the answer (configure_simulation sets
% config.gridMode), and save_results already receives config, so this needs no
% change anywhere else - main_simulation_wrapper passes config unchanged.
%
% ORDER OF THE TAGS MATTERS
% The grid goes AFTER the regime, not before. paired_batch/local_label finds
% the regime with contains(fname, ['_' regime '_']), and files already on disk
% start with <varName>_<regime>_. Appending keeps that prefix intact, so files
% written before and after this change are both still parsed correctly.
%
% MIXED FOLDERS ARE EXPECTED FOR A WHILE
% Files written before this change have no grid tag. Treat an untagged file as
% the grid recorded in sweep_manifest.txt (written by run_all_sweeps), or as
% 'common' if it predates the manifest.
%
% R.T. Sirmen harness, 2026

   fprintf('\nSaving results, please wait...');

   % Step 1: burst regime. Shared with saveCrossCorrelationResults.m so the
   % two save paths can never drift apart.
   burstType = burstRegimeTag(config);

   % Step 2: grid mode. Optional, so an older config without the field still
   % saves - it just saves under the old, ambiguous name.
   gridTag = '';
   if isfield(config, 'gridMode') && ~isempty(config.gridMode)
      gridTag = char(config.gridMode);
      % Guard against a value that would corrupt a filename.
      gridTag = regexprep(gridTag, '[^A-Za-z0-9]', '');
   end

   if isempty(gridTag)
      tagPart = burstType;
      fprintf('\n  (config.gridMode not set - saving without a grid tag)');
   else
      tagPart = sprintf('%s_%s', burstType, gridTag);
   end

   % Step 3: hand each variable to the engine.
   erM_total = "";
   for i = 1:numel(varargin)
      varName = inputname(i + 1);      % caller workspace name
      if isempty(varName)
         varName = sprintf('var%d', i);
      end

      baseFileName = sprintf('%s_%s', varName, tagPart);

      try
         erM = saveVars_YMD(config.dataSavePath, 'mat', baseFileName, varargin{i});

         if erM ~= ""
            erM_total = strcat(erM_total, "\n", erM);
         else
            fprintf('\nVariable saved successfully: %s', baseFileName);
         end
      catch ME
         fprintf('\nError saving %s: %s', varName, ME.message);
      end
   end

   if erM_total == ""
      fprintf('\nAll files saved successfully to %s\n', config.dataSavePath);
   else
      fprintf('\nSome errors occurred during save: %s\n', erM_total);
   end

   % Identifying string for the caller: regime plus grid, so a caller that
   % logs verStr logs something that identifies the run.
   verStr = tagPart;
end
