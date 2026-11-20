function d = campaign_log_dir()
%CAMPAIGN_LOG_DIR  Folder for the logs and the status file of the campaign scripts.
%
%   d = campaign_log_dir()
%
% SINT_LOGS if that environment variable is set, otherwise campaign_logs in
% the current folder. Created if absent. Every script in harness/campaigns
% writes its diary here and appends one line per finished step to
% campaign_status.txt, so the outcome of a long run can be read without
% copying console output by hand.
%
% R.T. Sirmen, 2026-11

   d = getenv('SINT_LOGS');
   if isempty(d), d = fullfile(pwd, 'campaign_logs'); end
   if ~exist(d, 'dir'), mkdir(d); end
end
