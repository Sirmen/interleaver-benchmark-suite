function [CV, erM] = calcCoefficientOfVariation(dData)
% The Coefficient of Variation is defined as the ratio of the standard deviation 
% to the mean, and it provides a normalized measure of the dispersion of the data.
%   Unitless: Because CV is the ratio of the standard deviation to the mean, 
%     it is a dimensionless number, making it useful for comparing the degree of 
%     variation between data sets with different units or different means.
%   Relative Measure: CV expresses the extent of variability in relation to the mean 
%     of the population, allowing for comparison of variability across different data sets.
try
   erM = "";
   mu = mean(dData);    % Calculate the mean
   sigma = std(dData);  % Calculate the standard deviation
   CV = sigma / mu;     % Calculate the Coefficient of Variation
catch cvErr
   erM = strcat("calcCoefficientOfVariation:\n",cvErr.message);
end