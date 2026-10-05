function [ dataDecoded, n, avgCorrectedCWrate, avgUncorrectableCWrate, errInfo, eccReal, rsDecoder, erM ] = ...
    decoderRS_CW( dataEncoded, base, eccMin )
% decodes the Reed-Solomon encoded message
% Inputs:
%   dataEncoded: Nx1 vector of symbols
%   base: symbol base (radix)
%   eccMin: minimum desired error correction ratio
% Outputs:
%   dataDecoded: estimated original message
%   n: codeword length in symbols
%   avgCorrectedCWrate: average rate of corrected symbols
%   avgUncorrectableCWrate: average rate of failed CWs
%   errInfo: vector of error info (0 = ok, 1 = corrected, -1 = failed)
%   eccReal: actual ECC achieved
%   rsDecoder: RSDecoder object used

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
    [k, n, infoCapacity, eccReal] = calcParametersRS(base, eccMin);

    %% RS Decoder - shared, built once. See getRSCodec.m for why.
    % Profiled: 85%% of this function's time was constructing this object
    % (setupImpl 2.038 s vs stepImpl 0.206 s over 381 calls), recomputing the
    % generator polynomial for parameters that never change.
    %
    % NOTE: this function decodes the WHOLE frame in one step() call, not
    % codeword by codeword - comm.RSDecoder takes a multi-codeword input and
    % errInfo comes back per codeword, which is where the per-CW statistics
    % below come from. So the locked input size is the frame length, and that
    % is what getRSCodec keys on.
    rsDecoder = getRSCodec('decoder', n, k, numel(dataEncoded));

    %% Decoding
    [dataDecoded, errInfo] = step(rsDecoder, dataEncoded);
    correctedCWCount     = sum(errInfo > 0);
    uncorrectableCWCount = sum(errInfo < 0);

    lenRcv = length(dataEncoded);
    nBlock = lenRcv / n;
    avgCorrectedCWrate     = correctedCWCount / lenRcv;
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
   errMdl = ME.stack(1).name;
   errLine = ME.stack(1).line;
   errPos = strcat(errMdl, " Line:", num2str(errLine));
   erM = strcat('Error in ', errMdl,': %s\n  %s', ME.message, errPos);
end
end
