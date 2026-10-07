function summary=ExportTwistedFrontPilot_v3()
%EXPORTTWISTEDFRONTPILOT_V3 Clarify correction/replay evidence without rerun.
    v3=V3Root_v3(mfilename('fullpath'));V3LegacyAddPath_v3(genpath(V3Path_v3(v3)));
    folder=fullfile(fileparts(mfilename('fullpath')),'twisted_return');file=fullfile(folder,'pilot.mat');
    loaded=load(V3Path_v3(file));report=loaded.report;summary=loaded.summary;
    if isfield(summary,'fresh_full_BL2_closure')
        summary.correction_full_BL2_closure=summary.fresh_full_BL2_closure;
        summary=rmfield(summary,'fresh_full_BL2_closure');
    end
    if isfield(summary,'actual_map_evaluations')
        summary.core_objective_map_count=summary.actual_map_evaluations;
        summary=rmfield(summary,'actual_map_evaluations');
    end
    summary.independent_BL2_replay_performed=~isempty(fieldnames(report.independent_replay));
    root=report.solver;fd=root.jacobianDiagnostics;
    diagnostic=struct('service_wall_budget',report.options.MaxWallSeconds, ...
        'root_budget_qualification','Service subtracts initial-evaluation time before constructing RootSolver; exact remaining root value is not serialized.', ...
        'core_function_evaluation_count',root.functionEvaluationCount, ...
        'core_objective_map_count',root.mapEvaluationCount,'cache_hits',root.cacheHitCount, ...
        'invalid_evaluation_count',root.invalidEvaluationCount, ...
        'Jacobian_evaluation_count',root.jacobianEvaluationCount, ...
        'Newton_iterations',root.output.iterations,'accepted_Newton_iterations',root.acceptedNewtonIterations, ...
        'invalid_Newton_trials',root.invalidTrialCount, ...
        'invalid_pre_map_calls',root.functionEvaluationCount-root.mapEvaluationCount-root.cacheHitCount, ...
        'final_Jacobian_finite_columns',all(isfinite(root.finalJacobian),1), ...
        'final_FD_per_column_reliability',root.perColumnReliability, ...
        'final_FD_selected_steps',root.selectedFiniteDifferenceSteps, ...
        'count_qualification','Core objective count records residual evaluations; each may additionally evaluate an actual BL2 map near convergence.', ...
        'last_FD_failures',struct('column',{},'reasons',{}));
    initial=report.initial_evaluation;final=root.evaluationInfo;
    names={'cyclic_event_signature','section_relative_event_signature','event_cluster_signature','return_multiplicity'};
    diagnostic.raw_compatibility_metadata=struct();
    for j=1:numel(names)
        name=names{j};
        diagnostic.raw_compatibility_metadata.(name)=struct('initial',initial.(name),'final',final.(name), ...
            'unchanged',isequal(initial.(name),final.(name)));
    end
    if isfield(fd,'columns')
        for k=1:numel(fd.columns)
            column=fd.columns(k);reasons=column.failureReasons(:).';
            if isfield(column,'candidates')
                for j=1:numel(column.candidates)
                    attempt=column.candidates(j);
                    if isfield(attempt,'failureReasons'),reasons=[reasons,attempt.failureReasons(:).'];end %#ok<AGROW>
                end
            end
            diagnostic.last_FD_failures(k)=struct('column',k,'reasons',{unique(reasons,'stable')});
        end
    end
    summary.diagnostics=diagnostic;
    summary.failure_interpretation='Second FD exhausted the correction slice before physical evaluations in columns7-13; candidate conditioning is not established by the partial matrix.';
    loaded.summary=summary;save(V3Path_v3(file),'-struct','loaded','-v7');
    RoundJSON_v3(fullfile(folder,'pilot.json'),summary);
    save(V3Path_v3(fullfile(folder,'cost_diagnostics.mat')),'diagnostic','fd','-v7');
    RoundJSON_v3(fullfile(folder,'cost_diagnostics.json'),diagnostic);disp(summary);
end
