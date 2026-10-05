function [failed, cData] = controlCorrectShape_N1(data)
% controls & corrects input shape to be (Nx1)
   failed = false;
   cData = data;
   size_data = size(cData);
   if size_data(2) ~= 1 % correct the shape
      cData = cData'; % transpose row/col
      size_data_t = size(cData);
      if size_data_t(2) ~= 1 
         failed = true;
      end
   end
end