function formattedNames = formatMetricNames(names)
    % Format metric names for professional scientific publication
    % Supports Greek symbols and automatic subscripting for underscores
    
    if ischar(names), names = {names};
    elseif isstring(names), names = cellstr(names); end
    
    formattedNames = cell(size(names));
    for i = 1:length(names)
        name = names{i};
        
        % 1. Remove technical prefixes
        name = strrep(name, 'Method=', '');
        
        % 2. GREEK SYMBOLS (TeX Format)
        % Note: Using \ instead of Unicode to support all interpreters
        greekVars = {'alpha','beta','gamma','delta','epsilon','zeta','eta',...
                     'theta','lambda','mu','pi','rho','sigma','tau','phi','omega'};
        for g = 1:length(greekVars)
            name = strrep(name, greekVars{g}, ['\' greekVars{g}]);
        end
        % Uppercase Greek
        name = strrep(name, 'Delta', '\Delta');
        name = strrep(name, 'Sigma', '\Sigma');
        name = strrep(name, 'Omega', '\Omega');

        % 3. SUBSCRIPT & SUPERSCRIPT LOGIC
        % If name contains '_', wrap following text in _{ }
        % Example: Enhanced_Helical -> Enhanced_{Helical}
        if contains(name, '_')
            parts = strsplit(name, '_');
            % Subscript the second part
            name = sprintf('%s_{%s}', parts{1}, strjoin(parts(2:end), '_'));
        end
        
        % 4. SPECIAL KPI OVERRIDES
        name = strrep(name, 'S_{factor}', 'S-Factor');
        name = strrep(name, 'S_ECC', 'S_{ECC}');
        name = strrep(name, 'S_{ECC_norm}', 'S_{ECCnorm}');
        name = strrep(name, 'sepMin', 'Min_{sep}');
        name = strrep(name, 'sepAvg', '\mu_{sep}');
        name = strrep(name, 'adjMin', 'Min_{adj}');
        name = strrep(name, 'adjAvg', '\mu_{adj}');
        name = strrep(name, 'adjCV', 'CV_{adj}'); 
        name = strrep(name, '\delta_{BS}', '\Delta_{BS}');
        name = strrep(name, '\delta_{G}', '\Delta_{G}');

        name = strrep(name, 'eccViolations', 'V_{ECC}');
        name = strrep(name, 'eccUtilization', 'U_{ECC}');

        name = strrep(name, 'laplacianEnergy', 'LE');
        name = strrep(name, 'effectiveness', 'Effectiveness');
        name = strrep(name, 'noiseActual', 'Noise_{Actual}');
        name = strrep(name, 'effectiveness', 'Effectiveness');

        formattedNames{i} = name;
    end
end
