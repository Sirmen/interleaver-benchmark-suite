function fecConfig = configure_FEC_parameters(base, eccMin)
% Returns Forward Error Correction Coding parameters 
%  (independent of interleaver block size)
%
% Standard RS code configuration
% Common RS codes:
%   RS(7,5):   n=7, k=5, t=1   (1/7 = 14.2857..% overhead, corrects 1 symbol)
%   RS(15,11): n=15, k=11, t=2 (27% overhead, corrects 2 symbols)
%   RS(31,25): n=31, k=25, t=3 (24% overhead, corrects 3 symbols)
%   RS(255,223): n=255, k=223, t=16 (14% overhead, corrects 16 symbols)

   % Default: RS(7,5) - commonly used for burst error correction
   % fecConfig.n = 7;        % Codeword length (symbols)
   % fecConfig.k = 5;        % Message length (symbols)
   [ k, n, infoCapacity, eccReal ] = calcParametersRS( base, eccMin );
   fecConfig.n = n;        % Codeword length (symbols)
   fecConfig.k = k;        % Message length (symbols)
   
   fecConfig.p = fecConfig.n - fecConfig.k;  % Parity symbols
   fecConfig.t_correct = floor(fecConfig.p / 2);  % Correctable symbols per codeword
   
   % fecConfig.eccReal = fecConfig.t_correct / fecConfig.n; % Err correction capability (e.g., 1/7 = 14.29%)
   fecConfig.eccReal = eccReal; % Err correction capability (e.g., 1/7 = 14.29%)
   
   % fecConfig.IR = fecConfig.k / fecConfig.n; % Information Rate
   fecConfig.IR = infoCapacity; % Information Rate
   fecConfig.overhead = fecConfig.p / fecConfig.k;  % Fractional overhead

   % --- GENERALIZED FIELDS ---
   fecConfig.L = fecConfig.n;         % Codeword length (Block Size L)
   fecConfig.tau = fecConfig.eccReal; % Normalized Capacity
   
   % Alternative configurations (uncomment to use)
   % RS(15,11): eccConfig = struct('n',15, 'k',11, 'p',4, 't_correct',2, 'overhead',0.36);
   % RS(31,25): eccConfig = struct('n',31, 'k',25, 'p',6, 't_correct',3, 'overhead',0.24);
   % RS(255,223): eccConfig = struct('n',255, 'k',223, 'p',32, 't_correct',16, 'overhead',0.14);
end