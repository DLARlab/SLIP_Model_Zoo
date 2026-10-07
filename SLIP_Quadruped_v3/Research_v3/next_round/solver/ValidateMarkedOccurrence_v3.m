function result=ValidateMarkedOccurrence_v3(outputDirectory)
%VALIDATEMARKEDOCCURRENCE_V3 Preserve selected BL count; reject repeated cycles.
    v3=V3Root_v3(mfilename('fullpath'));
    V3LegacyAddPath_v3(genpath(V3Path_v3(v3)));if nargin<1,outputDirectory=fileparts(mfilename('fullpath'));end
    outputDirectory=V3OutputPath_v3(outputDirectory);
    x=zeros(14,1);x(3)=1.1;
    seed=struct('state',x,'mode',false(4,1),'parameter',[10;10;20;20;1;1;0;0;2;.5], ...
        'return_policy','BL-marked-apex-return','occurrence',2, ...
        'provenance',struct('kind','intentional-two-cycle-ordinary-PIP-negative-control'));
    [solution,report]=PeriodicSolutionSolver_v3(seed,struct('Symmetry','pronk'));
    actualOccurrence=NaN;
    if isfield(report,'independent_replay')&&isfield(report.independent_replay,'map_info')
        actualOccurrence=report.independent_replay.map_info.section_chart.BL_touchdowns_per_return;
    end
    result=struct('name','marked-occurrence-and-repeated-cycle-rejection','passed',false, ...
        'declared_occurrence',2,'replayed_occurrence',actualOccurrence, ...
        'accepted',report.accepted,'full_closure',report.full_closure, ...
        'primitive_status',string(member(report.primitive,'status','unavailable')), ...
        'source_sha256',RoundSHA256_v3(fullfile(v3,'Numerics_v3','PeriodicSolutionSolver_v3.m')));
    result.passed=isempty(solution)&&~report.accepted&&actualOccurrence==2 ...
        &&report.full_closure<=1e-8&&result.primitive_status=="multiple_cover_detected";
    save(V3Path_v3(fullfile(outputDirectory,'case6_marked_occurrence.mat')),'seed','solution','report','result','-v7');
    summaryFile=fullfile(outputDirectory,'solver_validation_summary.mat');
    if isfile(V3Path_v3(summaryFile))
        loaded=load(V3Path_v3(summaryFile),'summary');summary=loaded.summary;
        item=struct('name',result.name,'passed',result.passed,'evidence',sprintf( ...
            'Declared/replayed BL occurrence %d/%d; full closure %.9g; primitive %s; accepted %d.', ...
            2,actualOccurrence,report.full_closure,result.primitive_status,report.accepted));
        summary.cases(end+1)=item;
        summary.all_required_gates_passed=all([summary.cases.passed]);
        summary.post_occurrence_repair_source_sha256=result.source_sha256;
        summary.occurrence_repair_scope='Preserve immutable correction policy for fresh replay; audit proper event-located apex recurrences. Original five cases use occurrence one; this extra case exercises the changed occurrence-two path.';
        save(V3Path_v3(summaryFile),'summary','-v7');
        f=fopen(V3Path_v3(fullfile(outputDirectory,'solver_validation_summary.json')),'w');c=onCleanup(@()fclose(f));
        fprintf(f,'%s\n',jsonencode(summary,'PrettyPrint',true));
    end
    disp(result);
end
function value=member(data,name,fallback)
    value=fallback;if isfield(data,name),value=data.(name);end
end
