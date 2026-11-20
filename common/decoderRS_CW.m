function [ dataDecoded, n, avgCorrectedCWrate, avgUncorrectableCWrate, errInfo, eccReal, rsDecoder, erM ] = ...
    decoderRS_CW( dataEncoded, base, eccMin, nShort )
%DECODERRS_CW  Decode a Reed-Solomon frame and report per-codeword statistics.
%
% Inputs:
%   dataEncoded: Nx1 vector of symbols, a whole number of codewords
%   base: symbol base (radix)
%   eccMin: minimum desired error correction ratio. PASS eccMin, NOT eccReal
%           - see the round-trip note below.
%   nShort: OPTIONAL shortened codeword length, matching the encoder's.
% Outputs:
%   dataDecoded: estimated original message
%   n: codeword length in symbols
%   avgCorrectedCWrate: fraction of CODEWORDS that needed correction, in [0,1]
%   avgUncorrectableCWrate: fraction of CODEWORDS the decoder could not
%           correct, in [0,1]
%   errInfo: per codeword, the NUMBER of symbol errors corrected (0 when the
%           codeword arrived clean), or -1 when the codeword was detected as
%           uncorrectable. It is not a 0/1/-1 flag - the previous header said
%           "1 = corrected", which understated it: a codeword corrected at
%           three symbols reports 3.
%   eccReal: actual ECC achieved
%   rsDecoder: the live shared RSDecoder object (do not release it)
%
% -------------------------------------------------------------------------
% THE DENOMINATOR THAT WAS WRONG
% -------------------------------------------------------------------------
% The two rate outputs are siblings built from sibling counts, and they used
% different denominators:
%
%     avgCorrectedCWrate     = correctedCWCount / lenRcv;     % SYMBOL count
%     avgUncorrectableCWrate = uncorrectableCWCount / nBlock; % codeword count
%
% correctedCWCount = sum(errInfo > 0) counts CODEWORDS, as its name and the
% output's name both say, so dividing it by the symbol count produced a
% quantity that is neither a per-codeword rate nor a per-symbol one - it was
% the right rate divided by n, so n times too small, 15 times on RS(15,9).
% The old header called it "average rate of corrected symbols", which is a
% third quantity again and not what the numerator counts.
%
% It now divides by nBlock, matching its name, its sibling, and the [0,1]
% range a rate is read as. If the per-SYMBOL figure is ever wanted it is a
% different numerator, not a different denominator:
%
%     correctedSymbolRate = sum(errInfo(errInfo > 0)) / lenRcv;
%
% NOTHING IN THE PUBLISHED CAMPAIGN MOVES. decodeRS_all returns both rates,
% and run_simulations_sci discards them at the call site -
% [decoded_ns_all, ~, ~, ~, erM] - so no reported number was ever computed
% from either. decodeErrRate, the quantity the KPIs rest on, comes from
% calcDecErrorRates_all comparing the decoded symbols against the original
% with symerr, and never touches these counts. The fix moves a wrong number
% that no result depended on.
%
% A FRAME THAT IS NOT A WHOLE NUMBER OF CODEWORDS
% nBlock = lenRcv/n was used as a denominator without being checked, so a
% truncated or mis-assembled frame silently produced a fractional block count
% and a rate scaled by the fraction. comm.RSDecoder would also have objected,
% but after the statistics were already wrong. It is now checked first.
%
% THE ROUND TRIP, AND WHY THIS FUNCTION NO LONGER DEPENDS ON IT
% decodeRS_all used to pass eccReal into the eccMin slot above, so
% calcParametersRS was applied to its own output and the decoder's code
% depended on ceil(n*(t/n)) == t. That holds at all 4083 valid (n,t) pairs
% for n = 2^m - 1, which is why it never showed. Over SHORTENED lengths it
% fails at 439 of 21328 pairs, and where it fails the decoder builds a
% different code from the encoder and the frame decodes to noise silently.
%
% Both sides are now handed eccMin, so nothing is re-derived from a derived
% quantity. calcParametersRS additionally refuses, on every call, to return a
% parameter set that would not survive the round trip - the trap is closed at
% the source as well as at the call sites.
%
% R.T. Sirmen, 2026-10-31

