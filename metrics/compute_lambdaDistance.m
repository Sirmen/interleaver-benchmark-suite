function lambdaMin = compute_lambdaDistance(perm)
% Lambda distance (2nd order spread)

N = length(perm);

d = diff(perm);
dd = diff(d);

lambdaMin = min(abs(dd)) / (N-1);
end
