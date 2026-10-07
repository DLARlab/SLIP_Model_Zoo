function report = RunResearchCampaign_v3(stage, configFile, outputDirectory)
%RUNRESEARCHCAMPAIGN_V3 Dependency-ordered, checkpointed physical studies.
% Each stage is also callable independently. Configuration is registered
% before execution; imported-seed comparisons never establish graph edges.
    v3=V3Root_v3(mfilename('fullpath'));
    originalPath=path;restore=onCleanup(@() path(originalPath)); %#ok<NASGU>
    folders={'Schema_v3','Adapters_v3','Dynamics_v3','Simulation_v3', ...
        'Orbit_v3','Numerics_v3','Stability_v3','Graphics_v3','Examples_v3'};
    for i=1:numel(folders),V3LegacyAddPath_v3(fullfile(v3,folders{i}));end
    configFile=canonicalWithin(v3,configFile);
    outputDirectory=canonicalWithin(v3,outputDirectory);
    if ~isfolder(V3Path_v3(outputDirectory)),mkdir(V3Path_v3(outputDirectory));end
    cfg=jsondecode(fileread(V3Path_v3(configFile)));rng(cfg.seed,'twister');
    started=tic;
    report=struct('schema_version','research-evidence-v3-1','stage',char(stage), ...
        'model_id',cfg.model_id,'config',cfg,'matlab_version',version, ...
        'started_utc',char(datetime('now','TimeZone','UTC')), ...
        'status','running','elapsed_seconds',0);
    writeJSON(fullfile(outputDirectory,[char(stage),'.json']),report);
    switch char(stage)
        case 'inventory'
            report.release=version('-release');report.platform=computer;
            report.toolboxes=ver;report.licenses=license('inuse');
            report.cpu_cores=feature('numcores');
            report.reference_archive_present=isfile(V3Path_v3(fullfile(fileparts(v3), ...
                'SLIP_Quadruped','P2_Numerical_Run_Archive','P2_original_layout_20261007.tar.gz')));
            report.status='completed';
        case 'compatibility'
            manifest=jsondecode(fileread(V3Path_v3(fullfile(v3,'Research_v3','baseline', ...
                'source_fixture_manifest.json'))));
            observations=struct([]);
            for k=1:numel(manifest.records)
                source=manifest.records(k);file=fullfile(v3,source.fixture_path);
                [data,variable]=fixtureArray(file);
                columns=unique(round(linspace(1,size(data,2),cfg.budgets.fixture_columns_per_family)));
                for column=columns
                    entry=struct('source',source,'variable',variable,'column',column, ...
                        'legacy_period',NaN,'physical_parameter',[],'initial_state',[], ...
                        'initial_mode',[],'status','rejected','reason','', ...
                        'residual_norm',NaN,'detected_period',NaN, ...
                        'events',struct([]),'scheduled_events',struct([]), ...
                        'first_divergence',struct(),'classification',struct());
                    try
                        old=data(:,column);[x,p,q,schedule]=convertFixture(old,cfg);
                        entry.initial_state=x;entry.physical_parameter=p;entry.initial_mode=q;
                        entry.legacy_period=old(22);entry.scheduled_events=schedule;
                        f=framework(cfg);
                        [~,details]=f.problem.evaluateWithInfo(f.problem.packState(x),p,q);
                        entry.residual_norm=details.residual_norm;
                        entry.detected_period=details.map_info.period;
                        entry.events=eventSummary(details.map_info.event_history);
                        entry.first_divergence=firstDivergence(schedule,entry.events,1e-6);
                        entry.status='replayed_nonperiodic';
                        if details.admissible && entry.residual_norm<=1e-8
                            orbit=f.problem.createOrbit(f.problem.packState(x),p,q,details);
                            if exist(V3Path_v3('GaitIdentification_v3'),'file')
                                entry.classification=GaitIdentification_v3(orbit);
                            end
                            entry.status='accepted_autonomous_seed';
                            fixtureArtifact=fullfile(outputDirectory,sprintf('fixture_%02d_%05d.mat',k,column));
                            save(V3Path_v3(fixtureArtifact),'orbit','details','source','column','-v7');
                        end
                        converted=struct('state',x,'parameter',p,'mode',q, ...
                            'source',source,'column',column,'scheduled_events_diagnostic_only',schedule);
                        convertedPath=fullfile(v3,source.study,'ConvertedSeeds_v3', ...
                            sprintf('%s_column_%05d.mat',erase(string(fileName(file)),'.mat'),column));
                        save(V3Path_v3(convertedPath),'converted');
                    catch ex
                        entry.reason=sprintf('%s: %s',ex.identifier,ex.message);
                    end
                    if isempty(observations),observations=entry;
                    else,observations(end+1)=entry;end %#ok<AGROW>
                    report.observations=observations;
                    writeJSON(fullfile(outputDirectory,'compatibility.json'),report);
                    fprintf('Fixture %s column %d: %s %.3g %s\n',fileName(file),column, ...
                        entry.status,entry.residual_norm,entry.reason);
                    if toc(started)>cfg.budgets.total_wall_seconds
                        report.status='budget_exhausted';break
                    end
                end
                if strcmp(report.status,'budget_exhausted'),break;end
            end
            report.observations=observations;
            report.accepted_seed_count=sum(strcmp({observations.status},'accepted_autonomous_seed'));
            if ~strcmp(report.status,'budget_exhausted'),report.status='completed';end
        case 'vertical'
            p=cfg.baseline_v3_parameters(:);f=framework(cfg);
            energies=linspace(cfg.domain.energy(1),cfg.domain.energy(2),12);
            points=struct([]);
            for E=energies
                x=zeros(14,1);x(3)=E;q=false(4,1);
                [~,d]=f.problem.evaluateWithInfo(f.problem.packState(x),p,q);
                v=sqrt(2*(E-1));w=sqrt(40);theta=atan2(v/w,1/40);
                expected=(2*pi-2*theta)/w+2*v;
                orbit=f.problem.createOrbit(f.problem.packState(x),p,q,d);
                states=d.map_info.trajectory.state;modes=d.map_info.trajectory.mode;
                energyValues=zeros(size(states,1),1);
                for j=1:size(states,1)
                    energyValues(j)=QuadrupedEnergy_v3.evaluate(states(j,:).',modes(j,:).',p);
                end
                point=struct('energy',E,'period',orbit.period,'analytic_period',expected, ...
                    'period_error',abs(orbit.period-expected),'closure',d.residual_norm, ...
                    'energy_range',max(energyValues)-min(energyValues), ...
                    'delayed_first_LO_obstruction',2*pi/w,'classification',struct());
                if exist(V3Path_v3('GaitIdentification_v3'),'file'),point.classification=GaitIdentification_v3(orbit);end
                if isempty(points),points=point;else,points(end+1)=point;end %#ok<AGROW>
                save(V3Path_v3(fullfile(outputDirectory,sprintf('vertical_%02d.mat',numel(points)))),'orbit','point');
            end
            report.points=points;report.max_period_error=max([points.period_error]);
            report.max_closure=max([points.closure]);report.max_energy_range=max([points.energy_range]);
            report.status='completed';
        case 'fixed_family'
            [orbit,~,f]=QuadrupedalExample_v3(struct('Refine',false));
            report.seed_kind='imported PK seed; no root ancestry assigned';
            report.physical_parameter=orbit.parameter;
            report.runs=struct([]);
            solver=RootSolver_v3(struct('MaxIterations',cfg.budgets.root_max_iterations, ...
                'MaxFunctionEvaluations',cfg.budgets.root_max_function_evaluations, ...
                'FunctionTolerance',1e-9,'ResidualAcceptanceTolerance',1e-8, ...
                'Jacobian',HybridFiniteDifferenceJacobian_v3(struct( ...
                'RelativeCandidateSteps',[3e-4,1e-4],'MaximumRelativeError',.01))));
            for direction=[-1,1]
                checkpoint=fullfile(outputDirectory,sprintf('family_%+d.mat',direction));
                previous=struct('points',[]);seedOrbit=orbit;
                if isfile(V3Path_v3(checkpoint))
                    loaded=load(V3Path_v3(checkpoint),'branch');previous=loaded.branch;
                    if ~isempty(previous.points)
                        seedOrbit=previous.points(end).orbit;
                        [~,replay]=f.residual.evaluateWithInfo( ...
                            f.residual.packState(seedOrbit.initial_state),seedOrbit.parameter,seedOrbit.initial_mode);
                        if ~replay.admissible || replay.residual_norm>1e-8
                            error('RunResearchCampaign_v3:ResumeReplay','Saved point failed current-model replay.');
                        end
                    end
                end
                remaining=cfg.budgets.fixed_parameter_points_per_direction;
                if ~isempty(previous.points)
                    remaining=max(1,remaining-numel(previous.points)+1);
                end
                options=struct('Symmetry','pronk','RootSolver',solver, ...
                    'Jacobian',solver.Jacobian, ...
                    'StepSize',.003,'MinimumStepSize',1e-5,'MaximumStepSize',.01, ...
                    'MaxPoints',remaining, ...
                    'InitialDirection',direction,'ParameterBounds',cfg.domain.energy.', ...
                    'MaxWallSeconds',cfg.budgets.continuation_wall_seconds, ...
                    'CheckpointFunction',@(branch) saveCheckpoint(checkpoint,mergeBranches(previous,branch)));
                if ~isempty(previous.points),options.InitialTangent=previous.points(end).tangent;end
                run=struct('direction',direction,'status','unresolved','reason','', ...
                    'accepted_count',0,'max_full_closure',NaN,'energy',[]);
                try
                    [branch,~]=FixedParameterContinuation_v3.run(f.residual, ...
                        f.residual.packState(seedOrbit.initial_state),seedOrbit.parameter,seedOrbit.initial_mode,options);
                    branch=mergeBranches(previous,branch);
                    branch.energy=arrayfun(@(point) point.p(11),branch.points);
                    classifications=cell(1,numel(branch.points));
                    for j=1:numel(branch.points)
                        if exist(V3Path_v3('GaitIdentification_v3'),'file')
                            classifications{j}=GaitIdentification_v3(branch.points(j).orbit);
                        end
                    end
                    branch=CompactResearchBranch_v3(branch);
                    temporary=[checkpoint,'.partial.mat'];
                    % Compact branch variables are below the MAT v7 limit.
                    % Lossless v7 compression avoids repeated HDF5 struct overhead.
                    save(V3Path_v3(temporary),'branch','classifications','-v7');
                    movefile(V3Path_v3(temporary),V3Path_v3(checkpoint),'f');
                    run.status='completed_bounded_branch';run.reason=branch.terminationReason;
                    run.accepted_count=numel(branch.points);run.energy=branch.energy;
                    run.max_full_closure=max(arrayfun(@(pt) norm( ...
                        pt.orbit.poincare_state(2:end)-pt.orbit.initial_state(2:end),inf),branch.points));
                catch ex
                    run.reason=sprintf('%s: %s',ex.identifier,ex.message);
                end
                if isempty(report.runs),report.runs=run;else,report.runs(end+1)=run;end
            end
            report.status='completed';
        case 'parent_only'
            % Freeze predictions before loading any held-out daughter data.
            p=cfg.baseline_v3_parameters(:);x=zeros(14,1);x(3)=1.1;q=false(4,1);
            f=framework(cfg);[~,base]=f.problem.evaluateWithInfo(f.problem.packState(x),p,q);
            parent=f.problem.createOrbit(f.problem.packState(x),p,q,base);
            s=QuadrupedSchema_v3.shared();
            front=zeros(14,1);front(s.Leg.AngleIndices(3))=1;front(s.Leg.AngleIndices(4))=-1;
            hind=zeros(14,1);hind(s.Leg.AngleIndices(1))=1;hind(s.Leg.AngleIndices(2))=-1;
            forehind=zeros(14,1);forehind(s.Leg.AngleIndices(1:2))=1;forehind(s.Leg.AngleIndices(3:4))=-1;
            predictions=struct('parent_state',x,'parameter',p,'directions',[front,hind,forehind], ...
                'origin','symmetry sectors; candidates only, no critical eigenvector claim', ...
                'frozen_utc',char(datetime('now','TimeZone','UTC')),'held_out_data_used',false);
            save(V3Path_v3(fullfile(outputDirectory,'parent_predictions_frozen.mat')),'predictions','parent');
            report.predictions=predictions;report.attempts=struct([]);
            solver=RootSolver_v3(struct('MaxIterations',min(5,cfg.budgets.root_max_iterations), ...
                'MaxFunctionEvaluations',min(500,cfg.budgets.root_max_function_evaluations), ...
                'FunctionTolerance',1e-8,'ResidualAcceptanceTolerance',1e-7));
            for k=1:min(cfg.budgets.alternative_seed_count,6)
                sector=ceil(k/2);signValue=2*mod(k,2)-1;
                guess=x+signValue*1e-3*predictions.directions(:,sector);
                trial=struct('sector',sector,'sign',signValue,'converged',false,'reason','', ...
                    'distance_to_parent',NaN,'residual',NaN,'network_edge',false);
                try
                    family=EnergyFamilyResidual_v3(f.problem,x,q,p);
                    [u,info]=solver.solve(family,family.packState(guess),[p;1.1],q);
                    trial.converged=info.converged;trial.reason=info.message;
                    trial.residual=info.residualNorm;
                    trial.distance_to_parent=norm(family.fullState(u)-x);
                    save(V3Path_v3(fullfile(outputDirectory,sprintf('parent_attempt_%d.mat',k))),'info','u','guess');
                catch ex,trial.reason=sprintf('%s: %s',ex.identifier,ex.message);end
                if isempty(report.attempts),report.attempts=trial;else,report.attempts(end+1)=trial;end
                writeJSON(fullfile(outputDirectory,'parent_only.json'),report);
            end
            report.status='completed_bounded_search';
            report.connection_status='No branch edge is certified by this search.';
        case 'floquet'
            [orbit,~,f]=QuadrupedalExample_v3(struct('Refine',false));
            analyzer=FloquetAnalysis_v3(struct('RelativeStep',3e-4));
            full=analyzer.analyzeOrbit(f.map,orbit);
            save(V3Path_v3(fullfile(outputDirectory,'full_floquet.mat')),'full','-v7');
            report.unrestricted=struct('reliable',full.reliable,'warning',full.warning, ...
                'multipliers_real',real(full.multipliers),'multipliers_imag',imag(full.multipliers), ...
                'dimension',full.physicalCoordinateDimension);
            report.status='completed';
        case 'pip_pk_local'
            report=DiscoverPronkFromPIP_v3(configFile,outputDirectory);
        otherwise
            error('RunResearchCampaign_v3:Stage','Unknown campaign stage %s.',stage);
    end
    report.elapsed_seconds=toc(started);
    report.finished_utc=char(datetime('now','TimeZone','UTC'));
    writeJSON(fullfile(outputDirectory,[char(stage),'.json']),report);
    save(V3Path_v3(fullfile(outputDirectory,[char(stage),'_report.mat'])),'report','-v7');
