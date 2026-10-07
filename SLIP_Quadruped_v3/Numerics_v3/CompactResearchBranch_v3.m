function [compact, report] = CompactResearchBranch_v3(branch)
%COMPACTRESEARCHBRANCH_V3 Checkpoint evidence without duplicate FD traces.
% Primary accepted/rejected orbit trajectories and event logs remain intact.
% Nested diagnostic trajectories retain endpoints, event logs, termination,
% and sample counts; matrices, stencils, rank, signatures, states, and solver
% counters are copied unchanged. The input branch/handle orbits are not edited.
    if ~isstruct(branch) || ~isscalar(branch)
        error('CompactResearchBranch_v3:Branch', 'Branch must be a scalar structure.');
    end
    omittedTrajectories = 0;
    omittedOrbits = 0;
    compact = branch;
    names = fieldnames(branch);
    for fieldIndex = 1:numel(names)
        name = names{fieldIndex};
        if any(strcmp(name, {'points','failures'})) && isstruct(branch.(name))
            points = branch.(name);
            for pointIndex = 1:numel(points)
                pointNames = fieldnames(points(pointIndex));
                for pointField = 1:numel(pointNames)
                    key = pointNames{pointField};
                    value = points(pointIndex).(key);
                    if strcmp(key, 'orbit')
                        points(pointIndex).(key) = primaryOrbit(value);
                    elseif strcmp(key, 'trajectory')
                        % A top-level rejected trace can be its only replay.
                        points(pointIndex).(key) = value;
                    else
                        points(pointIndex).(key) = diagnostics(value, key);
                    end
                end
            end
            compact.(name) = points;
        else
            compact.(name) = diagnostics(branch.(name), name);
        end
    end
    report = struct('schema_version','compact-research-checkpoint-v3-1', ...
        'omitted_duplicate_trajectories',omittedTrajectories, ...
        'omitted_nested_orbits',omittedOrbits, ...
        'preserved_primary_orbits',true,'preserved_rejected_states',true, ...
        'policy',['Primary point.orbit trajectory/events remain complete. ', ...
        'Nested diagnostic traces retain endpoints, events and termination; ', ...
        'derivative matrices, steps, errors, signatures, ranks and counters remain.']);
    compact.compact_checkpoint = report;

    function output = primaryOrbit(value)
        output = value;
        if isa(value, 'HybridOrbit_v3') && isscalar(value)
            % Clone the handle before stripping nested stability traces.
            output = HybridOrbit_v3();
            keys = properties(value);
            for propertyIndex = 1:numel(keys)
                key = keys{propertyIndex};
                if strcmp(key, 'trajectory')
                    output.(key) = primaryTrajectory(value.(key));
                else
                    output.(key) = diagnostics(value.(key), key);
                end
            end
        elseif isstruct(value)
            for orbitIndex = 1:numel(value)
                keys = fieldnames(value(orbitIndex));
                for propertyIndex = 1:numel(keys)
                    key = keys{propertyIndex};
                    if strcmp(key,'trajectory')
                        output(orbitIndex).(key)=primaryTrajectory(value(orbitIndex).(key));
                    else
                        output(orbitIndex).(key) = diagnostics(value(orbitIndex).(key), key);
                    end
                end
            end
        end
    end

    function output=primaryTrajectory(value)
        output=value;
        if isa(value,'Trajectory_v3')
            output=Trajectory_v3();
            keys=properties(value);
            raw={'time','state','mode','event_time','event_type'};
            for index=1:numel(keys)
                key=keys{index};
                if any(strcmp(key,raw)),output.(key)=value.(key);
                else,output.(key)=diagnostics(value.(key),key);end
            end
        end
    end

    function output = diagnostics(value, key)
        if isa(value,'function_handle')
            output=struct('diagnostic_kind','runtime-function-descriptor', ...
                'signature',func2str(value),'requires_runtime_reconstruction',true);
        elseif isa(value,'PoincareSection_v3') || isa(value,'HybridSystemBase_v3') || ...
                isa(value,'HybridSimulator_v3') || isa(value,'ReturnPolicyBase_v3')
            output=struct('diagnostic_kind','runtime-object-descriptor', ...
                'source_class',class(value),'requires_runtime_reconstruction',true);
            keys=properties(value);
            for index=1:numel(keys)
                field=keys{index};output.settings.(field)=diagnostics(value.(field),field);
            end
        elseif isa(value, 'Trajectory_v3') || ...
                (strcmpi(key,'trajectory') && ~isempty(value))
            omittedTrajectories = omittedTrajectories + 1;
            output = trajectorySummary(value);
        elseif isa(value, 'HybridOrbit_v3') || ...
                (strcmpi(key,'orbit') && ~isempty(value))
            omittedOrbits = omittedOrbits + 1;
            output = orbitSummary(value);
        elseif isstruct(value)
            output = value;
            keys = fieldnames(value);
            for item = 1:numel(value)
                for propertyIndex = 1:numel(keys)
                    nestedKey = keys{propertyIndex};
                    output(item).(nestedKey) = diagnostics(value(item).(nestedKey), nestedKey);
                end
            end
        elseif iscell(value)
            output = value;
            for item = 1:numel(value)
                output{item} = diagnostics(value{item}, key);
            end
        else
            output = value;
        end
    end

    function summary = trajectorySummary(value)
        summary = struct('diagnostic_kind','duplicate-trajectory-summary', ...
            'source_class',class(value),'full_trace_preserved',false);
        time = member(value,'time',[]);
        states = member(value,'state',[]);
        modes = member(value,'mode',[]);
        summary.sample_count = numel(time);
        if ~isempty(time)
            summary.time_interval = [time(1),time(end)];
        else
            summary.time_interval = [];
        end
        if ~isempty(states)
            summary.initial_state = states(1,:);
            summary.final_state = states(end,:);
        else
            summary.initial_state = [];
            summary.final_state = [];
        end
        if ~isempty(modes)
            summary.initial_mode = modes(1,:);
            summary.final_mode = modes(end,:);
        else
            summary.initial_mode = [];
            summary.final_mode = [];
        end
        keys = {'event_history','event_batches','event_type','event_time', ...
            'termination_reason','termination_time','termination_state', ...
            'termination_mode','termination_metadata','termination','metadata'};
        for keyIndex = 1:numel(keys)
            key = keys{keyIndex};
            data = member(value,key,[]);
            if ~isempty(data)
                summary.(key) = diagnostics(data,key);
            end
        end
    end

    function summary = orbitSummary(value)
        summary = struct('diagnostic_kind','duplicate-orbit-summary', ...
            'source_class',class(value),'full_trace_preserved',false);
        keys = {'initial_state','initial_mode','parameter','period', ...
            'poincare_state','stride_displacement','event_history','mode_history', ...
            'return_policy_name','return_multiplicity','cyclic_event_signature', ...
            'section_relative_event_signature','event_cluster_signature', ...
            'minimum_physical_margin','schema_metadata','section_chart','primitive_cycle'};
        for keyIndex = 1:numel(keys)
            key = keys{keyIndex};
            data = member(value,key,[]);
            if ~isempty(data)
                summary.(key) = diagnostics(data,key);
            end
        end
    end
end

function output = member(value, key, fallback)
    output = fallback;
    if isstruct(value) && isscalar(value) && isfield(value,key)
        output = value.(key);
    elseif isobject(value) && isscalar(value) && isprop(value,key)
        output = value.(key);
    end
end
