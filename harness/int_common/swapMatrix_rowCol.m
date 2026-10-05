function [ final_matrix, erM ] = swapMatrix_rowCol(original_matrix, swapOdds)
try
   erM=""; 
   %%%
   final_matrix = original_matrix;
   
   % Swap Diagonal Chunks
   final_matrix = swapSESW(final_matrix);  

   % swap rows Odd/Even
   final_matrix = swapRowsOddEven(final_matrix, swapOdds);
   % final_matrix = swapRowsPermuted(final_matrix);

   % swap cols Odd/Even
   final_matrix = swapColsOddEven(final_matrix, swapOdds);
   % final_matrix = swapColsPermuted(final_matrix);
catch errsmfft3
   erM = strcat("Error in swapMatrix:\n", errsmfft3.message);
   % rethrow(errgpfft);
end % catch
end
