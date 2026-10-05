function plotSepAvg(L, K, distAll, intMethods, config)
% %%%%% plots Separation Averages
try
   nMethod = length(intMethods);
   rowMax = ceil(nMethod/2);
   sepMax = 0.1;
   %
   fig = figure('Name', 'Separations'); hold on
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
         % 
         dataLen = length(sepData) + 1;
         % sepMaxC = max(max(sepData)) + 0.1;
         % if sepMaxC > sepMax
         %    sepMax = sepMaxC;
         % end
            sepMax = dataLen + 5;

         % plot  
         rowNo = i; colNo = 1;
         if i > rowMax
            rowNo = i-rowMax; colNo = 2; 
         end 
         subplot(rowMax,2,i),    plot(sepData, 'k'), hold on, grid on;           
            % ylabel(method,'FontAngle','italic','FontWeight','bold','Color','r');     
               % title(strcat(method,' (avg:', num2str(mean(sepData),'%.2f'),' N:', num2str(dataLen),')')); ylim([0 sepMax]) 
               meanSepData = mean(sepData);
               title(strcat(method,': avg:', num2str(meanSepData,'%.2f'), ...
                     ' N:', num2str(dataLen),'(', num2str(meanSepData/dataLen,'%.2f'),')'), 'FontSize', 11); 
               ylim([0 sepMax]) 
      end % if ~isempty(filteredData)
   end
   sgttl = strcat('Seperations in the Sample Signal L:', num2str(L), ' K:', num2str(K));
   sgtitle(sgttl);

   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
catch errPEs
    rethrow(errPEs);
end % catch
end
