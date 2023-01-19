function [D,f_band] = nonlinear_measures( data,srate,features,f_band, ...
                                           py_v,lzc_path )
%% NONLINEAR_MEASURES: finds nonlinear measures across epochs in EEG data
% Adapted from Python code from William Bosl, Fleming Peck by Gerardo Parra
%   Inputs:
%       - data      -  double | matrix with data to compute measures for, 
%                      with dimensions: n_channels x n_samples x n_epochs
%       - srate     - (optional) double | sampling rate of EEG data
%                     (default: 1000)
%       - features  - (optional) string array | sfeatures to compute, must 
%                     be a subset of the default: 
%                       [ "katz", "higuchi", "lzw_rho_median", "Power",
%                         "SampE", "hurstrs", "dfa" ]
%       - f_band    - (optional) struct | frequency bands to compute
%                     measures in, with fields 'name' and 'range'
%       - py_v      - (optional) char | version of Python (default: '3.9')
%       - lzc_path  - (optional) char | path to LZW_Ruffini.py (default:
%                     './nlm_scripts')
%   Outputs:
%       - D         - struct | contains fields for each computed feature, 
%                     each feature contains values computed across segments 
%                     and channels for each frequency band
%       - f_band    - struct | frequency bands used to compute measures, 
%                     with fields 'name' and 'range'

%% set default params if empty
if ~exist('srate','var'), srate = 1000; end
if ~exist('features','var'), features = []; end
if ~exist('f_bands','var'), f_band = struct([]); end
if ~exist('py_v','var'), py_v = '3.9'; end
if isempty(features)
    features = [ "katz", "higuchi", "lzw_rho_median", "Power", "SampE", ...
                 "hurstrs", "dfa"];
end
n_feat = length(features);
if isempty(f_band)
    f_names  = {'delta','theta','alpha','beta','gamma'};
    f_ranges = {[0.5 4],[4 8],[8 12],[13 30],[30 55]};
    f_band = struct('name',f_names,'range',f_ranges);
end
n_fband = length(f_band);

%% load & configure python
% set python to input py_v
if str2double(py_v) < 3, error('Python 3 is required'); end
try pyenv('Version',py_v); 
catch err
    if ~strcmp('MATLAB:Pyenv:PythonLoadedInProcess',err.identifier)
        error(err)
    end
end
% import modules
nolds = py.importlib.import_module('nolds');
ant   = py.importlib.import_module('antropy');
try
    lzc = py.importlib.import_module('LZW_Ruffini');
catch
    % add lzc_path to python search path
    if ~exist('lzc_path','var')
        lzc_path = fullfile('.','nlm_scripts'); 
    end
    P = py.sys.path;
    if count(P,lzc_path) == 0
        insert(P,int32(0),lzc_path);
    end
    % try to import again
    try
        lzc = py.importlib.import_module('LZW_Ruffini');
    catch
        error(['Error importing LZW_Ruffini module. Include path to '   ...
               'LZW_Ruffini.py when calling nonlinear_measures.m so'    ...
               'that it is included in the search path'])
    end
end

%% run cwt
[n_chan,~,n_epoch] = size(data);
chans_nan  = find(isnan(data(:,1,1)));
wt = cell(n_chan,1);
for i_c = 1:n_chan
    % skip NaN channels
    if sum(i_c == chans_nan)
        wt{i_c} = NaN;
        continue
    end
    % run cwt on each epoch
    for i_e = 1:n_epoch
        trial_data = squeeze(data(i_c,:,i_e));
        [wt_e,f]   = cwt(trial_data,srate,FrequencyLimits=[0.5 100]);
        wt{i_c}(:,:,end+1) = flip(abs(wt_e),1);
    end
end
f = flip(f);

%% compute features on each channel and frequency band
% iterate through frequency bands
for i_b = 1:n_fband
    fband_name = f_band(i_b).name;
    fband_i    = get_indexes(f_band(i_b).range,f,1);
    % iterate through channels
    for i_c = 1:n_chan
        % skip NaN channels
        if isnan(wt{i_c})
            for i_f = 1:n_feat
                D.(features(i_f)).(fband_name)(i_c,:) = NaN(1,n_epoch);
            end
            continue
        end
        % iterate through epochs
        for i_e = 1:n_epoch
            % get mean freq band data from channel
            y = squeeze(mean(wt{i_c}(fband_i,:,i_e),1));
            % skip 0 epochs
            if all(y==0)
                for i_f = 1:n_feat
                    D.(features(i_f)).(fband_name)(i_c,i_e) = NaN;
                end
                continue
            end
    
            % Feature set 1: Power
            % --------------------
%             if any(contains(features,"Power"))
%                 v = bandpower(y,srate);
%                 D.("Power").(fband)(i_c,i_e) = v;
%             end
        
            % Feature set 2: Sample Entropy, Hurst parameter, DFA
            % ---------------------------------------------------
            if contains("SampE",features)
                try
                    D.("SampE").(fband_name)(i_c,i_e) = nolds.sampen(y);
                catch
                    D.("SampE").(fband_name)(i_c,i_e) = NaN;
                end
            end
            if contains("hurstrs",features)
                try
                    hurst = nolds.hurst_rs(y);
                    D.("hurstrs").(fband_name)(i_c,i_e) = hurst;
                catch
                    D.("hurstrs").(fband_name)(i_c,i_e) = NaN;
                end
            end
            if contains("dfa",features)
                try
                    D.("dfa").(fband_name)(i_c,i_e) = nolds.dfa(y);
                catch
                    D.("dfa").(fband_name)(i_c,i_e) = NaN;
                end
            end
    
            % Feature set 3: Fractal dimensions
            % ---------------------------------
            if contains("katz",features)
                try
                    katz = ant.fractal.katz_fd(y);
                    D.("katz").(fband_name)(i_c,i_e) = katz;
                catch
                    D.("katz").(fband_name)(i_c,i_e) = NaN;
                end
            end
            if contains("higuchi",features)
                try
                    higuchi = ant.fractal.higuchi_fd(y);
                    D.("higuchi").(fband_name)(i_c,i_e) = higuchi;
                catch
                    D.("higuchi").(fband_name)(i_c,i_e) = NaN;
                end
            end
    
            % Feature set 4: Lempel Ziv Complexity
            % ------------------------------------
            y_b = binarize(y);
            if contains("lzw_rho_median",features)
                try
                    lzc_rho0 = lzc.Compute_rho0(y_b);
                    D.("lzw_rho_median").(fband_name)(i_c,i_e) = lzc_rho0;
                catch
                    D.("lzw_rho_median").(fband_name)(i_c,i_e) = NaN;
                end
            end
            if contains("lzw_rho1_median",features)
                try
                    lzc_rho1 = lzc.Compute_rho1(y_b);
                    D.("lzw_rho1_median").(fband_name)(i_c,i_e) = lzc_rho1;
                catch
                    D.("lzw_rho1_median").(fband_name)(i_c,i_e) = NaN;
                end
            end
        end
    end
end

end

%% function to binarize vector
function v_b = binarize(v,method)
    % verify inptus
    if ~isvector(v), error('Input must be a vector'); end
    if ~exist('method','var'), method = 'median'; end
    % intialize vector of zeros
    v_b = zeros(1,length(v));
    % set threshold based on method
    switch method
        case 'median'
            thr = median(v);
        case 'mean'
            thr = mean(v);
    end
    % set indices above thr to one
    v_b(v>thr) = 1;
end