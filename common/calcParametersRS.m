function [ k, n, infoCapacity, eccReal, codeInfo ] = calcParametersRS( base, eccMin, nShort )
%CALCPARAMETERSRS  Reed-Solomon code parameters from an alphabet and an ECC floor.
%
%   [k, n, infoCapacity, eccReal] = calcParametersRS(base, eccMin)
%
%   [k, n, infoCapacity, eccReal, codeInfo] = calcParametersRS(base, eccMin, nShort)
%
%   base    radix (alphabet size) of the plain message to be encoded
%   eccMin  minimum desired fraction of correctable symbols per codeword
%   nShort  OPTIONAL. Deliver a SHORTENED code of this codeword length
%           instead of the natural 2^m - 1. Omit it and this function
%           behaves exactly as before, down to the last returned digit.
%
%   k             message length in symbols
%   n             codeword length in symbols
%   infoCapacity  k/n, the useful data fraction of a codeword
%   eccReal       t/n, the correction fraction actually achieved
%   codeInfo      struct carrying the MOTHER code the encoder must be built
%                 from: nFull, kFull, t, shortenBy. Without nShort it holds
%                 the natural code, so a caller can use it unconditionally.
%
% THE CODE
%   m = ceil(log2(base))    symbol width in bits; the alphabet must fit GF(2^m)
%   n = 2^m - 1             codeword length
%   t = ceil(n * eccMin)    smallest t meeting the requested floor
%   k = n - 2t              message length
%
% The encoder takes m bits per symbol and k symbols per message, appends 2t
% parity symbols, and transmits n = k + 2t symbols. The decoder receives n
% symbols and reproduces the k-symbol message exactly when at most t of them
% are corrupt.
%
% SHORTENING
% ---------------------------------------------------------------------------
% A shortened code fixes s message symbols to zero and does not transmit
% them, giving (n, k) = (nFull - s, kFull - s). It removes symbols from the
% message only, so the parity count and therefore the minimum distance are
% untouched: d = nFull - kFull + 1 and t = (nFull - kFull)/2 are the same
% code's, and n - k = 2t still holds. What DOES change is the correction
% FRACTION, because t is now spread over a shorter codeword: eccReal = t/n
% rises as n falls.
%
% So eccMin is read against the delivered length here, exactly as it is
% without shortening: t = ceil(nShort * eccMin). That keeps one meaning for
% the argument across both paths - "the fraction of a transmitted codeword
% the caller needs corrected" - rather than two that happen to share a name.
%
% WHY A SHORTENED CODE IS WANTED AT ALL. Two properties of the interleaving
% study depend on n and cannot be varied with n = 2^m - 1, which is always
% congruent to 3 modulo 4; the dither-period interleaver, for one, needs
% 4 | n. Such n become reachable the moment n is free, and shortening is the
% standard way to free it.
%
% -------------------------------------------------------------------------
% WHAT CHANGED FROM THE PREVIOUS VERSION, AND WHAT DELIBERATELY DID NOT
% -------------------------------------------------------------------------
% Every code parameter in the interleaving study comes from this file: the
% codeword length that sets the length grid, the correction
% capability that sets the noise band through eccReal, and the message length
% that sets the frame. A change here moves everything downstream, so the
% formula for t is untouched and the returned values are identical to the
% previous version for every input that previously yielded a valid code.
% verify_rs_params.m is the check; it passes on all ten bases and five ECC
% floors it sweeps, and on the six published codes.
%
% 1. THE MISSING BOUND ON k, now an error.
%    t = ceil(n*eccMin) grows with eccMin while n is fixed, so k = n - 2t
%    passes through zero and goes negative with no complaint. The previous
%    version returned k = -1 for every base at eccMin = 0.5, and a caller
%    would carry that into comm.RSEncoder before anything objected. Each of
%    those cases is now an error naming the three numbers involved.
%
%    The alternative repair - reduce t until k >= 1 and return the weaker
%    code - was NOT adopted. It would silently return a code the caller did
%    not ask for, which is a change to parameter selection, and parameter
%    selection is not changed here without being asked. An infeasible
%    request now says so instead of being quietly downgraded.
%
%    The feasible range follows from k >= 1: eccMin <= (n-1)/(2n), just under
%    one half. For n = 15 that is 0.4667, for n = 255 it is 0.4980.
%
% 2. logb REPLACED BY log2.
%    logb is not a MATLAB function; it resolved to a project file, so this
%    file could not be used outside the project tree and gave no error that
%    said why. log2 is a built-in and is exact at powers of two, where
%    log(x)/log(2) is the arrangement that can land a hair above an integer
%    and push ceil up by one. Checked over every integer base from 2 to 4096:
%    ceil(log(b)/log(2)) and ceil(log2(b)) agree at all 4095 of them, so the
%    substitution moves no symbol width. The ten bases in use return exactly
%    the n they returned before.
%
% 3. INPUT VALIDATION.
%    base < 2 or a non-finite eccMin produced a silent NaN or a complex m and
%    then nonsense downstream. Both are rejected here. base is not required
%    to be a power of two: a non-power alphabet is embedded in the next field
%    up, which is how base = 10 reaches GF(16), and that is intended.
%
% 4. THE SIGNATURE IS UNCHANGED, including the order [k, n, ...], which reads
%    backwards but is what every caller in the tree expects. t is not
%    returned because no caller takes it; it is recoverable as (n - k)/2.
%
% A PROPERTY RELIED ON ELSEWHERE, RECORDED HERE
% decodeRS_all passes eccReal into the eccMin slot of decoderRS_CW, so this
% function is applied to its own output. That is safe only if it is
% idempotent: ceil(n * (t/n)) must return t. It is exact in real arithmetic,
% and in IEEE double it was checked exhaustively over all 4083 valid (n,t)
% pairs for m = 2..12 with no failure. The idempotency is therefore a
% property this file is entitled to rely on, not an accident to leave
% undocumented - verify_rs_codec.m tests it as a contract.
%
% R.T. Sirmen, 2026-10-31

