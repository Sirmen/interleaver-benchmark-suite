function [avgDataRaw, summaryTable, erM] = get_primaryMetrics_summary(results, methods)
summaryTable = table();
avgDataRaw = struct();
erM = "";
try
   % --- 1. Setup & Proper Length Detection ---
   nMethods = length(methods);
   
   % % we use [ ] to concatenate the fields into a single row vector.
   % sampleMethod = methods{1}; 
   % tempVec = [results.avInfoRate_all.(sampleMethod)]; 
   % nRuns = length(tempVec);
   nRuns = length(results.testedSizes);
   
   % Pre-allocate matrices with NaN
   dataDER = NaN(nMethods, nRuns);
   dataCR  = NaN(nMethods, nRuns);
   dataBE  = NaN(nMethods, nRuns);
   dataRES = NaN(nMethods, nRuns);
   dataEffectiveness = NaN(nMethods, nRuns);
   
   % --- 2. Centralized Data Retrieval ---
   for i = 1:nMethods
       method = methods{i};
       
       % Use [ ] to extract all values into one vector
       der = [results.avDecodeErrRate_all.(method)];
       cr  = [results.avContribution_all.(method)];
       be  = [results.avInfoRate_all.(method)];
       eff = [results.avEfficiency_all.(method)];
       res = [results.avDecodeErrRate_all.(method)];
       
       len = min(length(be), nRuns);
       
       dataBE(i, 1:len)     = be(1:len);
       dataRES(i, 1:len)   = eff(1:len);
       dataCR(i, 1:len) = cr(1:len);
       dataDER(i, 1:len)   = der(1:len);
       % Effectiveness trace
       dataEffectiveness(i, 1:len) = be(1:len) .* cr(1:len);
   end
 
   mean_CR =            mean(dataCR, 2, 'omitnan');
   mean_eta_ER =        mean(dataRES, 2, 'omitnan');
   mean_effectiveness = mean(dataEffectiveness, 2, 'omitnan');
   mean_DER =           mean(dataDER, 2, 'omitnan');
   mean_IR =            mean(dataBE, 2, 'omitnan');

   cMethods = categorical(methods);

   % --- 3. Summary Table mean calculations
   summaryTable = table( ...
                        cMethods(:), ...
                        mean_CR(:), mean_eta_ER(:), mean_effectiveness(:), mean_DER(:), mean_IR(:), ...
      'VariableNames', {'Method', 'CR', 'eta_ER', 'Effectiveness', 'DER', 'IR'} ...
      );
   
   summaryTable = sortrows(summaryTable, 'CR', 'descend');
   
   % Package for return
   avgDataRaw.dataBE = dataBE;
   avgDataRaw.dataRES = dataRES;
   avgDataRaw.dataCR = dataCR;
   avgDataRaw.dataDER = dataDER;
   avgDataRaw.dataEffectiveness = dataEffectiveness;

catch ME
   erM = strcat('*** Error in get_primaryMetrics_summary: ', ME.message);
   fprintf(strcat(erM, " Line:")); 
   disp(ME.stack(1).line);
   avgDataRaw = struct();
   summaryTable = table();
end
end