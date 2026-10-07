function report=ExportResearchEvidence_v3(outputDirectory)
%EXPORTRESEARCHEVIDENCE_V3 Replay and index accepted campaign orbits.
% This is validation, not discovery. Raw trajectories remain in referenced MAT
% artifacts. Independent replay uses tighter tolerances than the main sweep.
    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    oldPath=path;cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
    addpath(root);
    if nargin<1,outputDirectory=fullfile(root,'Research_v3','runs','full');end
    outputDirectory=V3OutputPath_v3(outputDirectory);
    folders={'Schema_v3','Dynamics_v3','Simulation_v3','Orbit_v3','Numerics_v3'};
    for k=1:numel(folders),addpath(fullfile(root,folders{k}));end
    s=QuadrupedSchema_v3.shared();system=Quadrupedal_Dynamics_v3();
    simulator=HybridSimulator_v3(struct('RelTol',1e-11,'AbsTol',1e-13));
    timer=tic;report=struct('schema_version','replayed-solution-index-v3-1', ...
        'model_id','v3-autonomous-first-directed-root-compressive-stance', ...
        'purpose','independent tighter replay of stored accepted states', ...
        'replay_settings',struct('relative_tolerance',1e-11,'absolute_tolerance',1e-13, ...
        'closure_target',1e-8),'solutions',struct([]),'status','running');
    files=[dir(fullfile(outputDirectory,'vertical_*.mat')); ...
        dir(fullfile(outputDirectory,'fixture_*.mat')); ...
        dir(fullfile(outputDirectory,'pronk_daughter_v2_*.mat')); ...
        dir(fullfile(outputDirectory,'family_*.mat'))];
    for fileIndex=1:numel(files)
        file=V3OutputPath_v3(fullfile(files(fileIndex).folder,files(fileIndex).name));data=load(file);
        if isfield(data,'branch')
            for j=1:numel(data.branch.points)
                record(data.branch.points(j).orbit,file,j,'imported-seed continuation');
            end
        elseif isfield(data,'orbit')&&isa(data.orbit,'HybridOrbit_v3')
            if startsWith(files(fileIndex).name,'pronk'),origin='parent-only';
            elseif startsWith(files(fileIndex).name,'vertical'),origin='analytic parent';
            else,origin='imported comparison';end
            record(data.orbit,file,1,origin);
        end
        checkpoint();
    end
    report.count=numel(report.solutions);
    if isempty(report.solutions),report.failed_replay_count=0;
    else,report.failed_replay_count=sum(~[report.solutions.replay_passed]);end
    report.status='completed_validation';report.elapsed_seconds=toc(timer);checkpoint();

    function record(orbit,file,index,origin)
        if isempty(orbit),return;end
        compact=CompactResearchBranch_v3(struct('points',struct('orbit',orbit)));
        orbit=compact.points.orbit;
        closure=Inf;raw=[];reason='';signatureMatch=false;admissible=false;
        discreteClosed=false;cycleComplete=false;policyMatch=false;
        replayPeriod=NaN;replayMultiplicity=NaN;
        try
            policy=storedReturnPolicy(orbit,s);
            map=PoincareMap_v3(system,PoincareSection_v3.apex(s.State.dy),simulator,policy);
            problem=PeriodicOrbitResidual_v3(map,orbit.initial_state);
            [~,info]=problem.evaluateWithInfo(problem.packState(orbit.initial_state), ...
                orbit.parameter,orbit.initial_mode);
            raw=info.next_state(2:end)-orbit.initial_state(2:end);
            closure=norm(raw,inf);admissible=info.admissible;
            signatureMatch=strcmp(info.section_relative_event_signature,orbit.section_relative_event_signature);
            discreteClosed=info.discrete_closed;cycleComplete=info.cycle_complete;
            replayPeriod=info.map_info.period;replayMultiplicity=info.return_multiplicity;
            policyMatch=strcmp(info.return_policy_name,orbit.return_policy_name)&& ...
                replayMultiplicity==orbit.return_multiplicity;
        catch ex,reason=sprintf('%s: %s',ex.identifier,ex.message);end
        classification=GaitIdentification_v3(orbit);
        [energy,energyInfo]=QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter);
        chart=QuadrupedPhysicalChart_v3.create(orbit.initial_state,orbit.initial_mode,orbit.parameter);
        item=struct('id',sprintf('%s:%d',erase(files(fileIndex).name,'.mat'),index), ...
            'origin',origin,'artifact',erase(file,[root,filesep]),'artifact_point_index',index, ...
            'model_id',report.model_id,'schema_metadata',orbit.schema_metadata, ...
            'initial_state',orbit.initial_state,'initial_mode',orbit.initial_mode, ...
            'physical_parameter',orbit.parameter,'energy',energy,'energy_finite_inertia',~energyInfo.infinite_pitch_inertia, ...
            'section_chart',orbit.section_chart,'physical_chart',chart, ...
            'primitive_period',orbit.period,'drift',orbit.stride_displacement, ...
            'mean_speed',orbit.stride_displacement(1)/orbit.period, ...
            'return_policy',orbit.return_policy_name,'return_multiplicity',orbit.return_multiplicity, ...
            'event_word',orbit.section_relative_event_signature,'cyclic_event_word',orbit.cyclic_event_signature, ...
            'event_log',orbit.event_history,'cluster_data',orbit.event_clusters, ...
            'flight_count',classification.flight_count,'gait_label',classification.label, ...
            'classification',classification,'minimum_physical_margin',orbit.minimum_physical_margin, ...
            'minimum_guard_transversality',orbit.minimum_guard_transversality, ...
            'section_transversality',orbit.section_transversality, ...
            'replay_closure_components',raw,'replay_closure_inf',closure, ...
            'replay_signature_match',signatureMatch,'replay_admissible',admissible, ...
            'replay_discrete_closed',discreteClosed,'replay_cycle_complete',cycleComplete, ...
            'replay_policy_match',policyMatch,'replay_period',replayPeriod, ...
            'replay_return_multiplicity',replayMultiplicity, ...
            'replay_passed',isfinite(closure)&&closure<=1e-8&&signatureMatch&&admissible&& ...
                discreteClosed&&cycleComplete&&policyMatch,'replay_failure_reason',reason, ...
            'derivative_diagnostics_artifact',erase(file,[root,filesep]), ...
            'branch_neighbors',struct('previous_index',max(0,index-1),'next_index',[]), ...
            'parent_edge_certificate','Research_v3/graph/index.json');
        if isfield(data,'branch')&&index<numel(data.branch.points),item.branch_neighbors.next_index=index+1;end
        if isempty(report.solutions),report.solutions=item;else,report.solutions(end+1)=item;end
        fprintf('Replay %s: %.3g signature %d admissible %d\n',item.id,closure,signatureMatch,admissible);
        if startsWith(files(fileIndex).name,'vertical_07')||startsWith(files(fileIndex).name,'fixture_09_00001')
            trajectory=orbit.trajectory;
            series=struct('artifact',item.artifact,'time',trajectory.time, ...
                'state',trajectory.state,'mode',trajectory.mode,'event_time',trajectory.event_time, ...
                'event_type',trajectory.event_type,'physical_parameter',orbit.parameter);
            writeJSON(fullfile(outputDirectory,[erase(files(fileIndex).name,'.mat'),'_series.json']),series);
        end
    end
    function checkpoint()
        report.elapsed_seconds=toc(timer);
        writeJSON(fullfile(outputDirectory,'solution_index.json'),report);
    end
