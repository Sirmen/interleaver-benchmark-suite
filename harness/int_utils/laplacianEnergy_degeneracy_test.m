% LE_DEGENERACY_TEST  Lemma 4, checked numerically.
%
% calcLaplacianEnergy builds a graph with an edge between perm(i) and
% perm(i+1). Because every value occurs exactly once in a permutation, that
% graph is a Hamiltonian path on N vertices for EVERY permutation: degree 2
% everywhere except the two endpoints, and no repeated edge. Hence
%
%     tr(L^2) = [4(N-2) + 2] + 2(N-1) = 6N - 8,   LE = (6N - 8) / N^2
%
% independent of the permutation. This script checks the closed form against
% the implementation over the identity, the reversal, a rotation and random
% permutations, at five lengths including one odd. One distinct value per
% length, equal to the formula, is the expected result.
%
% Runs in both MATLAB and Octave: no merge(), no uniquetol(), no string().
% The first version used merge(), an Octave built-in with no MATLAB
% equivalent - a test that proves an implementation-independent result should
% not itself depend on the interpreter.

fprintf('\n=== LE DEGENERACY TEST  (Lemma 4) ===\n');
fprintf('%6s %10s %12s %16s %16s %8s\n', ...
        'N', 'distinct', 'spread', 'measured', '(6N-8)/N^2', 'match');
fprintf('%s\n', repmat('-', 1, 74));

allExact = true;
for N = [6 50 300 1200 1201]
   vals = zeros(1, 200);
   for k = 1:200
      switch mod(k, 4)
         case 0, p = randperm(N);      % random
         case 1, p = 1:N;              % identity
         case 2, p = N:-1:1;           % reversal
         case 3, p = [2:N 1];          % rotation
      end
      vals(k) = calcLaplacianEnergy(p);
   end

   % Distinct count without uniquetol: scale, then round to 12 digits.
   sc = max(abs(vals)); if sc == 0, sc = 1; end
   nDist = numel(unique(round(vals / sc * 1e12)));

   pred   = (6 * N - 8) / N^2;
   spread = max(vals) - min(vals);
   exact  = (spread == 0) && (abs(vals(1) - pred) < 1e-12 * max(1, abs(pred)));
   if exact, tag = 'EXACT'; else, tag = 'NO'; allExact = false; end

   fprintf('%6d %10d %12.3e %16.10f %16.10f %8s\n', ...
           N, nDist, spread, vals(1), pred, tag);
end

fprintf('%s\n', repmat('-', 1, 74));
if allExact
   fprintf(['Every permutation of a given length returns the same value, equal to\n' ...
            'the closed form. The metric cannot rank interleavers at a fixed N,\n' ...
            'and the association reported for it is with the frame length.\n\n']);
else
   fprintf(2, ['At least one length disagreed with the closed form. Either the\n' ...
               'implementation on the path is not the one Lemma 4 describes, or\n' ...
               'the lemma is wrong. Resolve before quoting either.\n\n']);
end
