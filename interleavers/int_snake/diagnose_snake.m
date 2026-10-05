%% diagnose_snake.m
% Ten seconds, one answer: why does paramsInt.permutations lack a method?
%
% Runs exactly the two steps run_simulations_sci runs - configure, interleave -
% and prints what came out, instead of letting the failure surface 200 lines
% later inside getDeintParams.
%
% R.T. Sirmen harness, 2026

clc; clear;

% Resolved rather than typed in; two outputs on purpose, and the folder is what
% gets tested (find_table_dir returns erM = "", and isempty("") is false).
[dataDir_PrimeFactor, ~] = find_table_dir();
if isempty(dataDir_PrimeFactor)
   dataDir_PrimeFactor = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data_PrimeFactor');
end

METHOD = 'snake';    % the method that went missing

%% ---------------------------------------------------------------
if exist('clearHarnessCaches','file') == 2, clearHarnessCaches(); end

[config, params] = configure_simulation();
fprintf('intMethods            : %s\n', strjoin(params.intMethods, ', '));

%% A. Is the interleaver file even on the path?
fprintf('\n--- A. FILES ---\n');
fprintf('interleaver_%s.m     : %s\n', METHOD, mat2str(exist(['interleaver_' METHOD], 'file') == 2));
fprintf('interleaver_generic_pc.m : %s\n', mat2str(exist('interleaver_generic_pc','file') == 2));
nBlocks = numel(strfind(fileread(which('interleave_all_pc')), ['''' METHOD '''']));
fprintf('interleave_all_pc mentions ''%s'' : %d times  (0 = stale file)\n', METHOD, nBlocks);

%% B. Is it in the table the sweep will actually load?
fprintf('\n--- B. TABLE ---\n');
[tpc, erM] = PrecomputedInterleaverLoader(char(dataDir_PrimeFactor));
if erM ~= "", error('loader: %s', erM); end
fld = ['perms_' METHOD];
if isfield(tpc, fld)
   fprintf('%-16s : %d entries\n', fld, tpc.(fld).Count);
   sweepLens = unique(ceil((config.sizeMin:config.sizeStep:config.sizeMax) / config.FECk) * config.FECn);
   miss = sweepLens(~cellfun(@(k) tpc.(fld).isKey(k), ...
                             arrayfun(@(n) sprintf('N_%d', n), sweepLens, 'UniformOutput', false)));
   if isempty(miss)
      fprintf('   every sweep length cached\n');
   else
      fprintf('   NOT cached (these run live): %s\n', mat2str(miss));
   end
else
   fprintf('%-16s : ABSENT - every length runs live\n', fld);
end

%% C. Run the interleave step for real, at one length
fprintf('\n--- C. INTERLEAVE ---\n');
[tp, tf, erM] = PrimeFactorLoader(char(dataDir_PrimeFactor));
if erM ~= "", error('PrimeFactorLoader: %s', erM); end
tables = struct('table_precomputed', tpc, 'table_primes', tp, 'table_factors', tf);

N = ceil(config.sizeMin / config.FECk) * config.FECn;   % first encoded length
encoded = randi([0 config.base-1], 1, N);
L = estimate_L_for_size(N);
paramsInt = configure_interleaver_params(params, config, encoded, params.intMethods, L, ceil(N/L), tables);
paramsInt.encoded = encoded;

[interleaved_all, permutation_all, paramsIntOut, erM] = ...
   interleave_all_pc(params.intMethods, paramsInt, tables);

fprintf('N                     : %d\n', N);
fprintf('erM                   : [%s]\n', char(erM));
if isstruct(paramsIntOut) && isfield(paramsIntOut, 'permutations')
   got = fieldnames(paramsIntOut.permutations);
   fprintf('permutations written  : %s\n', strjoin(got', ', '));
   missing = setdiff(params.intMethods, got');
   if isempty(missing)
      fprintf('\n>>> ALL METHODS OK at N=%d. The failure is length-dependent -\n', N);
      fprintf('    re-run this with config.sizeMin raised, or read the erM that\n');
      fprintf('    run_simulations_sci prints just before the getDeintParams line.\n');
   else
      fprintf('\n>>> MISSING: %s\n', strjoin(missing, ', '));
      fprintf('    erM above is empty, so no block reported a failure - which means\n');
      fprintf('    no block MATCHED. Check section A: interleave_all_pc has no case\n');
      fprintf('    for this name.\n');
   end
else
   fprintf('permutations          : NONE - not one method produced output\n');
end

%% D. The single call, isolated
fprintf('\n--- D. ISOLATED CALL ---\n');
[y, p, Lo, Ko, Qo, Ro, erM] = interleaver_generic_pc( ...
      encoded, METHOD, config.padSymbol, config.maxExtensionPercentage, ...
      tpc, paramsInt.permutationSeed, tp, tf, paramsInt);
fprintf('erM                   : [%s]\n', char(erM));
fprintf('perm length           : %d  (input %d)\n', numel(p), N);
if ~isempty(p)
   fprintf('valid permutation     : %s\n', mat2str(numel(unique(p)) == numel(p)));
   fprintf('identity?             : %s\n', mat2str(isequal(p(:).', 1:numel(p))));
end
