function plotKPIBoxplots(KPItableDetailed, config, methods)
%PLOTKPIBOXPLOTS  Distribution of KPI metrics across methods.
%
% TWO FIXES, 2026
% ---------------------------------------------------------------------------
% 1. THE WARNING: "boxplot might not be displayed properly in the tiled chart
%    layout". boxplot builds its own axes decorations and does not cooperate
%    with tiledlayout/nexttile - MATLAB says so and then draws it anyway, often
%    with the labels in the wrong place. Switched to subplot, which boxplot has
%    always supported. sgtitle works with both.
%
% 2. THE LATENT BUG: [data_CR{:}] horizontally concatenates the per-method
%    column vectors into one matrix. That is only valid when EVERY method has
%    exactly the same number of observations. The moment one method has a
%    different trial count - a retry, a length it could not handle, a regime
%    where it failed - this either throws "Dimensions of arrays being
%    concatenated are not consistent" or, if the counts happen to match by
%    accident, silently plots one method's data under another's label.
%    Replaced with boxplot's grouped form, boxplot(values, groupIndex), which
%    takes ragged groups by construction and cannot mislabel.
%
% A method with no rows at all is dropped from the plot and named, rather than
% producing an empty box that reads as "all zeros".
%
% R.T. Sirmen harness, 2026

   if nargin < 3 || isempty(methods)
      methods = unique(KPItableDetailed.method, 'stable');
   end
   methods = local_toCellstr(methods);

   % Widen the figure with the method count. Three panels side by side means
   % each gets under a quarter of the width; at 24 methods the rotated labels
   % collapse into a smear at the default figure size. Height is left alone.
   nM     = numel(methods);
   figW   = min(1900, 620 + 52 * nM);
   fig    = figure('Name', 'KPI Distributions', 'Color', 'w');
   set(fig, 'Position', [60, 80, figW, 560]);
   tickFS = 10; if nM > 12, tickFS = 8; end

   % EXPLICIT PANEL GEOMETRY - do not go back to plain subplot(1,3,s).
   % subplot fills its slot to within a hair of the figure edge, so the
   % super-title lands on top of the three per-axes titles. tiledlayout would
   % reserve the space, but boxplot does not cooperate with tiledlayout (that
   % is the warning this file was fixed for in the first place). So the margins
   % are set here: 18%% at the top for the super-title, 20%% at the bottom for
   % the rotated method labels.
   % Bottom margin grows with the label load. The full sweep runs 24 methods
   % with names up to 13 characters ('convolutional'); at 35 degrees those
   % overrun a fixed 20%% strip and get clipped by the figure edge.
   labelLoad   = max(cellfun(@numel, methods)) * min(numel(methods), 24) / 24;
   panelBottom = min(0.34, 0.20 + 0.012 * max(0, labelLoad - 8));
   panelHeight = 0.80 - panelBottom;
   panelLeft   = [0.08, 0.41, 0.74];
   panelWidth  = 0.23;   % 0.10 gap: room for each panel's y-label

   specs = { ...
      'CR',            'CR',            'CR Distribution',            false; ...
      'effectiveness', 'E',             'Effectiveness Distribution', false; ...
      'RES',           'RES (Z-score)', 'RES Distribution',           true };

   dropped = {};
   for s = 1:size(specs, 1)
      col = specs{s,1};

      [vals, grp, used, missing] = local_gather(KPItableDetailed, methods, col);
      dropped = union(dropped, missing);

      subplot('Position', [panelLeft(s), panelBottom, panelWidth, panelHeight]);
      if isempty(vals)
         axis off;
         text(0.5, 0.5, sprintf('%s: no data', col), 'HorizontalAlignment', 'center');
         continue;
      end

      boxplot(vals, grp, 'Labels', used);
      ylabel(specs{s,2});
      title(specs{s,3}, 'FontSize', 11, 'FontWeight', 'bold');
      if specs{s,4}
         yline(0, 'm--', 'Mean', 'LineWidth', 1.5);
      end
      grid on;
      set(gca, 'TickLabelInterpreter', 'none', 'XTickLabelRotation', 35, 'FontSize', tickFS);
   end

   % Placed by hand at y = 0.96, above the panels' 0.80 ceiling. sgtitle's own
   % default placement is what collided with the panel titles.
   annotation(fig, 'textbox', [0 0.93 1 0.06], ...
              'String', 'KPI Metric Distributions Across Methods', ...
              'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
              'EdgeColor', 'none', 'FontSize', 12, 'FontWeight', 'bold', ...
              'Interpreter', 'none');

   if ~isempty(dropped)
      fprintf(2, 'plotKPIBoxplots: no rows for %s - dropped from the plot.\n', ...
              strjoin(dropped, ', '));
   end

   if isfield(config, 'saveResults') && config.saveResults
      sMsg = savePlot(fig, config.dataSavePath);
      fprintf('%s \n', sMsg);
   end
end

%% ------------------------------------------------------------------------
function [vals, grp, used, missing] = local_gather(T, methods, col)
%LOCAL_GATHER  Stack one column into (values, group) form, ragged-safe.
   vals = []; grp = []; used = {}; missing = {};
   if ~ismember(col, T.Properties.VariableNames)
      missing = methods; return;
   end
   tmeth = local_toCellstr(T.method);
   for m = 1:numel(methods)
      idx = strcmp(tmeth, methods{m});
      v = T.(col)(idx);
      v = v(~isnan(v));
      if isempty(v)
         missing{end+1} = methods{m}; %#ok<AGROW>
         continue;
      end
      used{end+1} = methods{m};       %#ok<AGROW>
      vals = [vals; v(:)];                                  %#ok<AGROW>
      grp  = [grp;  repmat(numel(used), numel(v), 1)];      %#ok<AGROW>
   end
end

function c = local_toCellstr(x)
%LOCAL_TOCELLSTR  cell / string array / char / categorical -> cellstr.
   if isstruct(x)
      % Checked FIRST and named explicitly: a struct arriving here is the
      % signature of a dropped or reordered argument at the call site, not an
      % exotic method-list type. Saying so beats falling through to a generic
      % "cannot interpret" further down.
      error(['%s: got a struct where the method list should be. ' ...
             'Check the argument order at the call site.'], mfilename);
   elseif iscellstr(x)
      c = x(:)';
   elseif isstring(x)
      c = cellstr(x(:)');
   elseif ischar(x)
      if size(x, 1) > 1
         c = cellstr(x)';        % char matrix, one method per row
      else
         c = {x};
      end
   elseif exist('iscategorical', 'builtin') || exist('iscategorical', 'file')
      if iscategorical(x)
         c = cellstr(x(:)');
         return;
      end
      c = local_lastResort(x);
   elseif iscell(x)
      c = cellfun(@char, x(:)', 'UniformOutput', false);
   else
      error('plotKPIBoxplots: cannot interpret a %s as a method list', class(x));
   end
end

function sMsg = savePlot(fig, savePath)
   savePath = char(savePath);
   if ~exist(savePath, 'dir'), mkdir(savePath); end
   fullPath = fullfile(savePath, 'KPI_Boxplots.png');
   saveas(fig, fullPath);
   sMsg = fullPath;
end

function c = local_lastResort(x)
   if iscell(x)
      c = cellfun(@char, x(:)', 'UniformOutput', false);
   else
      error('%s: cannot interpret a %s as a method list', mfilename, class(x));
   end
end
