function sMsg = savePlot(fig, dataSavePath)
   plotName = fig.Name; 
   
   % % 1. Save as a MATLAB .fig file (for future editing/zooming)
   % sMsg = saveVars_YMD(config.dataSavePath, 'fig', plotName, fig);
   
   % 2. Save as a high-resolution .png (for your paper/report)
   % saveVars_YMD uses exportgraphics() internally for images
   sMsg = saveVars_YMD(dataSavePath, 'png', plotName, fig);
   
   % Error Reporting
   if sMsg == ""
      sMsg = strcat('..(', plotName, ') saved to: ', dataSavePath);
   end
end
