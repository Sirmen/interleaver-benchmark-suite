function print_performance_table(summaryTable)
   fprintf('METHOD RANKING (by CR(μ))\n');
   fprintf('%s\n', repmat('=', 1, 65));
   fprintf('%-18s | %10s | %10s | %13s\n', 'Interleaver', 'CR(μ)', 'η_ER(μ)', 'Effectiveness(μ)');
   fprintf('%s\n', repmat('-', 1, 65));
   
   for i = 1:height(summaryTable)
     fprintf('%-18s | %10.4f | %10.4f | %13.4f\n', ...
             char(summaryTable.Method(i)), ...
             summaryTable.CR(i), ...
             summaryTable.eta_ER(i), ...
             summaryTable.Effectiveness(i));
   end
   fprintf('%s\n', repmat('=', 1, 65));
end
