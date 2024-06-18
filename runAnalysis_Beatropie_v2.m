%% Example script for Entropy analysis
restoredefaultpath
addpath('/Users/kloosterman/Documents/MATLAB/fieldtrip-20240603') % add ft to path, download from https://download.fieldtriptoolbox.org/
ft_defaults % this sets up fieldtrip toolbox for use, see https://www.fieldtriptoolbox.org/faq/installation/
addpath('/Users/kloosterman/Documents/GitHub/mMSE') % My entropy analysis software, download from https://github.com/LNDG/mMSE

datapath = '/Users/kloosterman/Library/CloudStorage/Dropbox/PROJECTS/Teaching/23-24SS/FoPra_EEG/data'; % replace this path with your data path

%% preprocessing EEG data: reading xdf file into memory and filtering
% this section loads in the data and does some basic preprocessing. See% https://www.fieldtriptoolbox.org/tutorial/continuous/ for more info

% To load in the data, first either disable lines 123/124 in fieldtrip-20240603/fileio/private/sccn_xdf.m, and change line 122 to:  
% hdr.label{j} = [stream.info.desc.channels.channel{j}.label];
% OR replace fieldtrip-20240603/fileio/private/sccn_xdf.m with sccn_xdf.m
% that I sent around.

cfg=[]; % The cfg variable contains all the analysis settings that we will use. 
% cfg.reref = 'yes';  % No rereferencing for now
% cfg.refchannel = {'EEG_M1', 'EEG_M2'};
cfg.hpfilter = 'yes';
cfg.hpfreq = 1;
cfg.lpfilter = 'yes';
cfg.lpfreq = 30;
cfg.dataset = fullfile(datapath, 'raw', 'Beatropie_007_BB.xdf'); % make a folder called raw in your datapath folder, and put your data there. Then, change filename!
data = ft_preprocessing(cfg); % After setting up the cfg we call ft_preprocessing with cfg as input, data is the output variable

% Now you should have a structure "data" in your workspace

%% read triggers and cut trials out of the data
% event = ft_read_event(cfg.dataset); % Manual triggers do not show up
cfg=[];
cfg.dataset = fullfile(datapath, 'raw', 'Beatropie_007_BB.xdf'); % make a folder called raw in your datapath folder, and put your data there. Then, change filename!
cfg.trialfun = 'ft_trialfun_manualtriggers';
cfg = ft_definetrial(cfg);
trl = cfg.trl;

cfg=[];
cfg.trl = trl;
data = ft_redefinetrial(cfg, data); % this gives you trials for each time the spacebar was pressed

%% visualize data, and mark data that you want to remove by selecting intervals with the mouse
% see https://www.fieldtriptoolbox.org/faq/how_can_i_use_the_databrowser/
% for more info
cfg=[];
cfg.event = KeyboardEvents;
cfg = ft_databrowser(cfg, data); % your marked periods will be saved in the cfg structure. 

%% cut the data of interest from the raw file
cfg.artfctdef.reject =  'partial'; % this makes data is cut into trials
data_clean = ft_rejectartifact(cfg, data);
disp(data_clean) % this shows the contents of data_Clean in the command window
ntrials = length(data.trial) % check that only 1 trial remains that contains your data of interest.

%% mse analysis on the data of interest: nothing has to be changed here
cfg = [];
cfg.m = 2;
cfg.r = 0.5;
cfg.timwin = floor(data_clean.time{1}(end)-data_clean.time{1}(1));  % take whole dataset
middlesample = round(length(data_clean.time{1})/2);  % put toi halfway the dataset
cfg.toi = data_clean.time{1}(middlesample);
cfg.timescales = 20;  % cfg.timescales = 10:30;
cfg.recompute_r = 'perscale_toi_sp';
cfg.coarsegrainmethod = 'filtskip';
cfg.filtmethod = 'lp';
cfg.mem_available = 40e+09;
cfg.allowgpu = true;
cfg.trials = 'all';
mse = ft_entropyanalysis(cfg, data_clean); % compute entropy and put in variable mse

%% plot topoplot of mse result
mse.freq = mse.timescales;
mse.dimord = 'chan_freq_time';

cfg=[];
cfg.layout = 'EEG1005.lay';
cfg.parameter = 'sampen';
ft_topoplotTFR(cfg, mse); colorbar
