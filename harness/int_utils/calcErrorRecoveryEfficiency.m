function [etaER, erM, diagnostics] = calcErrorRecoveryEfficiency(DER, rho_noise, varargin)
% calcErrorRecoveryEfficiency - Compute Error Recovery Efficiency
%
% Error Recovery Efficiency (η_ER) measures how effectively the interleaver
% + ECC system recovers from errors compared to the baseline noise level.
%
% Formula: η_ER = 1 - (DER / ρ_noise)
%
% Where:
%   DER       - Decoder Error Rate (fraction of symbols with errors AFTER decoding)
%   ρ_noise   - Noise ratio (fraction of symbols with errors BEFORE decoding)
%
% Interpretation:
%   η_ER = 1.0  → Perfect recovery (all errors corrected, DER = 0)
%   η_ER = 0.5  → 50% of errors corrected
%   η_ER = 0.0  → No error correction (DER = ρ_noise)
%   η_ER < 0.0  → Decoder failures exceed correctable errors (error propagation)
%
% Usage:
%   [etaER, erM] = calcErrorRecoveryEfficiency(DER, rho_noise)
%   [etaER, erM, diag] = calcErrorRecoveryEfficiency(DER, rho_noise, 'verbose', true)
%
% Inputs:
%   DER        - Decoder error rate (scalar or vector)
%   rho_noise  - Noise ratio, proportion of corrupted symbols (scalar or vector)
%
% Options (Name-Value):
%   'verbose'     - Print detailed diagnostics (default: false)
%   'method'      - Calculation method: 'standard', 'normalized', 'capped' (default: 'standard')
%   'baseline'    - Baseline for normalization (default: rho_noise)
%
% Outputs:
%   etaER        - Error Recovery Efficiency (same size as DER)
%   erM          - Error message string (empty if success)
%   diagnostics  - Structure with detailed metrics
%
% Methods:
%   'standard'   - η_ER = 1 - (DER / ρ_noise)
%   'normalized' - η_ER = (ρ_noise - DER) / ρ_noise (same as standard, different form)
%   'capped'     - η_ER = max(0, 1 - (DER / ρ_noise)) (forces non-negative)
%
% Examples:
%   % Perfect recovery
%   etaER = calcErrorRecoveryEfficiency(0.00, 0.15)  % → 1.0
%
%   % Partial recovery (corrected 80% of errors)
%   etaER = calcErrorRecoveryEfficiency(0.03, 0.15)  % → 0.8
%
%   % No recovery
%   etaER = calcErrorRecoveryEfficiency(0.15, 0.15)  % → 0.0
%
%   % Decoder failure (error propagation)
%   etaER = calcErrorRecoveryEfficiency(0.20, 0.15)  % → -0.333
%
% Literature:
%   Common in turbo code and LDPC performance evaluation
%   Related to "coding gain" but normalized by noise level
%   Similar to (1 - residual_error_rate / channel_error_rate)
%
% See also: calcContributionRatio, calcEffectiveness

erM = "";
etaER = [];
diagnostics = struct();

