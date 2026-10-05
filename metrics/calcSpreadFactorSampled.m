function S = calcSpreadFactorSampled(pos, sampleK)
    % Sampled 2D minimum distance (O(K))
    
    N = length(pos);
    sampleK = min(sampleK, N);
    idx = randperm(N, sampleK);
    P = pos(idx);
    S = Inf;
    
    for a = 1:sampleK-1
        jj = (a+1):sampleK;
        dx = idx(jj) - idx(a);
        dy = P(jj) - P(a);
        d = sqrt(dx.^2 + dy.^2);
        m = min(d);
        if m < S
            S = m;
        end
    end
    
    if isinf(S)
        S = 0;
    end
end
