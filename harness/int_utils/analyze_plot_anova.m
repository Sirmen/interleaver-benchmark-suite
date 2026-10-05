function analyze_plot_anova(results, config, params)
   fprintf('\n=== STATISTICAL ANALYSIS ===\n');
   [anovaResults, erM] = calcANOVA_analysis(results, config, params);
   if erM == ""
      % Save ANOVA results
      if config.saveResults      
         erM = saveVars_YMD(config.dataSavePath, 'mat', 'anova_results', anovaResults);
         if erM ~= ""
            fprintf(erM);
         end
      
         erM = saveVars_YMD(config.dataSavePath, 'csv', 'anova_method_summary', anovaResults.summary);
         if erM ~= ""
            fprintf(erM);
         end
      end
   else
      fprintf('ANOVA analysis failed: %s\n', erM);
   end
end
