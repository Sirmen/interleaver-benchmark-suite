function d = divisors(n)
%DIVISORS  Octave shim for MATLAB's divisors() (Symbolic Math Toolbox).
%   Returns all positive divisors of the positive integer N, ascending.
%   Only for running this harness under Octave; MATLAB uses its own.
   n = double(n);
   if ~isscalar(n) || n < 1 || mod(n,1) ~= 0
      error('divisors: N must be a positive integer scalar.');
   end
   d = [];
   for k = 1:floor(sqrt(n))
      if mod(n, k) == 0
         d(end+1) = k;
         if k ~= n/k, d(end+1) = n/k; end
      end
   end
   d = sort(d);
end
