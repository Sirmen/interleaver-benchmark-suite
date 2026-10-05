function [decErrRate_all, erM] = calcDecErrorRates_all(intMethods, decoded_all, A)
try
   erM=""; decErrRate_all=[];
   %%%
   if iscolumn(A)
      dataRow = A.';
   else
      dataRow = A;
   end
   %
   for i = 1:length(intMethods)
      method = intMethods{i};

      decoded = decoded_all.(method)(1:length(dataRow));

      [~, errRate] = symerr(dataRow, decoded); 
      decErrRate_all.(method) = errRate;

      % Final NaN check
      if isnan(decErrRate_all.(method))
         decErrRate_all.(method) = 0;
      end
   end
        
catch cererr
   erM = cererr.message; return;
end
end
