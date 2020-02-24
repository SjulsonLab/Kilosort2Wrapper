function KS2Wrapper(basepath)
%function to 

%% you need to change most of the paths in this block

basepath = 'C:\Users\fermi\Data\20190301'; % the raw data binary file is in this folder
rootH = 'C:\Users\fermi\Data'; % path to temporary binary file (same size as data, should be on fast SSD)
% pathToYourConfigFile = 'D:\GitHub\KiloSort2\configFiles'; % take from Github folder and put it somewhere else (together with the master_file)

%before this, run the script to generate the channel map
chanMapFile = fullfile(basepath,'chanMap.mat');
ops = StandardConfig_KS2Wrapper;

ops.trange = [0 Inf]; % time range to sort
ops.NchanTOT    = 71; % total number of channels in your recording

% run(fullfile(pathToYourConfigFile, 'configFile384.m'))
ops.fproc       = fullfile(rootH, 'temp_wh.dat'); % proc file on a fast SSD
ops.chanMap = fullfile(chanMapFile);

%% this block runs all the steps of the algorithm
fprintf('Looking for data inside %s \n', basepath)

% is there a channel map file in this folder?
fs = dir(fullfile(basepath, 'chan*.mat'));
if ~isempty(fs)
    ops.chanMap = fullfile(basepath, fs(1).name);
end

% find the binary file
fs          = [dir(fullfile(basepath, '*.bin')) dir(fullfile(basepath, '*.dat'))];
ops.fbinary = fullfile(basepath, fs(1).name);

% preprocess data to create temp_wh.dat
rez = preprocessDataSub(ops);

% time-reordering as a function of drift
rez = clusterSingleBatches(rez);

% saving here is a good idea, because the rest can be resumed after loading rez
save(fullfile(basepath, 'rez.mat'), 'rez', '-v7.3');

% main tracking and template matching algorithm
rez = learnAndSolve8b(rez);

% final merges
rez = find_merges(rez, 1);

% final splits by SVD
rez = splitAllClusters(rez, 1);

% final splits by amplitudes
rez = splitAllClusters(rez, 0);

% decide on cutoff
rez = set_cutoff(rez);

fprintf('found %d good units \n', sum(rez.good>0))

% write to Phy
fprintf('Saving results to Phy  \n')
rezToPhy(rez, basepath);

%% if you want to save the results to a Matlab file...

% discard features in final rez file (too slow to save)
rez.cProj = [];
rez.cProjPC = [];

% save final results as rez2
fprintf('Saving final results in rez2  \n')
fname = fullfile(basepath, 'rez2.mat');
save(fname, 'rez', '-v7.3');
