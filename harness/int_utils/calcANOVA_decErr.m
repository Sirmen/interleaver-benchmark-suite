function [p,tbl,stats, erM] = calcANOVA_decErr(statsAll)
% ANOVA for method comparison
try
   erM=""; % avInfoRate_all=[];
   %%%

   methods = unique({statsAll.method});
   nMethods = length(methods);
   metrics = {'noise', 'decodeErrRate', 'cont', 'effectiveness'};
   
   % Initialize an empty table with proper variable types
   data = table('Size', [0, length(metrics)+1], ...
                'VariableTypes', ['cell', repmat({'double'}, 1, length(metrics))], ...
                'VariableNames', ['method', metrics]);

   %
   [p,tbl,stats] = anova1(data.decodeErrRate, data.method);
   multcompare(stats); % Post-hoc pairwise comparisons
   
   % Correlation between noise and error for each method
   for m = 1:nMethods
       idx = strcmp(data.method, methods{m});
       [R,P] = corrcoef(data.noise(idx), data.decodeErrRate(idx));
       fprintf('%s: R=%.2f (p=%.4f)\n', methods{m}, R(2,1), P(2,1));
   end
   
   % Calculate mean metrics per method
   summary = grpstats(data, 'method', {'mean','sem'}, 'DataVars',{'decodeErrRate','cont','effectiveness'});
   
   % Sort by error rate (ascending) and effectiveness (descending)
   summary = sortrows(summary, {'mean_decodeErrRate','mean_effectiveness'}, {'ascend','descend'});
   
   disp(summary(:,{'method','mean_decodeErrRate','mean_effectiveness','mean_cont'}));
   
   % % Interactive data exploration
   % uitable('Data', summary{:,2:end}, 'ColumnName', summary.Properties.VariableNames(2:end),...
   %         'RowName', summary.method, 'Units','Normalized','Position',[0 0 1 1]);
   
catch errAnvde
   erM = errAnvde.message; 
   fprintf(erM);
   return;
end
end
