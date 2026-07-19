%% Function: Event Timing Regulation (Outside Zero Function)
function X_out = EventTimingRegulation(X_in)
    X_out = X_in;
    n = numel(X_in);
    if n == 22
        % Full state+timing vector: timings at indices 14-22
        tIdx = 14:22;
        timings = X_in(tIdx);
    elseif n == 9
        % Only timing vector: assign directly
        timings = X_in(:);
        tIdx = 1:9;
    else
        error('EventTimingRegulation:InvalidInput', ...
            'Input length must be 9 or 22.');
    end
    % Extract timings
    tBL_TD = timings(1);
    tBL_LO = timings(2);
    tFL_TD = timings(3);
    tFL_LO = timings(4);
    tBR_TD = timings(5);
    tBR_LO = timings(6);
    tFR_TD = timings(7);
    tFR_LO = timings(8);
    tAPEX  = timings(9);
    % Wrap into [0, tAPEX]
    wrap = @(t) mod(t, tAPEX);
    tBL_TD_ = wrap(tBL_TD);
    tBL_LO_ = wrap(tBL_LO);
    tFL_TD_ = wrap(tFL_TD);
    tFL_LO_ = wrap(tFL_LO);
    tBR_TD_ = wrap(tBR_TD);
    tBR_LO_ = wrap(tBR_LO);
    tFR_TD_ = wrap(tFR_TD);
    tFR_LO_ = wrap(tFR_LO);
    tAPEX_  = tAPEX;
    % Place back into output
    newTimings = [tBL_TD_; tBL_LO_; tFL_TD_; tFL_LO_; tBR_TD_; tBR_LO_; tFR_TD_; tFR_LO_; tAPEX_];
    X_out(tIdx) = newTimings;
end
