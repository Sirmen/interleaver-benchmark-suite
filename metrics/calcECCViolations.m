function violations = calcECCViolations(perm, noiseLocations, messageLength, t_correct)
% Count ECC codewords that exceed error correction capability
%
% Inputs:
%   perm - interleaver permutation
%   noiseLocations - logical array of error positions
%   messageLength - RS message length (k symbols per codeword)
%   t_correct - error correction capability (symbols per codeword)
%
% Output:
%   violations - number of codewords with more than t_correct errors
    
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
    
    % Count violations
    violations = 0;
    for b = 1:numCodewords
        idxStart = (b-1) * messageLength + 1;
        idxEnd = min(b * messageLength, N);
        
        errorCount = sum(origErrors(idxStart:idxEnd));
        
        if errorCount > t_correct
            violations = violations + 1;
        end
    end
end
