function [failed, correctedData] = controlCorrectShape_1N(inputData)
% Controls & corrects input shape to be (1xN)
% Returns:
%   failed - true if input cannot be converted to 1xN vector
%   correctedData - input data reshaped to 1xN if possible

    if isrow(inputData)
        % Already in correct shape
        correctedData = inputData;
        failed = false;
    elseif iscolumn(inputData)
        % Transpose to make it row vector
        correctedData = inputData';
        failed = false;
    else
        failed = true;
        correctedData = inputData;
    end
end