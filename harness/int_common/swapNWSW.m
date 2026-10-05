function [outMatrix, erM] = swapNWSW(inMatrix)
try
   outMatrix= []; erM = "";
   % Get the size of the matrix
   [rs, cs] = size(inMatrix);
   midRow = fix(rs/2);
   midCol = fix(cs/2);

   % Split the matrix in half row-wise
   N_half = inMatrix(1:midRow, :);
   S_half = inMatrix((rs-midRow)+1:end, :);
   
   % Split each half into quarters
   NW_q = N_half(:, 1:midCol);
   SW_q = S_half(:, 1:midCol);
   
   % swap the NW-SW halves to form the final matrix
   outMatrix = inMatrix;
   outMatrix(1:midRow,          1:midCol) = SW_q;
   outMatrix((rs-midRow+1):end, 1:midCol) = NW_q;
catch errsnwsw
   erM = strcat("Error in swapNWSW:\n", errsnwsw.message);
   % rethrow(errsnwsw);
end % catch
end