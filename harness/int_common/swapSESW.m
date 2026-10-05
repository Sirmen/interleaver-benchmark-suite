function [outMatrix, erM] = swapSESW(inMatrix)
try
   outMatrix= []; erM = "";
   % Get the size of the matrix
   [rm, cm] = size(inMatrix);
   
   % Split the matrix in half row-wise
   upper_half = inMatrix(1:round(rm/2), :);
   lower_half = inMatrix(round(rm/2)+1:end, :);
   
   % Get the size of the lower half
   [rl, cl] = size(lower_half);
   
   % row-wise Split the lower half into halves 
   split_col = round(cl / 2);
   left_half_lower_half = lower_half(:, 1:split_col);
   right_half_lower_half = lower_half(:, split_col+1:end);
   
   new_lower_half = [right_half_lower_half left_half_lower_half];
   
   % Concatenate the halves to form the final matrix
   outMatrix = [upper_half; new_lower_half];
catch errsld
   erM = strcat("Error in swapSESW:\n", errsld.message);
   % rethrow(errsld);
end % catch
end
