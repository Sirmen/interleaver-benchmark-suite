function R = further_campaigns(campaignRoot, opts)
%FURTHER_CAMPAIGNS  Table 6 of the paper: the verdicts at five further configurations.
%
%   R = further_campaigns(campaignRoot)
%   R = further_campaigns(campaignRoot, struct('tableDir', tableDir, 'rerun', true))
%
% campaignRoot holds one folder per campaign, named either <code> or
% results_<code>, for code = c15lo, c15t2, c15t4, code31, code24. Each holds the
% KPItableDetailed_*, correlation_data_* and config_* files of that campaign
% (eight conditions at n = 15, four at n = 31 and n = 24).
%
% For each campaign metric_scorecard is run at its (n, t), exactly as for the
% primary configuration; it writes scorecard_metrics.csv into the campaign
% folder. The table below is then read from that file: |rho| / IQR for every
% row of Table 6, a dagger where C2 fails (fewer than 6 of 8, or 3 of 4,
% conditions clear 0.30), the "other eight discarded" row as the largest |rho|
% and the largest pass count among them, and the ratio of giniLoad (B = 12n) to
% delta_G with its block-bootstrap interval (Section 8.9).
%
% OPTIONS
%   tableDir  permutation table folder; default: find_table_dir. The tables of
%             n = 31 and n = 24 are keyed by lengths no other campaign uses
%             (124m, 24c), so one table serves every campaign.
%   rerun     true (default): run metric_scorecard; false: read an existing
%             scorecard_metrics.csv and only print.
%   codes     subset of the five campaign names, default all five.
%
% Nothing is simulated. metric_scorecard takes several minutes per campaign.
%
% R.T. Sirmen, 2026-11

   if nargin < 2, opts = struct(); end
   campaignRoot = char(campaignRoot);
   tableDir = local_opt(opts, 'tableDir', '');
   rerun    = local_opt(opts, 'rerun', true);

   %        code      n   t  conditions  column heading
   SPEC = {'c15lo',  15, 3, 8, 'RS(15,9) [0.50,0.90]tau'; ...
           'c15t2',  15, 2, 8, 'RS(15,11) t=2'; ...
           'c15t4',  15, 4, 8, 'RS(15,7) t=4'; ...
           'code31', 31, 5, 4, 'RS(31,21) t=5'; ...
           'code24', 24, 4, 4, 'RS(24,16) t=4'};
   codes = local_opt(opts, 'codes', SPEC(:, 1).');
   SPEC = SPEC(ismember(SPEC(:, 1), codes), :);

   % Table 6 rows: metric, burst length as a multiple of n (0 = none), label
   ROWS = {'delta_G', 0, 'DeltaG'; 'eta_ES', 0, 'etaES'; 'giniLoad', 12, 'giniLoad (12n)'; ...
           'esLoad', 12, 'esLoad (12n)'; 'meanMaxCW', 24, 'meanMaxCW (24n)'; 'S_ECC', 0, 'SECC'; ...
           'delta_BS', 0, 'DeltaBS'; 'maxErrCW', 24, 'maxErrCW (24n)'; 'eta_sep', 0, 'etasep'; ...
           'B_guar', 0, 'Bguar'; 'sepMin', 0, 'sepmin'; 'cvLoad', 24, 'cvLoad (24n)'; ...
           'overT', 12, 'overT (12n)'; 'laplacianEnergy', 0, 'LE'; 'U_ECC', 0, 'UECC'; ...
           'V_ECC', 0, 'VECC'; 'S_sf', 0, 'Ssf'};
   OTHER = {'PSR', 'Snew', 'adjMin', 'adjDispersion', 'adjCV', 'S_factor', 'S_ach', 'dispersion'};

   R = struct('code', {}, 'folder', {}, 'cells', {}, 'other', {}, 'ratio', {});
   for ci = 1:size(SPEC, 1)
      [code, n, t, nCond] = SPEC{ci, 1:4};
      folder = local_find(campaignRoot, code);
      nc = numel(dir(fullfile(folder, 'correlation_data_*.mat')));
      if nc ~= nCond
         error('further_campaigns: %d correlation_data files in %s, expected %d.', nc, folder, nCond);
      end
      csvFile = fullfile(folder, 'scorecard_metrics.csv');
      if rerun || exist(csvFile, 'file') ~= 2
         fprintf('\n##### %s: metric_scorecard at (n, t) = (%d, %d)\n', code, n, t);
         metric_scorecard(folder, struct('tableDir', tableDir, 'FECn', n, 'FECt', t));
      end
      M = local_readcsv(csvFile);
      cells = cell(size(ROWS, 1), 1);
      for ri = 1:size(ROWS, 1)
         key = local_key(ROWS{ri, 1}, ROWS{ri, 2}, n);
         v = local_get(M, key, csvFile);
         cells{ri} = sprintf('%.3f%s / %.3f', v.cell, local_dag(v, nCond), v.IQR_len);
      end
      mx = -inf; mp = -inf;
      for oi = 1:numel(OTHER)
         v = local_get(M, OTHER{oi}, csvFile);
         mx = max(mx, v.cell); mp = max(mp, v.pass);
      end
      g = local_get(M, local_key('giniLoad', 12, n), csvFile);
      R(end + 1) = struct('code', code, 'folder', folder, 'cells', {cells}, ...
                          'other', sprintf('<= %.3f / <= %d/%d', mx, mp, nCond), ...
                          'ratio', [g.ratio_to_ref g.ratio_lo g.ratio_hi]); %#ok<AGROW>
   end

   fprintf('\n##### Table 6: |rho| / IQR at the five further configurations (dagger: C2 fails)\n');
   fprintf('%-18s', 'metric');
   for ci = 1:size(SPEC, 1), fprintf('%-24s', SPEC{ci, 5}); end
   fprintf('\n');
   for ri = 1:size(ROWS, 1)
      fprintf('%-18s', ROWS{ri, 3});
      for ci = 1:numel(R), fprintf('%-24s', R(ci).cells{ri}); end
      fprintf('\n');
   end
   fprintf('%-18s', 'other 8 discarded');
   for ci = 1:numel(R), fprintf('%-24s', R(ci).other); end
   fprintf('\n\n##### Section 8.9: giniLoad (B = 12n) / delta_G, 95%% block-bootstrap interval\n');
   for ci = 1:numel(R)
      fprintf('  %-26s %.3f [%.3f, %.3f]\n', SPEC{ci, 5}, R(ci).ratio);
   end
end

% ---------------------------------------------------------------------------
function folder = local_find(root, code)
   cand = {fullfile(root, code), fullfile(root, ['results_' code])};
   for k = 1:numel(cand)
      if exist(cand{k}, 'dir') == 7, folder = cand{k}; return; end
   end
   error('further_campaigns: neither %s nor %s exists.', cand{:});
end

function key = local_key(name, mult, n)
   if mult == 0, key = name; else, key = sprintf('%s_B%d', name, mult * n); end
end

function d = local_dag(v, nCond)
   need = 6; if nCond == 4, need = 3; end
   if v.pass >= need, d = ''; else, d = char(8224); end
end

function M = local_readcsv(f)
% scorecard_metrics.csv: header line, then metric,cell,trial,...,ratio_hi
   txt = splitlines(strtrim(fileread(f)));
   % Empty fields are kept: a design-time row leaves 'trial' empty (it has no
   % per-trial value), and strsplit collapses consecutive delimiters by default.
   hdr = strsplit(txt{1}, ',', 'CollapseDelimiters', false);
   M = containers.Map('KeyType', 'char', 'ValueType', 'any');
   for i = 2:numel(txt)
      p = strsplit(txt{i}, ',', 'CollapseDelimiters', false);
      if numel(p) ~= numel(hdr)
         error('further_campaigns: %s line %d has %d fields, the header %d.', f, i, numel(p), numel(hdr));
      end
      s = struct();
      for j = 2:numel(hdr), s.(hdr{j}) = str2double(p{j}); end
      M(p{1}) = s;
   end
end

function v = local_get(M, key, f)
   if ~isKey(M, key), error('further_campaigns: %s has no row %s.', f, key); end
   v = M(key);
end

function v = local_opt(s, f, dflt)
   if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = dflt; end
end
