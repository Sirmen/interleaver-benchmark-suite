function [vectorInterleaved, permutation, strategy_info, erM] = interleaver_turbo(vectorIn, block_size, pad_symbol, maxExtensionPercentage)
% Fast Turbo Interleaver with cached QPP lookup and safe fallbacks
% -------------------------------------------------------------------------
% Inputs:
%   vectorIn: input data vector (1xN)
%   block_size: target block size for interleaving
%   pad_symbol: symbol for padding (default 0)
%   maxExtensionPercentage: maximum extension allowed (e.g., 0.2)
%
% Outputs:
%   vectorInterleaved: interleaved data vector
%   permutation: permutation indices used
%   strategy_info: info structure (fields depend on strategy)
%   erM: error message (empty if no error)
%
% Version: Oct 2025; documentation and fallback audit 2026
% -------------------------------------------------------------------------
%
% WHAT THIS METHOD IS IN THE COMPARISON
% -------------------------------------------------------------------------
% The benchmark's `turbo` entry is the 3GPP LTE quadratic permutation
% polynomial (QPP) interleaver, Sun & Takeshita:
%       pi(i) = (f1*i + f2*i^2) mod N,     i = 0..N-1
% valid (a bijection) iff f1 is coprime to N and every prime dividing N also
% divides f2 - i.e. f2 is a multiple of rad(N). Parameter selection lives in
% turbo_selectQPPParameters.m.
%
% READ THIS BEFORE TRUSTING METHODS 2-4 BELOW
% -------------------------------------------------------------------------
% This file has a four-tier fallback chain. Until the 2026 fix,
% turbo_selectQPPParameters returned f1 = 1 for roughly half the sampled N and
% failed outright at N = 255, so the chain fired constantly and the column
% labelled "turbo" in the results was frequently NOT a QPP interleaver at all.
% With the corrected selector, METHOD 1 succeeds for every N the sweep uses and
% methods 2-4 are unreachable. They are retained as a safety net, but if one
% ever fires the result must NOT be reported as LTE-QPP, for these reasons:
%
%   METHOD 2 (tryFastNearestQPP) CHANGES THE TRANSMITTED LENGTH.
%     It pads N up to the nearest multiple of 8 in 8..800 and returns a
%     permutation of THAT length. The extension guard earlier in this function
%     was applied to padded_length, not to test_size, so this path can exceed
%     maxExtensionPercentage silently. Bandwidth efficiency BE would then be
%     N/test_size < 1 while the harness still records BE = 1. It also caps out
%     at 800, so it cannot help large frames at all.
%
%   METHOD 3 (tryFastBlockQPP) is a BLOCK-wise QPP: a short QPP of length
%     8..64 repeated across ceil(N/block_size) blocks. Its dispersion is
%     bounded by the block size, not by N, so its separation metrics do not
%     scale with frame length. It is a different method, closer to `block`.
%
%   METHOD 4 (useFastDeterministicInterleaver) is not a QPP at all.
%
% If any of these appear in a run, strategy_info.strategy will say so - check
% that field before quoting turbo numbers in the paper. A run where every frame
% reports strategy = 'QPP' is the expected, and only publishable, outcome.
% -------------------------------------------------------------------------

if nargin < 3
    pad_symbol = 0;
end
if nargin < 4
    maxExtensionPercentage = 0.1;
end

vectorInterleaved = [];
permutation = [];
strategy_info = struct();
erM = "";

