function [statsECC, erM] = calcECCStats(n, t, perm, noiseLocs)
% Computes ECC related metrics based on FEC codeword boundaries (n) 
%  S_ECC: (Current Margin / Total Capacity). True Safety Margin: 1.0 = Perfect, 0 = Limit, <0 = Failure.
%  S_ECC_norm: normalized S_ECC
%  V_ECC: ecc Violation. Number of blocks that actually failed the RS decoder
%  U_ECC: ecc Utilization. Average fraction of t-capacity used across all codewords
erM = ""; statsECC = struct();
try
   % 1. Setup Parameters

   lenPerm = length(perm);
   numCWs = ceil(lenPerm / n);
   
   % 2. Map errors to de-interleaved positions (The "After" state)
   deinterleavedErrors = false(1, lenPerm);
   errorIndices = find(noiseLocs);
   if ~isempty(errorIndices)
       % Map errors relative to the permutation indices
       validIdx = errorIndices(errorIndices <= lenPerm);
       deinterleavedErrors(perm(validIdx)) = true;
   end

   % 3. Segment into codewords of size n
   paddedErrors = [deinterleavedErrors, false(1, (numCWs * n) - lenPerm)];
   cwMatrix = reshape(paddedErrors, n, numCWs);
   errorsPerCW = sum(cwMatrix, 1);
   
   maxErrorsInCW = max(errorsPerCW);
   
   % S_ECC: True Safety Margin (Capacity - Worst Block)
   statsECC.S_ECC = t - maxErrorsInCW; 
   
   % normalized S_ECC (Current Margin / Total Capacity). 1.0 = Perfect, 0 = Limit, <0 = Failure.
   statsECC.S_ECC_norm = (t - maxErrorsInCW) / t; 
   
   % V_ECC: eccViolations - Number of blocks that actually failed the RS decoder
   statsECC.V_ECC = sum(errorsPerCW > t); 
   
   % eccUtilization: Average fraction of t-capacity used across all codewords
   statsECC.U_ECC = mean(errorsPerCW) / t;

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end
