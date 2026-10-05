function final_matrix = swapColsPermuted(final_matrix)
   % Get the size of the matrix
   [nR, nC] = size(final_matrix);
   % permute columns
   colSequence = getPerm(nC);
   for c=1:nC
      cTemp = final_matrix(:,c);
      final_matrix(:,c) = final_matrix(:,colSequence(c));
      final_matrix(:,colSequence(c)) = cTemp;
   end
end
