% Test program for swapRowsOddEven function
% Tests matrices with 2 to 15 rows with swapOdds=true

clear;
clc;

fprintf('Testing swapRowsOddEven with swapOdds=true\n');
fprintf('==========================================\n\n');

% Store results for summary table
maxRs = 15;
swapDetails = cell(maxRs-1, 1);

% Test for matrix sizes from 2 to 15 rows
for numRows = 2:maxRs
    numCols = 4; % Fixed number of columns for clarity
    
    % Create a test matrix with sequential numbers for easy tracking
    testMatrix = reshape(1:(numRows*numCols), numRows, numCols);
    
    fprintf('Test Case: %d rows x %d cols\n', numRows, numCols);
    fprintf('------------------------------\n');
    
    % Display original matrix
    fprintf('Original Matrix:\n');
    disp(testMatrix);
    
    % Call the function with swapOdds=true
    [resultMatrix, errorMsg] = swapRowsOddEven(testMatrix, true);
    
    % Display result matrix
    fprintf('After Swapping (swapOdds=true):\n');
    disp(resultMatrix);
    
    % Show which rows were swapped and build swap details string
    half_row = round(numRows / 2);
    fprintf('Row swaps performed:\n');
    swapStr = '';
    swapCount = 0;
    for r = 1:2:floor(numRows/2)
        aimRow = r + half_row;
        fprintf('  Row %d <--> Row %d\n', r, aimRow);
        if swapCount > 0
            swapStr = sprintf('%s, Row %d <--> Row %d', swapStr, r, aimRow);
        else
            swapStr = sprintf('Row %d <--> Row %d', r, aimRow);
        end
        swapCount = swapCount + 1;
    end
    if swapCount == 0
        fprintf('  No swaps performed (no odd rows in first half)\n');
        swapStr = 'None';
    end
    
    % Store swap details for summary
    swapDetails{numRows-1} = swapStr;
    
    fprintf('\n');
end

fprintf('Testing complete!\n\n');

% Print summary table
fprintf('SUMMARY TABLE\n');
fprintf('=============\n');
for rs = 2:maxRs
    fprintf('rs=%d, swaps: %s\n', rs, swapDetails{rs-1});
end