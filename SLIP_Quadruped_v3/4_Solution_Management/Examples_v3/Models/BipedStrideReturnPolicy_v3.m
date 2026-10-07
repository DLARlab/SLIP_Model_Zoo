classdef BipedStrideReturnPolicy_v3 < ReturnPolicyBase_v3
    %BIPEDSTRIDERETURNPOLICY_V3 Close one alternating left/right stride.
    %   Intermediate step apexes are rejected.  Acceptance requires the
    %   initial right-continuous flight mode and one TD/LO of each leg.

    methods
        function obj = BipedStrideReturnPolicy_v3()
            obj.Name = 'alternating-biped-stride-return';
        end
    end

    methods (Access = protected)
        function [accepted, diagnostics] = acceptCandidate( ...
                ~, candidate, ~)
            touchdown = zeros(2, 1);
            liftoff = zeros(2, 1);
            unclassified = strings(0, 1);
            for index = 1:numel(candidate.event_history)
                event = candidate.event_history(index);
                if isfield(event, 'is_stop') && event.is_stop
                    continue
                end
                [leg, kind] = BipedStrideReturnPolicy_v3.classify(event);
                if isempty(leg) || leg < 1 || leg > 2
                    unclassified(end + 1, 1) = ...
                        string(event.type); %#ok<AGROW>
                elseif kind == "touchdown"
                    touchdown(leg) = touchdown(leg) + 1;
                elseif kind == "liftoff"
                    liftoff(leg) = liftoff(leg) + 1;
                else
                    unclassified(end + 1, 1) = ...
                        string(event.type); %#ok<AGROW>
                end
            end

            modeClosed = isequal(double(candidate.initial_mode(:)), ...
                double(candidate.mode(:)));
            complete = all(touchdown >= 1) && all(liftoff >= 1);
            accepted = modeClosed && complete;
            if ~modeClosed
                reason = 'right-continuous biped mode has not closed';
            elseif ~complete
                reason = 'both legs have not completed touchdown and liftoff';
            else
                reason = 'alternating left/right stride cycle is complete';
            end

            perLeg = repmat(struct( ...
                'leg_index', 0, 'leg_name', '', ...
                'touchdown_count', 0, 'liftoff_count', 0), 2, 1);
            names = {'L', 'R'};
            for leg = 1:2
                perLeg(leg).leg_index = leg;
                perLeg(leg).leg_name = names{leg};
                perLeg(leg).touchdown_count = touchdown(leg);
                perLeg(leg).liftoff_count = liftoff(leg);
            end
            diagnostics = struct( ...
                'complete', accepted, ...
                'reason', reason, ...
                'mode_closed', modeClosed, ...
                'touchdown_counts', touchdown, ...
                'liftoff_counts', liftoff, ...
                'event_counts_per_leg', perLeg, ...
                'unclassified_events', unclassified, ...
                'return_multiplicity', candidate.index);
        end
    end

    methods (Static, Access = private)
        function [leg, kind] = classify(event)
            leg = [];
            kind = "";
            metadata = struct();
            if isfield(event, 'metadata') && isstruct(event.metadata)
                metadata = event.metadata;
            end
            if isfield(metadata, 'leg_index')
                leg = double(metadata.leg_index);
            end
            if isfield(metadata, 'event_kind')
                kind = lower(string(metadata.event_kind));
            end
            name = upper(string(event.type));
            if isempty(leg)
                if startsWith(name, "L_")
                    leg = 1;
                elseif startsWith(name, "R_")
                    leg = 2;
                end
            end
            if strlength(kind) == 0
                if contains(name, "TD")
                    kind = "touchdown";
                elseif contains(name, "LO")
                    kind = "liftoff";
                end
            end
        end
    end
end
