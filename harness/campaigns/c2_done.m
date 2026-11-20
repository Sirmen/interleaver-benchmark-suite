function tf = c2_done(step)
%C2_DONE  True if campaign_status.txt records step (e.g. 'code24_smoke') as OK
%         on its LAST line for that step. Lets code2_run_all resume where a
%         previous run stopped instead of repeating hours of finished work.
   tf = false;
   f = fullfile(campaign_log_dir(), 'campaign_status.txt');
   if exist(f, 'file') ~= 2, return; end
   L = splitlines(string(fileread(f)));
   L = L(contains(L, " " + step + " "));
   if isempty(L), return; end
   tf = contains(L(end), " OK ");
end