try
    erM = "";
    dataDecoded=[];
    n=0;
    avgCorrectedCWrate=0;
    avgUncorrectableCWrate=1;
    errInfo=[];
    eccReal=0;
    rsDecoder=NaN;

    %% Input shape correction
    sizeData = size(dataEncoded);
    if sizeData(2) ~= 1
        dataEncoded = dataEncoded';
        if size(dataEncoded, 2) ~= 1
            error("Data shape error: Must be (Nx1)");
        end
        recoverShape = true;
    else
        recoverShape = false;
    end

    %% RS parameter calculation
    if nargin < 4, nShort = []; end
    [k, n, infoCapacity, eccReal, codeInfo] = calcParametersRS(base, eccMin, nShort); %#ok<ASGLU>

    %% The frame must be a whole number of codewords
    lenRcv = length(dataEncoded);
    nBlock = lenRcv / n;
    if lenRcv < n || mod(lenRcv, n) ~= 0
        error(['decoderRS_CW: the frame is %d symbols, which is not a whole ' ...
               'number of n = %d codewords (%.4f of one). Per-codeword ' ...
               'statistics would be scaled by the remainder.'], ...
               lenRcv, n, nBlock);
    end

    %% RS Decoder - shared, built once. See getRSCodec.m for why.
    % Profiled: 85%% of this function's time was constructing this object
    % (setupImpl 2.038 s vs stepImpl 0.206 s over 381 calls), recomputing the
    % generator polynomial for parameters that never change.
    %
    % NOTE: this function decodes the WHOLE frame in one step() call, not
    % codeword by codeword - comm.RSDecoder takes a multi-codeword input and
    % errInfo comes back per codeword, which is where the per-CW statistics
    % below come from. So the locked input size is the frame length, and that
    % is what getRSCodec keys on. The encoder in encoderRS_CW does the
    % opposite and loops one codeword per step(); the two are interoperable
    % because RS coding is per-codeword by definition, and
    % verify_rs_codec.m checks that claim rather than assuming it.
    % Built from the MOTHER code with the delivered message length as
    % ShortMessageLength. Unshortened this is the previous call exactly.
    rsDecoder = getRSCodec('decoder', codeInfo.nFull, codeInfo.kFull, lenRcv, k);

    %% Decoding
    [dataDecoded, errInfo] = step(rsDecoder, dataEncoded);

    correctedCWCount     = sum(errInfo > 0);   % codewords repaired
    uncorrectableCWCount = sum(errInfo < 0);   % codewords given up on

    avgCorrectedCWrate     = correctedCWCount / nBlock;
    avgUncorrectableCWrate = uncorrectableCWCount / nBlock;

    %% Restore original shape
    if recoverShape
        dataDecoded = dataDecoded';
    end

    %% NO release() - releasing is exactly what forced the rebuild every call.
    % The object is owned by getRSCodec and stays ready for the next frame.
    % Drop it explicitly with getRSCodec('clear') if you change (n,k).
    %
    % Side note: rsDecoder is an OUTPUT of this function and is documented as
    % "RSDecoder object used". Before this change it was released just before
    % being returned, so every caller received a dead object. Now the handle
    % it returns is the live shared one - do not release it either.

catch ME
   % ME.stack can be empty for an error raised outside a function frame, in
   % which case indexing it threw a second error from inside the catch and
   % buried the first. The %s placeholders in the previous version were also
   % never filled - strcat does not format - so the message read
   % "Error in X: %s\n  %s<message><position>".
   if isempty(ME.stack)
      erM = string(sprintf('Error in decoderRS_CW: %s', ME.message));
   else
      erM = string(sprintf('Error in %s (line %d): %s', ...
                           ME.stack(1).name, ME.stack(1).line, ME.message));
   end
end
end
