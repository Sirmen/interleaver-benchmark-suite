% CROSSCORR_SELFTEST  Prove that the mediation verdict responds to structure.
%
%   crosscorr_selftest
%
% Three fixtures with known structure, one per verdict the function can
% return, and a fourth condition already covered in the code: a rank-collinear
% leg, for which the partial is undefined and must be reported as such rather
% than printed as a number outside [-1, 1].
%
%   A  y depends on x only through m          -> consistent with mediation
%   B  m is unrelated to x and to y           -> a leg is too weak
%   C  y depends on x through m AND directly  -> survives conditioning
%
% Each case gets its own fixture. An earlier version put all three structures
% into one CR column, where every addition diluted the others and no case
% tested what it was named for.
%
% Noise is applied at the (method, length) CELL level, because the statistic
% is computed on cell means and replicate-level noise averages away.

% Three independent fixtures, one per branch. Sharing one CR across three
% structures makes each addition dilute the others, which tests nothing.
function crosscorr_selftest()
  base = fullfile(tempdir,'ccx'); randn('seed',3); rand('seed',3);
  run_case('A  pure path      x->m->y', @(s,e)deal(s+e(1), (s+e(1))+e(2)), 'consistent with mediation');
  run_case('B  no path        m unrelated', @(s,e)deal(e(1), 2*s+e(2)), 'a leg is too weak');
  run_case('C  path + strong direct leg', @(s,e)deal(s+0.6*e(1), 3*s+(s+0.6*e(1))+0.3*e(2)), 'survives conditioning');
end
function run_case(label, f, expect)
  d = fullfile(tempdir,'ccx'); if exist(d,'dir'), rmdir(d,'s'); end; mkdir(d);
  meths = {'S','block','drp','goldenRP','snake','time','prime','turbo','random','chaotic'};
  lens = 420:60:1200; nM=numel(meths); nL=numel(lens); reps=4; rows=nM*nL*reps;
  mid=zeros(rows,1); el=zeros(rows,1); X=zeros(rows,1); M=zeros(rows,1); Y=zeros(rows,1); q=0;
  for li=1:nL, for mi=1:nM
      s = randn; [m,y] = f(s, randn(1,2));
      for r=1:reps
        q=q+1; mid(q)=mi; el(q)=lens(li);
        X(q)=s+0.05*randn; M(q)=m+0.05*randn; Y(q)=y+0.05*randn;
      end
  end, end
  correlation_data = struct('methodID',mid,'encodedLen',el,'methodNames',{meths}, ...
                            'S_sf',X,'V_ECC',M,'CR',Y,'RES',Y);
  save(fullfile(d,'correlation_data_single_common_260905_1.mat'),'correlation_data');
  out = evalc('metric_crosscorr(d, struct(''pairs'', {{''S_sf'',''V_ECC'',''CR''}}));');
  ln = regexp(out, 'S_sf\s+V_ECC\s+CR[^\n]*', 'match', 'once');
  got = ~isempty(strfind(ln, expect));
  if got, mark='OK'; else, mark='<<< PROBLEM'; end
  fprintf('%-34s %s\n   %s\n', label, mark, strtrim(ln));
end
