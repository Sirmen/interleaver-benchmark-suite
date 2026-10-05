function [avIntRuntime_ns, erM] = calcAvIntRuntime_all(intMethods, interleaveTime_sums, testCounts)
try            
   erM=""; avIntRuntime_ns=[];
   %%%
   % Calculate & keep avg interleaving run times
   for i = 1:length(intMethods)
      methodName = intMethods{i};
      avIntRuntime_ns.(methodName) = [interleaveTime_sums.(methodName)] / testCounts.(methodName); 
   end
catch carterr
   erM = carterr.message; return;
end
end