end

function f=framework(cfg)
    system=Quadrupedal_Dynamics_v3();s=QuadrupedSchema_v3.shared();
    simulator=HybridSimulator_v3(struct('RelTol',cfg.integration.relative_tolerance, ...
        'AbsTol',cfg.integration.absolute_tolerance));
    section=PoincareSection_v3.apex(s.State.dy);
    map=PoincareMap_v3(system,section,simulator,EventCycleReturnPolicy_v3(), ...
        struct('MaxReturnTime',cfg.domain.primitive_period_max, ...
        'MaxCycleEvents',cfg.domain.event_count_max,'MaxSectionCrossings',16));
    f=struct('system',system,'simulator',simulator,'map',map, ...
        'problem',PeriodicOrbitResidual_v3(map,zeros(s.State.Dimension,1)));
end

function [array,name]=fixtureArray(file)
    data=load(V3Path_v3(file));names=fieldnames(data);name='';
    for k=1:numel(names)
        value=data.(names{k});
        if isnumeric(value) && size(value,1)==29 && size(value,2)>0
            if strcmp(names{k},'results'),name=names{k};break;end
            if isempty(name),name=names{k};end
        end
    end
    if isempty(name),error('RunResearchCampaign_v3:FixtureFormat','No 29-row fixture array.');end
    array=data.(name);
