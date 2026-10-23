function [primes_table, factors_table, erM] = PrimeFactorLoader(dataDir)
    % Load prime and factor data with persistent storage
    persistent loaded_primes loaded_factors loaded_dir
    
    erM = "";
    primes_table = [];
    factors_table = [];

    try
        if nargin < 1
            dataDir = 'prime_factor_data';
        end

        % ---------------------------------------------------
        % RETURN CACHED VALUES WHEN AVAILABLE
        % ---------------------------------------------------
        if ~isempty(loaded_primes) && ~isempty(loaded_factors) && strcmp(loaded_dir, dataDir)
            primes_table  = loaded_primes;
            factors_table = loaded_factors;
            fprintf('Using cached primes & factors (from memory)\n');
            return;     % <-- THIS MUST BE HERE
        end
        
        fprintf('\nLoading primes & factors from disk:\n  %s\n', dataDir);

        % -------------------- load primes --------------------
        primes_file = fullfile(dataDir,'primes.bin');
        if exist(primes_file,'file')
            fid = fopen(primes_file,'rb');
            count = fread(fid,1,'uint32');
            primes_table = fread(fid,count,'uint32');
            fclose(fid);
        else
            erM = sprintf('PrimeFactorLoader: primes file missing:\n%s', primes_file);
            return;
        end

        % -------------------- load factors --------------------
        % -------------------- load factors --------------------
        % OPTIONAL, AND THE WARNING IS NOT DECORATION.
        %
        % factors.mat is a CACHE: the divisor pairs in it are computable, and
        % the three methods that receive the table - snake, algebraic and S -
        % each fall back to computing their own (interleaver_snake defaults
        % table_factors to struct() and does its own near-square
        % factorisation). So a missing table is not a reason to refuse to run,
        % and refusing made the published repository unable to start
        % metric_scorecard, since the file is 235 MB and cannot go in git.
        %
        % EQUIVALENCE IS MEASURED, NOT ASSUMED. verify_tablefree_equivalence
        % builds snake, algebraic and S twice at every length of the published
        % grid - once with this table and once with an empty one, table_primes
        % passed in both arms - and compares the permutations elementwise and
        % S's chosen L and K. Result: no difference, in any method at any
        % length. The check mattered: getFactorPairs reads a cache in one
        % branch and computes in the other, and if it returns empty
        % getLK_S_min falls through to findUniqueMultiplierPairs with the
        % multiplier floor at 2 instead of the 3 the harness passes, which
        % would have moved S's L and K without raising anything.
        %
        % The warning stays because the equivalence is verified ON THAT GRID,
        % not proved for every N.
        factors_file = fullfile(dataDir,'factors.mat');
        if exist(factors_file,'file')
            data = load(factors_file);
            factors_table = data.factor_data;
        else
            factors_table = struct();
            fprintf(2, ['PrimeFactorLoader: no factors.mat in\n  %s\n' ...
                        '  Continuing without it. The table is a cache of computable\n' ...
                        '  values; snake, algebraic and S derive their own, and\n' ...
                        '  verify_tablefree_equivalence found the two paths identical\n' ...
                        '  at every length of the published grid. At a length outside\n' ...
                        '  that grid, run that check before quoting parameters.\n'], dataDir);
        end

        % ---------------------------------------------------
        % STORE IN CACHE
        % ---------------------------------------------------
        loaded_primes  = primes_table;
        loaded_factors = factors_table;
        loaded_dir     = dataDir;

    catch ME
        erM = sprintf('%s: line %d\n%s', ME.stack(1).name, ME.stack(1).line, ME.message);
    end
end
