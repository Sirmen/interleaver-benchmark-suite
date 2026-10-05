function out = methodDisplayName(names, mode)
%METHODDISPLAYNAME  Internal method identifier  <->  name used in the paper.
%
%   methodDisplayName('drp')                 -> 'DRP'
%   methodDisplayName({'S','drp'})           -> {'S-Interleaving','DRP'}
%   methodDisplayName('DRP', 'toInternal')   -> 'drp'
%   methodDisplayName(T.method)              -> display names for a whole column
%
% WHY A MAPPING RATHER THAN A RENAME
% ---------------------------------------------------------------------------
% An identifier is written as TEXT inside every saved artifact of the campaign
% - KPItableDetailed.method, stats_all.method - and as a field key in the
% precomputed permutation tables. Renaming it in the code changes none of
% those, and produces a split: the files on disk say one thing, the code says
% another, and every routine that matches on a method name has to know both or
% silently drop rows. So the internal identifier is permanent and arbitrary,
% and the display name is editorial.
%
% RULE
%   Use this at the LAST step before something is shown to a human - axis
%   labels, table headers, printed reports, exported CSVs for the paper.
%   NEVER use the output to index, filter, compare or look anything up. If a
%   display name reaches a lookup, that is the bug this file exists to prevent.
%
% R.T. Sirmen harness, 2026

   if nargin < 2 || isempty(mode), mode = 'toDisplay'; end

   % internal , display
   MAP = {
      'S',              'S-Interleaving'
      'arp',            'ARP'
      'drp',            'DRP'
      'goldenRP',       'GRP'
      'srandom',        'S-random'
      'multiDim',       'multi-D block'
      'turbo',          'QPP'
      'prime',          'Prime'
      'algebraic',      'Algebraic'
      'latinSquare',    'Latin square'
      'block',          'Block'
      'matrix',         'Matrix'
      'helical',        'Helical'
      'helicalScan',    'Helical scan'
      'diagonal',       'Diagonal'
      'spiral',         'Spiral'
      'snake',          'Snake'
      'hierarchical',   'Hierarchical'
      'convolutional',  'Convolutional'
      'chaotic',        'Chaotic'
      'random',         'Random'
      'time',           'Time (OFDM)'
      'freqDeterm',     'Freq. determ.'
      'freqRandom',     'Freq. random'
      };

   wasChar   = ischar(names);
   wasString = isstring(names);
   if wasChar, names = {names}; end
   if wasString, names = cellstr(names); end
   if ~iscell(names)
      error('methodDisplayName: expected a char, string or cellstr');
   end

   switch lower(mode)
      case 'todisplay', from = 1; to = 2;
      case 'tointernal', from = 2; to = 1;
      otherwise
         error('methodDisplayName: mode must be ''toDisplay'' or ''toInternal''');
   end

   out = cell(size(names));
   for i = 1:numel(names)
      n = char(names{i});
      k = find(strcmp(MAP(:, from), n), 1);
      if isempty(k)
         % Unmapped names pass through unchanged rather than being replaced by
         % a placeholder: an unknown method should be visible in the output,
         % not hidden behind '(unknown)'.
         out{i} = n;
      else
         out{i} = MAP{k, to};
      end
   end

   if wasChar,   out = out{1};        end
   if wasString, out = string(out);   end
end
