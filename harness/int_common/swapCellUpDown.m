function outMatrix = swapCellUpDown(inMatrix, swapOdds)
   outMatrix = inMatrix;
   nRow = size(inMatrix,1);
   nCol = size(inMatrix,2);
   if swapOdds
      beginRow = 2; beginCol = 2; 
   else
      beginRow = 1; beginCol = 1; 
   end
   for r=beginRow:2:nRow
      for c=beginCol:2:nCol
         if (r + 2) <= nRow
            % swap
            cTemp = outMatrix(r, c);
            outMatrix(r, c) = outMatrix(r + 1, c);
            outMatrix(r+1, c) = cTemp;
         end
      end
   end
end
