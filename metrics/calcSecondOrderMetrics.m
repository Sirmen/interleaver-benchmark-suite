function metrics = calcSecondOrderMetrics(perm)
% Second-order dispersion metrics (Sun & Takeshita 2005)
    N = length(perm);
    
    % Second-order differences (for Lambda metrics)
    d = diff(perm);
    dd = diff(d);
    absDD = abs(dd);
    
    % Lambda metrics (based on second derivatives)
    metrics.lambdaMin = min(absDD);
    metrics.lambdaAvg = mean(absDD);
    
    % TRUE Triangle Metric (T-Metric) - measures triangle inequality violations
    % Build distance matrix between error positions
    distMatrix = zeros(N, N);
    for i = 1:N
        for j = i+1:N
            distMatrix(i,j) = abs(perm(i) - perm(j));
            distMatrix(j,i) = distMatrix(i,j);
        end
    end
    
    % Check triangle inequality for all triplets
    maxViolation = 0;
    for i = 1:N
        for j = i+1:N
            for k = j+1:N
                % Triangle inequality: d(i,k) <= d(i,j) + d(j,k)
                violation = abs(distMatrix(i,k) - (distMatrix(i,j) + distMatrix(j,k)));
                maxViolation = max(maxViolation, violation);
            end
        end
    end
    
    metrics.triangleMetric = maxViolation / N;  % Normalized T-Metric
end
