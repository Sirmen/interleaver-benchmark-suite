function itIsUnique = isUnique(inVector)
% R.Tanju Sirmen 2025
% returns whether all values in inVector are unique

itIsUnique = length(unique(inVector)) == length(inVector);