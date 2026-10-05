% test_InterleaverSpiral.m
% Standalone test for the spiral interleaver.
% R.Tanju Sirmen - 2026
%
% Runs the full sweep, checks permutation validity and interleave/deinterleave
% round-trip, and reports separation, ECC-aware and cost metrics with plots.
% All the work is in testInterleaver.m - this file only sets the options, so
% the 24 method tests cannot drift apart.
% NOTE: min adjacency is 1 for every N - a spiral walk reads grid-adjacent
%       cells consecutively, so half the legs emit runs of consecutive indices.
%
% Usage:
%   test_InterleaverSpiral                 % full sweep, with plots
%   r = test_InterleaverSpiral;            % keep the results struct

clear all; close all;

opts = struct();
opts.Nmin        = 30;      % shortest encoded length
opts.Nmax        = 510;     % longest encoded length
opts.Nstep       = 1;
opts.base        = 10;      % symbol alphabet
opts.maxExt      = 0.5;     % max padding allowed
opts.seed        = 2106;
opts.FECn        = 15;      % RS codeword length, for the ECC-aware metrics
opts.FECt        = 3;       % correctable symbols per codeword
opts.burstTrials = 40;      % bursts injected per length
opts.plot        = true;
opts.verbose     = true;

results = testInterleaver('spiral', opts);
