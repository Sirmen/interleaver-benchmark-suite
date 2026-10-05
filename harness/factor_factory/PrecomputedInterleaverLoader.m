%% ========================================================================
%% PrecomputedInterleaverLoader.m
%% Loads precomputed interleaver data with caching
%% ========================================================================

function [table, erM] = PrecomputedInterleaverLoader(dataDir)
% Load precomputed interleaver table with persistent caching
%
% INPUTS:
%   dataDir - directory containing 'table_factors_precomputed.mat'
%
% OUTPUTS:
%   table - struct containing:
%           .divs: containers.Map of divisors
%           .perms_XXX: containers.Map of permutations for each type
%   erM   - error message (empty if success)

persistent cache_table cache_dir

erM = "";
table = [];

try
    if nargin < 1
        dataDir = pwd;
    end
    
    % Return cached data if already loaded from this directory
    if ~isempty(cache_table) && strcmp(cache_dir, dataDir)
        table = cache_table;
        return;
    end
    
    % Load from file
    file = fullfile(dataDir, 'table_factors_precomputed.mat');
    
    if ~exist(file, 'file')
        erM = sprintf('Precomputed file not found:\n%s\n\nRun PrecomputeInterleaversGenerator first.', file);
        return;
    end
    
    fprintf('Loading precomputed interleavers from:\n  %s\n', file);
    
    data = load(file);
    
    if isfield(data, 'table')
        table = data.table;
    elseif isfield(data, 'precomputed_factors')
        % Support old format
        table = data.precomputed_factors;
    else
        erM = 'Invalid precomputed file format';
        return;
    end
    
    % Cache for next time
    cache_table = table;
    cache_dir = dataDir;
    
    fprintf('  Loaded successfully\n');
    
catch ME
    erM = sprintf('%s (line %d): %s', ...
        ME.stack(1).name, ME.stack(1).line, ME.message);
end

end
