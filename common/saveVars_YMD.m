function erM = saveVars_YMD(dataSavePath, ext, varargin) 
   erM = "";

   if mod(numel(varargin), 2) ~= 0
       erM = '*** Input error: Variable inputs must be provided as Name-Value pairs.';
       return;
   end

   % Ensure directory exists
   if ~exist(dataSavePath, 'dir')
       mkdir(dataSavePath);
   end

   dateStr = datestr(now, 'yymmdd');

   for i = 1:2:numel(varargin)
      varNameChar = varargin{i};
      varValue = varargin{i+1};
      
      try
         % --- STEP 1: DETECT VERSION FOR THIS SPECIFIC VARIABLE ---
         % Filter directory for files matching: "VariableName_BurstType_YYMMDD_*.ext"
         pattern = sprintf('%s_%s_*.%s', varNameChar, dateStr, ext);
         existingFiles = dir(fullfile(dataSavePath, pattern));
         
         maxVer = 0;
         if ~isempty(existingFiles)
             % Regex looks for: [CurrentName]_[Date]_[Digit].[Extension]
             % We specifically capture the digit after the variable name and date
             regexPattern = sprintf('%s_%s_(\\d+)\\.%s$', varNameChar, dateStr, ext);
             tokens = regexp({existingFiles.name}, regexPattern, 'tokens');
             
             for t = 1:numel(tokens)
                 if ~isempty(tokens{t})
                     verNum = str2double(tokens{t}{1}{1});
                     if verNum > maxVer, maxVer = verNum; end
                 end
             end
         end
         
         versionNum = maxVer + 1;
         fileName = fullfile(dataSavePath, sprintf('%s_%s_%d.%s', ...
                             varNameChar, dateStr, versionNum, ext));

         % --- STEP 2: SAVE LOGIC
         if (isgraphics(varValue) || (isa(varValue, 'matlab.ui.Figure')))
             % Use appropriate method for figures
             switch lower(ext)
                 case 'fig'
                     % Save as MATLAB figure file
                     savefig(varValue, fileName);
                 case {'png', 'jpg', 'jpeg', 'tiff', 'bmp', 'pdf', 'eps'}
                     % Save as image format
                     exportgraphics(varValue, fileName);
                 otherwise
                     % Try saveas for other formats, or fall back to exportgraphics
                     saveas(varValue, fileName);
             end
         elseif istable(varValue) && strcmpi(ext, 'csv')
             writetable(varValue, fileName);
         else
             S = struct();
             S.(varNameChar) = varValue;
             save(fileName, '-struct', 'S', varNameChar, '-v7.3');
         end
         
      catch ME
         erM = strcat(erM, sprintf('*** Error saving %s: %s\n', varNameChar, ME.message));
      end
   end
end
