function fecConfig = configure_FEC_parameters(base, eccMin, nShort)
%CONFIGURE_FEC_PARAMETERS  Forward error correction parameters for the sweep.
%   Independent of the interleaver block size.
%
%   fecConfig = configure_FEC_parameters(base, eccMin)
%   fecConfig = configure_FEC_parameters(base, eccMin, nShort)
%
%   nShort  OPTIONAL. Deliver a SHORTENED code of this codeword length. Omit
%           it and every returned field is exactly what it was before.
%
% Common RS codes:
%   RS(7,5):     n=7,   k=5,   t=1
%   RS(15,11):   n=15,  k=11,  t=2
%   RS(31,25):   n=31,  k=25,  t=3
%   RS(255,223): n=255, k=223, t=16
%
% WHY THE MOTHER CODE IS RETURNED AS WELL
% ---------------------------------------------------------------------------
% A shortened code is transmitted as n symbols but ENCODED by the mother code
% RS(nFull, kFull) with kFull - k message symbols held at zero. comm.RSEncoder
% and comm.RSDecoder want the mother code's lengths plus ShortMessageLength,
% so the codec layer needs nFull and kFull and cannot derive them from n and k
% alone. They are carried here rather than recomputed in three places.
%
% PASS eccMin TO THE CODEC, NOT eccReal
% ---------------------------------------------------------------------------
% The sweep used to hand config.eccReal to encoderRS_CW and decoderRS_CW,
% which then recomputed t = ceil(n * eccReal) from it. That works only while
% the function is idempotent on its own output, and for n = 2^m - 1 it is:
% checked over all 4083 valid (n,t) pairs for m = 2..12 with no failure.
%
% IT IS NOT GENERALLY TRUE. Over shortened lengths the same check fails for
% 439 of 21328 (n,t) pairs - n = 25, 41, 43, 50, 51, 58, 70, 75 and others -
% because t/n rounds in binary and n*(t/n) can land a hair above t, which
% ceil then lifts to t+1. The encoder and decoder would build DIFFERENT codes
% and nothing would say so.
%
% The shortened lengths this study uses, 12 and 24, happen to be safe. Relying
% on that would be relying on an accident, so the sweep now passes eccMin to
% both sides and neither re-derives from a derived quantity. For every code
% run before 6 November 2026 this changes nothing, because there eccMin and
% eccReal produce the same t.
%
% R.T. Sirmen, 2026-11-06

   if nargin < 3, nShort = []; end

   [k, n, infoCapacity, eccReal, codeInfo] = calcParametersRS(base, eccMin, nShort);

   fecConfig.n = n;        % codeword length actually transmitted (symbols)
   fecConfig.k = k;        % message length actually carried (symbols)

   fecConfig.p = fecConfig.n - fecConfig.k;        % parity symbols
   fecConfig.t_correct = floor(fecConfig.p / 2);   % correctable symbols per CW

   fecConfig.eccReal = eccReal;        % t/n, the delivered correction fraction
   fecConfig.IR = infoCapacity;        % k/n, the information rate
   fecConfig.overhead = fecConfig.p / fecConfig.k;

   % --- THE MOTHER CODE, for the codec layer ---------------------------
   fecConfig.nFull       = codeInfo.nFull;
   fecConfig.kFull       = codeInfo.kFull;
   fecConfig.shortenBy   = codeInfo.shortenBy;
   fecConfig.isShortened = codeInfo.shortenBy > 0;
   fecConfig.m           = codeInfo.m;

   % --- GENERALIZED FIELDS ---
   fecConfig.L = fecConfig.n;         % codeword length (block size L)
   fecConfig.tau = fecConfig.eccReal; % normalized capacity

   % The parity count has to survive shortening, which removes message
   % symbols only. If it does not, the mother code and the delivered code
   % disagree and everything downstream is built on the wrong one.
   if fecConfig.p ~= (codeInfo.nFull - codeInfo.kFull)
      error(['configure_FEC_parameters: delivered RS(%d,%d) has %d parity ' ...
             'symbols but its mother RS(%d,%d) has %d. Shortening must not ' ...
             'change the parity count.'], n, k, fecConfig.p, ...
             codeInfo.nFull, codeInfo.kFull, codeInfo.nFull - codeInfo.kFull);
   end
   if fecConfig.t_correct ~= codeInfo.t
      error(['configure_FEC_parameters: t is %d from the delivered code and ' ...
             '%d from the mother code. They cannot differ.'], ...
             fecConfig.t_correct, codeInfo.t);
   end
end
