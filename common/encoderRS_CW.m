function [ dataEncoded, lenCWdata, lenCW, dataPadded, infoRate, eccReal, erM ] =  encoderRS_CW(dataPlain, base, eccMin, padSym, nShort)
%ENCODERRS_CW  Encode a message into Reed-Solomon codewords, block by block.
%
% Inputs:
%   dataPlain: Nx1 vector of symbols
%   base: radix (alphabet size)
%   eccMin: minimum ECC target (e.g. 0.14). eccReal may also be passed here.
%   padSym: symbol used to pad the message out to a whole codeword
%   nShort: OPTIONAL shortened codeword length. Omit for the natural code;
%           every output is then exactly what it was before.
% Outputs:
%   dataEncoded: encoded data (symbols)
%   lenCWdata: data symbols per codeword (k)
%   lenCW: total codeword length (n)
%   dataPadded: padded input message
%   infoRate: payload symbols / encoded symbols, INCLUDING the padding cost -
%           see the note below; this is not k/n
%   eccReal: realized ECC capability
%   erM: error message string (empty if no error)
%
% -------------------------------------------------------------------------
% infoRate IS ASSIGNED TWICE, ON PURPOSE
% -------------------------------------------------------------------------
% calcParametersRS fills it with infoCapacity = k/n, the code's own rate, and
% line "infoRate = lenData / length(dataEncoded)" then overwrites it with the
% delivered rate, which is lower whenever the message does not fill its last
% codeword. Both are legitimate and they are different numbers: for a 1000
% symbol message under RS(15,9), k/n = 0.6 while the delivered rate is
% 1000/1680 = 0.5952. The second is what a caller measuring overhead wants,
% so the overwrite stays; it is called out here because a reader who sees
% only the first assignment will take the wrong one.
%
% Nothing in the campaign reads it: run_simulations_sci takes the encoded
% frame and discards the rest - [encoded, ~, ~, ~, ~, ~, erM].
%
% WHY THE BLOCK LOOP IS STILL A LOOP
% The decoder hands comm.RSDecoder the whole frame in one step() call; this
% function feeds comm.RSEncoder one codeword at a time. The asymmetry is
% historical, not required, and collapsing the loop to a single step() over
% dataPadded should be identical because RS coding is per-codeword by
% definition. "Should be" is not "is", and this file produces the data every
% later number rests on, so the loop is unchanged here and
% verify_rs_codec.m checks the two forms symbol for symbol. Adopt the single
% call only once that check has passed on the lengths in use, and note that
% the encoder's locked input size would then become the frame length, so
% getRSCodec would need a frameLen key on the encoder branch too.
%
% WHAT WAS ADDED
% padSym and the input alphabet were both unchecked. A pad symbol or a data
% symbol at or above 2^m is not a member of GF(2^m); comm.RSEncoder rejects
% it, but from inside its own stack with a message that does not name the
% caller's symbol or its position. Both are now checked here, where the
% numbers are still in scope. Note the test is against the FIELD size 2^m,
% not against base: base = 10 legitimately encodes over GF(16), so symbols
% 10..15 are valid field elements even though the source alphabet never
% produces them, and rejecting them would break a caller that pads with
% base-1 after a field promotion.
%
% R.T. Sirmen, 2026-10-31

try
   erM = "";

   if nargin < 4 || isempty(padSym)
      error('encoderRS_CW: padSym is required - there is no safe default pad symbol.');
   end
   if nargin < 5, nShort = []; end

   % Ensure column vector input
   [failed, dataPlain] = controlCorrectShape_N1(dataPlain);
   if failed
      erM = sprintf("encoderRS_CW Data shape error: (%s) Must be (Nx1)", mat2str(size(dataPlain)));
      return;
   end

   % RS Parameters. calcParametersRS applies its own validity gate, so the
   % values below have already been checked against every RS invariant and
   % against the eccReal round trip before they reach this line.
   [lenCWdata, lenCW, infoRate, eccReal, codeInfo] = calcParametersRS(base, eccMin, nShort);

   % Symbols must be elements of GF(2^m). THE FIELD IS THE MOTHER CODE'S,
   % not the delivered codeword's: a shortened RS(24,16) still lives in
   % GF(32), so lenCW + 1 would give 25 and reject legal symbols 25..31.
   fieldSize = codeInfo.nFull + 1;             % 2^m
   if ~isscalar(padSym) || ~isfinite(padSym) || padSym < 0 || ...
      padSym ~= floor(padSym) || padSym >= fieldSize
      error(['encoderRS_CW: padSym = %s is not an element of GF(%d). ' ...
             'It must be an integer in 0..%d.'], ...
             mat2str(padSym), fieldSize, fieldSize - 1);
   end
   if ~isempty(dataPlain)
      bad = find(dataPlain < 0 | dataPlain >= fieldSize | ...
                 dataPlain ~= floor(dataPlain), 1);
      if ~isempty(bad)
         error(['encoderRS_CW: symbol %s at position %d is not an element ' ...
                'of GF(%d). Symbols must be integers in 0..%d.'], ...
                mat2str(dataPlain(bad)), bad, fieldSize, fieldSize - 1);
      end
   end

   % Padding
   lenData = length(dataPlain);
   numBlocks = ceil(lenData / lenCWdata);
   totalDataLength = numBlocks * lenCWdata;
   paddingLen = totalDataLength - lenData;
   padding = padSym * ones(paddingLen, 1);
   dataPadded = [dataPlain; padding];

   % Encoder - shared, built once. See getRSCodec.m.
   % The loop below feeds one codeword's worth of symbols per step(), so the
   % locked input size is always lenCWdata and the object never needs
   % releasing during a sweep.
   % The object is built from the MOTHER code with the delivered message
   % length as ShortMessageLength; it then takes lenCWdata symbols per step
   % and returns lenCW. Unshortened, codeInfo.nFull == lenCW and
   % codeInfo.kFull == lenCWdata, so this is the previous call exactly.
   rsEncoder = getRSCodec('encoder', codeInfo.nFull, codeInfo.kFull, [], lenCWdata);

   % Encode block-by-block
   dataEncoded = zeros(numBlocks * lenCW, 1, 'like', dataPlain);
   for i = 1:numBlocks
       bStart = (i - 1) * lenCWdata + 1;
       bEnd = i * lenCWdata;
       blockPlain = dataPadded(bStart:bEnd);
       blockEncoded = step(rsEncoder, blockPlain);
       eStart = (i - 1) * lenCW + 1;
       eEnd = i * lenCW;
       dataEncoded(eStart:eEnd) = blockEncoded;
   end

   infoRate = lenData / length(dataEncoded);  % delivered rate, padding included
   % NO release() - the object is owned by getRSCodec.

catch ME
   % See the note in decoderRS_CW: ME.stack can be empty, and strcat never
   % filled the %s placeholders the previous version put in the message.
   if isempty(ME.stack)
      erM = string(sprintf('Error in encoderRS_CW: %s', ME.message));
   else
      erM = string(sprintf('Error in %s (line %d): %s', ...
                           ME.stack(1).name, ME.stack(1).line, ME.message));
   end
end
end
