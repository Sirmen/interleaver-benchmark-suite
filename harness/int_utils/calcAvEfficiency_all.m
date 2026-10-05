function [avEfficiency_ns, avContribution_ns, erM] = calcAvEfficiency_all(intMethods, efficiency_all, contribution_all, L, N)
% Calculate & keep avg contributions & Efficiencys
try            
   erM=""; % statsAll=[];
   %%%
   avEfficiency_ns.L = L;    avEfficiency_ns.N = N;   
   avContribution_ns.L = L;  avContribution_ns.N = N;   
   %
   for i = 1:length(intMethods)
      methodName = intMethods{i};

      avEfficiency_ns.(methodName) = mean([efficiency_all.(methodName)], 'omitnan'); 
      avContribution_ns.(methodName) = mean([contribution_all.(methodName)], 'omitnan'); 
   end
catch caecerr
   erM = caecerr.message; return;
end
end
