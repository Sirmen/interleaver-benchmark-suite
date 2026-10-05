function methodStats = getMethodStats(stats_all, methodName)
% Extract all stats for a specific method from the stats_all array
try
    if isempty(stats_all)
        methodStats = [];
        return;
    end
    
    methodName = char(methodName);
    allMethods = {stats_all.method};
    matchIdx = strcmp(allMethods, methodName);
    methodStats = stats_all(matchIdx);
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
   error(erM);
   methodStats = []; 
end
end
