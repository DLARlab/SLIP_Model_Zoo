classdef CircularPhase_v3
    %CIRCULARPHASE_V3 Explicit interfaces between circle phases and lifts.
    methods (Static)
        function wrapped = wrap(phase)
            validateattributes(phase,{'numeric'},{'real','finite'});
            wrapped=mod(phase,1);
        end
        function difference = difference(a,b)
            % Shortest local displacement a-b; half-turn has two lifts.
            difference=mod(a-b+0.5,1)-0.5;
        end
        function [lifted,transition] = liftNear(wrapped,reference)
            validateattributes(reference,{'numeric'},{'real','finite'});
            phase=CircularPhase_v3.wrap(wrapped);
            transition=round(reference-phase);
            lifted=phase+transition;
            if any(abs(abs(lifted-reference)-0.5)<64*eps,'all')
                error('CircularPhase_v3:AmbiguousLift','A half-turn requires an explicit chart choice.');
            end
        end
    end
end
