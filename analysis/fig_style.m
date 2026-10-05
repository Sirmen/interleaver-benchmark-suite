function out = fig_style(action, varargin)
%FIG_STYLE  One visual system for every figure in the manuscript.
%
%   f = fig_style('new', 'single')          % 3.5 in wide, one column
%   f = fig_style('new', 'double', 2.6)     % 7.16 in wide, height in inches
%   fig_style('axes', gca)                  % fonts, ticks, box, grid
%   fig_style('save', f, 'fig4_bsweep')     % EMF for Word, PDF for submission
%   c = fig_style('colors');  m = fig_style('markers');
%   fig_style('scale', 1.5)                 % every figure's type, one knob
%
% WHY A SHARED HELPER AND NOT PER-SCRIPT FORMATTING
% ===========================================================================
% Seven figures drawn by seven scripts drift: one ends up 9 pt and another
% 11 pt, one has a box and another does not, and a reviewer reads the
% inconsistency as carelessness before reading the content. Everything that
% is a house style rather than a result lives here, so changing the house
% style is one edit and not seven.
%
% WIDTHS
% IEEE Transactions is two columns, 3.5 in each, 7.16 in across both. A figure
% drawn at some other width is scaled on insertion, which rescales the text
% with it and breaks the point sizes below. Draw at final size; never scale.
%
% COLOUR AND GREY
% Journals are read on paper and on screen. Every series therefore carries a
% marker or a line style as well as a colour, so the figure survives being
% printed in grey. The palette is Okabe-Ito, which is distinguishable under
% the common forms of colour vision deficiency.
%
% EXPORT
% EMF is vector inside Word, which is what the .docx manuscript needs; PDF is
% vector for the eventual IEEEtran submission. Both are written, from the same
% figure, so the two versions of the paper cannot show different artwork.
% exportgraphics is used where available (R2020a+) because it crops to the
% axes; print is the fallback.
%
% R.T. Sirmen harness, 2026

   switch lower(action)
      case 'new',     out = local_new(varargin{:});
      case 'axes',    local_axes(varargin{:}); out = [];
      case 'save',    out = local_save(varargin{:});
      case 'colors',  out = local_colors();
      case 'markers', out = local_markers();
      case 'sizes',   out = local_sizes();
      case 'scale',   out = local_scale(varargin{:});
      otherwise, error('fig_style:action', 'unknown action: %s', action);
   end
end

% =========================================================================
function f = local_new(width, heightIn)
   if nargin < 1 || isempty(width), width = 'single'; end
   switch lower(width)
      case 'single', W = 3.50;
      case 'double', W = 7.16;
      otherwise,     W = width;          % a number, in inches
   end
   if nargin < 2 || isempty(heightIn), heightIn = W * 0.62; end
   % Renderer painters. Every figure here is lines, patches and text - no
   % transparency, no lighting, nothing that needs OpenGL - and painters is
   % what the vector exports use in any case. Pinning it keeps the export off
   % the hardware graphics path, which on some machines stalls the export with
   % "Graphics timeout ... graphics handshaking issue".
   f = figure('Units', 'inches', 'Position', [1 1 W heightIn], ...
              'Color', 'w', 'PaperUnits', 'inches', ...
              'PaperSize', [W heightIn], ...
              'PaperPosition', [0 0 W heightIn], ...
              'PaperPositionMode', 'manual', ...
              'Renderer', 'painters', 'RendererMode', 'manual', ...
              'InvertHardcopy', 'off');
end

% -------------------------------------------------------------------------
function local_axes(ax)
   if nargin < 1 || isempty(ax), ax = gca; end
   s = local_sizes();
   set(ax, 'FontName', s.font, 'FontSize', s.tick, 'Box', 'off', ...
           'TickDir', 'out', 'LineWidth', 0.6, 'Layer', 'top', ...
           'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15], ...
           'GridColor', [0.7 0.7 0.7], 'GridAlpha', 0.5);
   set(get(ax, 'XLabel'), 'FontName', s.font, 'FontSize', s.label);
   set(get(ax, 'YLabel'), 'FontName', s.font, 'FontSize', s.label);
   set(get(ax, 'Title'),  'FontName', s.font, 'FontSize', s.title, ...
                          'FontWeight', 'normal');
end

