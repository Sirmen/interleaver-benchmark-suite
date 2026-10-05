function final_matrix = swapRowsPermuted(final_matrix)
   % Get the size of the matrix
   [nR, nC] = size(final_matrix);
   % permute rows
   rowSequence = getPerm(nR);
   for r=1:nR
      rTemp = final_matrix(r,:);
      final_matrix(r,:) = final_matrix(rowSequence(r),:);
      final_matrix(rowSequence(r),:) = rTemp;
   end
end
