function [outMatrix, erM] = swapColsOddEven(inMatrix, swapOdds)
% swap odd or even cols, depending on swapOdds=true
try
   outMatrix= []; erM = "";
   % Get the size of the matrix
   [rs, cs] = size(inMatrix);
   half_col = round(cs / 2);

   outMatrix = inMatrix;
   beginCol = 2; % assume even
   if swapOdds
      beginCol = 1;
   end
   
   for c=beginCol:2:floor(cs/2)
      aimCol = c + half_col;
      % swap
      cTemp = inMatrix(:,c);
      outMatrix(:,c) = outMatrix(:,aimCol);
      outMatrix(:,aimCol) = cTemp;
   end
catch errsec
   erM = strcat("Error in swapColsOddEven:\n", errsec.message);
   % rethrow(errsec);
end % catch
end