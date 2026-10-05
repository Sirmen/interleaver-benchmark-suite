function [outVector, erM] = shiftVectorByX(inVector, X)
% shifts points by x positions to rights (circular)
try
   outVector = inVector; erM = "";

   % Get the size of the matrix
   N = length(inVector);

   sRight = 1:N-X;
   sLeft = N-X+1:N;
   sNdx = [sLeft sRight];

   outVector(:) = inVector(sNdx);
   
catch errsec
   erM = strcat("Error in shiftVectorByX:\n", errsec.message);
   % rethrow(errsec);
end % catch
end