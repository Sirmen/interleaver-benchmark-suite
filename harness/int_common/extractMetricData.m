function data = extractMetricData(stats_all, methods, metricName)
% Extract metric data for all methods - handles array structure
try
    nMethods = length(methods);
    data = zeros(1, nMethods);
    
    for i = 1:nMethods
        method = methods{i};
        methodStats = getMethodStats(stats_all, method);
        
        if ~isempty(methodStats) && isfield(methodStats(1), metricName)
            values = [methodStats.(metricName)];
            data(i) = mean(values(~isnan(values) & ~isinf(values)));
        end
    end
catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
    fprintf(strcat('\n ** ', erM, '\n'));
end
end
