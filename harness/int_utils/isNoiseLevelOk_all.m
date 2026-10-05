function [noiseLevelOk, noisyCount, erM] = isNoiseLevelOk_all(intMethods, permutation_all, noiseLocations, noisyCountMin, noisyCountMax)
try
   erM=""; noisyCount=0; noiseLevelOk = true; % assume ok
   %%%
   for i = 1:length(intMethods)
      methodName = intMethods{i};

      permutation = permutation_all.(methodName); % extract related permutation
      [noiseLevelOk, noisyCount] = isNoiseLevelOk_single(permutation, noiseLocations, noisyCountMin, noisyCountMax);
   end
catch errinlo
   noiseLevelOk = false;
   erM = errinlo.message; 
end
end

function [noiseLevelOk, noisyCount] = isNoiseLevelOk_single(permutation, noiseLocations, noisyCountMin, noisyCountMax)
   [noisyPointsSorted, noiseDistances] = checkNoisePositions(noiseLocations, permutation);
   % noisyCount_d = sum(noiseDistances ~= 0);
   noisyCount = length(noisyPointsSorted);
   noiseLevelOk = (noisyCount >= noisyCountMin) && (noisyCount <= noisyCountMax);
end