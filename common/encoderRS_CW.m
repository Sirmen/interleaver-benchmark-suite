function [ dataEncoded, lenCWdata, lenCW, dataPadded, infoRate, eccReal, erM ] =  encoderRS_CW(dataPlain, base, eccMin, padSym)
% Encodes the plain data into Reed-Solomon coded message.
% Inputs:
%   dataPlain: Nx1 vector of symbols
%   base: radix (alphabet size)
%   eccMin: minimum ECC target (e.g., 0.14)
%   padSym: symbol used for padding
% Outputs:
%   dataEncoded: encoded data (symbols)
%   lenCWdata: data symbols per codeword (k)
%   lenCW: total codeword length (n)
%   dataPadded: padded input message
%   infoRate: data-to-codeword ratio
%   eccReal: realized ECC capability
%   erM: error message string (empty if no error)

try
   erM = "";

   % Ensure column vector input
   [failed, dataPlain] = controlCorrectShape_N1(dataPlain);
   if failed 
      erM = sprintf("encoderRS_CW Data shape error: (%s) Must be (Nx1)", mat2str(size(dataPlain)));
      return;
   end

   % RS Parameters
   [lenCWdata, lenCW, infoRate, eccReal] = calcParametersRS(base, eccMin);

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
   rsEncoder = getRSCodec('encoder', lenCW, lenCWdata);

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

   infoRate = lenData / length(dataEncoded);  % actual data ratio
   % NO release() - the object is owned by getRSCodec.

   % WORTH TRYING LATER, NOT CHANGED HERE:
   % The block loop above calls step() once per codeword - 112 calls for an
   % encoded length of 1680. comm.RSEncoder accepts a multi-codeword input in
   % one call, exactly as the decoder side already does, so the whole loop
   % could collapse to
   %       dataEncoded = step(rsEncoder, dataPadded);
   % RS encoding is per-codeword by definition, so the result should be
   % identical - but "should be" is not "is", and this file produces the data
   % every later number depends on. Verify byte-for-byte on a few lengths
   % before adopting it. Note the encoder's locked input size would then
   % become the frame length, so getRSCodec would need the frameLen key for
   % the encoder too.

catch ME
   errMdl = ME.stack(1).name;
   errLine = ME.stack(1).line;
   errPos = strcat(errMdl, " Line:", num2str(errLine));
   erM = strcat('Error in ', errMdl,': %s\n  %s', ME.message, errPos);
end
end