end

function [x,p,q,schedule]=convertFixture(old,cfg)
    s=QuadrupedSchema_v3.shared();x=zeros(s.State.Dimension,1);
    x(s.Root.UnknownIndices)=LegacyStateAdapter_v3.toV3Unknown(old(1:13));
    p=LegacyParameterAdapter_v3.toV3(old(23:29),cfg.legacy_parameter_policy);
    ids=LegacyEventAdapter_v3.toV3(1:8);times=old(14:21);
    schedule=repmat(struct('type','','time',0),1,8);
    for j=1:8,schedule(j)=struct('type',s.Event.Names{ids(j)},'time',times(j));end
    [~,order]=sort(times);schedule=schedule(order);
    oldMode=times([2,4,6,8])<times([1,3,5,7]);q=LegacyModeAdapter_v3.toV3(oldMode);
end

function summary=eventSummary(history)
    summary=struct('type',{},'time',{});
    for k=1:numel(history)
        if any(endsWith(string(history(k).type),["_TD","_LO"]))
            summary(end+1)=struct('type',char(history(k).type),'time',history(k).time); %#ok<AGROW>
        end
    end
end

function divergence=firstDivergence(scheduled,actual,tol)
    divergence=struct('found',false,'index',NaN,'scheduled',struct(), ...
        'actual',struct(),'reason','');
    scheduled=clusterEvents(scheduled,tol);actual=clusterEvents(actual,tol);
    for k=1:max(numel(scheduled),numel(actual))
        if k>numel(scheduled)||k>numel(actual)
            divergence.found=true;divergence.index=k;divergence.reason='event count differs';break
        end
        if ~strcmp(scheduled(k).type,actual(k).type)||abs(scheduled(k).time-actual(k).time)>tol
            divergence.found=true;divergence.index=k;divergence.scheduled=scheduled(k);
            divergence.actual=actual(k);divergence.reason='first event name/time divergence';break
        end
    end
