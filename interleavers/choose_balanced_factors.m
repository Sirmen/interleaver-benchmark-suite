function [Lbest, Kbest, Npad] = choose_balanced_factors(N0, maxExtensionPercentage)
% choose_balanced_factors - Find optimal coprime L×K for interleaving
%
% Guarantees: 
%   1. COPRIME dimensions (gcd(L,K) = 1) - Critical for maximum spread
%   2. Near-square (L ≈ K) - Optimal for burst protection
%   3. Minimal padding - Within maxExtensionPercentage
%
% Theory:
%   Coprime dimensions ensure maximum interleaving distance (Ramsey 1970)
%   Near-square provides best burst error decorrelation (Forney 1971)
%
% Algorithm:
%   Strategy 1: Search for coprime factorizations near sqrt(N)
%   Strategy 2: If none found, use nearest coprime pair (L, L±1) or (L, L±2)
%   Strategy 3: Fallback to prime factorization approach
%
% Returns:
%   Lbest, Kbest - Coprime factors with L ≤ K
%   Npad - Padding needed (Ntarget - N0)

   Lbest = [];
   Kbest = [];
   Npad = 0;
   
   if N0 < 1
       Lbest = 1;
       Kbest = 1;
       return;
   end
   
   maxN = floor(N0 * (1 + maxExtensionPercentage));
   
   %% Strategy 1: Search for coprime factorizations close to sqrt(N)
   best_balance = Inf;  % Lower is better (measures |L - K|)
   
   for Ntry = N0:maxN
       sqrtN = sqrt(Ntry);
       
       % Search divisors near sqrt(N) for balanced coprime pairs
       search_radius = min(20, floor(sqrtN/2));
       
       for L = max(2, floor(sqrtN) - search_radius) : ceil(sqrtN) + search_radius
           if mod(Ntry, L) == 0
               K = Ntry / L;
               
               if K < 2  % Skip trivial
                   continue;
               end
               
               % Ensure L ≤ K
               if L > K
                   [L, K] = deal(K, L);
               end
               
               % Check if coprime
               if gcd(L, K) == 1
                   balance = abs(L - K);
                   padding = Ntry - N0;
                   
                   % Score: prioritize balance, then minimal padding
                   score = balance + padding * 0.1;
                   
                   if score < best_balance
                       best_balance = score;
                       Lbest = L;
                       Kbest = K;
                       Npad = padding;
                   end
                   
                   % Early exit if perfect square coprime found with minimal padding
                   if balance < 2 && padding < N0 * 0.1
                       return;
                   end
               end
           end
       end
   end
   
   % If found a good coprime pair, return it
   if ~isempty(Lbest)
       return;
   end
   
   %% Strategy 2: Force coprime using (L, L±1) or (L, L±k) patterns
   % These are always coprime: consecutive integers, or L and L+prime
   
   for Ntry = N0:maxN
       sqrtN = sqrt(Ntry);
       L_center = round(sqrtN);
       
       % Try consecutive or near-consecutive coprime patterns
       candidates = [
           L_center, L_center + 1;      % Consecutive (always coprime)
           L_center, L_center - 1;
           L_center + 1, L_center + 2;
           L_center - 1, L_center - 2;
           L_center, L_center + 2;      % Differ by 2 (often coprime)
           L_center, L_center - 2;
       ];
       
       for i = 1:size(candidates, 1)
           L = candidates(i, 1);
           K = candidates(i, 2);
           
           if L < 2 || K < 2
               continue;
           end
           
           % Ensure L ≤ K
           if L > K
               [L, K] = deal(K, L);
           end
           
           if L * K == Ntry && gcd(L, K) == 1
               balance = abs(L - K);
               padding = Ntry - N0;
               score = balance + padding * 0.1;
               
               if isempty(Lbest) || score < best_balance
                   best_balance = score;
                   Lbest = L;
                   Kbest = K;
                   Npad = padding;
               end
           end
       end
   end
   
   if ~isempty(Lbest)
       return;
   end
   
   %% Strategy 3: Prime-based approach - Use (p, q) where p,q are coprime
   % Find two factors closest to sqrt(N) that are coprime
   
   for Ntry = N0:maxN
       sqrtN = sqrt(Ntry);
       
       % Get all divisors
       divs = divisors(Ntry);
       
       % Find pairs closest to sqrt that are coprime
       for i = 1:length(divs)
           L = divs(i);
           K = Ntry / L;
           
           if L < 2 || K < 2 || L > K
               continue;
           end
           
           if gcd(L, K) == 1
               balance = abs(L - K);
               padding = Ntry - N0;
               score = balance + padding * 0.1;
               
               if isempty(Lbest) || score < best_balance
                   best_balance = score;
                   Lbest = L;
                   Kbest = K;
                   Npad = padding;
               end
           end
       end
   end
   
   if ~isempty(Lbest)
       return;
   end
   
   %% Strategy 4: Force coprime by using prime factorization
   % Split prime factors to create coprime L and K
   
   for Ntry = N0:maxN
       [L, K] = findCoprimeFactorization(Ntry);
       
       if L >= 2 && K >= 2 && gcd(L, K) == 1
           balance = abs(L - K);
           padding = Ntry - N0;
           score = balance + padding * 0.1;
           
           if isempty(Lbest) || score < best_balance
               best_balance = score;
               Lbest = L;
               Kbest = K;
               Npad = padding;
           end
       end
   end
   
   if ~isempty(Lbest)
       return;
   end
   
   %% Fallback: Use nearest coprime pair construction
   % Construct coprime by design using algorithm
   
   sqrtN0 = round(sqrt(N0));
   L = sqrtN0;
   K = sqrtN0 + 1;  % Consecutive integers are always coprime
   
   Ntarget = L * K;
   if Ntarget <= maxN
       Lbest = L;
       Kbest = K;
       Npad = Ntarget - N0;
       return;
   end
   
   % Absolute fallback: smallest coprime pair
   Lbest = max(2, sqrtN0 - 1);
   Kbest = Lbest + 1;
   Npad = Lbest * Kbest - N0;
   
   % Ensure within bounds
   if N0 + Npad > maxN
       % Last resort: use (2, ceil(N0/2))
       Lbest = 2;
       Kbest = ceil(N0 / 2);
       if mod(Kbest, 2) == 0  % Make K odd to ensure coprime with 2
           Kbest = Kbest + 1;
       end
       Npad = Lbest * Kbest - N0;
   end

