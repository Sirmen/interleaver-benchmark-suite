function [outMatrix, erM] = swapNENW(inMatrix)
try
   outMatrix= []; erM = "";
   % Get the size of the matrix
   [rm, cm] = size(inMatrix);
   
   % col-wise Split the matrix into halves
   left_half = inMatrix(:,1:round(cm/2));
   right_half = inMatrix(:,round(cm/2)+1:end);
   
   % Get the size of the left-half
   [rl, cl] = size(left_half);
   
   % row-wise Split the left-half into halves
   split_row = round(rl / 2);
   upper_half_left_half = left_half(1:split_row,:);
   lower_half_left_half = left_half(split_row+1:end,:);
   
   % concat halves 
   new_left_half = [lower_half_left_half; upper_half_left_half];
   
   % Concatenate the halves to form the final matrix
   outMatrix = [new_left_half right_half];
catch errsld
   erM = strcat("Error in swapNENW:\n", errsld.message);
   % rethrow(errsld);
end % catch
end