try
    %% Parse inputs
    p = inputParser;
    addRequired(p, 'DER', @(x)isnumeric(x) && all(x(:) >= 0));
    addRequired(p, 'rho_noise', @(x)isnumeric(x) && all(x(:) >= 0) && all(x(:) <= 1));
    addParameter(p, 'verbose', false, @islogical);
    addParameter(p, 'method', 'standard', @(x)ismember(x, {'standard', 'normalized', 'capped'}));
    addParameter(p, 'baseline', [], @isnumeric);
    parse(p, DER, rho_noise, varargin{:});
    opts = p.Results;
    
    %% Validate inputs
    if any(rho_noise(:) == 0)
        erM = 'Error: rho_noise contains zeros. Cannot divide by zero.';
        etaER = NaN(size(DER));
        return;
    end
    
    % Check dimension compatibility
    if ~(isscalar(DER) || isscalar(rho_noise) || isequal(size(DER), size(rho_noise)))
        erM = 'Error: DER and rho_noise must be scalar or same size';
        etaER = NaN(size(DER));
        return;
    end
    
    %% Use baseline if provided (for comparing to no-interleaver case)
    if ~isempty(opts.baseline)
        baseline = opts.baseline;
    else
        baseline = rho_noise;
    end
    
    %% Compute Error Recovery Efficiency
    switch opts.method
        case 'standard'
            % Standard formula: η_ER = 1 - (DER / ρ_noise)
            etaER = 1 - (DER ./ baseline);
            
        case 'normalized'
            % Equivalent form: η_ER = (ρ_noise - DER) / ρ_noise
            etaER = (baseline - DER) ./ baseline;
            
        case 'capped'
            % Capped version (non-negative only)
            etaER = max(0, 1 - (DER ./ baseline));
    end
    
    %% Compute diagnostics
    diagnostics.DER = DER;
    diagnostics.rho_noise = rho_noise;
    diagnostics.baseline = baseline;
    diagnostics.etaER = etaER;
    diagnostics.method = opts.method;
    
    % Error correction statistics
    diagnostics.errors_corrected_fraction = max(0, (baseline - DER) ./ baseline);
    diagnostics.errors_remaining_fraction = DER ./ baseline;
    diagnostics.errors_corrected_absolute = baseline - DER;
    
    % Classification
    diagnostics.perfect_recovery = (DER == 0);
    diagnostics.partial_recovery = (DER > 0) & (DER < baseline);
    diagnostics.no_recovery = (DER >= baseline) & (DER < 1.5 * baseline);
    diagnostics.decoder_failure = (DER >= 1.5 * baseline);
    
    % Statistical summary (for vector inputs)
    if ~isscalar(etaER)
        diagnostics.etaER_mean = mean(etaER(:), 'omitnan');
        diagnostics.etaER_std = std(etaER(:), 'omitnan');
        diagnostics.etaER_min = min(etaER(:));
        diagnostics.etaER_max = max(etaER(:));
        diagnostics.etaER_median = median(etaER(:), 'omitnan');
        
        diagnostics.perfect_recovery_rate = sum(diagnostics.perfect_recovery(:)) / numel(DER);
        diagnostics.partial_recovery_rate = sum(diagnostics.partial_recovery(:)) / numel(DER);
        diagnostics.decoder_failure_rate = sum(diagnostics.decoder_failure(:)) / numel(DER);
    end
    
    %% Verbose output
    if opts.verbose
        fprintf('\n=== ERROR RECOVERY EFFICIENCY ===\n');
        fprintf('Method: %s\n', opts.method);
        
        if isscalar(etaER)
            fprintf('\nInputs:\n');
            fprintf('  DER (Decoder Error Rate):    %.6f (%.2f%%)\n', DER, DER*100);
            fprintf('  ρ_noise (Noise Ratio):       %.6f (%.2f%%)\n', rho_noise, rho_noise*100);
            fprintf('  Baseline:                    %.6f (%.2f%%)\n', baseline, baseline*100);
            
            fprintf('\nOutput:\n');
            fprintf('  η_ER (Error Recovery Eff.):  %.6f (%.2f%%)\n', etaER, etaER*100);
            
            fprintf('\nInterpretation:\n');
            fprintf('  Errors corrected (fraction): %.6f (%.2f%%)\n', ...
                diagnostics.errors_corrected_fraction, diagnostics.errors_corrected_fraction*100);
            fprintf('  Errors remaining (fraction): %.6f (%.2f%%)\n', ...
                diagnostics.errors_remaining_fraction, diagnostics.errors_remaining_fraction*100);
            
            if diagnostics.perfect_recovery
                fprintf('  Status: ✓ PERFECT RECOVERY (all errors corrected)\n');
            elseif diagnostics.partial_recovery
                fprintf('  Status: ○ PARTIAL RECOVERY (%.1f%% of errors corrected)\n', ...
                    diagnostics.errors_corrected_fraction * 100);
            elseif diagnostics.decoder_failure
                fprintf('  Status: ✗ DECODER FAILURE (error propagation detected)\n');
            else
                fprintf('  Status: ✗ NO RECOVERY (DER ≥ ρ_noise)\n');
            end
        else
            fprintf('\nVector Statistics (N=%d):\n', numel(etaER));
            fprintf('  η_ER mean:    %.6f ± %.6f\n', diagnostics.etaER_mean, diagnostics.etaER_std);
            fprintf('  η_ER median:  %.6f\n', diagnostics.etaER_median);
            fprintf('  η_ER range:   [%.6f, %.6f]\n', diagnostics.etaER_min, diagnostics.etaER_max);
            
            fprintf('\nRecovery Rates:\n');
            fprintf('  Perfect recovery:  %.2f%% (%d/%d)\n', ...
                diagnostics.perfect_recovery_rate*100, sum(diagnostics.perfect_recovery(:)), numel(DER));
            fprintf('  Partial recovery:  %.2f%% (%d/%d)\n', ...
                diagnostics.partial_recovery_rate*100, sum(diagnostics.partial_recovery(:)), numel(DER));
            fprintf('  Decoder failures:  %.2f%% (%d/%d)\n', ...
                diagnostics.decoder_failure_rate*100, sum(diagnostics.decoder_failure(:)), numel(DER));
        end
        fprintf('================================\n');
    end
    