try
   %% Input validation
   if ~isscalar(base) || ~isnumeric(base) || ~isfinite(base) || base < 2
      error('calcParametersRS: base must be a finite scalar >= 2 (got %s).', ...
            mat2str(base));
   end
   if ~isscalar(eccMin) || ~isnumeric(eccMin) || ~isfinite(eccMin) || eccMin <= 0
      error('calcParametersRS: eccMin must be a finite scalar > 0 (got %s).', ...
            mat2str(eccMin));
   end

   %% The code
   m     = ceil(log2(base));    % bits per symbol
   nFull = 2^m - 1;             % natural codeword length (symbols)

   if nargin < 3 || isempty(nShort)
      n = nFull;                % unshortened: the path everything else uses
   else
      if ~isscalar(nShort) || ~isnumeric(nShort) || ~isfinite(nShort) || ...
         nShort ~= floor(nShort) || nShort < 3 || nShort > nFull
         error(['calcParametersRS: nShort must be a whole number in 3..%d ' ...
                'for GF(2^%d) (got %s). A shortened code cannot be longer ' ...
                'than its mother code.'], nFull, m, mat2str(nShort));
      end
      n = nShort;
   end

   t = ceil(n * eccMin);        % correctable symbols: smallest t meeting eccMin
   k = n - 2 * t;               % data symbols
   eccReal = t / n;             % actual error correction ratio
   infoCapacity = k / n;        % useful data ratio

   % The mother code the encoder is actually built from. Shortening takes the
   % same t, so the parity count is 2t either way and only the message is cut.
   kFull = nFull - 2 * t;
   codeInfo = struct('nFull', nFull, 'kFull', kFull, 't', t, ...
                     'shortenBy', nFull - n, 'm', m);

   %% The bound the previous version did not apply
   if k < 1
      error(['calcParametersRS: eccMin = %.6g is not achievable at n = %d ' ...
             'over GF(2^%d). It needs t = %d correctable symbols, leaving ' ...
             'k = %d data symbols. The largest eccMin this length supports ' ...
             'is %.6g (k = 1).'], eccMin, n, m, t, k, (n-1)/(2*n));
   end
   % The mother code has to exist too. It is longer than the delivered one and
   % carries the same parity, so it fails only in cases the check above lets
   % through by a hair; it is checked rather than assumed.
   if kFull < 1
      error(['calcParametersRS: a shortened RS(%d,%d) would need the mother ' ...
             'code RS(%d,%d), whose message length is not positive. Reduce ' ...
             'eccMin or use a larger base.'], n, k, nFull, kFull);
   end

   %% VALIDITY GATE - nothing leaves this function unchecked
   % ------------------------------------------------------------------------
   % Every number this file returns is a DERIVED quantity, and everything
   % downstream - the burst band, the codec objects, the KPI chain - is built
   % on it. A parameter set that is wrong here is wrong everywhere and says
   % nothing about being wrong: the campaign runs, produces figures, and means
   % something else. This project has paid for that four times.
   %
   % So the invariants are checked on EVERY call rather than in a test file
   % that someone has to remember to run. It is a dozen comparisons against
   % the cost of an encode, and it makes "the parameters were validated" a
   % property of the code path instead of a claim in a header.
   local_gate(2^m - 1 == nFull,        'n_full is not 2^m - 1 (m=%d, nFull=%d)', m, nFull);
   local_gate(2^m >= base,             'alphabet %g does not fit GF(2^%d)', base, m);
   local_gate(n >= 3 && n <= nFull,    'n = %d outside 3..%d', n, nFull);
   local_gate(t >= 1,                  't = %d is not positive', t);
   local_gate(n - k == 2*t,            'n-k = %d but 2t = %d', n-k, 2*t);
   local_gate(nFull - kFull == 2*t,    'mother parity %d but 2t = %d', nFull-kFull, 2*t);
   local_gate(abs(eccReal - t/n) < eps(max(1,t/n)), 'eccReal %.17g ~= t/n', eccReal);
   local_gate(abs(infoCapacity - k/n) < eps(max(1,k/n)), 'infoCapacity %.17g ~= k/n', infoCapacity);
   local_gate(eccReal >= eccMin - 1e-12, 'eccReal %.6g below the requested %.6g', eccReal, eccMin);
   local_gate(t == 1 || (t-1)/n < eccMin, 't = %d is not the smallest meeting eccMin %.6g', t, eccMin);

   % THE ROUND TRIP. Callers in this tree hand eccReal back into the eccMin
   % slot - decodeRS_all did it for years - and that is sound only where
   % ceil(n*(t/n)) == t. For n = 2^m - 1 it holds at all 4083 valid (n,t)
   % pairs for m = 2..12. Over SHORTENED lengths it fails at 439 of 21328,
   % because t/n rounds in binary and n*(t/n) can land just above t. Where it
   % fails, an encoder built from eccMin and a decoder built from eccReal are
   % DIFFERENT CODES and the frame decodes to noise without a word.
   %
   % The sweep no longer passes eccReal, but a parameter set that cannot
   % survive the round trip is a trap for the next caller, so it is refused
   % here rather than returned with a warning nobody reads.
   local_gate(ceil(n * eccReal) == t, ...
              ['RS(%d,%d) cannot be recovered from its own eccReal: ' ...
               'ceil(%d * %.17g) = %d, not %d. Pass eccMin, never eccReal.'], ...
              n, k, n, eccReal, ceil(n*eccReal), t);

catch err
   fprintf('\n   >>> error in calcParametersRS <<<\n');
   rethrow(err);
end % catch
end

% -------------------------------------------------------------------------
function local_gate(ok, fmt, varargin)
%LOCAL_GATE  Refuse to return a parameter set that fails an invariant.
%   Deliberately an error and not a warning. A warning in a sweep of a
%   million trials scrolls past, and the campaign finishes looking healthy.
   if ~ok
      error(['calcParametersRS: VALIDITY GATE - ' fmt], varargin{:});
   end
end
