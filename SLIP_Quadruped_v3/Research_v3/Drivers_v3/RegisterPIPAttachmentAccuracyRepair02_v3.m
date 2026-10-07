function registration=RegisterPIPAttachmentAccuracyRepair02_v3(sourceTaskId,outputDirectory)
%REGISTERPIPATTACHMENTACCURACYREPAIR02_V3 Opt/step revision, no driver edits/maps.
% The unchanged native driver copies the frozen runtime-options template,
% retaining explicitly supplied OptimalityTolerance and StepTolerance.
    v3=V3Root_v3(mfilename('fullpath'));
    assert(any(strcmp(sourceTaskId,{'PIP_candidate_1','PIP_PK_low_energy_neighborhood'})));
    if nargin<2,outputDirectory=fullfile(v3,'Research_v3/next_round/solver/attachment_accuracy_repair_02',sourceTaskId);end
    outputDirectory=V3OutputPath_v3(outputDirectory);if ~isfolder(V3Path_v3(outputDirectory)),mkdir(V3Path_v3(outputDirectory));end
    assert(~isfile(V3Path_v3(fullfile(outputDirectory,'registration.json')))&&~isfile(V3Path_v3(fullfile(outputDirectory,'input_snapshot.mat'))));
    previousPath=fullfile('Research_v3/next_round/solver/attachment_accuracy_repair',sourceTaskId,'registration.json');
    previous=jsondecode(fileread(V3Path_v3(fullfile(v3,previousPath))));
    for items={previous.source_hashes,previous.canonical_source_hashes,previous.physical_model_hashes,previous.original_records}
        hashes=items{1};
        for k=1:numel(hashes)
            assert(V3HashMatches_v3(hashes(k).sha256, fullfile(v3,hashes(k).path)), ...
                'RegisterPIPAttachmentAccuracyRepair02_v3:SourceEpoch','Source or original daughter changed: %s.',hashes(k).path);
        end
    end
    assert(V3HashMatches_v3(previous.canonical_gate_sha256, fullfile(v3,previous.canonical_gate)) ...
        &&V3HashMatches_v3(previous.candidate.snapshot_sha256, fullfile(v3,previous.candidate.input_snapshot)));
    original=load(V3Path_v3(fullfile(v3,previous.candidate.input_snapshot)));
    failedPath=fullfile('Research_v3/next_round/tasks/full',previous.candidate.id,'accuracy_repair_r000_attempt_001.mat');
    failed=load(V3Path_v3(fullfile(v3,failedPath)),'report');failedReport=failed.report;
    assert(~failedReport.accepted&&failedReport.solver.primaryExitflag==3 ...
        &&contains(failedReport.primary_failure.message,'First-order optimality tolerance satisfied.') ...
        &&isempty(fieldnames(failedReport.replay_failure))&&isempty(fieldnames(failedReport.finalization_failure)));
    coordinates=failedReport.final_coordinates(:);initialJ=failedReport.solver.finalJacobian;
    assert(numel(coordinates)==5&&isequal(size(initialJ),[5,5])&&all(isfinite(initialJ(:))));
    runtimeOptions=failedReport.options;
    runtimeOptions.SolverOptions.OptimalityTolerance=1e-18;
    runtimeOptions.SolverOptions.StepTolerance=1e-13;
    runtimeOptions.SolverOptions.ResidualAcceptanceTolerance=1e-12;
    runtimeOptions.SolverOptions.FunctionTolerance=1e-13;
    assert(isequal(runtimeOptions.Constraint,original.originalReport.options.Constraint) ...
        &&isequal(failedReport.acceptance,original.originalReport.acceptance));
    seed=original.seed;seed.state=failedReport.final_candidate;
    seed.provenance.previous_accuracy_repair_artifact=failedPath;
    % This is only a labelled option template required by the unchanged
    % driver interface. Untouched measured reports are saved separately.
    originalReport=struct('options',runtimeOptions,'option_template_only',true);
    originalAcceptedReport=original.originalReport;originalRecord=original.originalRecord;originalEntry=original.originalEntry;
    inputFile=fullfile(outputDirectory,'input_snapshot.mat');
    RoundSave_v3(inputFile,struct('originalReport',originalReport,'originalAcceptedReport',originalAcceptedReport, ...
        'failedReport',failedReport,'originalRecord',originalRecord,'originalEntry',originalEntry, ...
        'seed',seed,'coordinates',coordinates,'initialJ',initialJ,'runtimeOptions',runtimeOptions));
    candidate=previous.candidate;candidate.id=[candidate.id,'_revision02'];
    candidate.method_registration=relative(fullfile(outputDirectory,'registration.json'));
    candidate.input_snapshot=relative(inputFile);candidate.snapshot_sha256=RoundSHA256_v3(inputFile);
    r=failedReport.solver.residual(:);step=-initialJ\r;gradient=initialJ.'*r;
    registration=previous;registration.schema_version='prospective-PIP-attachment-accuracy-repair-v3-2';
    registration.registered_utc=char(datetime('now','TimeZone','UTC'));registration.candidate=candidate;
    registration.previous_registration=previousPath;registration.previous_registration_sha256=RoundSHA256_v3(fullfile(v3,previousPath));
    registration.previous_failed_artifact=failedPath;registration.previous_failed_artifact_sha256=RoundSHA256_v3(fullfile(v3,failedPath));
    newSource='Research_v3/Drivers_v3/RegisterPIPAttachmentAccuracyRepair02_v3.m';
    registration.source_hashes(end+1)=struct('path',newSource,'sha256',RoundSHA256_v3(fullfile(v3,newSource)));
    registration.driver_function='RunPIPAttachmentAccuracyRepair_v3';registration.active_wrapper_changed=false;
    driverPath='Research_v3/Drivers_v3/RunPIPAttachmentAccuracyRepair_v3.m';
    driverSnapshot=fullfile(outputDirectory,'driver_source_snapshot.txt');copyfile(V3Path_v3(fullfile(v3,driverPath)),V3Path_v3(driverSnapshot));
    registration.driver_source_snapshot=relative(driverSnapshot);
    registration.driver_source_snapshot_sha256=RoundSHA256_v3(driverSnapshot);
    registration.accuracy_revision=2;registration.root_optimality_tolerance=1e-18;registration.root_step_tolerance=1e-13;
    registration.initial_residual=failedReport.final_scaled_norm;registration.initial_J_source=failedPath;
    registration.initial_J_available=true;registration.initial_J_newly_evaluated_in_previous_attempt=failedReport.solver.derivativeEvaluated;
    registration.initial_J_condition_estimate=cond(initialJ);registration.remaining_linear_step_estimate=step;
    registration.actual_previous_firstorderopt=failedReport.solver.output.firstorderopt;
    registration.previous_J_transpose_r=gradient;registration.previous_J_transpose_r_inf=norm(gradient,inf);
    registration.previous_primary_failure=failedReport.primary_failure;
    registration.diagnosis='Revision01 stopped at first-order optimality1e-14 while the stricter residual gate remained unsatisfied; no independent replay or finalization failure occurred.';
    registration.revision_scope='Explicit Opt1e-18 and Step1e-13 inherited from frozen runtime options by the unchanged driver; same Resid1e-12/Function1e-13, model, damping, amplitude, free E and physical acceptance.';
    registration.runtime_template_policy='originalReport is an explicitly labelled options-only interface template; untouched accepted and failed measured reports are retained separately.';
    registration.cost_policy='New task ID and output checkpoint; previous measured wall/evaluation costs remain charged only to revision01.';
    registration.return_map_evaluations=0;registration.correction_executed=false;registration.active_campaign_modified=false;
    RoundSave_v3(fullfile(outputDirectory,'registration.mat'),struct('registration',registration));
    RoundJSON_v3(fullfile(outputDirectory,'registration.json'),registration);
    function path=relative(file),path=strrep(file,[v3,filesep],'');end
end
