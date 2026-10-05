function plotPermutationEntropy(base, L, K, distAll, intMethods)
% %%%%% permutation entropy analysis 
try
   delay = 1; % delay between points in ordinal patterns (1 means successive points)
   order = base-1; % order 3 of ordinal patterns (4-points ordinal patterns)
   windowSize = K; % 512 ordinal patterns in one sliding window
   %
   sepMax = 0.1;
   maxPE = 0.1;
   figure, hold on
   nMethod = length(intMethods);
   % extract performance data. rows are methods, cols performances 
   for i=1:nMethod
      method = string(intMethods(i));
      % extract all data for this method 
      indices = strcmp(string({distAll.method}), intMethods(i));
      filteredData = distAll(indices);
      if ~isempty(filteredData)
         % extract separations data for this method 
         separationsS = {filteredData.separations};
         % get the last one
         separationsLast = cell2mat(separationsS(length(separationsS)));
         sepData = separationsLast(:);
         % compute PE
         [peData, erMpe] = PEanalysis( sepData, delay, order, windowSize );
         if ~isempty(erMpe)
            fprintf(strcat("\n\t",erMpe));
            % error(erMpe);
         end
         % 
         dataLen = length(sepData) + 1;
         % sepMaxC = max(max(sepData)) + 0.1;
         % if sepMaxC > sepMax
         %    sepMax = sepMaxC;
         % end
            sepMax = dataLen + 5;
         % maxPEC = max(max(peData)) + 0.1;
         % if maxPEC > maxPE
         %    maxPE = maxPEC;
         % end
            maxPE = 0.8;
         % plot  
         pNo = (i-1) * 2 + 1;
         subplot(nMethod,2,pNo),    plot(sepData, 'k'), hold on, grid on;           
            ylabel(method,'FontAngle','italic','FontWeight','bold','Color','r');     
               title(strcat('Seperations (avg:', num2str(mean(sepData),'%.2f'),' N:', num2str(dataLen),')')); ylim([0 sepMax]) 
         subplot(nMethod,2,pNo+1),  plot(length(sepData) - length(peData)+1:length(sepData), peData, 'b'), hold on, grid on;
               title(strcat('Permutation Entropy (avg:', num2str(mean(peData),'%.2f'),')'));   ylim([-0.5 maxPE]) 
      end % if ~isempty(filteredData)
   end
   sgttl = strcat('Permutation Entropy Analysis of the Signal L:', num2str(L), ' K:', num2str(K));
   sgtitle(sgttl);
catch errPEs
    rethrow(errPEs);
end % catch
end
