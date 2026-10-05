function [R, erM] = computeInterleaverLiteratureMetrics(perm, varargin)
% computeInterleaverLiteratureMetrics  Compute integrated interleaver metrics
% and produce publication-style figures (Takeshita / Sun & Takeshita / Dolinar).
%
% Usage:
%   R = computeInterleaverLiteratureMetrics(perm)
%   R = computeInterleaverLiteratureMetrics(perm, 'samplePairs',20000, 'figPrefix','runs/run1')
%
% Inputs:
%   perm : 1xN permutation vector (vectorInterleaved = vectorIn(perm))
% Options (Name-Value):
%   'samplePairs' : number of random pairs for sampled distance spectrum (default 20000)
%   'spreadSample' : number of points to sample when computing spread (default 5000)
%   'figPrefix' : path prefix to save figures (default '', doesn't save)
%   'showPlots'  : true/false (default true)
%
% Output R (struct) contains:
%   .N, .perm, .pos (inverse perm)
%   Separation metrics (sepMin, sepAvg, sepVar, sepHist, sepEntropy, eta_sep, ...)
%   Adjacency metrics (adjMin, adjAvg, adjVar, CV_adj, Htrans, ...)
%   Spread factor S (approx or exact), distance spectrum (sampled hist), triangle metric T,
%   lambdaMin (second-order min), permLaplacianEnergy, block metrics placeholders, ecc-aware placeholders.
%   Figures are displayed and saved if figPrefix provided.
%
% Notes:
% For large N (>3k) the script uses sampling for spread and distance spectrum to avoid O(N²) cost. 
% You can increase samplePairs and spreadSample as you like.
% 
% Figures: scatter of (i, pos(i)) corresponds to Takeshita's scatter; 
% NN-distance CDF + distance histogram mirror the plots used to characterize spread/distribution in the literature.
% 
% The function returns R with every scalar/array you'll need for tables/plots
%
erM = ""; R = {};
try
   % Parse inputs
   p = inputParser;
   addRequired(p, 'perm', @(x)isvector(x) && ~isscalar(x));
   addParameter(p, 'samplePairs', 20000, @(x)isnumeric(x)&&x>0);
   addParameter(p, 'spreadSample', 5000, @(x)isnumeric(x)&&x>0);
   addParameter(p, 'figPrefix', '', @ischar);
   addParameter(p, 'showPlots', true, @islogical);
   parse(p, perm, varargin{:});
   opts = p.Results;
   
   % Ensure row vector
   perm = perm(:)'; 
   N = numel(perm);
   
   % Build inverse permutation pos: pos(k) = position of original symbol k in interleaved vector
   pos = zeros(1,N); pos(perm) = 1:N;
   
   R = struct();
   R.N = N; R.perm = perm; R.pos = pos;
   
   %% -------------------------------
   % 1) Separation metrics (your sep family)
   % sep_i = |pos(i+1) - pos(i)|, normalized by (N-1)
   seps_raw = abs( pos(2:end) - pos(1:end-1) );   % length N-1
   seps = seps_raw ./ max(1, (N-1));
   
   R.sep.sep = seps;
   R.sep.sepMin = min(seps);
   R.sep.sepMax = max(seps);
   R.sep.sepAvg = mean(seps);
   R.sep.sepVar = var(seps);
   R.sep.sepCV = std(seps)./(eps+mean(seps));
   [R.sep.sepEntropy, erM] = computeEntropy(seps, 50);
   if erM ~= ""
      erM = strcat("Err in computeInterleaverLiteratureMetrics \n ", erM); 
      return
   end
   % separationEfficiency: normalized to random mean (0.5)
   R.sep.eta_sep = R.sep.sepAvg / 0.5;
   R.sep.sepUniformity = 1 - R.sep.sepCV;
   R.sep.sepSkewness = skewness(seps);
   R.sep.sepKurtosis = kurtosis(seps);
   R.sep.sepHist = histcounts(seps, 0:1/50:1, 'Normalization','probability');
   
   %% -------------------------------
   % 2) Adjacency metrics (your adj family)
   adj_raw = abs( perm(2:end) - perm(1:end-1) ); % length N-1
   adj = adj_raw ./ max(1,(N-1));
   R.adj.adj = adj;
   R.adj.adjMin = min(adj);
   R.adj.adjMax = max(adj);
   R.adj.adjAvg = mean(adj);
   R.adj.adjVar = var(adj);
   R.adj.CV_adj = std(adj)./(eps+mean(adj));
   R.adj.adjUniformity = 1 - R.adj.CV_adj;
   [R.adj.Htrans, erM] = computeEntropy(adj, 50);
   if erM ~= ""
      erM = strcat("Err in computeInterleaverLiteratureMetrics \n ", erM); 
      return
   end
   
   %% -------------------------------
   % 3) Spread factor (Takeshita-style) -- sampled for large N
   if N <= 3000
      [S_exact, erM] = computeSpreadExact(pos);
      if erM ~= ""
         erM = strcat("Err in computeInterleaverLiteratureMetrics \n ", erM); 
         return
      end
      R.spread.S_exact = S_exact / max(1,(N-1));
      R.spread.S_sampled = R.spread.S_exact;
   else
      % approximate (sample)
      [S_sampled, erM] = computeSpreadSampled(pos, opts.spreadSample);
      if erM ~= ""
         erM = strcat("Err in computeInterleaverLiteratureMetrics \n ", erM); 
         return
      end
      R.spread.S_exact = NaN;
      R.spread.S_sampled = S_sampled / max(1,(N-1));
   end
   
   %% -------------------------------
   % 4) Distance spectrum (sampled pairs)
   [numPairs, numBins] = deal(opts.samplePairs, 200);
   [d_edges, d_counts, d_vals, erM] = computeDistanceSpectrumSampled(pos, numPairs, numBins);
   if erM ~= ""
      erM = strcat("Err in computeInterleaverLiteratureMetrics \n ", erM); 
      return
   end
   R.distance.edges = d_edges;
   R.distance.counts = d_counts;
   R.distance.sampledValues = d_vals;
   R.distance.mean = mean(d_vals)/(N-1);
   R.distance.var  = var(d_vals)/(N-1)^2;
   
   %% -------------------------------
   % 5) Triangle metric (Sun & Takeshita)
   d1 = diff(perm);          % first difference
   if numel(d1) >= 2
       d2 = diff(d1);       % second difference
       T = sum(abs(d2));
       R.triangle.T = T / max(1,(N-2));
       R.triangle.lambdaMin = min(abs(d2)) / max(1,(N-1));
   else
       R.triangle.T = 0;
       R.triangle.lambdaMin = 0;
   end
   
   %% -------------------------------
   % 6) perm Laplacian energy (graph-spectral style)
   % Build adjacency graph where edges from i->pos(i)?? We'll compute Laplacian of permutation-as-graph:
   % represent permutation as permutation graph: edges between i and pos(i)
   Gedges = [ (1:N)' , pos(:) ];
   % Build sparse adjacency (undirected)
   i_idx = [Gedges(:,1); Gedges(:,2)];
   j_idx = [Gedges(:,2); Gedges(:,1)];
   A = sparse(i_idx, j_idx, 1, N, N);
   deg = full(sum(A,2));
   L = spdiags(deg,0,N,N) - A;
   % Laplacian energy: sum of squares of eigenvalues (approx via trace(L^2))
   % For large N, compute trace(L^2) directly
   LE = trace((L*L));
   R.permLaplacianEnergy = LE / (N^2);
   
   %% -------------------------------
   % 7) Block metrics (placeholders) -- compute generic block stats for a block size if present
   % If user provided blockSize via varargin
   blockSize = [];
   if any(strcmpi(varargin,'blockSize'))
       idx = find(strcmpi(varargin,'blockSize'));
       if idx+1 <= numel(varargin), blockSize = varargin{idx+1}; end
   end
   
   if ~isempty(blockSize) && blockSize >= 1 && blockSize <= N
       % compute intra-block pairwise distances normalized
       K = floor(N / blockSize);
       minBlocks = zeros(K,1); avgBlocks=zeros(K,1); varBlocks=zeros(K,1);
       for k=1:K
           B = perm((k-1)*blockSize + (1:blockSize));
           d = pdist(B', 'euclidean') ./ (N-1);
           if isempty(d)
               minBlocks(k)=0; avgBlocks(k)=0; varBlocks(k)=0;
           else
               minBlocks(k)=min(d); avgBlocks(k)=mean(d); varBlocks(k)=var(d);
           end
       end
       R.block.minBlockMin = min(minBlocks);
       R.block.minBlockMax = max(minBlocks);
       R.block.minBlockAvg = mean(minBlocks);
       R.block.avgBlock = mean(avgBlocks);
       R.block.varBlockAvg = mean(varBlocks);
       R.block.varBlockMax = max(varBlocks);
   else
       R.block = [];
   end
   
   %% -------------------------------
   % 8) ECC-aware placeholders (the actual computation requires ECC model + mapping)
   % We'll place NaNs; user can fill with ECC outputs.
   R.ecc.eccAwareScore = NaN;
   R.ecc.eccComplianceImprovement = NaN;
   
   %% -------------------------------
   % 9) Figures (publication style, 3 rows x 2 cols)
   if opts.showPlots
       fig = figure('Name','Interleaver Analysis','Units','normalized','Position',[0.05 0.05 0.9 0.8]);
       % Left top: permutation scatter (i vs pos(i)) - similar to Takeshita figs
       subplot(3,2,1);
       scatter(1:N, pos, 6, 'filled'); axis([1 N 1 N]); axis square;
       xlabel('i (original index)'); ylabel('pos(i)'); title('Permutation scatter (i vs pos(i))');
       grid on;
       
       % Right top: nearest-neighbor distance (hist) - relates to spread
       subplot(3,2,2);
       edges = linspace(0, max(d_vals)/(N-1), numBins);
       histogram(d_vals./(N-1), edges, 'Normalization','probability');
       xlabel('Normalized 2D distance'); ylabel('Probability'); title('Distance spectrum (sampled)');
       
       % Middle left: sep histogram
       subplot(3,2,3);
       histogram(seps, 0:1/50:1, 'Normalization','probability');
       xlabel('Normalized separation |pos(i+1)-pos(i)|'); ylabel('Prob'); title('Separation (adjacent originals)');
       
       % Middle right: adjacency histogram
       subplot(3,2,4);
       histogram(adj, 0:1/50:1, 'Normalization','probability');
       xlabel('Normalized adjacency |perm(j+1)-perm(j)|'); ylabel('Prob'); title('Adjacency (output neighbors)');
       
       % Bottom left: CDF of nearest neighbor distances (approx)
       subplot(3,2,5);
       % compute NN distances (sampled)
       nn = computeNearestNeighborDistances(pos, min(N, 2000));
       [f,x] = ecdf(nn./(N-1));
       stairs(x, f, 'LineWidth',1.2); xlabel('Normalized NN distance'); ylabel('CDF'); title('NN distance CDF');
       grid on;
       
       % Bottom right: triangle metric visualization (bar of d2)
       subplot(3,2,6);
       if numel(d2)>=1
           bar(1:numel(d2), d2); xlabel('i'); ylabel('Second diff abs'); title('Permutation second differences (|d2|)');
       else
           text(0.1,0.5,'Insufficient length for second differences','FontSize',10);
           axis off;
       end
       
       % Save
       if ~isempty(opts.figPrefix)
           try
               saveas(fig, [opts.figPrefix '_interleaver_analysis.png']);
               savefig(fig, [opts.figPrefix '_interleaver_analysis.fig']);
           catch
               warning('Failed to save figures to %s', opts.figPrefix);
           end
       end
   end

