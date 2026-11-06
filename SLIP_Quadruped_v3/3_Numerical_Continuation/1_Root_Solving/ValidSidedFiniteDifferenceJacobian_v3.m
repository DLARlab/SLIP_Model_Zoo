classdef ValidSidedFiniteDifferenceJacobian_v3 < FiniteDifferenceJacobian_v3
    %VALIDSIDEDFINITEDIFFERENCEJACOBIAN_V3 Bounded numerical acquisition.
    % Try +h, then -h, at halvings 0:2 for each fresh column. The caller's
    % one-output function remains the authority for admissible evaluations.
    % RootSolver supplies SCALED coordinates; no column unscaling occurs here.
    % This estimates a numerical correction matrix, not a classical hybrid
    % derivative. Newton can use a complete finite matrix; the current strict
    % fsolve reliability gate intentionally refuses allReliable=false.
    %
    % compute returns an all-NaN refusal matrix instead of throwing a failed
    % refresh into a caller's catch that might retain an old nonempty matrix.
    % No files, callbacks, model policies or previous matrices are retained.

    properties (SetAccess=private)
        DeadlineUnixSeconds = Inf
        DeadlineMonotonicNs = Inf
    end
    properties (Constant)
        MaximumHalvings = 2
    end

    methods
        function obj=ValidSidedFiniteDifferenceJacobian_v3(varargin)
            options=struct();
            if nargin==1&&isstruct(varargin{1})&&isscalar(varargin{1})
                options=varargin{1};
            elseif nargin>0
                assert(mod(nargin,2)==0,'ValidSidedFD:NameValue','Use an options struct or name/value pairs.');
                for k=1:2:nargin
                    name=varargin{k};
                    assert((ischar(name)&&isrow(name))||(isstring(name)&&isscalar(name)), ...
                        'ValidSidedFD:Option','Option names must be scalar text.');
                    options.(char(name))=varargin{k+1};
                end
            end
            base=struct('Method','forward','RelativeStep',1e-8,'MinimumStep',0, ...
                'MaximumStep',Inf,'CheckFinite',true,'FailurePolicy','nan');
            utc=Inf;monotonic=Inf;names=fieldnames(base);
            for key=fieldnames(options).'
                name=key{1};match=find(strcmpi(name,names),1);
                if ~isempty(match),base.(names{match})=options.(name);
                elseif strcmpi(name,'DeadlineUnixSeconds'),utc=options.(name);
                elseif strcmpi(name,'DeadlineMonotonicNs'),monotonic=options.(name);
                else,error('ValidSidedFD:Option','Unknown option %s.',name);
                end
            end
            obj@FiniteDifferenceJacobian_v3(base);
            obj.DeadlineUnixSeconds=utc;obj.DeadlineMonotonicNs=monotonic;
            obj.validateAcquisitionOptions();
        end

        function [J,f0,info]=compute(obj,fun,x,varargin)
            % Before a valid baseline establishes m, the 1-by-n placeholder
            % is explicitly unusable; avoid an unnecessary n-by-n allocation.
            n=numel(x);J=NaN(1,n);partial=J;f0=[];steps=NaN(n,1);
            available=false(n,1);attempted=false(n,1);selected=NaN(n,1);
            probes=cell(0,1);calls=0;outputDimensionKnown=false;
            info=struct('method','bounded-valid-sided-numerical-acquisition', ...
                'relativeStep',obj.RelativeStep,'maximumHalvings',obj.MaximumHalvings, ...
                'maximumFunctionCalls',1+6*n,'evaluations',0,'steps',steps, ...
                'selectedSteps',steps,'selectedProbeIndices',selected, ...
                'failedColumns',1:n,'unattemptedColumns',1:n,'messages',{cell(1,n)}, ...
                'perColumnNumericalAvailability',available, ...
                'perColumnReliability',false(n,1),'allReliable',false, ...
                'success',false,'classicalDerivative',false, ...
                'numericalAcquisitionOnly',true,'derivative_certificate_claimed',false, ...
                'unusable_all_NaN_refusal_sentinel',true,'old_or_partial_J_returned_for_use',false, ...
                'coordinateSystem','Caller coordinates; RootSolver_v3 supplies scaled coordinates.', ...
                'residualValidityAuthority','The one-output function and its thrown errors; no map metadata is inferred.', ...
                'baseCoordinates',x,'originalInputSize',[],'baseResidual',[],'probes',{probes}, ...
                'outputDimensionKnown',false,'partialJacobian',partial, ...
                'deadline_unix_seconds',obj.DeadlineUnixSeconds, ...
                'deadline_monotonic_ns',obj.DeadlineMonotonicNs,'failure',struct());
            try
                assert(isa(fun,'function_handle'),'ValidSidedFD:Function','Expected one function handle.');
                validateattributes(x,{'double','single'},{'real','finite','vector','nonempty'});
                obj.validateAcquisitionOptions();obj.checkDeadline();
                originalSize=size(x);info.originalInputSize=originalSize;x=x(:);
                relative=obj.relativeStepFor(x);info.relativeStep=relative;
                nominal=min(max(relative*(1+abs(x)),obj.MinimumStep),obj.MaximumStep);
                info.nominalSteps=nominal;
                [f0,valid]=sample(x,0,0,0,0);
                if isnumeric(f0)&&isvector(f0)&&~isempty(f0)
                    m=numel(f0);J=NaN(m,n);partial=J;outputDimensionKnown=true;
                end
                assert(valid,'ValidSidedFD:Base','A fresh finite real vector baseline is required.');
                f0=f0(:);m=numel(f0);
                for column=1:n
                    attempted(column)=true;
                    for halving=0:obj.MaximumHalvings
                        magnitude=nominal(column)/2^halving;
                        if magnitude<obj.MinimumStep,continue;end
                        for direction=[1,-1]
                            obj.checkDeadline();v=x;v(column)=x(column)+direction*magnitude;
                            actual=v(column)-x(column);
                            [value,valid]=sample(v,column,direction,halving,actual);
                            if valid&&numel(value)==m
                                % Integer residual subtraction/division can
                                % saturate; retain raw values in diagnostics
                                % and form the quotient in floating point.
                                candidate=(double(value(:))-double(f0))/double(actual);
                                if isreal(candidate)&&all(isfinite(candidate))
                                    partial(:,column)=candidate;steps(column)=actual;
                                    selected(column)=numel(probes);available(column)=true;
                                    probes{end}.column_usable=true;break
                                end
                                probes{end}.failure=struct('identifier','ValidSidedFD:Column', ...
                                    'message','The actual signed quotient is nonfinite or complex.');
                            elseif valid
                                probes{end}.failure=struct('identifier','ValidSidedFD:Dimension', ...
                                    'message',sprintf('Residual length changed from %d to %d.',m,numel(value)));
                                probes{end}.valid=false;
                            end
                        end
                        if available(column),break;end
                    end
                    if ~available(column)
                        info.messages{column}='No finite valid signed column at halvings 0:2; partial and old matrices are unusable.';
                        error('ValidSidedFD:MissingColumn','Fresh column %d could not be acquired.',column);
                    end
                end
                obj.checkDeadline();J=partial;info.success=true;
                info.unusable_all_NaN_refusal_sentinel=false;
            catch problem
                % This assignment replaces an old caller matrix even when a
                % refresh fails. The diagnostic partial never becomes J.
                J=NaN(size(partial));info.failure=obj.failure(problem);
            end
            info.evaluations=calls;info.steps=steps;info.selectedSteps=steps;
            info.selectedProbeIndices=selected;info.failedColumns=find(~available).';
            info.unattemptedColumns=find(~attempted).';
            info.perColumnNumericalAvailability=available;info.probes=probes;
            info.baseResidual=f0;info.partialJacobian=partial;
            info.outputDimensionKnown=outputDimensionKnown;
            try
                obj.checkDeadline();
            catch problem
                J=NaN(size(partial));info.success=false;
                info.unusable_all_NaN_refusal_sentinel=true;
                info.finalDeadlineFailure=obj.failure(problem);
                if isempty(fieldnames(info.failure)),info.failure=info.finalDeadlineFailure;end
            end

            function [value,valid]=sample(v,column,direction,halving,actual)
                row=struct('probe_index',numel(probes)+1,'evaluation_index',NaN,'column',column, ...
                    'direction',direction,'halving',halving,'actualSignedStep',actual, ...
                    'coordinates',reshape(v,originalSize),'invoked',false,'returned',false,'valid',false, ...
                    'column_usable',false,'residual',[],'returned_output_class','', ...
                    'returned_output_size',[],'failure',struct());
                value=[];valid=false;
                try
                    obj.checkDeadline();
                    assert(column==0||(isfinite(actual)&&actual~=0), ...
                        'ValidSidedFD:Step','The actual floating-point step must be finite and nonzero.');
                    assert(all(isfinite(v)),'ValidSidedFD:Point','Probe coordinates must remain finite.');
                    assert(calls<1+6*n,'ValidSidedFD:CallBound','The finite acquisition call bound was exceeded.');
                    row.invoked=true;calls=calls+1;row.evaluation_index=calls;
                    value=fun(reshape(v,originalSize),varargin{:});row.returned=true;
                    row.returned_output_class=class(value);row.returned_output_size=size(value);
                    if isnumeric(value),row.residual=value;end
                    valid=isnumeric(value)&&isreal(value)&&isvector(value)&&~isempty(value)&&all(isfinite(value(:)));
                    if valid,value=value(:);
                    else
                        row.failure=struct('identifier','ValidSidedFD:Residual', ...
                            'message','Expected a finite real numeric residual vector.');
                        if ~isnumeric(value),value=[];end
                    end
                    obj.checkDeadline();row.valid=valid;
                catch problem
                    valid=false;row.valid=false;row.failure=obj.failure(problem);
                end
                probes{end+1,1}=row;
                if ~valid&&isfinite(obj.DeadlineUnixSeconds)
                    % A late return remains recorded, but no further sample
                    % may begin after either original deadline expires.
                    obj.checkDeadline();
                end
            end
        end
    end

    methods (Access=private)
        function validateAcquisitionOptions(obj)
            assert(strcmpi(obj.Method,'forward')&&isequal(obj.CheckFinite,true) ...
                &&strcmpi(obj.FailurePolicy,'nan'),'ValidSidedFD:Options', ...
                'Valid-sided acquisition requires forward, CheckFinite=true and FailurePolicy=nan.');
            assert(isempty(obj.RelativeStep)||(isnumeric(obj.RelativeStep)&&isreal(obj.RelativeStep) ...
                &&isscalar(obj.RelativeStep)&&isfinite(obj.RelativeStep)&&obj.RelativeStep>0), ...
                'ValidSidedFD:RelativeStep','RelativeStep must be empty or finite and positive.');
            assert(isnumeric(obj.MinimumStep)&&isreal(obj.MinimumStep)&&isscalar(obj.MinimumStep) ...
                &&isfinite(obj.MinimumStep)&&obj.MinimumStep>=0 ...
                &&isnumeric(obj.MaximumStep)&&isreal(obj.MaximumStep)&&isscalar(obj.MaximumStep) ...
                &&obj.MaximumStep>0&&obj.MaximumStep>=obj.MinimumStep, ...
                'ValidSidedFD:Bounds','Use consistent nonnegative minimum and positive maximum steps.');
            a=obj.DeadlineUnixSeconds;b=obj.DeadlineMonotonicNs;
            assert(isnumeric(a)&&isreal(a)&&isscalar(a)&&a>0 ...
                &&isnumeric(b)&&isreal(b)&&isscalar(b) ...
                &&((isfinite(a)&&isfinite(b))||(isinf(a)&&isinf(b)&&b>0)), ...
                'ValidSidedFD:Deadline','Supply both finite absolute clocks, or leave both Inf.');
        end
        function value=relativeStepFor(obj,x)
            value=obj.RelativeStep;
            if isempty(value)
                if isa(x,'single'),value=sqrt(eps('single'));else,value=sqrt(eps('double'));end
            end
        end
        function checkDeadline(obj)
            if isfinite(obj.DeadlineUnixSeconds)
                assert(posixtime(datetime('now','TimeZone','UTC'))<obj.DeadlineUnixSeconds ...
                    &&double(java.lang.System.nanoTime)<obj.DeadlineMonotonicNs, ...
                    'ValidSidedFD:Deadline','An original absolute UTC or monotonic deadline expired.');
            end
        end
    end
    methods (Static,Access=private)
        function out=failure(problem)
            out=struct('identifier',problem.identifier,'message',problem.message, ...
                'stack',problem.stack,'causes',{{}});
            for k=1:numel(problem.cause)
                out.causes{end+1,1}=ValidSidedFiniteDifferenceJacobian_v3.failure(problem.cause{k});
            end
        end
    end
end
