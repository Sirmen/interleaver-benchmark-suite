function R = verify_tablefree_equivalence(dataPath, tableDir, opts)
%VERIFY_TABLEFREE_EQUIVALENCE  Does dropping factors.mat change any permutation?
%
%   R = verify_tablefree_equivalence('<resultsDir>', '<tableDir>')
%   R = verify_tablefree_equivalence(..., struct('Nset', [36 180 1800]))
%
% WHY THIS EXISTS
% ---------------------------------------------------------------------------
% factors.mat is 235 MB, over GitHub's per-file limit, so it is archived with
% the data record rather than the code. PrimeFactorLoader therefore treats it
% as optional and derives what it needs when it is absent. That is only safe
% if the derived values equal the cached ones, and three methods are affected:
% interleaver_generic_pc passes the factor table to snake, algebraic and S and
% to nothing else.
%
% The risk is not hypothetical. getFactorPairs has two branches - read the
% cache, or compute with findUniqueMultiplierPairs - and its own header
% records that the two handle failure differently: the cache branch returns an
% empty matrix where the computing branch throws. Worse, if getFactorPairs
% comes back empty, getLK_S_min falls through to
%
%     findUniqueMultiplierPairs(adjustedN, 2)
%
% with the multiplier floor at 2, not the minMultiplier of 3 the harness
% passes. So a missing table could change S's L and K at some lengths without
% any error being raised, and S is the method this study is about.
%
% WHAT IS COMPARED
% ---------------------------------------------------------------------------
% For every length on the published grid, each of the three methods is built
% twice from the same inputs, the arms differing only in the factor table:
%
%     with     interleaver_X(..., table_primes, table_factors)
%     without  interleaver_X(..., table_primes, struct())
%
% table_primes is passed in BOTH arms. It comes from primes.bin, which is
% small and is in the repository, and isInPrimesTable decides whether N is
% carried to N+1 - a difference that has nothing to do with factors.mat and
% would otherwise be charged to it.
%
% The permutations are compared elementwise, and for S the chosen L and K are
% compared as well, because those are the parameters the provenance audit is
% about: equal permutations with different L and K would still mean the
% published parameter table is not what a table-free run reproduces.
%
% Nothing is written except the CSV, and no parameter is changed.
%
% R. Tanju Sirmen study.

   if nargin < 3, opts = struct(); end
   if nargin < 2 || isempty(tableDir), tableDir = ''; end
   pad = 0;
   mx  = 0.0;                          % as interleaver_generic_pc passes for S

   if isempty(tableDir) || exist(fullfile(char(tableDir), 'factors.mat'), 'file') ~= 2
      error(['verify_tablefree_equivalence: this test needs a tableDir that DOES ' ...
             'hold factors.mat - it is the reference arm. Give the folder with ' ...
             'the full table.']);
   end
   [tp, tfac, erP] = PrimeFactorLoader(tableDir);
   if erP ~= "", error('verify_tablefree_equivalence: %s', erP); end
   if ~isstruct(tfac) || isempty(fieldnames(tfac))
      error(['verify_tablefree_equivalence: the reference arm loaded an empty ' ...
             'factor table, so both arms would be the same test.']);
   end

   % The grid comes from the campaign files, not from a list retyped here: a
   % hardcoded grid that drifts from the published one tests the wrong lengths.
   if isfield(opts, 'Nset')
      Nset = opts.Nset(:)';
   else
      d = dir(fullfile(dataPath, 'correlation_data_*.mat'));
      if isempty(d)
         error(['verify_tablefree_equivalence: no correlation_data_*.mat in %s, ' ...
                'and no opts.Nset given'], dataPath);
      end
      Nall = [];
      for i = 1:numel(d)
         L = load(fullfile(d(i).folder, d(i).name));
         fn = fieldnames(L); C = L.(fn{1});
         Nall = [Nall; C.N(:)];  %#ok<AGROW>
      end
      Nset = sort(unique(Nall))';
   end
   fprintf('\n  verify_tablefree_equivalence: %d lengths, %d - %d\n', ...
           numel(Nset), min(Nset), max(Nset));

   METH = {'snake', 'algebraic', 'S'};
   R = struct('method', {}, 'N', {}, 'permEqual', {}, 'paramEqual', {}, 'note', {});
   bad = 0;

   for mi = 1:numel(METH)
      m = METH{mi};
      nEq = 0; nDiff = 0; nErr = 0;
      for N = Nset
         x = 1:N;
         [pA, LA, KA, eA] = local_build(m, x, pad, mx, tp, tfac);
         [pB, LB, KB, eB] = local_build(m, x, pad, mx, tp, struct());

         note = '';
         if eA ~= "" || eB ~= ""
            pEq = false; parEq = false; nErr = nErr + 1;
            note = sprintf('with="%s" without="%s"', eA, eB);
         else
            pEq   = numel(pA) == numel(pB) && all(pA(:)' == pB(:)');
            parEq = isequaln(LA, LB) && isequaln(KA, KB);
            if pEq && parEq, nEq = nEq + 1; else, nDiff = nDiff + 1; end
            if ~parEq
               note = sprintf('L,K with=(%s,%s) without=(%s,%s)', ...
                              num2str(LA), num2str(KA), num2str(LB), num2str(KB));
            end
         end
         if ~(pEq && parEq)
            bad = bad + 1;
            R(end+1) = struct('method', m, 'N', N, 'permEqual', pEq, ...
                              'paramEqual', parEq, 'note', note);  %#ok<AGROW>
         end
      end
      fprintf('  %-10s %4d identical, %4d differing, %4d errored\n', ...
              m, nEq, nDiff, nErr);
   end

   fprintf('\n');
   if bad == 0
      fprintf(['  EQUIVALENT. Dropping factors.mat changes no permutation and no\n' ...
               '  L,K on this grid, for any of the three methods that receive the\n' ...
               '  table. The optional treatment in PrimeFactorLoader is safe here.\n\n']);
   else
      fprintf(2, ['  NOT EQUIVALENT: %d (method, length) case(s) differ. The table\n' ...
                  '  cannot be treated as optional until these are understood - see\n' ...
                  '  the CSV and the getLK_S_min fallback noted in this file''s header.\n\n'], bad);
      for i = 1:min(numel(R), 12)
         fprintf(2, '    %-10s N=%-5d perm=%d param=%d  %s\n', ...
                 R(i).method, R(i).N, R(i).permEqual, R(i).paramEqual, R(i).note);
      end
   end

   try
      out = fullfile(dataPath, 'tablefree_equivalence.csv');
      fid = fopen(out, 'w');
      if fid < 0, error('cannot open %s', out); end
      fprintf(fid, 'method,N,permEqual,paramEqual,note\n');
      for i = 1:numel(R)
         fprintf(fid, '%s,%d,%d,%d,"%s"\n', R(i).method, R(i).N, ...
                 R(i).permEqual, R(i).paramEqual, R(i).note);
      end
      if isempty(R), fprintf(fid, 'ALL,0,1,1,"no differences on the tested grid"\n'); end
      fclose(fid);
      fprintf('  wrote %s\n\n', out);
   catch err
      fprintf(2, '  could not write the CSV: %s\n', err.message);
   end
end

function [p, L, K, erM] = local_build(m, x, pad, mx, tp, tf)
% One construction, with the arguments interleaver_generic_pc uses for this
% method. L and K are returned only where the method reports them; elsewhere
% they are [] in both arms and compare equal.
   p = []; L = []; K = []; erM = "";
   try
      switch m
         case 'snake'
            [~, p, L, K, erM] = interleaver_snake(x, pad, mx, tp, tf);
         case 'algebraic'
            [~, p, L, K, ~, erM] = interleaver_algebraic(x, pad, mx, tp, tf, struct());
         case 'S'
            [~, p, L, K, erM] = interleaver_S(x, pad, 0.0, 3, tp, tf, "minSum", "oddOnly");
         otherwise
            erM = sprintf('local_build: unknown method %s', m);
      end
   catch ME
      erM = ME.message;
   end
end
