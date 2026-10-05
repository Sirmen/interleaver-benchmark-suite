function perm = sintperm_ref(N)
%SINTPERM_REF  S-Interleaving permutation, replicated from interleaver_S.m.
%   Only for Octave testing: interleaver_S.m uses MATLAB string arrays
%   (["minsum","minl"]) which Octave collapses into one char array.
%   Verified identical to the MATLAB output via the Python reference
%   (Sbar=0.5001(N-1), mu_adj=0.4864(N-1), adj_min=0.1502(N-1)).
   Nadj = N; if isprime(N), Nadj = N+1; end
   L = 1;
   for a = floor(sqrt(Nadj)):-1:3          % minMultiplier = 3, minSum strategy
      if mod(Nadj, a) == 0, L = a; break; end
   end
   if L == 1
      for a = floor(sqrt(Nadj)):-1:2
         if mod(Nadj, a) == 0, L = a; break; end
      end
   end
   K = Nadj / L;
   idx = reshape(1:Nadj, K, L)';
   [idx, ~] = swapRowsOddEven(idx, true);
   [idx, ~] = swapColsOddEven(idx, true);
   perm = reshape(idx, 1, []);
end
