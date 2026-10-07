function summary=RunPeriodicSolverValidation_v3(outputDirectory)
%RUNPERIODICSOLVERVALIDATION_V3 Focused numerical gates, not a general suite.
    v3=V3Root_v3(mfilename('fullpath'));
    V3LegacyAddPath_v3(genpath(V3Path_v3(v3)));
    if nargin<1,outputDirectory=fileparts(mfilename('fullpath'));end
    outputDirectory=V3OutputPath_v3(outputDirectory);if ~isfolder(V3Path_v3(outputDirectory)),mkdir(V3Path_v3(outputDirectory));end
    started=tic;p=[10;10;20;20;1;1;0;0;2;.5];q=false(4,1);
    summary=struct('schema_version','focused-periodic-solver-validation-v3-1', ...
        'matlab_version',version,'platform',computer,'started_utc',char(datetime('now','TimeZone','UTC')), ...
        'cases',struct([]),'all_required_gates_passed',false);
    sourceFiles={'Numerics_v3/PeriodicSolutionSolver_v3.m','Numerics_v3/RootSolver_v3.m', ...
        'Orbit_v3/ConstrainedEnergyResidual_v3.m','Orbit_v3/EnergyFamilyResidual_v3.m', ...
        'Simulation_v3/EventDetector_v3.m','Simulation_v3/HybridSimulator_v3.m','Orbit_v3/PoincareMap_v3.m'};
    for k=1:numel(sourceFiles)
        summary.source_hashes(k)=struct('path',sourceFiles{k},'sha256',RoundSHA256_v3(fullfile(v3,sourceFiles{k})));
    end
    fd=HybridFiniteDifferenceJacobian_v3(struct('RelativeCandidateSteps',[3e-5,1e-5], ...
        'MaximumRelativeError',.05));
    options=struct('Symmetry','pronk','MaxWallSeconds',240,'SolverOptions', ...
        struct('Algorithm','newton','MaxIterations',20,'MaxFunctionEvaluations',600,'Jacobian',fd, ...
        'UseBroyden',true,'JacobianRefreshInterval',5));
    x=zeros(14,1);x(3)=1.1;
    pipSeed=struct('state',x,'mode',q,'parameter',p,'return_policy','BL-marked-apex-return', ...
        'occurrence',1,'provenance',struct('kind','analytic-ordinary-PIP','energy',1.1));
    [pip,pipReport]=PeriodicSolutionSolver_v3(pipSeed,options);
    save(V3Path_v3(fullfile(outputDirectory,'case1_pip.mat')),'pip','pipReport','-v7');
    [pk,sourceReport]=QuadrupedalExample_v3(struct('Refine',false));
    pkSeed=struct('state',pk.initial_state,'mode',pk.initial_mode,'parameter',pk.parameter, ...
        'return_policy','BL-marked-apex-return','occurrence',1,'provenance', ...
        struct('kind','imported-PK','source_path',sourceReport.fixture_path,'source_column',1));
    [pkAccepted,pkReport]=PeriodicSolutionSolver_v3(pkSeed,options);
    save(V3Path_v3(fullfile(outputDirectory,'case1_pk.mat')),'pk','pkAccepted','pkReport','sourceReport','-v7');
    addCase('known-PIP-and-PK',pipReport.accepted&&pkReport.accepted, ...
        sprintf('PIP closure %.9g; PK closure %.9g',pipReport.full_closure,pkReport.full_closure));
    perturbed=pkSeed;perturbed.state(2)=perturbed.state(2)+1e-3;
    perturbed.state([7,9,11,13])=perturbed.state([7,9,11,13])+1e-3;
    options2=options;options2.Energy=QuadrupedEnergy_v3.evaluate(pk.initial_state,pk.initial_mode,pk.parameter);
    [corrected,correctionReport]=PeriodicSolutionSolver_v3(perturbed,options2);
    save(V3Path_v3(fullfile(outputDirectory,'case2_actual_correction.mat')),'perturbed','corrected','correctionReport','-v7');
    actual=correctionReport.accepted&&correctionReport.solver.acceptedNewtonIterations>0 ...
        &&correctionReport.initial_scaled_norm>1e-6;
    addCase('meaningful-nonlinear-correction',actual,sprintf('Initial %.9g; final %.9g; accepted Newton iterations %d', ...
        correctionReport.initial_scaled_norm,correctionReport.final_scaled_norm, ...
        value(correctionReport.solver,'acceptedNewtonIterations',0)));
    % Four independent synchronized flight coordinates plus unknown energy.
    reference=[pk.initial_state([2,3,7,8]);options2.Energy];
    historicalBranch=load(V3Path_v3(fullfile(v3,'Research_v3','runs','full','family_-1.mat')),'branch');
    normal=historicalBranch.branch.points(1).tangent(:);normal=normal/norm(normal);
    augmented=options;augmented.FamilyConstraint='arclength';
    augmented.Constraint=struct('reference',reference,'normal',normal,'target',1e-4);
    [arc,arcReport]=PeriodicSolutionSolver_v3(pkSeed,augmented);
    save(V3Path_v3(fullfile(outputDirectory,'case3_arclength.mat')),'arc','arcReport','augmented','-v7');
    augmented.FamilyConstraint='amplitude';augmented.Constraint.normal=[1;0;0;0;0];
    augmented.Constraint.target=-1e-4;
    [daughter,amplitudeReport]=PeriodicSolutionSolver_v3(pkSeed,augmented);
    save(V3Path_v3(fullfile(outputDirectory,'case3_signed_amplitude.mat')),'daughter','amplitudeReport','augmented','-v7');
    addCase('fixed-energy-and-augmented-constraints',correctionReport.accepted&&arcReport.accepted&&amplitudeReport.accepted ...
        &&abs(arcReport.constraint_residual)<1e-8&&abs(amplitudeReport.constraint_residual)<1e-8, ...
        sprintf('Arc residual %.9g; amplitude residual %.9g; these are constrained family corrections, not branch-existence claims.', ...
        arcReport.constraint_residual,amplitudeReport.constraint_residual));
    fixture=fullfile(v3,'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits','SourceFixtures_v3','BD1_20_2_BG.mat');
    source=load(V3Path_v3(fixture));names=fieldnames(source);column=[];variable='';
    for k=1:numel(names),if isnumeric(source.(names{k}))&&size(source.(names{k}),1)==29
            variable=names{k};column=source.(variable)(:,1);break;end,end
    mapped=LegacyStateAdapter_v3.toV3Unknown(column(1:13));
    [physical,conversion]=LegacyParameterAdapter_v3.toV3(column(23:29),'v2-exact');
    failedSeed=struct('state',[0;mapped],'mode',q,'parameter',physical, ...
        'return_policy','BL-marked-apex-return','occurrence',1, ...
        'provenance',struct('kind','legacy-source-conversion','source_path',fixture,'variable',variable,'column',1));
    save(V3Path_v3(fullfile(outputDirectory,'case4_converted_before_replay.mat')),'failedSeed','column','conversion','-v7');
    failedOptions=options;failedOptions.Symmetry='none';failedOptions.MaxWallSeconds=90;
    [failedSolution,failedReport]=PeriodicSolutionSolver_v3(failedSeed,failedOptions);
    save(V3Path_v3(fullfile(outputDirectory,'case4_failed_imported.mat')),'failedSolution','failedReport','-v7');
    addCase('failed-imported-seed-preserved',~failedReport.accepted&&~isempty(failedReport.final_candidate) ...
        &&~isempty(fieldnames(failedReport.primary_failure)) ...
        &&isfield(failedReport.partial_evidence,'failure_trace'),failureText(failedReport));
    old=load(V3Path_v3(fullfile(v3,'Research_v3','runs','full','parent_attempt_1.mat')));
    oldSummary=struct('residual_norm',old.info.residualNorm,'exitflag',old.info.exitflag, ...
        'message',old.info.message,'output',old.info.output,'accepted_iterations',old.info.acceptedNewtonIterations, ...
        'jacobian_reliable',old.info.jacobianReliable,'per_column_reliability',old.info.perColumnReliability, ...
        'invalid_evaluations',old.info.invalidEvaluationCount,'map_evaluations',old.info.mapEvaluationCount);
    simulator=HybridSimulator_v3();map=PoincareMap_v3(Quadrupedal_Dynamics_v3(),PoincareSection_v3.apex(4),simulator,EventCycleReturnPolicy_v3());
    base=PeriodicOrbitResidual_v3(map,zeros(14,1));family=EnergyFamilyResidual_v3(base,x,q,p);
    root=RootSolver_v3(struct('Algorithm','newton','MaxIterations',5,'MaxFunctionEvaluations',500, ...
        'MaxWallSeconds',120,'FunctionTolerance',1e-8,'ResidualAcceptanceTolerance',1e-7, ...
        'Jacobian',HybridFiniteDifferenceJacobian_v3(struct('RelativeCandidateSteps',[3e-4,1e-4]))));
    [parentCandidate,reproduced]=root.solve(family,family.packState(old.guess),[p;1.1],q);
    save(V3Path_v3(fullfile(outputDirectory,'case5_parent_failure_reproduced.mat')),'oldSummary','parentCandidate','reproduced','-v7');
    % Find an actual numerical candidate in the former reduced/full gap.
    pkMap=PoincareMap_v3(Quadrupedal_Dynamics_v3(),PoincareSection_v3.apex(4),HybridSimulator_v3(), ...
        BLMarkedApexReturnPolicy_v3());
    pkProblem=PeriodicOrbitResidual_v3(pkMap,pk.initial_state);
    pkFamily=EnergyFamilyResidual_v3(pkProblem,pk.initial_state,pk.initial_mode,pk.parameter,struct('Symmetry','pronk'));
    gap=struct('found',false);
    for magnitude=[1e-8,3e-8,1e-7,3e-7]
        trial=pk.initial_state;trial(2)=trial(2)+magnitude;
        [reduced,details]=pkFamily.evaluateWithInfo(pkFamily.packState(trial),[pk.parameter;options2.Energy],pk.initial_mode);
        if norm(reduced,inf)<=1e-7&&details.full_physical_closure_norm>1e-8
            gap=struct('found',true,'state',trial,'magnitude',magnitude,'reduced',reduced,'details',details);break;end
    end
    if gap.found
        oldThresholdRoot=RootSolver_v3(struct('ResidualAcceptanceTolerance',1e-7));
        [~,gapLegacy]=oldThresholdRoot.solve(pkFamily,pkFamily.packState(gap.state),[pk.parameter;options2.Energy],pk.initial_mode);
        gapSeed=pkSeed;gapSeed.state=gap.state;
        [gapCorrected,gapReport]=PeriodicSolutionSolver_v3(gapSeed,options2);
    else,gapLegacy=struct();gapCorrected=[];gapReport=struct('accepted',false);end
    save(V3Path_v3(fullfile(outputDirectory,'case5_tolerance_gap.mat')),'gap','gapLegacy','gapCorrected','gapReport','-v7');
    preserved=~reproduced.converged&&~isempty(reproduced.primaryMessage) ...
        &&~strcmp(reproduced.primaryErrorIdentifier,'EnergyFamilyResidual_v3:FullClosure') ...
        &&isempty(reproduced.orbit);
    addCase('tolerance-gap-and-primary-finalization',preserved&&gap.found&&gapReport.accepted ...
        &&gapLegacy.primaryConverged&&~gapLegacy.converged, ...
        sprintf('Historical accepted Newton iterations %d, map evaluations %d; reproduced primary: %s; full closure secondary: %s', ...
        oldSummary.accepted_iterations,oldSummary.map_evaluations,reproduced.primaryMessage,reproduced.finalizationMessage));
    ValidateMarkedOccurrence_v3(outputDirectory);
    current=load(V3Path_v3(fullfile(outputDirectory,'solver_validation_summary.mat')),'summary');summary=current.summary;
    summary.all_required_gates_passed=all([summary.cases.passed]);summary.elapsed_seconds=toc(started);
    summary.finished_utc=char(datetime('now','TimeZone','UTC'));writeSummary();
    function addCase(name,passed,evidence)
        item=struct('name',name,'passed',logical(passed),'evidence',evidence);
        if isempty(summary.cases),summary.cases=item;else,summary.cases(end+1)=item;end
        fprintf('SOLVER GATE %s: %d %s\n',name,passed,evidence);writeSummary();
    end
    function writeSummary()
        save(V3Path_v3(fullfile(outputDirectory,'solver_validation_summary.mat')),'summary','-v7');
        f=fopen(V3Path_v3(fullfile(outputDirectory,'solver_validation_summary.json')),'w');c=onCleanup(@()fclose(f));
        fprintf(f,'%s\n',jsonencode(summary,'PrettyPrint',true));
    end
end
function result=value(data,name,fallback)
    result=fallback;if isfield(data,name),result=data.(name);end
end
function text=failureText(report)
    if ~isempty(fieldnames(report.primary_failure)),text=report.primary_failure.message;
    else,text=report.replay_failure.message;end
end
