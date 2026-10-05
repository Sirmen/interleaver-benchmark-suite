function adjStats = compute_adjacency_metrics(perm, varargin)
% compute_adjacency_metrics  Stats for adjacency (perm(j+1)-perm(j))
% Output fields analogous to sepStats for adjacency.

opts.normalize = true;
opts.bins = 50;
opts = parse_args(opts, varargin{:});

N = numel(perm);
adj = abs( perm(2:end) - perm(1:end-1) );   % length N-1
if opts.normalize
    adjNorm = adj ./ (N-1);
else
    adjNorm = adj;
end

adjStats.adj = adj;
adjStats.adjNorm = adjNorm;
adjStats.adjMin = min(adjNorm);
adjStats.adjMax = max(adjNorm);
adjStats.adjAvg = mean(adjNorm);
adjStats.CV_adj  = std(adjNorm) / (eps + mean(adjNorm));
adjStats.adjVar = var(adjNorm);
adjStats.adjUniformity = 1 - adjStats.CV_adj;
adjStats.Htrans = -sum( (histcounts(adjNorm, opts.bins, 'Normalization','probability') + eps) .* ...
                        log2(histcounts(adjNorm, opts.bins, 'Normalization','probability') + eps) );
end