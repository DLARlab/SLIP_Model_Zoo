function id=RoundObservationNode_v3(taskId,observation)
%ROUNDOBSERVATIONNODE_V3 Distinguish transformed candidate evidence records.
    revision=0;if isfield(observation,'repair_revision'),revision=observation.repair_revision;end
    id=sprintf('%s_column_%d_revision_%d',taskId,observation.column,revision);
    if isfield(observation,'candidate_variant')&&~isempty(observation.candidate_variant) ...
            &&~strcmp(observation.candidate_variant,'mapped_source')
        id=[id,'_variant_',observation.candidate_variant];
    end
end
