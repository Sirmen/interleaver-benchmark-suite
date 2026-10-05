function plotAdjBlock(L, K, lastPerms, intMethods, config)
% %%%%% permutation entropy analysis 
try
   fig = figure('Name', 'Jumps'); hold on
   nMethod = length(intMethods);
   rowMax = ceil(nMethod/2);
   % 
   for i=1:nMethod
      method_cell = cellstr(intMethods(i));
      method = method_cell{1};
      % extract all data for this method 
      perm = extractfield(lastPerms, method);
      if ~isempty(perm)
         % compute perm stats
         excludeZero = false;
         
         [minBlockmin, minBlockmax, minBlockavg, ...
          varBlockMax, varBlockAvg, avgBlock, blockPatternFit, ...
          minAdj, avgAdj, varAdj, cvAdj, adjDistances] = ...  
                     intraVectorDistances(perm, L, excludeZero);

         dataLen = length(perm);
         % plot  
         rowNo = i; colNo = 1;
         if i > rowMax
            rowNo = i-rowMax; colNo = 2; 
         end 
         subplot(rowMax,2,i),    
         plot(adjDistances, 'k'), hold on, grid on;           
            % ylabel(method,'FontAngle','italic','FontWeight','bold','Color','r');     
               title(strcat(method, ': Adjacent avg:', num2str(avgAdj,'%.2f'), ...
                            ' Block avg:', num2str(avgBlock,'%.2f'),' N:', num2str(dataLen)), 'FontSize', 11); 
               ylim([0 1]) 
      end % if ~isempty(filteredData)
   end
   sgttl = strcat('Adjacent Distances in the Sample Signal L:', num2str(L), ' K:', num2str(K));
   sgtitle(sgttl);

   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
catch errPEs
    rethrow(errPEs);
end % catch
end

