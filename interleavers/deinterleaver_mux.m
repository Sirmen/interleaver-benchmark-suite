function [deintData, erM] = deinterleaver_mux(intData, delay)
% R.Tanju Sirmen - 2023
% Mux De-Interleaving
try
   erM = ""; deintData = []; 
   % control & correct shape of data to be Nx1
   [failed, intData] = controlCorrectShape_N1(intData);
   if failed 
      erM = strcat("Data shape error: (", num2str(size(intData)), ") Must be (Nx1)");
      error(erM)
   end

   % create comm object
   hDeint = comm.MultiplexedDeinterleaver('Delay', delay);

   % Deinterleave
   deintData = step(hDeint,intData);

catch errimdx
   erM = strcat("\tError in deinterleaver_matrix:\n", erM, errimdx.message);
   % rethrow(errimdx);
end % catch
end
