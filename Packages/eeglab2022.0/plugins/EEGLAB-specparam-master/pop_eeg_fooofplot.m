function LASTCOM = pop_eeg_fooofplot(EEG, varargin)
    % Similar to pop_eeg_fooof but only plots one IC/chan at a time

    uilist = {{ 'style' 'text' 'string' 'Type of data to fit and plot (component or channel):' } ...
            { 'style' 'edit' 'string' '"component"' } ... 
            { 'style' 'text' 'string' 'IC/channel to plot:' } ... %could be drop down list
            { 'style' 'edit' 'string' '' } ...
            { 'style' 'text' 'string' 'epoch range [min_ms max_ms]:' } ... %2 element array
            { 'style' 'edit' 'string' [num2str( EEG.xmin*1000) ' ' num2str(EEG.xmax*1000)]  } ...
            { 'style' 'text' 'string' 'percent of the data to sample for computing:' } ...
            { 'style' 'edit' 'string' 100 } ...
            { 'style' 'text' 'string' 'Frequency range to fit:' } ...
            { 'style' 'edit' 'string' '' } ...
            { 'style' 'text' 'string' 'Plot in loglog (boolean):' } ... %could be checkmark
            { 'style' 'edit' 'string' 'false' } ...
            ... % Now FOOOF settings
            { 'style' 'text' 'string' '                     FOOOF settings (optional)' 'fontweight' 'bold' }...       
            { 'style' 'text' 'string' 'peak_width_limits' } ...
            { 'style' 'edit' 'string' '' } ...
            { 'style' 'text' 'string' 'max_n_peaks' } ...
            { 'style' 'edit' 'string' '' } ...
            { 'style' 'text' 'string' 'min_peak_height' } ...
            { 'style' 'edit' 'string' '' } ...
            { 'style' 'text' 'string' 'peak_threshold' } ...
            { 'style' 'edit' 'string' '' } ...
            { 'style' 'text' 'string' 'aperiodic_mode' } ...
            { 'style' 'edit' 'string' "'fixed'" } ... 
            { 'style' 'text' 'string' 'verbose (boolean)' } ...%want to make a checkmark later
            { 'style' 'edit' 'string' 'false' } };
    uigeom = { [12 4] [12 3] [12 3] [12 3] [12 3] [12 3] [1] [12 3] [12 3] [12 3] [12 3] [12 3] [12 3]}; %12
    [result, usrdat, sres2, sres] = inputgui( 'uilist', uilist, 'geometry', uigeom, 'title', 'FOOOF EEG - pop_eeg_fooofplot()', 'helpcom', 'pophelp(''pop_eeg_fooofplot'');', 'userdata', 0); %currently ignoring usrdat, sres2, sres
    params = {}; %parameters for eeg_fooofplot w/o FOOOF settings
    settings_keys = {'peak_width_limits','max_n_peaks','min_peak_height','peak_threshold','aperiodic_mode','verbose'};
    settings = struct(); %can be empty
    for i = 1:length(result)
        if i < 7
            param_curr = eval( [ '[' result{i} ']' ] );
            params{end+1} = param_curr;
        else
            if ~isempty(eval( [ '[' result{i} ']' ] ))
                settings.(settings_keys{i-6}) = eval( [ '[' result{i} ']' ] );
            end
        end
    end

    if ~isempty(params)
        eeg_fooofplot(EEG, params{3}, params{4}, params{1}, params{2}, params{5}, params{6}, settings);
        LASTCOM = sprintf('EEG = eeg_fooofplot(EEG, [%d %d], %d, "%s", %d, [%d %d], %d, %s)', params{3}(1), params{3}(2), params{4}, params{1}, params{2}, params{5}(1), params{5}(2), params{6}, struct2str(settings));
    else
        LASTCOM = '';
    end