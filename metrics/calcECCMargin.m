function marginMin = calcECCMargin(perm, noiseLocations, messageLength, t_correct)
% Minimum ECC margin across all ECC codewords (negative = violation)
% 
% Inputs:
%   perm - interleaver permutation
%   noiseLocations - logical array of error positions
%   messageLength - RS message length (k symbols per codeword)
%   t_correct - error correction capability (symbols per codeword)
%
% Output:
%   marginMin - minimum margin across all codewords (t_correct - errorCount)
%               Negative values indicate ECC violations
    
    N = length(perm);
    numCodewords = ceil(N / messageLength);
    
    % Map errors back to original positions
    pos = zeros(1, N);
    pos(perm) = 1:N;
    origErrors = false(1, N);
    errorIndices = find(noiseLocations);
    if ~isempty(errorIndices)
        origErrors(perm(errorIndices)) = true;
    end
    
    % Compute margin for each codeword
    margins = zeros(numCodewords, 1);
    for b = 1:numCodewords
        idxStart = (b-1) * messageLength + 1;
        idxEnd = min(b * messageLength, N);
        
        errorCount = sum(origErrors(idxStart:idxEnd));
        margins(b) = t_correct - errorCount;
    end
    
    marginMin = min(margins);
end
