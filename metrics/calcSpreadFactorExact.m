function S = calcSpreadFactorExact(pos)
    % Exact 2D minimum distance (O(N^2))
    
    N = length(pos);
    S = Inf;
    
    for i = 1:N-1
        j = (i+1):N;
        dx = j - i;
        dy = pos(j) - pos(i);
        d = sqrt(dx.^2 + dy.^2);
        m = min(d);
        if m < S
            S = m;
        end
        if S <= 1
            break;
        end
    end
    
    if isinf(S)
        S = 0;
    end
end
