function cfg=RoundDomainRevisions_v3(cfg)
%ROUNDDOMAINREVISIONS_V3 Apply prospective source-informed domain journals.
% The previous registration and observations keep their previous meaning.
    v3=V3Root_v3(mfilename('fullpath'));
    file=fullfile(v3,'Research_v3','next_round','domain_revisions.mat');if ~isfile(V3Path_v3(file)),return;end
    saved=load(V3Path_v3(file),'revisions');revisions=saved.revisions;
    for k=1:numel(revisions)
        cfg.domain.energy(1)=revisions(k).energy_floor;
        cfg.domain.energy_stages.ordinary_parent_and_P2(1)=revisions(k).energy_floor;
        cfg.domain.energy_stages.full_source_comparison(1)=revisions(k).energy_floor;
        cfg.domain.energy_stages.ordinary_vertical_PIP=[1.000001,3];
    end
    cfg.domain_revision=numel(revisions);cfg.domain_revision_history='Research_v3/next_round/domain_revisions.json';
    cfg.domain.initial_subunit_source_audit='Research_v3/next_round/solver/domain_lower_energy_audit.json';
end
