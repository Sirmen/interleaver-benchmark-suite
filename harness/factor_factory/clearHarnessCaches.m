function clearHarnessCaches()
%CLEARHARNESSCACHES  Drop every persistent lookup cache in the harness.
%
%   clearHarnessCaches
%
% RUN THIS AFTER REGENERATING ANY TABLE, BEFORE THE NEXT SWEEP.
% ---------------------------------------------------------------------------
% Four loaders keep their results in `persistent` variables and hand back the
% cached copy whenever the requested directory string matches the one they
% loaded from:
%
%     PrecomputedInterleaverLoader   persistent cache_table cache_dir
%     PrimeFactorLoader              persistent loaded_primes loaded_factors loaded_dir
%     PrimeFactor_PrecomputedLoader  persistent loaded_primes loaded_factors loaded_precomputed loaded_dir
%     interleaver_turbo              persistent qppCache
%
% The cache key is the DIRECTORY, never the file's timestamp or contents. So
% the sequence everybody runs -
%
%     PrecomputeInterleaversGenerator(...)     % writes a fresh table
%     main_simulation_wrapper                  % ... reads the OLD one
%
% - serves the pre-regeneration table for the rest of the MATLAB session, from
% the same path, with no warning. The sweep then runs against permutations
% that no longer correspond to the interleaver files on disk: `snake` missing,
% `cross` present, the four new methods absent, and any method that was
% corrected still producing its old permutation.
%
% Nothing about that looks like an error. It looks like results.
%
% `clear functions` would also do it, at the cost of dropping every compiled
% function in the session. This clears exactly the four that cache data.
%
% Two persistent counters are cleared too - interleaver_random and
% interleaver_freqRandom hold a per-call counter that makes their draw
% reproducible from the base seed. Resetting them makes a rerun repeat the
% same sequence of permutations, which is what you want between comparable
% runs.
%
% R.T. Sirmen harness, 2026

   names = { ...
      'PrecomputedInterleaverLoader', ...
      'PrimeFactorLoader', ...
      'PrimeFactor_PrecomputedLoader', ...
      'interleaver_turbo', ...
      'interleaver_random', ...
      'interleaver_freqRandom'};

   % getRSCodec owns the shared comm.RSEncoder / comm.RSDecoder. They are
   % System objects, not data, so `clear` alone would drop the handle without
   % releasing the object - it asks for its own call.
   if exist('getRSCodec', 'file') == 2
      try
         getRSCodec('clear');
         fprintf('clearHarnessCaches: released the shared RS codec\n');
      catch ME
         fprintf(2, 'clearHarnessCaches: getRSCodec(''clear'') failed: %s\n', ME.message);
      end
   end

   cleared = {}; missing = {};
   for i = 1:numel(names)
      if exist(names{i}, 'file') == 2
         clear(names{i});
         cleared{end+1} = names{i}; %#ok<AGROW>
      else
         missing{end+1} = names{i}; %#ok<AGROW>
      end
   end

   fprintf('clearHarnessCaches: cleared %d\n', numel(cleared));
   for i = 1:numel(cleared), fprintf('   %s\n', cleared{i}); end
   if ~isempty(missing)
      fprintf('   (not on path, skipped: %s)\n', strjoin(missing, ', '));
   end
end
