function summary=PublishSolverValidationGate_v3(validationDirectory)
%PUBLISHSOLVERVALIDATIONGATE_V3 Publish only completed current-source gates.
    output=fileparts(mfilename('fullpath'));v3=fileparts(fileparts(fileparts(output)));V3LegacyAddPath_v3(genpath(V3Path_v3(v3)));
    loaded=load(V3Path_v3(fullfile(validationDirectory,'solver_validation_summary.mat')),'summary');summary=loaded.summary;
    diagnostic=load(V3Path_v3(fullfile(validationDirectory,'diagnostic_failure_schema_gate.mat')),'summary');
    assert(summary.all_required_gates_passed&&all([summary.cases.passed])&&diagnostic.summary.passed, ...
        'Publish only after every mandatory and diagnostic gate passes.');
    for k=1:numel(summary.source_hashes)
        assert(V3HashMatches_v3(summary.source_hashes(k).sha256, fullfile(v3,summary.source_hashes(k).path)), ...
            'A validated source changed before publication.');
    end
    assert(strcmp(diagnostic.summary.HybridSimulator_sha256, ...
        RoundSHA256_v3(fullfile(v3,'Simulation_v3','HybridSimulator_v3.m'))));
    assert(strcmp(diagnostic.summary.PoincareMap_sha256, ...
        RoundSHA256_v3(fullfile(v3,'Orbit_v3','PoincareMap_v3.m'))));
    summary.cases(end+1)=struct('name','failed-map-diagnostic-schema-preserved','passed',true, ...
        'evidence','Diagnostic failure returns stop_occurred=false; the Poincare map preserves original TensileStance identifier/message and a simulator-report cause.');
    summary.validation_artifact_directory=validationDirectory;
    summary.diagnostic_failure_schema=diagnostic.summary;
    summary.canonical_published_utc=char(datetime('now','TimeZone','UTC'));
    files=V3Dir_v3(fullfile(validationDirectory,'case*.mat'));
    for k=1:numel(files),copyfile(V3Path_v3(fullfile(files(k).folder,files(k).name)),V3Path_v3(fullfile(output,files(k).name)));end
    copyfile(V3Path_v3(fullfile(validationDirectory,'diagnostic_failure_schema_gate.mat')),V3Path_v3(fullfile(output,'diagnostic_failure_schema_gate.mat')));
    copyfile(V3Path_v3(fullfile(validationDirectory,'diagnostic_failure_schema_gate.json')),V3Path_v3(fullfile(output,'diagnostic_failure_schema_gate.json')));
    save(V3Path_v3(fullfile(output,'solver_validation_summary.mat')),'summary','-v7');
    RoundJSON_v3(fullfile(output,'solver_validation_summary.json'),summary);disp(summary);
end
