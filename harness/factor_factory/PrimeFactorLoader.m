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
        factors_file = fullfile(dataDir,'factors.mat');
        if exist(factors_file,'file')
            data = load(factors_file);
            factors_table = data.factor_data;
        else
            erM = sprintf('PrimeFactorLoader: factors file missing:\n%s', factors_file);
            return;
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
