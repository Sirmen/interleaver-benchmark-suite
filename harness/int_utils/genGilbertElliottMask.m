function [burstMask, geInfo, erM] = genGilbertElliottMask(lenEncoded, burstConfig)
%GENGILBERTELLIOTTMASK  Two-state Markov (Gilbert-Elliott) burst error mask.
%
%   [burstMask, geInfo, erM] = genGilbertElliottMask(lenEncoded, burstConfig)
%
% WHY THIS EXISTS
% ---------------
% The single- and multi-burst generators place a FIXED number of bursts of a
% FIXED total size, both chosen by the experimenter. The manuscript then
% *assumes* the channel is "ergodic, memoryless between bursts
% (non-Markovian)" (Sec. 2.2.3). Gilbert-Elliott replaces that assumption
% with a test: burst count, burst lengths and gaps all fall out of a Markov
% chain instead of being dictated, so the interleavers face error patterns
% nobody designed for them.
%
% MODEL
%   Good state: no errors.        P(Good -> Bad) = p
%   Bad  state: error w.p. e_B.   P(Bad -> Good) = r
%
%   stationary P(Bad)   = p / (p + r)
%   mean sojourn in Bad = 1 / r          (== mean burst length in symbols)
%   mean error rate     = e_B * p / (p + r)
%
% So a target rate RHO and a target mean burst length BBAR pin the chain:
%
%   r = 1 / BBAR ,      p = (RHO / e_B) * r / (1 - RHO / e_B)
%
% e_B = 1 reproduces the harness's existing all-symbols-corrupted bursts;
% e_B < 1 gives fragmented bursts (multipath / fading flavour) where the bad
% state punches holes rather than a solid block. Both are worth reporting.
%
% NOISE BALANCING
% The harness compares methods within a run using ONE shared mask, so a
% random realised count does not break fairness. It does break the run-to-run
% noise balance the survivorship-bias correction relies on, so the mask is
% redrawn until its error count lands inside
% [burstConfig.minNoisyCount, burstConfig.maxNoisyCount]; if the draws keep
% missing, the closest one is trimmed or extended minimally and geInfo.forced
% is set so you can report how often that happened.
%
% INPUT  burstConfig fields used
%   targetNoisyCount            target number of corrupted symbols
%   minNoisyCount/maxNoisyCount acceptance band (defaults to +/-20% of target)
%   ge_meanBurstLen             BBAR. Default: targetNoisyCount / burstCount
%   ge_errProbBad               e_B. Default 1.0
%   ge_maxDraws                 redraw budget. Default 50
%
% OUTPUT geInfo
%   p, r, e_B, meanBurstLen_target  the chain that was used
%   burstCount, burstSizes, burstStarts, burstEnds
%   totalErrors, realisedRate, meanBurstLen_realised, maxBurstLen
%   draws, forced
%   nudge, nudgeRuns                what the repair moved, both 0 when forced is false
%   burstSizesPre                   run lengths before the repair, [] when forced is false
%
% R.T. Sirmen harness integration, 2026

