function [policy,evidence]=RecordedReturnPolicy_v3(report)
%RECORDEDRETURNPOLICY_V3 Restore the complete policy actually used by admission.
% Delegated Residual.Map.ReturnPolicy takes precedence over recorded correction
% policy and literal seed metadata, in that order.
% CompactResearchBranch runtime-object-descriptors retain every property.
% Names, incomplete descriptors and lost function closures are not defaults.
    policy=[];evidence=struct('complete',false,'source_path','', ...
        'configuration',struct(),'reason','missing_recorded_return_policy');
    residual=member(member(report,'options',[]),'Residual',[]);
    if ~isempty(residual)
        declared=member(member(residual,'Map',[]),'ReturnPolicy',[]);
        evidence.source_path='options.Residual.Map.ReturnPolicy';
        if isempty(declared)
            evidence.reason='delegated_residual_missing_actual_return_policy';return
        end
    elseif ~isempty(member(report,'correction_return_policy',[]))
        declared=report.correction_return_policy;
        evidence.source_path='correction_return_policy';
    else
        declared=member(member(report,'seed',[]),'return_policy',[]);
        evidence.source_path='seed.return_policy';
    end
    if isa(declared,'ReturnPolicyBase_v3')&&isscalar(declared)
        className=class(declared);settings=struct();keys=properties(declared);
        for k=1:numel(keys),settings.(keys{k})=declared.(keys{k});end
    elseif isstruct(declared)&&isscalar(declared)&& ...
            isfield(declared,'diagnostic_kind')&&strcmp(declared.diagnostic_kind,'runtime-object-descriptor')&& ...
            isfield(declared,'source_class')&&isfield(declared,'settings')&& ...
            isstruct(declared.settings)&&isscalar(declared.settings)
        className=char(declared.source_class);settings=declared.settings;
    else
        evidence.reason='policy_name_or_incomplete_runtime_descriptor';return
    end
    switch className
        case 'BLMarkedApexReturnPolicy_v3'
            required={'Name','BLTouchdownsPerReturn','RequireModeClosure','LookaheadMaxTime','LookaheadMaxEvents','TimeTolerance'};
            expectedName='BL-marked-apex-return';
        case 'EventCycleReturnPolicy_v3'
            required={'Name','LegCount','LegNames','RequireModeClosure','EventClassifier'};
            expectedName='event-cycle-return';
        case 'IteratedReturnPolicy_v3'
            required={'Name','Multiplicity'};expectedName='iterated-section-return';
        case 'FirstReturnPolicy_v3'
            required={'Name'};expectedName='first-section-return';
        otherwise
            evidence.reason='unsupported_recorded_policy_class';return
    end
    if ~isequal(sort(fieldnames(settings)),sort(required(:)))
        evidence.reason='incomplete_or_unknown_recorded_policy_settings';return
    end
    if ~isequal(settings.Name,expectedName)
        evidence.reason='recorded_policy_name_class_mismatch';return
    end
    if strcmp(className,'EventCycleReturnPolicy_v3')&&~isempty(settings.EventClassifier)
        % Compact descriptors carry func2str, not the captured workspace.
        % Refuse even uncompressed custom callbacks so resume is equivalent.
        evidence.reason='custom_event_classifier_not_portably_reconstructible';return
    end
    evidence.configuration=struct('source_class',className,'settings',settings);
    try
        if isa(declared,'ReturnPolicyBase_v3')
            policy=declared;
        else
            options=rmfield(settings,'Name');
            switch className
                case 'BLMarkedApexReturnPolicy_v3',policy=BLMarkedApexReturnPolicy_v3(options);
                case 'EventCycleReturnPolicy_v3',policy=EventCycleReturnPolicy_v3(options);
                case 'IteratedReturnPolicy_v3'
                    multiplicity=options.Multiplicity;options=rmfield(options,'Multiplicity');
                    policy=IteratedReturnPolicy_v3(multiplicity,options);
                case 'FirstReturnPolicy_v3',policy=FirstReturnPolicy_v3(options);
            end
        end
        % A constructor may validate settings, but cannot silently alter them.
        keys=properties(policy);restored=struct();
        for k=1:numel(keys),restored.(keys{k})=policy.(keys{k});end
        if ~isequaln(orderfields(restored),orderfields(settings))
            policy=[];evidence.reason='restored_policy_settings_changed';return
        end
        evidence.complete=true;evidence.reason='complete_actual_policy_configuration';
    catch exception
        policy=[];evidence.reason='recorded_policy_reconstruction_failed';
        evidence.failure=struct('identifier',exception.identifier,'message',exception.message);
    end
end
function out=member(value,key,fallback)
    out=fallback;
    if isstruct(value)&&isscalar(value)&&isfield(value,key),out=value.(key);
    elseif isobject(value)&&isscalar(value)&&isprop(value,key),out=value.(key);
    elseif isstruct(value)&&isscalar(value)&&isfield(value,'settings')&& ...
            isstruct(value.settings)&&isscalar(value.settings)&&isfield(value.settings,key)
        out=value.settings.(key);
    end
end
