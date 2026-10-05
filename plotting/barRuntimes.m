function [] = barRuntimes(avIntRuntime_all, intMethods, config)
try
% barplots performances together
   % discard inf
   for i=1:length(intMethods)
      method = string(intMethods(i));
      runTimeData(i) = avIntRuntime_all.(method);
   end   
   
   limMul = 1.15;

   %  Sort the values in ascending order and get the sorting indices
   [runtimesSorted, sortIdx] = sort(runTimeData,'ascend');
   intMethodsSorted = intMethods(sortIdx);

   % plot decoding performances
   fig = figure('Name', 'Runtimes');
   b = bar(intMethodsSorted, runtimesSorted, 'FaceColor', [0.75 0.75 0.75]);  
   grid on;
   ylim_min = min(runtimesSorted);
   ylim_max = max(runtimesSorted); 
   if ylim_max > 0
      ylim([0 ylim_max*limMul]); % ylim([0 1]);
   end
   xtips1 = b(1).XEndPoints;
   ytips1 = b(1).YEndPoints;
   labels1 = string(b(1).YData);
   % text(xtips1,ytips1,labels1,'HorizontalAlignment','center','VerticalAlignment','bottom', ...
   %                            'FontSize',8,'FontAngle','italic','color','r'); 
   title('Average Interleaving Runtimes')

   
   if config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);  fprintf('%s \n',sMsg);
   end
catch errrtp
   rethrow(errrtp);
end % catch
end