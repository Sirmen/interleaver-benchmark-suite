function [outMatrix, erM] = swapNESW(inMatrix)
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
   % % NW_q = N_half(:,1:midCol);
   NE_q = N_half(:,(cs-midCol)+1:end);
   SW_q = S_half(:,1:midCol);
   % % SE_q = S_half(:,(cs-midCol)+1:end);
   
   % % outMatrix = [NW_q SW_q; SE_q NE_q];
   % swap the NE-SW halves to form the final matrix
   outMatrix = inMatrix;
   outMatrix(1:midRow, (cs-midCol)+1:cs) = SW_q;
   outMatrix((rs-midRow)+1:rs, 1:midCol) = NE_q;
catch errsdh
   erM = strcat("Error in swapNESW:\n", errsdh.message);
   % rethrow(errsdh);
end % catch
end