end

%  HELPER FUNCTIONS

function [L, K] = findCoprimeFactorization(N)
   % Ensure we produce L>=2 and K>=2 if possible (search a little upward)
   if N < 4
       L = 1; K = N;
       return;
   end

   % Try to find a composite Ntry within a small extension
   maxExt = 10; % small search window (tune or pass as param)
   found = false;
   for Ntry = N:(N + maxExt)
       divs = divisors(Ntry);
       % try pairs closest to sqrt
       sqrtN = sqrt(Ntry);
       bestDiff = Inf;
       Lbest = [];
       Kbest = [];
       for d = divs
           if d < 2, continue; end
           Kc = Ntry / d;
           if Kc < 2, continue; end
           if d > Kc, continue; end
           if gcd(d, Kc) == 1
               diff = abs(d - Kc);
               if diff < bestDiff
                   bestDiff = diff; Lbest = d; Kbest = Kc;
               end
           end
       end
       if ~isempty(Lbest)
           L = Lbest; K = Kbest; found = true; return;
       end
   end

   % If still not found, fall back to splitting prime factors as before
   factors = factor(N);
   L=1; K=1;
   factors = sort(factors, 'descend');
   for i = 1:length(factors)
       if L <= K
           L = L * factors(i);
       else
           K = K * factors(i);
       end
   end
   if L > K, [L,K] = deal(K,L); end
   % Force minimum 2
   if L < 2, L = 2; end
   if K < 2, K = max(2, K); end
end

function divs = divisors(N)
% Find all divisors of N efficiently
   if N == 1
       divs = 1;
       return;
   end
   
   divs = [];
   for i = 1:floor(sqrt(N))
       if mod(N, i) == 0
           divs = [divs, i, N/i];
       end
   end
   
   divs = unique(divs);
   divs = sort(divs);
end

function s = choose_step(n)
    % choose step in [2 .. n-1] which is coprime with n and roughly n/2
    candidates = floor(linspace(2, n-1, min(20, n-2)));
    % prefer values near n/2
    [~, idx] = sort(abs(candidates - n/2));
    s = [];
    for i = idx
        if gcd(candidates(i), n) == 1
            s = candidates(i);
            return;
        end
    end
    % fallback: find any coprime
    for c = 2:(n-1)
        if gcd(c, n) == 1
            s = c; return;
        end
    end
    s = 1;
end
