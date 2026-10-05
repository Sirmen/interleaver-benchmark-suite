function [deinterleaved_data, erM] = deinterleaver_universal(interleaved_data, permutation, originalSize)
% DEINTERLEAVER to be used to Deinterleave any interleaved data as long as
% the permutation used by the interleaver is correctly supplied
%
% Mathematical Foundation:
%     Interleaving is essentially a permutation operation: interleaved = original(permutation)
%     Deinterleaving is the inverse permutation: [~, inversePerm] = sort(permutation); deinterleaved = interleaved(inversePerm)
% 
% Advantages Over Traditional Methods:
%     Doesn't require knowledge of buffer sizes, slopes, or other interleaver parameters
%     Perfect reconstruction regardless of interleaver complexity
%     Handles padding/truncation automatically when you specify original size
%
%   Inputs:
%       interleaved_data: Interleaved data vector
%       permutation: Permutation indices used in interleaving
%       originalSize: Size of original data before padding
%   Outputs:
%       deinterleaved_data: Deinterleaved output data
%       erM: Error message if any

try
   erM = ""; deinterleaved_data = [];
   
   % Ensure input is a vector
   if ~isvector(interleaved_data); interleaved_data = interleaved_data(:); end
   if ~isvector(permutation);      permutation = permutation(:);           end
    
   if length(interleaved_data) ~= length(permutation)
      erM = sprintf('Permutation vector length (%d) must match interleaved data length (%d)', length(permutation), length(interleaved_data));
      return
   end
    
   if originalSize > length(interleaved_data)
      erM = sprintf('interleaved data length (%d) must be >= original data length (%d)', length(interleaved_data), originalSize);
      return
   end
            
   % Create inverse permutation
   [~, inversePerm] = sort(permutation);
   
   % Apply inverse permutation
   deinterleaved = interleaved_data(inversePerm);
   
   % Remove padding if needed
   deinterleaved_data = deinterleaved(1:originalSize);
   
   % Convert to row vector for consistency
   if iscolumn(deinterleaved_data)
      deinterleaved_data = deinterleaved_data';
   end
    
catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end
