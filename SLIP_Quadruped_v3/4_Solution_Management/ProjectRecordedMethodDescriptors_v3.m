function [report,evidence]=ProjectRecordedMethodDescriptors_v3(report)
%PROJECTRECORDEDMETHODDESCRIPTORS_V3 Data-only legacy storage translation.
% The original descriptor is retained in evidence. Function signatures become
% name-only unavailable-closure descriptors, never callable functions. A known
% derivative descriptor without settings cannot acquire defaults: its solver
% option is omitted explicitly and the original unavailable descriptor remains
% in evidence. All scientific flags and numeric method settings stay literal.
% Source report handles are not traversed or mutated.
    assert(isstruct(report)&&isscalar(report),'RecordedMethodProjection:Report','Supply one literal saved report.');
    evidence=cell(0,1);
    for envelope={'integration','replay_integration'}
        key=envelope{1};if ~isfield(report,key),continue;end
        profile=report.(key);
        assert(isstruct(profile)&&isscalar(profile),'RecordedMethodProjection:Profile','Known method envelopes must be scalar structs.');
        for name={'ODESolver','OutputFcn'}
            field=name{1};if ~isfield(profile,field),continue;end
            [profile.(field),row]=callable(profile.(field),[key,'.',field]);
            if ~isempty(row),evidence{end+1,1}=row;end
        end
        if isfield(profile,'ODEOptions')
            options=profile.ODEOptions;
            assert(isstruct(options)&&isscalar(options),'RecordedMethodProjection:ODEOptions','Saved ODE options must be a scalar struct.');
            for name={'OutputFcn','Events','Jacobian','Mass'}
                field=name{1};if ~isfield(options,field),continue;end
                [options.(field),row]=callable(options.(field),[key,'.ODEOptions.',field]);
                if ~isempty(row),evidence{end+1,1}=row;end
            end
            profile.ODEOptions=options;
        end
        report.(key)=profile;
    end
    if isfield(report,'options')&&isstruct(report.options)&&isscalar(report.options) ...
            &&isfield(report.options,'SolverOptions')&&isstruct(report.options.SolverOptions)&&isscalar(report.options.SolverOptions) ...
            &&isfield(report.options.SolverOptions,'Jacobian')
        value=report.options.SolverOptions.Jacobian;
        if isstruct(value)&&isscalar(value)&&isfield(value,'runtime_class') ...
                &&any(strcmp(value.runtime_class,{'FiniteDifferenceJacobian_v3','ValidSidedFiniteDifferenceJacobian_v3','C1GGValidSidedJacobian_v3'}))
            assert(isequal(sort(fieldnames(value)),sort({'runtime_class';'reconstruction_required'})) ...
                &&isequal(value.reconstruction_required,true), ...
                'RecordedMethodProjection:Derivative','Only an exactly observed settings-absent derivative descriptor is omitted; no implementation or settings are reconstructed.');
            evidence{end+1,1}=struct('path','options.SolverOptions.Jacobian','original_descriptor',value, ...
                'action','unavailable_derivative_option_omitted','replacement_field_present',false, ...
                'settings_available',false,'defaults_inserted',false,'callable_reconstructed',false);
            report.options.SolverOptions=rmfield(report.options.SolverOptions,'Jacobian');
        end
    end
end

function [out,evidence]=callable(value,path)
    out=value;evidence=[];
    if ~isstruct(value)||~isscalar(value)||~isfield(value,'runtime_class'),return;end
    assert(isequal(sort(fieldnames(value)),sort({'runtime_class';'signature';'reconstruction_required'})) ...
        &&strcmp(value.runtime_class,'function_handle')&&isequal(value.reconstruction_required,true) ...
        &&((ischar(value.signature)&&isrow(value.signature)&&~isempty(value.signature)) ...
        ||(isstring(value.signature)&&isscalar(value.signature)&&~ismissing(value.signature)&&strlength(value.signature)>0)), ...
        'RecordedMethodProjection:Callback','Unknown legacy callback descriptor at %s; no fallback or reconstruction is allowed.',path);
    out=struct('source_class','function_handle','name',value.signature,'closure_available',false);
    evidence=struct('path',path,'original_descriptor',value,'action','name_only_callback_descriptor', ...
        'replacement_field_present',true,'replacement_descriptor',out,'callable_reconstructed',false);
end