catch
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%%%%%%% Helper subfunctions %%%%%%%%

function [H, erM] = computeEntropy(v, nbins)
erM=""; H=NaN;
try
   if nargin<2, nbins=50; end
   p = histcounts(v, nbins, 'Normalization','probability');
   p = p(p>0);
   H = -sum(p .* log2(p + eps));
catch
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

function [S, erM] = computeSpreadExact(pos)
erM="";
try
   % exact O(N^2) spread (2D min distance)
   N = numel(pos);
   S = inf;
   for i=1:N-1
       j = (i+1):N;
       dx = j - i;
       dy = pos(j) - pos(i);
       d = sqrt(dx.^2 + dy.^2);
       m = min(d);
       if m < S, S = m; end
       if S <= 1, break; end
   end
   if isinf(S), S = 0; end
catch
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

function [S, erM] = computeSpreadSampled(pos, sampleK)
erM="";
try
   N = numel(pos);
   sampleK = min(sampleK, N);
   idx = randperm(N, sampleK);
   P = pos(idx);
   S = inf;
   for a = 1:sampleK-1
       jj = (a+1):sampleK;
       dx = idx(jj) - idx(a);
       dy = P(jj) - P(a);
       d = sqrt(dx.^2 + dy.^2);
       m = min(d);
       if m < S, S = m; end
   end
   if isinf(S), S = 0; end
