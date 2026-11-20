function [decoded_all, corcCWrate_all, uncorcCWrate_all, errCWs_all, erM] = decodeRS_all(intMethods, deinterleaved_all, base, eccMin, nShort)
%DECODERS_ALL  Decode every method's deinterleaved frame with the same code.
%
% THE THIRD ARGUMENT IS eccMin, AND IT USED TO BE eccReal.
% The caller handed config.eccReal here and decoderRS_CW then recomputed
% t = ceil(n * eccReal) from it, so the decoder's code depended on
% ceil(n*(t/n)) == t. That holds at all 4083 valid (n,t) pairs for
% n = 2^m - 1, which is why it never showed in four campaigns. Over
% SHORTENED codeword lengths it fails at 439 of 21328 pairs: t/n rounds in
% binary, n*(t/n) lands a hair above t, and ceil lifts it to t+1. The
% decoder would then build a DIFFERENT code from the encoder and the frame
% would decode to noise with nothing said.
%
% Both sides are now given eccMin, so neither re-derives from a derived
% quantity. For every code run before 6 November 2026 this changes no value,
% because there eccMin and eccReal yield the same t.
%
% nShort is the optional shortened codeword length and must match the one the
% encoder was given.
try
   erM=""; decoded_all=[]; corcCWrate_all=[]; uncorcCWrate_all=[]; errCWs_all=[];
   %%%
   for i = 1:length(intMethods)
      methodName = intMethods{i};

      deinterleaved = deinterleaved_all.(methodName); % extract deinterleaved data
      if nargin < 5, nShort = []; end
      [decoded, ~, corcCWrate, uncorcCWrate, errCWs, ~, ~, erM] = ...
            decoderRS_CW( deinterleaved, base, eccMin, nShort );
      if erM ~= ""
         error('Error in decodeRS_all:\n%s', erM);
      else
         decoded_all.(methodName) = decoded;
         corcCWrate_all.(methodName) = corcCWrate;
         uncorcCWrate_all.(methodName) = uncorcCWrate;
         errCWs_all.(methodName) = errCWs;
      end
   end
catch ME
   errMdl = ME.stack(1).name;
   errLine = ME.stack(1).line;
   errPos = strcat(errMdl, " Line:", num2str(errLine));
   erM = strcat('Error in ', errMdl,': %s\n  %s', ME.message, errPos);
end
end
