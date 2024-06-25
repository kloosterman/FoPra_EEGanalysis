%% Example script for FoPra Entropy analysis

%% set up toolbox paths and data paths, so MATLAB knows where to find it
% clear everything to start MATLAB fresh
restoredefaultpath; clear ft_hastoolbox

% add fieldtrip and the entropy toolbox to the path, download from https://download.fieldtriptoolbox.org/
ft_path = '/Users/kloosterman/Documents/MATLAB/fieldtrip-20240603';
addpath(ft_path); ft_defaults; % this sets up fieldtrip toolbox for use, see https://www.fieldtriptoolbox.org/faq/installation/

% add Entropy analysis function (mMSE toolbox) to the path, download from https://github.com/LNDG/mMSE
mMSE_path = '/Users/kloosterman/Documents/GitHub/mMSE';
addpath(mMSE_path)

% add the FoPra scripts to the path, download from https://github.com/kloosterman/
fopra_path = '/Users/kloosterman/Library/CloudStorage/Dropbox/PROJECTS/Teaching/23-24SS/FoPra_EEG/FoPra_EEGanalysis';
addpath(fopra_path)

% put the path of your raw xdf data here
datapath = '/Users/kloosterman/Library/CloudStorage/Dropbox/PROJECTS/Teaching/23-24SS/FoPra_EEG/data/beatropie'; % replace this path with your data path
cd(datapath)

%% preprocessing EEG data: reading xdf file into memory and filtering
% this section loads in the data and does some basic preprocessing. See% https://www.fieldtriptoolbox.org/tutorial/continuous/ for more info
% To load the data into fieldtrip, first replace sccn_xdf.m in
% fieldtrip-20240603/fileio/private/sccn_xdf.m with sccn_xdf.m that is in fopra_path

% put filename of the xdf files that are in your datapath here, without .xdf extension
% Beatropie_001_CT bis Beatropie_019_CT

% SUBJ = {'Beatropie_001' 'Beatropie_002', 'Beatropie_003', 'Beatropie_004', 'Beatropie_005', ...
%   'Beatropie_006', 'Beatropie_007', 'Beatropie_008', 'Beatropie_009', 'Beatropie_010', ...
%   'Beatropie_011', 'Beatropie_012', 'Beatropie_013', 'Beatropie_014', 'Beatropie_015', ...
%   'Beatropie_016', 'Beatropie_018', 'Beatropie_019'};
SUBJ = {'Beatropie_002_CT' 'Beatropie_011_CT' 'Beatropie_018'}; % visual triggers

data=[]; mse_all=[];
for isub = 1:length(SUBJ)
  for icond = 1:2
    try
    filename = [SUBJ{isub} '_' conds{icond} '.xdf'];
    disp(filename)
    cfg=[]; % The cfg variable contains all the analysis settings that we will use.
    % cfg.reref = 'yes';  % No rereferencing for now
    % cfg.refchannel = {'EEG_M1', 'EEG_M2'};
    cfg.hpfilter = 'yes';
    cfg.hpfreq = 1;
    cfg.lpfilter = 'yes';
    cfg.lpfreq = 30;
    cfg.dataset = fullfile(datapath, filename); % make a folder called raw in your datapath folder, and put your data there. Then, change filename!
    data = ft_preprocessing(cfg); % Now you should have a structure "data" in your workspace

    %% make trials by hand visually using the databrowser ("visual")
    %% OR use the keyboard triggers sent during recording ("trigger")

    if contains(filename, 'Beatropie_002') && strcmp(conds{icond}, 'CT')
      trial_method = 'visual'; % set this to either visual or trigger
    elseif contains(filename, 'Beatropie_011') && strcmp(conds{icond}, 'CT')
      trial_method = 'visual'; % set this to either visual or trigger
    elseif contains(filename, 'Beatropie_018')
      trial_method = 'visual'; % set this to either visual or trigger
    else
      trial_method = 'trigger'; % set this to either visual or trigger
    end
    switch trial_method % this switches between the two trial methods
      case 'trigger' % these lines are run if trial_method is set to 'trigger';
        cfg=[];  % read triggers and cut trials out of the data
        cfg.dataset = filename; % make a folder called raw in your datapath folder, and put your data there. Then, change filename!
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
    cfg.resamplefs = 15; % 15 Hz is enough for our entropy analysis
    data = ft_resampledata(cfg, data);

    %% mse analysis on the data of interest: nothing has to be changed here
    mse = [];
    for itrial = 1:length(data.trial)
      cfg = [];
      cfg.m = 2;
      cfg.r = 0.5;
      cfg.timwin = floor(data.time{itrial}(end)-data.time{itrial}(1));  % take whole dataset
      middlesample = round(length(data.time{itrial})/2);  % put toi halfway the dataset
      cfg.toi = data.time{itrial}(middlesample);
      cfg.timescales = 1;
      cfg.recompute_r = 'perscale_toi_sp';
      cfg.coarsegrainmethod = 'filtskip';
      cfg.filtmethod = 'lp';
      cfg.allowgpu = 0;
      cfg.trials = itrial;
      mse{itrial} = ft_entropyanalysis(cfg, data); % compute entropy and put in variable mse
      mse{itrial}.dimord = 'chan_freq_time';
      mse{itrial}.freq = mse{itrial}.timescales;
    end

    cfg=[];
    cfg.parameter = 'sampen';
    cfg.keepindividual = 'yes';
    mse = ft_freqgrandaverage(cfg, mse{:});

    %% save data and mse to file
    outfile = [SUBJ{isub} '_' conds{icond}];

    cd(datapath) % change directory to the datapath
    save([outfile '_data.mat'], 'data');
    save([outfile '_mse.mat'], 'mse');
    writematrix(mse.sampen, [outfile '_mse.csv'])
    mse_all = [mse_all; mse.sampen];
    catch
      warning(sprintf([filename ' gives errors']))
    end
  end
end
writematrix(mse_all, [outfile '_mse.csv'])
    
%% plot topoplot of mse result
mse.freq = mse.timescales;
mse.dimord = 'chan_freq_time';

cfg=[];
cfg.layout = 'EEG1005.lay';
cfg.parameter = 'sampen';
ft_topoplotTFR(cfg, mse); colorbar
