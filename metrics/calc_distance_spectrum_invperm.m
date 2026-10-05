function [edges, counts] = calc_distance_spectrum_invperm(perm, numPairs, numBins)
% computes histogram of sqrt((i-j)^2 + (pos(i)-pos(j))^2) for random pairs

if nargin < 2 || isempty(numPairs), numPairs = 20000; end
if nargin < 3 || isempty(numBins), numBins = 200; end

N = numel(perm);
pos = zeros(1,N); pos(perm) = 1:N;

iIdx = randi(N, numPairs, 1);
jIdx = randi(N, numPairs, 1);
mask = iIdx ~= jIdx;
iIdx = iIdx(mask); jIdx = jIdx(mask);
d = sqrt( (iIdx - jIdx).^2 + (pos(iIdx) - pos(jIdx)).^2 );

edges = linspace(0, max(d), numBins);
counts = histcounts(d, edges, 'Normalization','probability');
end