erM = ""; burstMask = zeros(1, lenEncoded); geInfo = struct();
try
   if lenEncoded < 4
      erM = "genGilbertElliottMask: lenEncoded must be >= 4"; return;
   end

   target = burstConfig.targetNoisyCount;
   if isempty(target) || target < 1
      erM = "genGilbertElliottMask: targetNoisyCount must be >= 1"; return;
   end
   target = min(target, lenEncoded - 1);

   if isfield(burstConfig, 'minNoisyCount') && ~isempty(burstConfig.minNoisyCount)
      loCount = burstConfig.minNoisyCount;
   else
      loCount = max(1, floor(0.8 * target));
   end
   if isfield(burstConfig, 'maxNoisyCount') && ~isempty(burstConfig.maxNoisyCount)
      hiCount = burstConfig.maxNoisyCount;
   else
      hiCount = min(lenEncoded, ceil(1.2 * target));
   end

   if isfield(burstConfig, 'ge_errProbBad') && ~isempty(burstConfig.ge_errProbBad)
      eB = burstConfig.ge_errProbBad;
   else
      eB = 1.0;
   end
   eB = min(max(eB, 0.05), 1.0);

   if isfield(burstConfig, 'ge_meanBurstLen') && ~isempty(burstConfig.ge_meanBurstLen)
      Bbar = burstConfig.ge_meanBurstLen;
   else
      nB = 3;
      if isfield(burstConfig, 'burstCount') && ~isempty(burstConfig.burstCount)
         nB = max(1, burstConfig.burstCount);
      end
      Bbar = target / (nB * eB);          % e_B < 1 needs longer bad runs
   end
   Bbar = min(max(Bbar, 2), lenEncoded / 2);

   if isfield(burstConfig, 'ge_maxDraws') && ~isempty(burstConfig.ge_maxDraws)
      maxDraws = burstConfig.ge_maxDraws;
   else
      maxDraws = 50;
   end

   % ---- chain parameters from (rho, Bbar, e_B) ----
   rho = target / lenEncoded;
   r   = 1 / Bbar;
   q   = rho / eB;                          % required stationary P(Bad)
   q   = min(max(q, 1e-6), 0.95);
   p   = q * r / (1 - q);
   p   = min(max(p, 1e-6), 1);

   % ---- draw until the realised count lands in the acceptance band ----
   best = []; bestGap = inf; draws = 0; forced = false;
   for draws = 1:maxDraws
      m = local_runChain(lenEncoded, p, r, eB);
      c = sum(m);
      if c >= loCount && c <= hiCount
         best = m; bestGap = 0; break;
      end
      gap = min(abs(c - loCount), abs(c - hiCount));
      if gap < bestGap, bestGap = gap; best = m; end
   end

   burstMask = best;
   nudge = 0; nudgeRuns = 0; sizesPre = [];
   if bestGap > 0
      % Record what the repair actually moved, so the manuscript can report it
      % instead of asserting that the structure survives. nudge is the signed
      % number of symbols added (+) or removed (-); nudgeRuns is the change in
      % the number of runs, which is zero unless an addition closed a one-symbol
      % gap and merged two runs.
      cPre = sum(burstMask);
      [sPre, ePre] = local_runs(burstMask);
      sizesPre = ePre - sPre + 1;
      [burstMask, forced] = local_nudge(burstMask, loCount, hiCount, target);
      sPost = local_runs(burstMask);
      nudge     = sum(burstMask) - cPre;
      nudgeRuns = numel(sPost) - numel(sPre);
   end

   % ---- descriptive statistics of what the chain actually produced ----
   [starts, ends] = local_runs(burstMask);
   sizes = ends - starts + 1;

   geInfo.p                     = p;
   geInfo.r                     = r;
   geInfo.e_B                   = eB;
   geInfo.meanBurstLen_target   = Bbar;
   geInfo.burstCount            = numel(starts);
   geInfo.burstSizes            = sizes;
   geInfo.burstStarts           = starts;
   geInfo.burstEnds             = ends;
   geInfo.totalErrors           = sum(burstMask);
   geInfo.realisedRate          = sum(burstMask) / lenEncoded;
   if isempty(sizes)
      geInfo.meanBurstLen_realised = 0;
      geInfo.maxBurstLen           = 0;
   else
      geInfo.meanBurstLen_realised = mean(sizes);
      geInfo.maxBurstLen           = max(sizes);
   end
   geInfo.draws     = draws;
   geInfo.forced    = forced;
   geInfo.nudge     = nudge;        % signed symbols moved by the repair, 0 if none
   geInfo.nudgeRuns = nudgeRuns;    % change in the number of runs, 0 if none
   % Run lengths of this same mask BEFORE the repair, empty when none was made.
   % Comparing burstSizesPre with burstSizes isolates what the repair did, which
   % comparing forced masks against unforced ones cannot: a forced mask is also a
   % mask that missed the band fifty times, so that comparison carries the
   % selection as well as the repair.
   geInfo.burstSizesPre = sizesPre;

catch ME
   erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

%% ------------------------------------------------------------------------
function m = local_runChain(N, p, r, eB)
% One pass of the two-state chain. Started in the stationary distribution so
% short frames are not biased toward Good by an arbitrary initial state.
   m = zeros(1, N);
   piB = p / (p + r);
   bad = rand() < piB;
   for i = 1:N
      if bad
         if rand() < eB, m(i) = 1; end
         if rand() < r,  bad = false; end
      else
         if rand() < p,  bad = true;  end
      end
   end
end

function [mm, forced] = local_nudge(m, lo, hi, target)
% Minimal repair when the redraw budget is exhausted: add or remove errors at
% the EDGES of existing runs, so the burst STRUCTURE is preserved and only the
% count moves into band.
   mm = m(:).'; forced = false; c = sum(mm); N = numel(mm);

   guard = 0;
   while c < lo && guard < 4*N
      guard = guard + 1;
      leftNeighbourOn  = [false, mm(1:end-1) ~= 0];
      rightNeighbourOn = [mm(2:end) ~= 0, false];
      cand = find(mm == 0 & (leftNeighbourOn | rightNeighbourOn));
      if isempty(cand)
         cand = find(mm == 0);               % no runs yet: seed anywhere
      end
      if isempty(cand), break; end
      mm(cand(randi(numel(cand)))) = 1;
      c = c + 1; forced = true;
   end

   guard = 0;
   while c > hi && guard < 4*N
      guard = guard + 1;
      leftOff  = [true, mm(1:end-1) == 0];
      rightOff = [mm(2:end) == 0, true];
      cand = find(mm ~= 0 & (leftOff | rightOff));   % run edges first
      if isempty(cand)
         cand = find(mm ~= 0);
      end
      mm(cand(randi(numel(cand)))) = 0;
      c = c - 1; forced = true;
   end
end

function [starts, ends] = local_runs(m)
   m = m(:).';
   d = diff([0, m ~= 0, 0]);
   starts = find(d ==  1);
   ends   = find(d == -1) - 1;
end