try
    %---------------------- Control & Input Preparation --------------------
    [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
    if failed
        erM = sprintf("interleaver_turbo: Data shape error: (%s) Must be (1xN)", mat2str(size(vectorIn)));
        return
    end

    strategy_info.original_length = length(vectorIn);
    strategy_info.block_size = block_size;
    strategy_info.pad_symbol = pad_symbol;

    original_length = length(vectorIn);
    if original_length < block_size
        padded_length = block_size;
    else
        padded_length = block_size * ceil(original_length / block_size);
    end

    if padded_length > (original_length * (1+maxExtensionPercentage))
        erM = sprintf("interleaver_turbo: Size-adjusted-N error: (%d)", padded_length);
        return
    end

    % Apply padding
    if padded_length > original_length
        padded_data = [vectorIn, repmat(pad_symbol, 1, padded_length - original_length)];
    else
        padded_data = vectorIn;
    end
    N = length(padded_data);
    strategy_info.padded_length = N;

    %---------------------- METHOD 1: Direct QPP ---------------------------
    % The only path that yields a genuine length-N LTE QPP interleaver. Since
    % the turbo_selectQPPParameters fix this succeeds for every N in the sweep.
    [f1,f2,qpp_error] = cachedQPPParameters(N);
    if isempty(qpp_error)
        strategy_info.strategy = 'QPP';
        strategy_info.f1 = f1;
        strategy_info.f2 = f2;
        strategy_info.N = N;

        permutation = mod((0:N-1) .* (f1 + f2*(0:N-1)), N) + 1;
        vectorInterleaved = padded_data(permutation);
        [vectorInterleaved,permutation] = shapeThem(vectorInterleaved, permutation);
        return
    end

    %---------------------- METHOD 2: Nearest QPP --------------------------
    % UNREACHABLE with the corrected selector. Changes the transmitted length
    % and bypasses the extension guard - see the header. Do not report as QPP.
    [vectorInterleaved, permutation, strategy_info, success, erM] = tryFastNearestQPP(padded_data, N, pad_symbol, strategy_info);
    if success
        [vectorInterleaved,permutation] = shapeThem(vectorInterleaved, permutation);
        return
    end

    %---------------------- METHOD 3: Block QPP ----------------------------
    % UNREACHABLE with the corrected selector. Block-wise, so its separation
    % does not scale with N - see the header. Do not report as QPP.
    [vectorInterleaved, permutation, strategy_info, success] = tryFastBlockQPP(padded_data, N, pad_symbol, strategy_info);
    if success
        [vectorInterleaved,permutation] = shapeThem(vectorInterleaved, permutation);
        return
    end

    %---------------------- METHOD 4: Deterministic ------------------------
    % UNREACHABLE with the corrected selector. Not a QPP at all - see header.
    [vectorInterleaved, permutation, strategy_info, erM] = useFastDeterministicInterleaver(padded_data, N, strategy_info);
    if erM == ""
      [vectorInterleaved,permutation] = shapeThem(vectorInterleaved, permutation);
    end
catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end


%% ------------------------------------------------------------------------
function [f1,f2,qpp_error] = cachedQPPParameters(N)
% persistent caching of QPP parameter lookups
persistent qppCache;
if isempty(qppCache)
    qppCache = containers.Map('KeyType','double','ValueType','any');
end
try
    if isKey(qppCache, N)
        vals = qppCache(N);
        f1 = vals{1}; f2 = vals{2}; qpp_error = "";
    else
        [f1,f2,qpp_error] = turbo_selectQPPParameters(N);
        if isempty(qpp_error)
            qppCache(N) = {f1,f2};
        end
    end
catch err
    f1 = []; f2 = []; qpp_error = sprintf("cachedQPPParameters error: %s", err.message);
end
end


%% ------------------------------------------------------------------------
function [vectorInterleaved, permutation, strategy_info, success, erM] = tryFastNearestQPP(padded_data, N, pad_symbol, strategy_info)
success = false;
vectorInterleaved = []; permutation = [];  erM = "";
try
    % NOTE: hard ceiling of 800. Frames longer than that get no candidate here
    % and fall through to METHOD 3 - which is why this tier was useless for the
    % sweep's larger lengths even when it was reachable.
    common_qpp_sizes = 8:8:800; % pre-defined fast search space
    valid_sizes = common_qpp_sizes(common_qpp_sizes >= N);
    if isempty(valid_sizes), return; end

    size_diffs = abs(valid_sizes - N);
    [~, sorted_indices] = sort(size_diffs);
    for i = 1:min(5,length(sorted_indices))
        test_size = valid_sizes(sorted_indices(i));
        [f1,f2,qpp_error] = cachedQPPParameters(test_size);
        if isempty(qpp_error)
            indices = 0:test_size-1;
            qpp_perm = mod(indices .* (f1 + f2*indices), test_size) + 1;
            extended_data = [padded_data, repmat(pad_symbol, 1, test_size - N)];
            vectorInterleaved = extended_data(qpp_perm);
            permutation = qpp_perm;

            strategy_info.strategy = 'nearest_QPP';
            strategy_info.f1 = f1;
            strategy_info.f2 = f2;
            strategy_info.original_N = N;
            strategy_info.N = test_size;
            strategy_info.extended_N = test_size;
            strategy_info.size_change = test_size - N;
            success = true;
            return
        end
    end
catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
    success = false;
end
end


%% ------------------------------------------------------------------------
function [vectorInterleaved, permutation, strategy_info, success, erM] = tryFastBlockQPP(padded_data, N, pad_symbol, strategy_info)
success = false; vectorInterleaved = []; permutation = []; erM = "";
try
    candidate_block_sizes = [8,16,24,32,40,48,56,64];
    for block_size = candidate_block_sizes
        if block_size >= N, continue; end
        [f1,f2,qpp_error] = cachedQPPParameters(block_size);
        if ~isempty(qpp_error), continue; end

        indices = 0:block_size-1;
        local_perm = mod(indices .* (f1 + f2 * indices), block_size) + 1;

        num_blocks = ceil(N / block_size);
        extended_length = num_blocks * block_size;
        extended_data = [padded_data, repmat(pad_symbol, 1, extended_length - N)];

        vectorInterleaved = zeros(1, extended_length);
        permutation = zeros(1, extended_length);
        for blk = 1:num_blocks
            s = (blk-1)*block_size + 1; e = blk*block_size;
            block_data = extended_data(s:e);
            vectorInterleaved(s:e) = block_data(local_perm);
            permutation(s:e) = local_perm + (blk-1)*block_size;
        end
        vectorInterleaved = vectorInterleaved(1:N);
        permutation = permutation(1:N);

        strategy_info.strategy = 'block_QPP';
        strategy_info.f1 = f1;
        strategy_info.f2 = f2;
        strategy_info.N = N;
        strategy_info.block_size = block_size;
        strategy_info.num_blocks = num_blocks;
        strategy_info.extended_length = extended_length;

        success = true;
        return
    end
catch ME
    success = false;
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end


%% ------------------------------------------------------------------------
function [vectorInterleaved, permutation, strategy_info, erM] = useFastDeterministicInterleaver(padded_data, N, strategy_info)
vectorInterleaved = []; permutation = []; erM = "";
try
    if N <= 1
        vectorInterleaved = padded_data;
        permutation = 1;
        strategy_info.strategy = 'identity';
        strategy_info.N = N;
        return;
    end

    if isPowerOfTwo(N)
        permutation = cachedBitReversal(N);
        strategy_info.strategy = 'bit_reversal';
        strategy_info.N = N;
        strategy_info.num_bits = log2(N);
    else
        stride = fastFindGoodStride(N);
        permutation = mod((0:N-1)*stride, N) + 1;
        strategy_info.strategy = 'stride_based';
        strategy_info.N = N;
        strategy_info.stride = stride;
    end
    vectorInterleaved = padded_data(permutation);
catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
    vectorInterleaved = padded_data;
    permutation = 1:N;
end
end


%% ------------------------------------------------------------------------
function perm = cachedBitReversal(N)
% Persistent LUT for bit-reversal permutations
persistent bitrevLUT;
if isempty(bitrevLUT), bitrevLUT = containers.Map('KeyType','double','ValueType','any'); end
try
    if isKey(bitrevLUT, N)
        perm = bitrevLUT(N);
    else
        perm = bitrevorder(1:N);
        bitrevLUT(N) = perm;
    end
catch
    perm = 1:N;
end
end


%% ------------------------------------------------------------------------
function stride = fastFindGoodStride(N)
try
    good_strides = [3,5,7,11,13,17,19,23,29,31];
    for s = good_strides
        if s < N && gcd(s,N)==1
            stride = s;
            return
        end
    end
    for s = 2:min(N-1,50)
        if gcd(s,N)==1
            stride = s;
            return
        end
    end
    stride = 1;
catch
    stride = 1;
end
end


%% ------------------------------------------------------------------------
function is_power = isPowerOfTwo(n)
   is_power = n > 0 && bitand(n,n-1)==0;
end


%% ------------------------------------------------------------------------
function [v,p] = shapeThem(v,p)
   if iscolumn(v), v = v'; end
   if iscolumn(p), p = p'; end
end
