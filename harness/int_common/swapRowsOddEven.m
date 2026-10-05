function [outMatrix, erM] = swapRowsOddEven(inMatrix, swapOdds)
% swap odd or even cols, depending on swapOdds=true
try
   outMatrix= []; erM = "";
   % Get the size of the matrix
   [rs, cs] = size(inMatrix);
   half_row = round(rs / 2);

   outMatrix = inMatrix;
   beginRow = 2; % assume even
   if swapOdds
      beginRow = 1;
   end
   for r=beginRow:2:floor(rs/2)
      aimRow = r + half_row;
      % swap
      rTemp = inMatrix(r,:);
      outMatrix(r,:) = outMatrix(aimRow,:);
      outMatrix(aimRow,:) = rTemp;
   end
catch errsec
   erM = strcat("Error in swapRowsOddEven:\n", errsec.message);
   % rethrow(errsec);
end % catch
end