catch ME
    erM = sprintf('Error in calcErrorRecoveryEfficiency: %s (line %d)', ...
        ME.message, ME.stack(1).line);
    etaER = NaN(size(DER));
end

end

%% Helper function: Compute from raw data
function [etaER, erM] = calcErrorRecoveryEfficiency_fromRaw(errorsAfter, errorsBefore, totalSymbols)
% Compute η_ER directly from error counts
%
% Inputs:
%   errorsAfter  - Number of errors after decoding (scalar or vector)
%   errorsBefore - Number of errors before decoding (must match errorsAfter size)
%   totalSymbols - Total number of symbols (scalar or same size as errors)
%
% Outputs:
%   etaER - Error Recovery Efficiency
%   erM   - Error message

erM = "";

try
    % Compute rates
    DER = errorsAfter ./ totalSymbols;
    rho_noise = errorsBefore ./ totalSymbols;
    
    % Call main function
    [etaER, erM] = calcErrorRecoveryEfficiency(DER, rho_noise);
    
catch ME
    erM = sprintf('Error in calcErrorRecoveryEfficiency_fromRaw: %s', ME.message);
    etaER = NaN(size(errorsAfter));
end

end

%% Comparison with related metrics
function compareRecoveryMetrics(DER, rho_noise)
% Compare Error Recovery Efficiency with related metrics
%
% Usage: compareRecoveryMetrics(0.03, 0.15)

fprintf('\n=== COMPARISON OF RECOVERY METRICS ===\n');
fprintf('Given: DER=%.4f, ρ_noise=%.4f\n\n', DER, rho_noise);

% 1. Error Recovery Efficiency (this metric)
etaER = 1 - (DER / rho_noise);
fprintf('1. Error Recovery Efficiency (η_ER):\n');
fprintf('   Formula: 1 - (DER / ρ_noise)\n');
fprintf('   Value:   %.4f (%.1f%%)\n', etaER, etaER*100);
fprintf('   Interp:  %.1f%% of errors were corrected\n\n', etaER*100);

% 2. Contribution Ratio (your current metric)
% Assuming cont = (rho_noise - DER) / rho_noise
cont = (rho_noise - DER) / rho_noise;
fprintf('2. Contribution Ratio (CR):\n');
fprintf('   Formula: (ρ_noise - DER) / ρ_noise\n');
fprintf('   Value:   %.4f (%.1f%%)\n', cont, cont*100);
fprintf('   Note:    IDENTICAL to η_ER (just different form)\n\n');

% 3. Effectiveness (if you have baseline without interleaver)
% Assume baseline DER without interleaver = rho_noise * 0.9 (90% uncorrected)
DER_baseline = rho_noise * 0.9;
effectiveness = (DER_baseline - DER) / DER_baseline;
fprintf('3. Effectiveness (vs baseline without interleaver):\n');
fprintf('   Formula: (DER_baseline - DER) / DER_baseline\n');
fprintf('   Value:   %.4f (%.1f%%)\n', effectiveness, effectiveness*100);
fprintf('   Note:    Requires baseline measurement\n\n');

% 4. Simple Error Reduction Ratio
reduction = (rho_noise - DER) / rho_noise;
fprintf('4. Error Reduction Ratio:\n');
fprintf('   Formula: (ρ_noise - DER) / ρ_noise\n');
fprintf('   Value:   %.4f (%.1f%%)\n', reduction, reduction*100);
fprintf('   Note:    Also IDENTICAL to η_ER\n\n');

% 5. Coding Gain (in dB, if you have SNR info)
fprintf('5. Coding Gain (requires SNR info):\n');
fprintf('   Formula: 10*log10(ρ_noise / DER)\n');
if DER > 0
    gain_dB = 10 * log10(rho_noise / DER);
    fprintf('   Value:   %.2f dB\n', gain_dB);
else
    fprintf('   Value:   Infinite (perfect correction)\n');
end
fprintf('   Note:    Different scale (logarithmic)\n\n');

fprintf('CONCLUSION:\n');
fprintf('η_ER and Contribution Ratio are mathematically IDENTICAL.\n');
fprintf('Both measure the fraction of errors successfully corrected.\n');
fprintf('======================================\n');

end
