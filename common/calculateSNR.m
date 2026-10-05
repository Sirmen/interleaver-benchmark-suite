function snr = calculateSNR(cleanData, noisyData)
% Calculate the true SNR between clean and noisy 3D data
% Inputs:
%   cleanData: 3D array of clean data
%   noisyData: 3D array of noisy data
   % Calculate the power of the clean signal
   cleanPower = sum(cleanData(:).^2) / numel(cleanData);
   
   % Calculate the power of the noise signal
   noiseSignal = noisyData - cleanData;
   noisePower = sum(noiseSignal(:).^2) / numel(noiseSignal);
   
   % Calculate the SNR in dB
   snr = 10 * log10(cleanPower / noisePower);
end
