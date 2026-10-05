function permutation = freqGridApply(basePerm, Nsc, Nsym)
%FREQGRIDAPPLY  Apply a subcarrier permutation to every OFDM symbol, rotated by
%   RENAMED 2026 from local_apply.m - see freqGridSetup.m for why the `local_`
%   prefix was wrong (these are path-level function files, not local functions).
%
%   the symbol index so successive symbols are decorrelated.
%
%   Shared by interleaver_freqDeterm and interleaver_freqRandom: the two
%   methods differ ONLY in how basePerm is produced (coprime stride vs random
%   draw), so the mapping itself lives in one place.
%
%   The time (symbol) index is never touched - that is interleaver_time's axis.
%
% R.T. Sirmen harness, 2026

   permutation = zeros(1, Nsc * Nsym);
   for tt = 0:Nsym-1
      rot = mod(basePerm + tt - 1, Nsc) + 1;
      permutation(tt*Nsc + (1:Nsc)) = tt*Nsc + rot;
   end
end
