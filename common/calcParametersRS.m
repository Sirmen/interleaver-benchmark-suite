function [ k, n, infoCapacity, eccReal ] = calcParametersRS( base, eccMin )
%% calculates the Reed-Solomon encoded msg parameters by inputs
%   base: radix (ie alphabet) of the plain msg to be encoded
%   eccMin: min desired percentage of correctable errors
% pads 0 to the plain msg -if needed- and returns
% 
% m: symbol size in bits 
% k: message size in symbols - ie lenSym
% n: code word size in symbols - ie lenCw
% t: number of correctable symbols 
%  
%  n = 2^m − 1
%  t = (n − k) / 2
% 
% The encoder 
%   takes m bits to form a symbol and k symbols to form the message, 
%   calculates 2t symbols to append to the message to form the code word 
%   to be transmitted ( k+2t = n symbols, or n*m bits ) 
% The decoder 
%   receives n symbols and if there are t or less corrupt symbols 
%   it correctly reproduces the initial message of k symbols.
%%
try
   m = ceil(logb(base, 2));     % bits per symbol
   n = 2^m - 1;                 % codeword length (symbols)
   t = ceil(n * eccMin);        % desired correctable symbols
   k = n - 2 * t;               % data symbols
   eccReal = t / n;             % actual error correction ratio
   infoCapacity = k / n;        % useful data ratio
catch err
   errMsg = strcat('\n   >>> error in calcParametersRS <<<\n');
   fprintf(errMsg);
   rethrow(err);
end % catch
end