% -------------------------------------------------------------------------
function files = local_save(f, stem, outDir)
% Write the same figure as EMF and PDF. A figure that exists only on screen
% is not a deliverable, and one exported at a different size than it was
% drawn at carries text at the wrong point size.
   if nargin < 3 || isempty(outDir)
      outDir = fullfile(pwd, 'figures');
   end
   if exist(outDir, 'dir') ~= 7, mkdir(outDir); end
   base = fullfile(outDir, stem);

   % Hide the interactive axes toolbar before export. Left visible it earns
   % a warning on every save and, on some releases, is drawn into the file.
   % Old releases have no Toolbar property, hence the try.
   for a_ = findall(f, 'Type', 'axes')'
      try, a_.Toolbar.Visible = 'off'; catch, end %#ok<NOSEM>
   end

   % Finish the draw before exporting. exportgraphics waits for the figure to
   % report itself ready (waitForFigureReady), and a figure built and exported
   % in one go without returning to the event queue can sit there unfinished
   % until the export times out with "Graphics timeout ... graphics
   % handshaking issue". drawnow is what ends that wait.
   drawnow;

   files = {};
   hasEG = local_have('exportgraphics');

   % PDF first: available on every platform, and the submission format.
   try
      if hasEG
         exportgraphics(f, [base '.pdf'], 'ContentType', 'vector', ...
                        'BackgroundColor', 'white');
      else
         print(f, base, '-dpdf', '-painters');
      end
      files{end+1} = [base '.pdf'];
   catch e
      fprintf(2, 'fig_style: PDF export failed (%s)\n', e.message);
   end

   % EVERY FORMAT CROPPED TIGHT. print() writes the whole page, margins
   % included, so the EMF and the PNG carried white bands top and bottom that
   % cost lines of text once placed; the PDF, through exportgraphics, did
   % not. exportgraphics (R2020a+) crops to the drawn content for all three,
   % and writes EMF on Windows. print() is the fallback on older releases.
   if ispc
      try
         if hasEG
            exportgraphics(f, [base '.emf'], 'ContentType', 'vector', ...
                           'BackgroundColor', 'white');
         else
            print(f, base, '-dmeta', '-painters');
         end
         files{end+1} = [base '.emf'];
      catch e
         fprintf(2, 'fig_style: EMF export failed (%s)\n', e.message);
      end
   else
      fprintf(2, 'fig_style: EMF needs Windows; wrote PDF only for %s\n', stem);
   end

   % The raster the manuscript uses: 600 dpi, cropped. Inserted at 100 %%
   % in Word it keeps the 9 pt type; the pixel width divided by 600 is its
   % size in inches, slightly under the drawn 3.5 / 7.16 in after cropping.
   try
      if hasEG
         exportgraphics(f, [base '_600dpi.png'], 'Resolution', 600, ...
                        'BackgroundColor', 'white');
      else
         print(f, [base '_600dpi'], '-dpng', '-r600');
      end
      files{end+1} = [base '_600dpi.png'];
   catch
   end

   for i = 1:numel(files), fprintf('  wrote %s\n', files{i}); end
end

% -------------------------------------------------------------------------
function tf = local_have(fn)
% Is a function callable, whatever form it ships in? exist() answers 2 for an
% .m file, 3 for a MEX file, 5 for a built-in and 6 for a P-file. Testing
% only 2 and 5 reported exportgraphics as absent on R2025b, where it ships as
% exportgraphics.p, and every save went down the print() fallback instead.
   tf = any(exist(fn) == [2 3 5 6]);
end

% -------------------------------------------------------------------------
function c = local_colors()
% Okabe-Ito, minus the near-white yellow, which does not print.
   c = [  0    0    0   ;      % black
        0.00 0.45 0.70 ;       % blue
        0.84 0.37 0.00 ;       % vermillion
        0.00 0.62 0.45 ;       % bluish green
        0.80 0.47 0.65 ;       % reddish purple
        0.34 0.71 0.91 ;       % sky blue
        0.90 0.62 0.00 ];      % orange
end

function m = local_markers()
   m = {'o', 's', '^', 'd', 'v', '>', 'p'};
end

function s = local_sizes()
% The base row is strict IEEE: 8 pt on a 3.5 in column, which is what the
% printed page wants and what looks small on a monitor at 100 %. Everything
% is multiplied by one number so the figures stay a system when it changes.
   k = local_scale();
   s = struct('font', 'Times New Roman', ...
              'tick',   round(8 * k), 'label', round(8 * k), ...
              'title',  round(8 * k), 'legend', round(7 * k), ...
              'note',   round(7 * k), 'lw', 1.1 * sqrt(k), 'ms', 4.5 * sqrt(k));
end

function k = local_scale(v)
% ONE KNOB FOR EVERY FIGURE.
%
%   fig_style('scale')        read it
%   fig_style('scale', 1.0)   strict IEEE, 8 pt at 3.5 in
%   fig_style('scale', 1.5)   12 pt, comfortable on screen
%
% The default is 1.15 - 9 pt - deliberately above the journal minimum. A figure typeset at exactly the
% journal minimum is legal and hard to read, and a reviewer reads the PDF on
% a screen before anyone prints it. Line width and marker size move with the
% square root of the factor, so type and marks stay in proportion rather than
% the marks swamping the type.
%
% This is a persistent, not a setting on disk: it lasts for the MATLAB
% session. Put the call at the top of a figure run to make it repeatable.
   persistent K
   if isempty(K), K = 1.15; end
   if nargin >= 1 && ~isempty(v)
      if ~isnumeric(v) || ~isscalar(v) || v <= 0.5 || v > 4
         error('fig_style:scale', 'scale must be a number in (0.5, 4]; got %s', mat2str(v));
      end
      K = double(v);
      fprintf('  figure type scale set to %.2f (%d pt axis labels at 3.5 in)\n', K, round(8 * K));
   end
   k = K;
end
