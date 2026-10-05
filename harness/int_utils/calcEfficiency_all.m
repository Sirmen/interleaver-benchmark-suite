function [efficiency_t, erM] = calcEfficiency_all(...
    methods, decErrRate_t, errRate_woInt, noiseRatio_all)
%  efficiency_t: (errRate_woInt - decErrRate_t.(method)) / noiseRatio_all.(method)
erM = "";
try
    % methods = fieldnames(decErrRate_t);
    
    for i = 1:length(methods)
        method = methods{i};
        
        % Handle NaN values
        if isnan(decErrRate_t.(method))
            erM = "Error in  calcEfficiency_all: decErrRate_t has NaN value(s)"; return;
        end
        
        if isnan(errRate_woInt)
            erM = "Error in  calcEfficiency_all: errRate_woInt has NaN value(s)"; return;
        end
        
        if isnan(noiseRatio_all.(method))
            erM = "Error in  calcEfficiency_all: noiseRatio_all has NaN value(s)"; return;
        end
        
        % Calculate efficiency
        if noiseRatio_all.(method) > 0
            efficiency_t.(method) = (errRate_woInt - decErrRate_t.(method)) / noiseRatio_all.(method);
        else
            efficiency_t.(method) = 0;
        end
        
        % Final NaN check
        if isnan(efficiency_t.(method))
            efficiency_t.(method) = 0;
        end
    end
catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end
