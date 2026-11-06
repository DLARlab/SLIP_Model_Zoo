function check=MatchingReturnSection_v3(left,right,reports)
%MATCHINGRETURNSECTION_V3 Refuse interpolation across declared return charts.
% Complete runtime configuration from both original admissions is required.
% An explicit chart transition/rephase must be admitted separately.
    if nargin<3,reports={};end
    [a,missingA]=identity(left);[b,missingB]=identity(right);
    configA=struct();configB=struct();complete=false;evidenceA=struct();evidenceB=struct();
    if numel(reports)==2
        [~,evidenceA]=RecordedReturnPolicy_v3(reports{1});[~,evidenceB]=RecordedReturnPolicy_v3(reports{2});
        configA=evidenceA.configuration;configB=evidenceB.configuration;
        complete=evidenceA.complete&&evidenceB.complete;
    end
    configurationIdentityMatches=complete&&matchesIdentity(configA,a)&&matchesIdentity(configB,b);
    compatible=isempty(missingA)&&isempty(missingB)&&isequaln(a,b) ...
        &&configurationIdentityMatches&&isequaln(configA,configB);
    check=struct('compatible',compatible,'left_identity',a,'right_identity',b, ...
        'left_missing_fields',{missingA},'right_missing_fields',{missingB}, ...
        'actual_policy_configuration_checked',complete, ...
        'policy_configuration_matches_declared_identity',configurationIdentityMatches, ...
        'left_policy_configuration',configA,'right_policy_configuration',configB, ...
        'left_policy_evidence',evidenceA,'right_policy_evidence',evidenceB, ...
        'rephase_or_chart_transition_inferred',false);
end
function matches=matchesIdentity(configuration,identity)
    matches=ismember(identity.return_policy_name,{configuration.source_class,configuration.settings.Name});
    if strcmp(configuration.source_class,'BLMarkedApexReturnPolicy_v3')
        matches=matches&&isequal(configuration.settings.BLTouchdownsPerReturn,identity.return_occurrence);
    elseif strcmp(configuration.source_class,'IteratedReturnPolicy_v3')
        matches=matches&&isequal(configuration.settings.Multiplicity,identity.return_occurrence);
    end
end
function [out,missing]=identity(orbit)
    name=char(orbit.return_policy_name);if isempty(name),name=char(orbit.return_policy);end
    out=struct('return_policy_name',name,'initial_mode',logical(orbit.initial_mode(:)), ...
        'section',struct(),'return_occurrence',1);missing={};chart=orbit.section_chart;
    keys={'id','geometry','crossing_orientation','boundary_ownership','translational_gauge'};
    for k=1:numel(keys)
        key=keys{k};
        if ~isstruct(chart)||~isscalar(chart)||~isfield(chart,key)
            missing{end+1}=key; %#ok<AGROW>
        else,out.section.(key)=chart.(key);end
    end
    if isempty(name),missing{end+1}='return_policy_name';end
    if ismember(name,{'BL-marked-apex-return','BLMarkedApexReturnPolicy_v3'})
        if isfield(chart,'BL_touchdowns_per_return'),out.return_occurrence=chart.BL_touchdowns_per_return;
        else,missing{end+1}='BL_touchdowns_per_return';end
    elseif ismember(name,{'iterated-section-return','IteratedReturnPolicy_v3'})
        out.return_occurrence=orbit.return_multiplicity;
    end
end
