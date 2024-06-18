function [trl, event] = ft_trialfun_manualtriggers(cfg)
% Read keyboard triggers from xdf file and make trl matrix: this tells
% fieldtrip where the trials should be extracted.

event = [];

% ft_path = fileparts(which('ft_definetrial'));
% addpath(fullfile(ft_path, 'external/xdf'))

hdr = ft_read_header(cfg.dataset);

trig = load_xdf(cfg.dataset);
trig = trig{2};
trig.time_stamps = trig.time_stamps - hdr.FirstTimeStamp;
kb_press_times = trig.time_stamps(1:2:end)';
kb_press_smp = round(kb_press_times .* hdr.Fs);
kb_press_smp = [kb_press_smp; hdr.nSamples]; % add last sample
% trl = [1 kb_press_smp(1)-1 0] % This keeps the first "trial"
for itrial = 1:length(kb_press_smp)-1
    trl(itrial,:) = [kb_press_smp(itrial) kb_press_smp(itrial+1)-1 0];
end

