% *************************************************************************
% Graphical-output base class for SLIP Model Zoo v3.
%
% Original attribution retained from OutputCLASS.m:
% Created by C. David Remy on 03/14/2011, MATLAB 2010a.
% Documentation: "A MATLAB Framework For Gait Creation", C. David Remy,
% Keith Buffinton, and Roland Siegwart, IEEE/RSJ IROS, 2011.
% Autonomous Systems Lab, ETH Zurich; Department of Mechanical
% Engineering, Bucknell University.
%
% The v3 adaptation retains the refresh-rate contract while using handle
% semantics so graphics objects can be updated without copying wrappers.
% *************************************************************************
classdef OutputCLASS_v3 < handle
    properties
        slowDown = 1
        rate = 0.04
    end

    methods
        function t = getTimeVector(obj, tStart, tEnd)
            arguments
                obj
                tStart (1, 1) double {mustBeFinite}
                tEnd (1, 1) double {mustBeFinite}
            end
            if tEnd < tStart
                error('OutputCLASS_v3:InvalidTimeInterval', ...
                    'tEnd must not precede tStart.');
            end
            tEnd = min(tEnd, tStart + 1e3);
            if obj.rate <= 0 || ~isfinite(obj.rate)
                t = [tStart; tEnd];
            else
                t = (tStart:obj.rate:tEnd).';
                if isempty(t) || t(end) < tEnd
                    t(end + 1, 1) = tEnd;
                end
            end
            t = unique(t, 'stable');
        end
    end
end
