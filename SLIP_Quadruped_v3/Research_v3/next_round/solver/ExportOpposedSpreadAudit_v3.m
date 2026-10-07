function summary=ExportOpposedSpreadAudit_v3()
%EXPORTOPPOSEDSPREADAUDIT_V3 Explicit counts and drift from actual raw events.
    v3=V3Root_v3(mfilename('fullpath'));V3LegacyAddPath_v3(genpath(V3Path_v3(v3)));
    folder=fullfile(fileparts(mfilename('fullpath')),'opposed_spread');saved=load(V3Path_v3(fullfile(folder,'summary.mat')),'summary');
    summary=saved.summary;
    exact=load(V3Path_v3(fullfile(folder,'exact_predictor_admission.mat')),'exactReport');
    correction=load(V3Path_v3(fullfile(folder,'nonlinear_correction.mat')),'correctionReport');
    summary.exact_predictor=augment(summary.exact_predictor,exact.exactReport);
    summary.nonlinear_correction=augment(summary.nonlinear_correction,correction.correctionReport);
    summary.evidence_epoch='Both scientific cases executed before the subsequent RootSolver warm-initial-J cost repair; neither supplied an initial Jacobian.';
    save(V3Path_v3(fullfile(folder,'summary.mat')),'summary','-v7');
    RoundJSON_v3(fullfile(folder,'summary.json'),summary);disp(summary);
    function result=augment(result,report)
        if ~report.accepted,return;end
        map=report.independent_replay.map_info;events=map.event_history;events=events(~[events.is_stop]);
        schema=QuadrupedSchema_v3.shared();
        result.actual_contact_counts_by_event_id=arrayfun(@(id)sum([events.guard_id]==id),schema.Event.IDs);
        result.actual_contact_event_names=schema.Event.Names;
        result.actual_contact_count=numel(events);
        result.horizontal_drift=map.raw_return_state(schema.State.x)-report.final_candidate(schema.State.x);
        result.state_drift=report.drift;result=rmfield(result,'drift');
        result.actual_flight_count=report.classification.flight_count;
        result.selected_next_BL_occurrence=map.section_chart.selected_return_BL_occurrence;
        assert(numel(events)==16&&all(result.actual_contact_counts_by_event_id==2) ...
            &&result.actual_flight_count==2&&result.selected_next_BL_occurrence==3);
    end
end
