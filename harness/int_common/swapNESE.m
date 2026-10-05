function [outMatrix, erM] = swapNESE(inMatrix)
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
   NE_q = N_half(:,(cs-midCol)+1:end);
   SE_q = S_half(:,(cs-midCol)+1:end);
   
   % swap the NE-SE halves to form the final matrix
   outMatrix = inMatrix;
   outMatrix(1:midRow,         (cs-midCol)+1:cs) = SE_q;
   outMatrix((rs-midRow)+1:rs, (cs-midCol)+1:cs) = NE_q;
catch errsnese
   erM = strcat("Error in swapNESE:\n", errsnese.message);
   % rethrow(errsnese);
end % catch
end