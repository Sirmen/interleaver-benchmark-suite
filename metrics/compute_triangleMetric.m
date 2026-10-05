function T = compute_triangleMetric(perm)
% Triangle Metric: Sun & Takeshita, 2002

N = length(perm);

d = diff(perm);          % first derivative
dd = diff(d);            % second derivative

T = sum(abs(dd));

% Normalize to 0-1
T = T / (N-2);
end
