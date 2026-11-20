function c31_status(step, status, logFile)
%C31_STATUS  One line per finished step in campaign_status.txt of the log folder.
%   Lets the outcome of every step be read from the log folder without
%   anyone copying console output by hand. (The name is historical: the
%   first campaign scripted this way was RS(31,21).)
   fid = fopen(fullfile(campaign_log_dir(), 'campaign_status.txt'), 'a');
   if fid > 0
      fprintf(fid, '%s  %-22s %-7s %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), step, status, logFile);
      fclose(fid);
   end
end
