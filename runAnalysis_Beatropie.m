%% Example script for FoPra Entropy analysis

%% set up toolbox paths and data paths, so MATLAB knows where to find it
% clear everything to start MATLAB fresh
cd ~;restoredefaultpath; clear ft_hastoolbox

% add fieldtrip and the entropy toolbox to the path, download from https://download.fieldtriptoolbox.org/
ft_path = '/Users/kloosterman/Documents/MATLAB/fieldtrip-20240603';
addpath(ft_path); ft_defaults; % this sets up fieldtrip toolbox for use, see https://www.fieldtriptoolbox.org/faq/installation/

% add Entropy analysis function (mMSE toolbox) to the path, download from https://github.com/LNDG/mMSE
mMSE_path = '/Users/kloosterman/Documents/GitHub/mMSE';
addpath(mMSE_path) 

% add the FoPra scripts to the path, download from https://github.com/kloosterman/FoPra_EEGanalysis
fopra_path = '/Users/kloosterman/Library/CloudStorage/Dropbox/PROJECTS/Teaching/23-24SS/FoPra_EEG/FoPra_EEGanalysis';
addpath(fopra_path)

% put the path of your raw xdf data here
datapath = '/Users/kloosterman/Library/CloudStorage/Dropbox/PROJECTS/Teaching/23-24SS/FoPra_EEG/data'; % replace this path with your data path

%% preprocessing EEG data: reading xdf file into memory and filtering
% this section loads in the data and does some basic preprocessing. See% https://www.fieldtriptoolbox.org/tutorial/continuous/ for more info
% To load the data into fieldtrip, first replace sccn_xdf.m in
% fieldtrip-20240603/fileio/private/sccn_xdf.m with sccn_xdf.m that is in fopra_path

filename = 'Beatropie_007_BB'; % filename of the xdf file that we will process 

cfg=[]; % The cfg variable contains all the analysis settings that we will use.
% cfg.reref = 'yes';  % No rereferencing for now
% cfg.refchannel = {'EEG_M1', 'EEG_M2'};
cfg.hpfilter = 'yes';
cfg.hpfreq = 1;
cfg.lpfilter = 'yes';
cfg.lpfreq = 30;
cfg.dataset = fullfile(datapath, [filename '.xdf']); % make a folder called raw in your datapath folder, and put your data there. Then, change filename!
data = ft_preprocessing(cfg); % Now you should have a structure "data" in your workspace

%% make trials by hand visually using the databrowser ("visual") 
%% OR use the keyboard triggers sent during recording ("trigger")

trial_method = 'trigger'; % set this to either visual or trigger
switch trial_method % this switches between the two trial methods
  case 'trigger' % these lines are run if trial_method is set to 'trigger';   
    cfg=[];  % read triggers and cut trials out of the data
    cfg.dataset = fullfile(datapath, [filename '.xdf']); % make a folder called raw in your datapath folder, and put your data there. Then, change filename!
    cfg.trialfun = 'ft_trialfun_manualtriggers';
    cfg = ft_definetrial(cfg); % define the trials using the ft_trialfun_manualtriggers function
    trl = cfg.trl;

    cfg=[];
    cfg.trl = trl; % trl has the start and end samples of your trials
    data = ft_redefinetrial(cfg, data); % this gives you trials for each time the spacebar was pressed
  case 'visual' % these lines are run if trial_method is set to 'visual';
    % visualize data, and mark data that you want to remove by selecting intervals with the mouse
    % select parts that can be removed - the periods that are not removed end
    % up as "trials" in the data structure. Press q after your are done marking
    % data to close the figure; use delete(gcf) if the figure is stuck
    % see https://www.fieldtriptoolbox.org/faq/how_can_i_use_the_databrowser/ for more info
    cfg=[];
    cfg = ft_databrowser(cfg, data); % your marked periods will be saved in the cfg structure.
    cfg.artfctdef.reject =  'partial'; % this makes sure the data is cut into trials
    data = ft_rejectartifact(cfg, data);
    disp(data) % this shows the contents of data in the command window
end

%% downsample to make the data easier to handle
data.fsample = round(data.fsample); % data.fsample = 250.0010 or 500.001, which gives errors. Rounding resolves it.
cfg = [];
cfg.resample = 'yes';
cfg.resamplefs = 125; % 125 Hz is enough for our entropy analysis
data = ft_resampledata(cfg, data);

%% select the trial of interest from the data
cfg=[];
cfg.trials = 1; % 1 selects trial 1, etc
data = ft_selectdata(cfg, data);

%% remove the channels (electrodes) that are noisy / uninteresting
cfg=[];
cfg.channel = {'all', '-Fp1', '-Fp2'}; % this selects all channels except Fp1 and Fp2
data = ft_selectdata(cfg, data);

%% now is a good time to save your preprocessed data to file
cd(datapath) % change directory to the datapath 
save(['data_' filename '.mat'], 'data'); % output filename is based on filename

%% mse analysis on the data of interest: nothing has to be changed here
cfg = [];
cfg.m = 2;
cfg.r = 0.5;
cfg.timwin = floor(data.time{1}(end)-data.time{1}(1));  % take whole dataset
middlesample = round(length(data.time{1})/2);  % put toi halfway the dataset
cfg.toi = data.time{1}(middlesample);
cfg.timescales = 15;  % cfg.timescales = 10:30;
cfg.recompute_r = 'perscale_toi_sp';
cfg.coarsegrainmethod = 'filtskip';
cfg.filtmethod = 'lp';
% cfg.mem_available = 40e+09;
cfg.allowgpu = true;
cfg.trials = 'all';
mse = ft_entropyanalysis(cfg, data); % compute entropy and put in variable mse

%% save your mse to file
cd(datapath) % change directory to the datapath 
save(['mse_' filename '.mat'], 'data'); % output filename is based on filename

%% plot topoplot of mse result
mse.freq = mse.timescales;
mse.dimord = 'chan_freq_time';

cfg=[];
cfg.layout = 'EEG1005.lay';
cfg.parameter = 'sampen';
ft_topoplotTFR(cfg, mse); colorbar
