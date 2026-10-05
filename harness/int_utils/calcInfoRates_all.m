function [avInfoRate_ns, erM] = calcInfoRates_all(intMethods, lenEncoded, interleaved_all)
try
   erM=""; % avInfoRate_all=[];
   %%%
   for i = 1:length(intMethods)
      methodName = intMethods{i};
      avInfoRate_ns.(methodName) = lenEncoded / length(interleaved_all.(methodName)); 
   end

      % if ~isempty(interleaved_all.(methodName))
      %    avInfoRate_ns.(methodName) = lenEncoded / length(interleaved_all.(methodName)); 
      % else
      %    erM = strcat((methodName),' - interleaved length = 0');
      % end
catch cirallerr
   erM = cirallerr.message; return;
end
end
