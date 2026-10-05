function [avDecodeErrRate_ns, erM] = calcAvDecodeErrRate_all(intMethods, decErrRate_all)
try            
   erM=""; avDecodeErrRate_ns=[];
   %%%
   % Calculate & keep avg decoding error rates WITH interleaving
   for i = 1:length(intMethods)
      methodName = intMethods{i};
      avDecodeErrRate_ns.(methodName) = mean([decErrRate_all.(methodName)], 'omitnan'); 
   end
catch cadererr
   erM = cadererr.message; return;
end
end
