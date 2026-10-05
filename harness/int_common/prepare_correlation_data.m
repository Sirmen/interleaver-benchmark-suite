function correlation_data = prepare_correlation_data(results, config)
% Extract and flatten all metrics for correlation analysis
% Works with results.stats_all structure where each entry is a stats struct
%
% Input: results structure (not just stats_all)

    correlation_data = struct();
    
    % Check if we have the stats_all field in results
    if ~isfield(results, 'stats_all') || isempty(results.stats_all)
        warning('results.stats_all is empty - no correlation data to prepare');
        return;
    end
    
    stats_all = results.stats_all;
    
    % Determine structure type
    if isstruct(stats_all) && length(stats_all) == 1
        % Case 1: stats_all is a single struct with method-named fields
        % e.g., stats_all.random, stats_all.cross, stats_all.S
        % Each field contains either stats structs OR permutation arrays
        
        methods = fieldnames(stats_all);
        fprintf('Structure type: Method-named fields\n');
        fprintf('Methods found: %s\n', strjoin(methods, ', '));
        
        % Check what's in the first method field
        firstMethodData = stats_all.(methods{1});
        
        if isstruct(firstMethodData)
            % It's a struct array - good!
            fprintf('Data type: Stats structures ✓\n');
            correlation_data = extractFromMethodFieldsStructure(stats_all, methods);
        else
            % It's raw data (permutations) - wrong structure
            error('stats_all contains raw data, not stats structures. Check data flow.');
        end
        
    elseif isstruct(stats_all) && length(stats_all) > 1
        % Case 2: stats_all is an array of structs with .method field
        % e.g., stats_all(1).method = 'random', stats_all(2).method = 'cross'
        
        fprintf('Structure type: Struct array with .method field\n');
        fprintf('Total records: %d\n', length(stats_all));
        
        if isfield(stats_all, 'method')
            methods = unique({stats_all.method});
            fprintf('Methods found: %s\n', strjoin(methods, ', '));
            correlation_data = extractFromStructArray(stats_all);
        else
            error('stats_all is a struct array but missing .method field');
        end
        
    else
        error('Unrecognized stats_all structure');
    end
    
    % Report summary
    fprintf('\n=== Correlation Data Summary ===\n');
    availableVars = fieldnames(correlation_data);
    fprintf('Total variables extracted: %d\n', length(availableVars));
    
    if ~isempty(availableVars)
        firstVar = availableVars{1};
        numObs = length(correlation_data.(firstVar));
        fprintf('Observations per variable: %d\n', numObs);
        
        % Check which requested variables are available
        missingVars = setdiff(config.correlationVariables, availableVars);
        availableRequestedVars = intersect(config.correlationVariables, availableVars);
        
        fprintf('Variables requested: %d\n', length(config.correlationVariables));
        fprintf('Variables available: %d\n', length(availableRequestedVars));
        
        if ~isempty(missingVars)
            fprintf('\n⚠ Missing variables (%d):\n', length(missingVars));
            for i = 1:min(10, length(missingVars))
                fprintf('  - %s\n', missingVars{i});
            end
            if length(missingVars) > 10
                fprintf('  ... and %d more\n', length(missingVars) - 10);
            end
        end
    end
    
    fprintf('================================\n\n');
end

function correlation_data = extractFromMethodFieldsStructure(stats_all, methods)
% Extract from structure like: stats_all.random(i), stats_all.cross(i), etc.

    correlation_data = struct();
    
    % Get field names from first method's first entry
    firstMethodData = stats_all.(methods{1});
    if isempty(firstMethodData)
        warning('No data for method %s', methods{1});
        return;
    end
    
    statsFields = fieldnames(firstMethodData(1));
    fprintf('Found %d fields in stats structure\n', length(statsFields));
    
    % Skip non-numeric fields
    skipFields = {'method', 'noiseLocations', 'burstConfig', 'permutation', ...
                 'separationsNormalized', 'separations', 'adjDistances'};
    
    % Collect all numeric scalar fields across all methods
    for fieldIdx = 1:length(statsFields)
        fieldName = statsFields{fieldIdx};
        
        if ismember(fieldName, skipFields)
            continue;
        end
        
        fieldValues = [];
        
        % Iterate through all methods
        for m = 1:length(methods)
            methodName = methods{m};
            
            if ~isfield(stats_all, methodName)
                continue;
            end
            
            methodStats = stats_all.(methodName);
            
            % Iterate through all runs for this method
            for i = 1:length(methodStats)
                if isfield(methodStats(i), fieldName)
                    val = methodStats(i).(fieldName);
                    
                    % Only keep numeric scalar values
                    if isnumeric(val) && isscalar(val) && isfinite(val)
                        fieldValues(end+1) = val;
                    end
                end
            end
        end
        
        % Store if we got valid data (need at least 3 points for correlation)
        if ~isempty(fieldValues) && length(fieldValues) >= 3
            correlation_data.(fieldName) = fieldValues;
        end
    end
    
    % Add method as a categorical variable (encoded as numeric)
    methodLabels = [];
    for m = 1:length(methods)
        methodName = methods{m};
        if isfield(stats_all, methodName)
            methodStats = stats_all.(methodName);
            methodLabels = [methodLabels, repmat(m, 1, length(methodStats))];
        end
    end
    
    if ~isempty(methodLabels)
        correlation_data.methodID = methodLabels;
    end
end

function correlation_data = extractFromStructArray(stats_all)
% Extract from array structure like: stats_all(i).method, stats_all(i).eccAwareScore, etc.

    correlation_data = struct();
    
    statsFields = fieldnames(stats_all);
    fprintf('Found %d fields in stats structure\n', length(statsFields));
    
    % Skip non-numeric fields
    skipFields = {'method', 'noiseLocations', 'burstConfig', 'permutation', ...
                 'separationsNormalized', 'separations', 'adjDistances'};
    
    % Collect all numeric scalar fields
    for fieldIdx = 1:length(statsFields)
        fieldName = statsFields{fieldIdx};
        
        if ismember(fieldName, skipFields)
            continue;
        end
        
        fieldValues = [];
        
        % Iterate through all records
        for i = 1:length(stats_all)
            if isfield(stats_all(i), fieldName)
                val = stats_all(i).(fieldName);
                
                % Only keep numeric scalar values
                if isnumeric(val) && isscalar(val) && isfinite(val)
                    fieldValues(end+1) = val;
                end
            end
        end
        
        % Store if we got valid data
        if ~isempty(fieldValues) && length(fieldValues) >= 3
            correlation_data.(fieldName) = fieldValues;
        end
    end
    
    % Add method as a categorical variable
    if isfield(stats_all, 'method')
        methods = {stats_all.method};
        uniqueMethods = unique(methods);
        methodMap = containers.Map(uniqueMethods, 1:length(uniqueMethods));
        
        methodLabels = zeros(1, length(stats_all));
        for i = 1:length(stats_all)
            methodLabels(i) = methodMap(stats_all(i).method);
        end
        
        correlation_data.methodID = methodLabels;
    end
end
