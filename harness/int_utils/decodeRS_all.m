function [decoded_all, corcCWrate_all, uncorcCWrate_all, errCWs_all, erM] = decodeRS_all(intMethods, deinterleaved_all, base, eccReal)
try
   erM=""; decoded_all=[]; corcCWrate_all=[]; uncorcCWrate_all=[]; errCWs_all=[];
   %%%
   for i = 1:length(intMethods)
      methodName = intMethods{i};

      deinterleaved = deinterleaved_all.(methodName); % extract deinterleaved data
      [decoded, ~, corcCWrate, uncorcCWrate, errCWs, ~, ~, erM] = decoderRS_CW( deinterleaved, base, eccReal );
      if erM ~= ""
         error('Error in decodeRS_all:\n%s', erM);
      else
         decoded_all.(methodName) = decoded;
         corcCWrate_all.(methodName) = corcCWrate;
         uncorcCWrate_all.(methodName) = uncorcCWrate;
         errCWs_all.(methodName) = errCWs;
      end
   end
catch ME
   errMdl = ME.stack(1).name;
   errLine = ME.stack(1).line;
   errPos = strcat(errMdl, " Line:", num2str(errLine));
   erM = strcat('Error in ', errMdl,': %s\n  %s', ME.message, errPos);
end
end