end

function policy=storedReturnPolicy(orbit,schema)
    name=char(orbit.return_policy_name);
    switch name
        case 'event-cycle-return'
            policy=EventCycleReturnPolicy_v3(struct('LegCount',schema.Leg.Count, ...
                'LegNames',{schema.LegNames}));
        case 'BL-marked-apex-return'
            chart=orbit.section_chart;
            if ~isfield(chart,'BL_touchdowns_per_return')
                error('ExportResearchEvidence_v3:UnknownReturnOccurrence', ...
                    'Stored BL-marked chart lacks its touchdown occurrence count.');
            end
            policy=BLMarkedApexReturnPolicy_v3(struct( ...
                'BLTouchdownsPerReturn',chart.BL_touchdowns_per_return));
        case 'first-section-return'
            policy=FirstReturnPolicy_v3();
        case 'iterated-section-return'
            policy=IteratedReturnPolicy_v3(orbit.return_multiplicity);
        otherwise
            error('ExportResearchEvidence_v3:UnsupportedReturnChart', ...
                'Unsupported stored return chart %s.',name);
    end
end

function writeJSON(file,data)
    fid=fopen(file,'w');if fid<0,error('ExportResearchEvidence_v3:Output','Cannot open %s',file);end
    cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(data,'PrettyPrint',true));
end
