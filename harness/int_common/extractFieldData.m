function [fData, erM] = extractFieldData(dataAll, intMethod, desiredFields)
try
   fData = zeros(length(intMethod),1); erM = "";
   % Extract indices where method = intMethod
   indices = strcmp(string({dataAll.method}), intMethod);
   filteredData = dataAll(indices);
   % Extract values 
   for f=1:length(desiredFields)
      field = desiredFields{f}; % Convert string to a valid field name
      dData = [filteredData.(field)];
      fData(f) = mean([dData],'omitnan');
   end
catch errefd
   erM = strcat("Error in extractFieldData:\n", errefd.message);
end % catch
end