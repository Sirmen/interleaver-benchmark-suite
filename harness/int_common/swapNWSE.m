function [outMatrix, erM] = swapNWSE(inMatrix)
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
   SE_q = S_half(:, midCol+1:cs);
   
   % swap the NW-SE halves to form the final matrix
   outMatrix = inMatrix;
   outMatrix(1:midRow, 1:midCol) = SE_q;
   outMatrix((rs-midRow+1):end, (cs-midCol+1):end) = NW_q;
catch errsdh
   erM = strcat("Error in swapNWSE:\n", errsdh.message);
   % rethrow(errsdh);
end % catch
end