end

function clusters=clusterEvents(events,tolerance)
    clusters=struct('type',{},'time',{});
    if isempty(events),return;end
    [~,order]=sort([events.time]);events=events(order);start=1;
    while start<=numel(events)
        last=start;
        while last<numel(events) && events(last+1).time-events(start).time<=tolerance,last=last+1;end
        clusters(end+1)=struct('type',strjoin(sort({events(start:last).type}),'&'), ...
            'time',mean([events(start:last).time])); %#ok<AGROW>
        start=last+1;
    end
end

function writeJSON(file,value)
    fid=fopen(V3Path_v3(file),'w');if fid<0,error('RunResearchCampaign_v3:Write','Cannot open %s.',file);end
    cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
function saveCheckpoint(file,branch)
    branch=CompactResearchBranch_v3(branch);
    temporary=[file,'.partial.mat'];
    save(V3Path_v3(temporary),'branch','-v7');
    movefile(V3Path_v3(temporary),V3Path_v3(file),'f');
end
function branch=mergeBranches(previous,branch)
    if isempty(previous.points),return;end
    newer=branch.points;
    if numel(newer)>1
        offset=previous.points(end).arclength;
        for k=2:numel(newer)
            newer(k).index=numel(previous.points)+k-1;
            newer(k).arclength=newer(k).arclength+offset;
        end
        branch.points=[previous.points,newer(2:end)];
    else,branch.points=previous.points;end
    branch.count=numel(branch.points);
    branch.failures=[previous.failures,branch.failures];
    branch=PseudoArclengthContinuation_v3().refreshBranchSummary(branch);
    branch.resume_note='Previous accepted points retained; latest point replayed before resuming.';
end
function name=fileName(file)
    [~,name,ext]=fileparts(file);name=[name,ext];
end
function target=canonicalWithin(v3,file)
    target=char(java.io.File(char(file)).getCanonicalPath());
    root=char(java.io.File(v3).getCanonicalPath());
    if ~startsWith(target,[root,filesep])
        error('RunResearchCampaign_v3:OutsideV3','All paths must resolve within v3.');
    end
end
