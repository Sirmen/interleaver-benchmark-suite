function S = calc_spread_factor_invperm(perm, varargin)
% Defines the "forbidden zone" for symbol clustering. (Tacheshita)  
% Uses pos(i) = invperm mapping: coordinate (i,pos(i))
N = numel(perm);
pos = zeros(1,N); pos(perm) = 1:N;

% options
opts.sample = [];   % if empty -> exact
if ~isempty(varargin)
    for k=1:2:numel(varargin)
        if strcmp(varargin{k},'sample'), opts.sample = varargin{k+1}; end
    end
end

if isempty(opts.sample) || opts.sample >= N
    % EXACT. Same answer as the old O(N^2) double scan, without the scan.
    % --------------------------------------------------------------------
    % Profiled at 0.928 s over 360 calls (2.6 ms each) - 19%% of a trial, and
    % it runs once per method per trial.
    %
    % The quantity is the minimum over pairs of
    %       d(i,j) = sqrt( (i-j)^2 + (pos(i)-pos(j))^2 )
    % The old code looped over i and compared against every j > i. But d
    % depends on the pair only through the horizontal gap dgap = |i-j| and the
    % vertical gap |pos(i)-pos(j)|, and it is increasing in both. So sweep by
    % HORIZONTAL GAP instead of by row:
    %
    %   for a fixed dgap, the best pair is the one whose vertical gap is
    %   smallest, and that is one vectorised min over the whole array;
    %
    %   once dgap reaches the running minimum S, every remaining gap gives
    %   d >= dgap >= S and cannot improve it - so the sweep stops.
    %
    % That is ceil(S) vectorised passes instead of N-1 loop iterations. For a
    % permutation with spread S the cost is O(N*S) with no interpreter
    % overhead per row, and S is small for exactly the permutations that used
    % to be slowest to reject.
    %
    % An earlier attempt kept the row loop and merely capped its inner range.
    % It gave the right answer but only 1.5x, because at that point the loop
    % overhead itself - 1679 iterations doing two comparisons each - was the
    % cost. Removing the loop is what matters, not shrinking its body.
    S = Inf;
    dgap = 1;
    while dgap < S && dgap < N
        vgap = min(abs(pos(1+dgap:N) - pos(1:N-dgap)));
        cand = sqrt(dgap^2 + vgap^2);
        if cand < S, S = cand; end
        dgap = dgap + 1;
    end
else
    % sample pairs of indices (nonzero pairs)
    M = opts.sample;
    idx = randperm(N, min(N, max(2,M)));
    S = inf;
    P = pos(idx);
    for a = 1:numel(idx)-1
        jj = (a+1):numel(idx);
        di = sqrt( (idx(a) - idx(jj)).^2 + (P(a) - P(jj)).^2 );
        S = min(S, min(di));
    end
end
end