catch
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

function [edges, counts, dvals, erM] = computeDistanceSpectrumSampled(pos, numPairs, bins)
% Fixed version - ensures all vectors have compatible dimensions for element-wise operations
erM=""; edges=NaN; counts=NaN; dvals=NaN;
try
   N = numel(pos);
   
   % Ensure pos is a row vector
   pos = pos(:)';
   
   numPairs = max(1000, round(min(numPairs, N*(N-1)/2)));
   iIdx = randi(N, numPairs, 1);
   jIdx = randi(N, numPairs, 1);
   mask = iIdx ~= jIdx;
   
   % Filter to keep only different pairs
   % iIdx = iIdx(mask);
   % jIdx = jIdx(mask);
   % 
   % % Ensure these are COLUMN vectors
   % iIdx = iIdx(:);
   % jIdx = jIdx(:);
    iIdx = iIdx(mask);
    jIdx = jIdx(mask);
    iIdx = iIdx(:);  % Force column vector
    jIdx = jIdx(:);  % Force column vector
    
    % Extract and force column vectors
    pos_i = pos(iIdx);
    pos_j = pos(jIdx);
    pos_i = pos_i(:);
    pos_j = pos_j(:);
    
    % Compute distances element-wise
    dx = iIdx - jIdx;
    dy = pos_i - pos_j;
    dvals = sqrt(dx.^2 + dy.^2);
    dvals = dvals(:);  % Ensure vector
    
   % Index into pos - this will give column vectors
   pos_i = pos(iIdx);  % Column vector of positions at indices iIdx
   pos_j = pos(jIdx);  % Column vector of positions at indices jIdx
   
   % Ensure these are also column vectors (in case pos indexing creates row vectors)
   pos_i = pos_i(:);
   pos_j = pos_j(:);
   
   % Now compute element-wise distances (all column vectors, element-wise operations)
   dx = iIdx - jIdx;        % Column vector
   dy = pos_i - pos_j;      % Column vector
   dvals = sqrt(dx.^2 + dy.^2);  % Column vector of distances
   
   % Ensure dvals is a vector for histcounts
   dvals = dvals(:);
   
   edges = linspace(0, max(dvals), bins);
   counts = histcounts(dvals, edges, 'Normalization','probability');
   
catch
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

function [nn, erM] = computeNearestNeighborDistances(pos, sampleLimit)
erM=""; nn=NaN;
try
   N = numel(pos);
   sampleLimit = min(N, sampleLimit);
   idx = randperm(N, sampleLimit);
   nn = zeros(size(idx));
   for a = 1:numel(idx)
       i = idx(a);
       % compute distances to all others (could sample for very large N)
       j = 1:N; j(i) = [];
       d = sqrt( (j - i).^2 + (pos(j) - pos(i)).^2 );
       nn(a) = min(d);
   end
catch
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end