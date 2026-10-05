function R = check_noise_fidelity(dataDir, opts)
%CHECK_NOISE_FIDELITY  Did each noise bin get the noise it was labelled with?
%
%   R = check_noise_fidelity('<resultsDir>')
%
% WHY THIS CHECK EXISTS, AND WHY NONE OF THE OTHERS COVERS IT
% ===========================================================================
% The health package checks that the noise applied is BALANCED ACROSS METHODS
% within a run - every method in a trial sees the same mask. It never checks
% that the noise applied matches the noise the trial was LABELLED with. Those
% are different properties, and the second is what every per-noise-level
% statement in the paper rests on.
%
% The question surfaced from C_NN. By Lemma 1 of the manuscript, C_NN of method j in a trial
% factors exactly as
%
%       C_NN_j = BE_j * kappa,     kappa = E / (rho * N)
%
% with E the number of corrupted positions, rho the target density and N the
% encoded length. BE_j is the dilution the correction exists to charge;
% kappa is the ratio of realized to target density, common to every method
% in the trial. For kappa the harness promises round(rho*N)/(rho*N): within
% about 6 % of 1 at the shortest frame and the lowest bin, closer elsewhere.
%
% An earlier version of Figure 3 plotted exactly kappa, per noise bin, for
% the ge0p70 condition, and read by eye it ran 1.22, 1.09, 0.99, 0.91, 0.83
% across the five bins. Multiplied back by the targets that is a realized
% density of about 0.22 in EVERY bin. If that reading is right, the five
% noise levels in that condition are one noise level with five labels, and
% the reason is in the generator, not in C_NN. A reading off a picture is
% not evidence. This measures it, per condition and per bin.
%
% WHAT IT REPORTS
%   per bin     target rho, mean realized density of the methods that do not
%               extend the frame, its spread, and kappa = realized / target
%   per sweep   the slope of realized on target across the bins. 1 means the
%               labels were honoured; 0 means every bin got the same noise.
%
% Only methods with BE = 1 are used: for them realized density IS E/N, with
% no dilution to divide out, so kappa is read directly.
%
% OPTIONS
%   tol      largest |kappa - 1| still called rounding          [0.07]
%
% R.T. Sirmen harness, 2026

   if nargin < 1 || isempty(dataDir)
      c = configure_simulation(); dataDir = char(c.dataSavePath);
   end
   if nargin < 2, opts = struct(); end
   if ~isfield(opts, 'tol'), opts.tol = 0.07; end

   d = dir(fullfile(dataDir, 'KPItableDetailed_*.mat'));
   if isempty(d), error('check_noise_fidelity: no KPItableDetailed_*.mat in %s', dataDir); end

   fprintf('\n=== NOISE FIDELITY: realized density against the labelled target ===\n');
   fprintf('methods with BE = 1 only; kappa = realized / target; tolerance |kappa-1| <= %.2f\n\n', opts.tol);

   R = struct('sweep', {}, 'target', {}, 'realized', {}, 'sd', {}, 'kappa', {}, ...
              'n', {}, 'slope', {}, 'verdict', {});
   for i = 1:numel(d)
      T = local_rows(load(fullfile(dataDir, d(i).name)));
      cfg = local_config(dataDir, d(i).name);
      tag = regexprep(d(i).name, '^KPItableDetailed_|\.mat$', '');
      if isempty(T) || isempty(cfg) || ~isfield(cfg, 'noiseLevels')
         fprintf(2, '%-34s  rows or config.noiseLevels missing - skipped\n', tag);
         continue;
      end
      need = {'encodedLen', 'interleavedLen', 'noiseActual', 'noiseBin'};
      if ~all(isfield(T, need))
         fprintf(2, '%-34s  missing a field among %s - skipped\n', tag, strjoin(need, ', '));
         continue;
      end
      elen = double([T.encodedLen]).';
      ilen = double([T.interleavedLen]).';
      nact = double([T.noiseActual]).';
      nbin = double([T.noiseBin]).';
      keep = (ilen == elen) & isfinite(nact) & nbin >= 1 & nbin <= numel(cfg.noiseLevels);
      nact = nact(keep); nbin = nbin(keep);

      ub = unique(nbin).';
      tg = cfg.noiseLevels(ub); tg = tg(:).';
      rl = nan(size(ub)); sd = rl; nn = rl;
      for k = 1:numel(ub)
         v = nact(nbin == ub(k));
         rl(k) = mean(v); sd(k) = std(v); nn(k) = numel(v);
      end
      kap = rl ./ tg;
      if numel(ub) >= 2
         pp = polyfit(tg, rl, 1); slope = pp(1);
      else
         slope = NaN;
      end

      if all(abs(kap - 1) <= opts.tol)
         verdict = 'labels honoured';
      elseif isfinite(slope) && slope < 0.3
         verdict = 'FLAT: every bin received about the same noise';
      else
         verdict = 'PARTIAL: realized noise tracks the label only in part';
      end

      fprintf('%-34s  slope %5.2f   %s\n', tag, slope, verdict);
      fprintf('      %9s %10s %9s %8s %9s\n', 'target', 'realized', 's.d.', 'kappa', 'rows');
      for k = 1:numel(ub)
         flag = ''; if abs(kap(k) - 1) > opts.tol, flag = '  <--'; end
         fprintf('      %9.4f %10.4f %9.4f %8.3f %9d%s\n', tg(k), rl(k), sd(k), kap(k), nn(k), flag);
      end
      fprintf('\n');

      R(end+1) = struct('sweep', tag, 'target', tg, 'realized', rl, 'sd', sd, ...
                        'kappa', kap, 'n', nn, 'slope', slope, 'verdict', verdict); %#ok<AGROW>
   end

   if isempty(R), return; end
   bad = ~strcmp({R.verdict}, 'labels honoured');
   if ~any(bad)
      fprintf(['Every sweep realized the noise it was labelled with, to within\n' ...
               'rounding of the injected count. kappa is then a rounding term and\n' ...
               'C_NN reduces to BE up to it, as the manuscript states.\n\n']);
   else
      fprintf(2, ['%d of %d sweeps did NOT realize their labelled noise. Every\n' ...
                  'per-noise-level statement drawn from them is a statement about one\n' ...
                  'noise level, and C_NN multiplies their CR by a bin-dependent kappa\n' ...
                  'that is common to all methods in a trial. Within-trial comparisons\n' ...
                  'are untouched; anything read ACROSS noise levels is not.\n\n'], ...
              sum(bad), numel(R));
   end
end

% =========================================================================
function cfg = local_config(dataPath, kpiName)
   cfg = [];
   fp = fullfile(dataPath, regexprep(kpiName, '^KPItableDetailed', 'config'));
   if ~exist(fp, 'file'), return; end
   S = load(fp); fn = fieldnames(S);
   for i = 1:numel(fn)
      v = S.(fn{i});
      if isstruct(v) && isscalar(v) && isfield(v, 'noiseLevels'), cfg = v; return; end
   end
end

function rows = local_rows(S)
   rows = [];
   fn = fieldnames(S);
   hasTable = exist('istable', 'builtin') || exist('istable', 'file');
   for i = 1:numel(fn)
      v = S.(fn{i});
      if hasTable && istable(v), rows = table2struct(v); return; end
      if isstruct(v) && numel(v) > 1, rows = v; return; end
   end
end
