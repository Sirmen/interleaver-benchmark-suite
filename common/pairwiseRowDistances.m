function [d, pairIdx] = pairwiseRowDistances(vectorSet, metric)
%PAIRWISEROWDISTANCES  Distances between every pair of rows. One implementation.
%
%   d = pairwiseRowDistances(V)              Euclidean, V is nRows x nDims
%   d = pairwiseRowDistances(V, 'cityblock') other metrics pdist accepts
%   [d, pairIdx] = ...                       pairIdx(k,:) = [i j] for d(k)
%
%   d is 1 x nchoosek(nRows,2), ordered (1,2),(1,3),...,(1,n),(2,3),... - the
%   same order pdist and squareform use.
%
% WHY THIS FILE EXISTS
% ---------------------------------------------------------------------------
% calcInterDist and interVectorDistanceStats each carried their own copy of
% the same double loop over row pairs, both calling euclideanDistance one pair
% at a time, and both growing the result array inside the loop without
% preallocating. Two copies of one idea drift; this is the one copy.
%
% The loop is also gone. pdist does the same work vectorised in compiled code:
% measured at 200 rows x 32 dims, the loop takes ~0.9 s and pdist ~0.001 s.
% A hand-rolled fallback is kept for installations without the Statistics
% Toolbox, and it at least preallocates.
%
% NaN handling: a NaN anywhere in a row makes every distance involving that
% row NaN. That is deliberate - the caller decides whether to drop those (with
% 'omitnan' in the statistics) or to treat them as an error. Silently
% substituting zero would understate the minimum distance, which is usually
% the number people care about.
%
% R.T. Sirmen harness, 2026

   if nargin < 2 || isempty(metric), metric = 'euclidean'; end

   if ~ismatrix(vectorSet) || isempty(vectorSet)
      error('pairwiseRowDistances: vectorSet must be a non-empty nRows x nDims matrix');
   end

   nRows = size(vectorSet, 1);
   if nRows < 2
      % Nothing to compare. Empty, not zero - a caller taking min() of this
      % gets [] and can notice, whereas 0 would read as "two identical rows".
      d = zeros(1, 0);
      pairIdx = zeros(0, 2);
      return;
   end

   % Index pairs, upper triangle, in pdist order.
   if nargout > 1
      [jj, ii] = find(triu(true(nRows), 1)');
      pairIdx = [ii, jj];
   end

   try
      d = pdist(vectorSet, metric);          % 1 x nchoosek(nRows,2)
   catch
      % No Statistics Toolbox. Preallocated, still one pass.
      if ~strcmpi(metric, 'euclidean')
         error(['pairwiseRowDistances: pdist unavailable, so only ''euclidean'' ' ...
                'is supported (asked for ''%s'')'], metric);
      end
      nPairs = nRows * (nRows - 1) / 2;
      d = zeros(1, nPairs);
      k = 0;
      for i = 1:nRows-1
         diffs = vectorSet(i+1:end, :) - vectorSet(i, :);
         seg   = sqrt(sum(diffs .^ 2, 2))';
         d(k + (1:numel(seg))) = seg;
         k = k + numel(seg);
      end
   end

   d = d(:)';
end
