function [deinterleaved_all, erM] = deinterleave_all_pc(intMethods, paramsInt, received_all, lenEncoded)
try
   erM=""; deinterleaved_all=[];
   %%%
   nMethods = length(intMethods);
   for i = 1:nMethods
      method = intMethods{i};
      [permutation, received] = getDeintParams(paramsInt, received_all, method);
      [deintA, erM] = deinterleaver_universal(received, permutation, lenEncoded);
      if erM == ""
         deinterleaved_all.(method) = deintA(1:lenEncoded); % stripout padding
      end
   end
catch ME
    erM = sprintf('%s: Error line %d: %s', ME.stack(1).name, ME.stack(1).line, ME.message);
end
end

function [permutation, received] = getDeintParams(paramsInt, received_all, method)
%GETDEINTPARAMS  Pull this method's permutation and received frame.
%
% THE ERROR THIS FUNCTION USED TO PRODUCE WAS A LIE
% ---------------------------------------------------------------------------
% Both lines below used to index straight into the structs. When a method was
% requested but never actually interleaved, the run died with
%
%     getDeintParams: Unrecognized field name "snake".
%
% which points at the DEINTERLEAVER - and the deinterleaver is fine. The field
% is missing because interleave_all_pc never wrote it, and there are only three
% ways that happens:
%
%   1. interleave_all_pc HAS NO BLOCK FOR THIS METHOD. The commonest cause
%      after a rename: intMethods asks for `snake`, the installed
%      interleave_all_pc still has the old `cross` block, so no block matches,
%      nothing is written, and every other method succeeds normally. Check with
%          grep -c "'snake'" interleave_all_pc.m
%      Zero means the patched file is not installed.
%   2. The method's block ran and set erM. Every later block is gated on
%      (erM == "") so they are skipped too - but the ones BEFORE it already
%      wrote their fields, which is why paramsInt.permutations exists and only
%      some entries are missing.
%   3. The method produced a frame longer than maxSize.
%
% All three are now named at the point of failure instead of being reported as
% a missing struct field.
   permutation = []; received = [];

   if ~isfield(paramsInt, 'permutations')
      error(['getDeintParams: paramsInt.permutations does not exist - ' ...
             'interleave_all_pc produced nothing at all. Check its erM.']);
   end

   if ~isfield(paramsInt.permutations, method)
      have = fieldnames(paramsInt.permutations);
      error(['getDeintParams: no permutation for method "%s".\n' ...
             '  interleave_all_pc did not write it. Methods it DID write: %s\n' ...
             '  Most likely interleave_all_pc has no block for "%s" (renamed method,\n' ...
             '  unpatched file), or that block set erM. This is not a deinterleaver fault.'], ...
             method, strjoin(have', ', '), method);
   end

   if ~isfield(received_all, method)
      error(['getDeintParams: no received frame for method "%s" - it was ' ...
             'interleaved but never transmitted.'], method);
   end

   permutation = paramsInt.permutations.(method);
   received    = received_all.(method);
end