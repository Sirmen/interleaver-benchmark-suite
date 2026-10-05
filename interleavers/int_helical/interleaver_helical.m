function [vectorInterleaved, permutation, L, K, erM] = interleaver_helical(vectorIn, padSymbol, maxExtensionPercentage)
%INTERLEAVER_HELICAL  Helical interleaver (self-contained, no helintrlv).
%   Lays the frame out on an L x K grid and reads it along helices: within one
%   read pass the row advances by 1 and the column advances by `step`, wrapping
%   modulo K. Used in standards such as DRM (Digital Radio Mondiale).
%
%   CONVENTION: vectorInterleaved = vectorIn(permutation)  (gather index).
%
% DOCUMENTATION CORRECTED 2026 - two comments, no behaviour change:
%
% 1. FILL ORDER. The header said "Fills matrix row-wise". It does not:
%       idxMatrix = reshape(1:Ntarget, L, K)
%    is COLUMN-major, so idxMatrix(r,c) = (c-1)*L + r and consecutive input
%    symbols sit in the same COLUMN, one row apart. The helical read is what
%    separates them: input index i = (c-1)*L + r leaves at output position
%       mod(c - r, K)*L + r,
%    so i and i+1 (same column, next row) land L-1 apart in the generic case.
%    The dispersion therefore comes from L, the COLUMN height - not from K, as
%    a reader assuming a row-wise fill would conclude.
%
% 2. STEP. The comment "typically choose coprime with K for maximum spreading"
%    sits above `step = 1`, which is coprime with every K, so the remark is
%    vacuous as written and reads as though a real parameter were being tuned.
%    step is fixed at 1 here, and that is the textbook helical interleaver;
%    it is not exposed as an argument. Left as-is deliberately: the harness
%    already carries stride-search variants (freqDeterm, convolutional), and
%    a second tunable here would make `helical` a different method than the
%    one the comparison table names.

erM = ""; vectorInterleaved = []; permutation = []; L = 0; K = 0;
try
    if nargin < 3 || isempty(maxExtensionPercentage), maxExtensionPercentage = 0.34; end
    if nargin < 2, padSymbol = 0; end

    [failed, vectorIn] = controlCorrectShape_1N(vectorIn);
    if failed
        erM = sprintf('interleaver_helical: Data shape error: (%s) Must be (1xN)', mat2str(size(vectorIn)));
        return;
    end

    N0 = numel(vectorIn);
    if N0 == 0
        erM = 'interleaver_helical: Empty input';
        return;
    end

    % 1. Use choose_balanced_factors for dimension selection
    [L, K, Npad] = choose_balanced_factors(N0, maxExtensionPercentage);
    if isempty(L)
        erM = sprintf('interleaver_helical: Could not find balanced factors for N=%d within extension %.2f', N0, maxExtensionPercentage);
        return;
    end

    Ntarget = L * K;
    
    % 2. Pad input to Ntarget if needed
    if Ntarget > N0
        vectorPadded = [vectorIn, repmat(padSymbol, 1, Ntarget - N0)];
    else
        vectorPadded = vectorIn;
    end

    % 3. TRUE HELICAL INTERLEAVING PATTERN
    
    % Index matrix, L rows x K columns, filled COLUMN-major (see note 1 above):
    % idxMatrix(r,c) = (c-1)*L + r.
    idxMatrix = reshape(1:Ntarget, L, K);
    
    % Helical read pattern: read with column offset
    % This is the standard pattern used in literature
    permutation = zeros(1, Ntarget);
    
    % Column advance per row. Fixed at 1 - the textbook helical read. Any step
    % coprime with K would also give a bijection; see note 2 in the header for
    % why this is not exposed as a parameter.
    step = 1;
    
    pos = 1;
    for start_col = 1:K
        for row = 1:L
            % Helical read: (row, (start_col + step*(row-1)) mod K)
            col = mod(start_col - 1 + step * (row - 1), K) + 1;
            permutation(pos) = idxMatrix(row, col);
            pos = pos + 1;
        end
    end

    % Validate permutation
    if numel(unique(permutation)) ~= Ntarget
        erM = 'interleaver_helical: Invalid permutation generated - duplicate indices';
        return;
    end

    % Apply permutation
    vectorInterleaved = vectorPadded(permutation);

    % Ensure row vectors
    vectorInterleaved = vectorInterleaved(:).';
    permutation = permutation(:).';

catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end
