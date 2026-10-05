function sepStats = compute_sep_metrics(perm, varargin)
% compute_sep_metrics  Compute separation metrics for permutation `perm`.
% Usage:
%   sepStats = compute_sep_metrics(perm)
%   sepStats = compute_sep_metrics(perm, 'normalize', true, 'bins', 50)
%
% Output fields (sepStats):
%   sep    : raw separation vector length N-1 (pos(i+1)-pos(i) absolute)
%   sepNorm: normalized sep (divide by N-1)
%   sepMin, sepMax, sepAvg
%   eta_sep   : meanSep / 0.5  (normalized to random mean 0.5)
%   sepUniformity   : 1 - (std/mean)  (higher=more uniform)
%   sepSkewness, sepKurtosis
%   Hsep            : entropy of binned sep distribution (bits)

opts.normalize = true;
opts.bins = 50;
opts = parse_args(opts, varargin{:}); % small helper below

N = numel(perm);
pos = zeros(1,N); pos(perm) = 1:N;

sep = abs( pos(2:end) - pos(1:end-1) );   % length N-1
if opts.normalize
    sepNorm = sep ./ (N-1);
else
    sepNorm = sep;
end

sepMin = min(sepNorm);
sepMax = max(sepNorm);
sepAvg = mean(sepNorm);

% Efficiency: normalized to random mean (random mapping mean ~ 0.5)
eta_sep = sepAvg / 0.5;

% Uniformity: using 1 - CV (coefficient of variation)
cv = std(sepNorm) / (eps + mean(sepNorm));
sepUniformity = 1 - cv;

% Higher moments
sepSkewness = skewness(sepNorm);
sepKurtosis = kurtosis(sepNorm);

% Entropy of binned distribution
[counts, edges] = histcounts(sepNorm, opts.bins, 'Normalization', 'probability');
counts(counts==0) = [];            % remove zeros for entropy
Hsep = -sum(counts .* log2(counts + eps));

sepStats.sep = sep;
sepStats.sepNorm = sepNorm;
sepStats.sepMin = sepMin;
sepStats.sepMax = sepMax;
sepStats.sepAvg = sepAvg;
sepStats.eta_sep = eta_sep;
sepStats.sepUniformity = sepUniformity;
sepStats.sepSkewness = sepSkewness;
sepStats.sepKurtosis = sepKurtosis;
sepStats.Hsep = Hsep;
sepStats.bins = edges;
sepStats.hist = counts;
end

%% small helper to parse name-value pairs
function opts = parse_args(defaults, varargin)
opts = defaults;
if isempty(varargin), return; end
for k=1:2:numel(varargin)
    if k+1>numel(varargin), break; end
    name = varargin{k}; val = varargin{k+1};
    if isfield(opts, name)
        opts.(name) = val;
    else
        opts.(name) = val;
    end
end
end