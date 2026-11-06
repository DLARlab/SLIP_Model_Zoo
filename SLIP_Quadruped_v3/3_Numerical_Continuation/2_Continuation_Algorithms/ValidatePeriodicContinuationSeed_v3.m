function [freshOrbit,freshReport,evidence]=ValidatePeriodicContinuationSeed_v3(orbit,report,symmetry,limit,PointCheck)
%VALIDATEPERIODICCONTINUATIONSEED_V3 Fresh fixed-state continuation intake.
% This NEW problem uses E0=energy(literal state,q,p), coupled [u;E], and the
% selector E-E0=0. It does not reconstruct historical solved coordinates.
% The shared PSS uses root-newton with at most one Newton iteration. A step
% that changes even one raw state/mode/parameter bit refuses the intake.
% Fresh T/stride are compared separately; no old P edge or exact identity is
% requalified. The caller owns prepared/returned custody. ContinuePeriodic-
% Branch calls with PointCheck=[] and persists the result before callbacks.
% LIMIT has deadline_unix_seconds, deadline_monotonic_ns and optionally
% IntegrationMaxStep (default .001). Failures RETURN actual diagnostics.
    if nargin<5,PointCheck=[];end
    freshOrbit=[];freshReport=struct();entered=tic;
    evidence=struct('schema','fixed-state-periodic-continuation-intake-v1', ...
        'accepted',false,'native_service_called',false,'native_service_returned',false, ...
        'root_solver_called',false,'root_solver_returned',false,'root_iterations',[], ...
        'raw_source_unchanged',false,'chart_roundtrip_exact',false, ...
        'candidate_raw_state_unchanged',false,'candidate_mode_unchanged',false, ...
        'candidate_parameter_unchanged',false,'all_nine',false, ...
        'policy_section_match',false,'period_stride_match',false,'point_check_pass',false, ...
        'timely',false,'failure',struct(),'elapsed_seconds',0, ...
        'old_physical_edge_requalified',false,'old_energy_authority_reconstructed',false, ...
        'scope','Fresh fixed-state intake only. Changed states refuse; historical admission and old P are not promoted. Fresh T/stride stay distinct from source values.');
    sourceBefore=[];
    try
        assert(isa(orbit,'HybridOrbit_v3')&&isscalar(orbit)&&isstruct(report)&&isscalar(report), ...
            'ContinuationSeed:Inputs','Use one native orbit and its saved scalar report.');
        assert(isstruct(limit)&&isscalar(limit)&&all(isfield(limit, ...
            {'deadline_unix_seconds','deadline_monotonic_ns'})), ...
            'ContinuationSeed:Clock','Use the caller''s explicit current-process absolute clocks.');
        for clockName={'deadline_unix_seconds','deadline_monotonic_ns'}
            validateattributes(limit.(clockName{1}),{'double'},{'real','scalar','finite'});
        end
        guard(limit);maxStep=.001;
        if isfield(limit,'IntegrationMaxStep'),maxStep=limit.IntegrationMaxStep;end
        validateattributes(maxStep,{'double'},{'real','scalar','finite','positive'});
        sourceBefore=literalRecord(orbit);evidence.source_record=sourceBefore;
        validateattributes(orbit.period,{'double'},{'real','scalar','finite','positive'});
        validateattributes(orbit.stride_displacement,{'double'},{'real','vector','numel',14,'finite'});
        schema=QuadrupedSchema_v3.shared();
        assert(exact(schema.validateState(orbit.initial_state),orbit.initial_state) ...
            &&exact(schema.validateMode(orbit.initial_mode),orbit.initial_mode) ...
            &&exact(schema.validateParameter(orbit.parameter),orbit.parameter), ...
            'ContinuationSeed:LiteralRepresentation','Source must already use the native double-column state/parameters and logical-column mode; no casting or projection is performed.');
        [~,recorded]=RecordedReturnPolicy_v3(report);
        assert(recorded.complete,'ContinuationSeed:Policy','A complete reconstructible actual return policy is required.');
        % Restore a separate handle; the source report''s policy is immutable.
        descriptor=struct('diagnostic_kind','runtime-object-descriptor', ...
            'source_class',recorded.configuration.source_class,'settings',recorded.configuration.settings);
        [policy,restored]=RecordedReturnPolicy_v3(struct('correction_return_policy',descriptor));
        assert(restored.complete&&exact(recorded.configuration,restored.configuration), ...
            'ContinuationSeed:Policy','The complete policy did not roundtrip.');
        profile=struct('RelTol',1e-12,'AbsTol',1e-14,'MaxStep',maxStep, ...
            'ODEOptions',odeset('OutputFcn',@(~,~,~)double(secondsLeft(limit)<=0)));
        map=PoincareMap_v3(Quadrupedal_Dynamics_v3(), ...
            PoincareSection_v3.apex(schema.PhaseIndex),HybridSimulator_v3(profile),policy, ...
            struct('MaxReturnTime',30,'MaxCycleEvents',1000,'MaxSectionCrossings',64));
        family=EnergyFamilyResidual_v3(PeriodicOrbitResidual_v3(map,orbit.initial_state), ...
            orbit.initial_state,orbit.initial_mode,orbit.parameter,struct('Symmetry',char(symmetry)));
        u=family.packState(orbit.initial_state);
        evidence.chart_roundtrip_exact=exact(family.fullState(u),orbit.initial_state);
        assert(evidence.chart_roundtrip_exact,'ContinuationSeed:Chart','The selected chart must roundtrip the literal raw state exactly.');
        E0=QuadrupedEnergy_v3.evaluate(orbit.initial_state,orbit.initial_mode,orbit.parameter);
        reference=[u;E0];normal=[zeros(numel(u),1);1];
        constraint=struct('reference',reference,'normal',normal,'target',0);
        residual=ConstrainedEnergyResidual_v3(family,1:numel(u),constraint,ones(numel(u)+1,1));
        evidence.new_target_energy=E0;evidence.constraint=constraint;
        evidence.coordinate_indices=family.CoordinateIndices;evidence.energy_pivot=family.EnergyPivot;
        evidence.integration_profile=rmfield(profile,'ODEOptions');
        seed=struct('state',orbit.initial_state,'mode',orbit.initial_mode, ...
            'parameter',orbit.parameter,'return_policy',policy, ...
            'provenance',struct('kind','new fixed-state continuation intake; historical E not reconstructed'));
        solver=struct('Algorithm','root-newton','MaxIterations',1, ...
            'MaxFunctionEvaluations',3000,'FunctionTolerance',1e-11, ...
            'ResidualAcceptanceTolerance',1e-10,'StepTolerance',1e-13, ...
            'OptimalityTolerance',1e-18,'ReuseJacobian',false,'UseBroyden',false, ...
            'Jacobian',FiniteDifferenceJacobian_v3(struct('Method','forward','RelativeStep',1e-5)));
        settings=struct('Residual',residual,'Coordinates',reference, ...
            'AugmentedParameter',[orbit.parameter;E0],'SolverOptions',solver, ...
            'MaxWallSeconds',max(.001,secondsLeft(limit)),'TraceFailure',false);
        guard(limit);evidence.native_service_called=true;
        [freshOrbit,freshReport]=PeriodicSolutionSolver_v3(seed,settings);
        evidence.native_service_returned=true;
        timing=value(freshReport,'phase_timing',struct());
        evidence.root_solver_called=value(timing,'root_solver_call_attempted',false);
        evidence.root_solver_returned=value(timing,'root_solver_call_returned',false);
        root=value(freshReport,'solver',struct());
        evidence.root_iterations=value(value(root,'output',struct()),'iterations',[]);
        evidence.all_nine=nine(freshReport)&&isequal(value(freshReport,'accepted',false),true);
        evidence.raw_source_unchanged=exact(sourceBefore,literalRecord(orbit));
        assert(evidence.raw_source_unchanged,'ContinuationSeed:SourceMutation','The source record changed during intake.');
        if ~isa(freshOrbit,'HybridOrbit_v3')||~isscalar(freshOrbit)
            error('ContinuationSeed:NoAdmittedOrbit','The native fixed-state service did not return an admitted orbit.');
        end
        evidence.candidate_raw_state_unchanged=exact(freshOrbit.initial_state,orbit.initial_state);
        evidence.candidate_mode_unchanged=exact(freshOrbit.initial_mode,orbit.initial_mode);
        evidence.candidate_parameter_unchanged=exact(freshOrbit.parameter,orbit.parameter);
        evidence.fresh_period=freshOrbit.period;evidence.saved_period=orbit.period;
        evidence.fresh_stride=freshOrbit.stride_displacement;evidence.saved_stride=orbit.stride_displacement;
        evidence.period_scaled_error=abs(freshOrbit.period-orbit.period)/max(1,abs(orbit.period));
        evidence.stride_scaled_inf=norm((freshOrbit.stride_displacement(:)-orbit.stride_displacement(:)) ...
            ./max(ones(14,1),abs(orbit.stride_displacement(:))),Inf);
        evidence.period_tolerance=1e-8;evidence.stride_tolerance=1e-8;
        evidence.period_stride_match=isfinite(evidence.period_scaled_error)&&isfinite(evidence.stride_scaled_inf) ...
            &&evidence.period_scaled_error<=evidence.period_tolerance&&evidence.stride_scaled_inf<=evidence.stride_tolerance;
        section=MatchingReturnSection_v3(orbit,freshOrbit,{report,freshReport});
        evidence.policy_section_match=section.compatible;
        assert(evidence.candidate_raw_state_unchanged&&evidence.candidate_mode_unchanged ...
            &&evidence.candidate_parameter_unchanged,'ContinuationSeed:ChangedState', ...
            'A correction changed the source raw state, modes or parameters; it cannot replace this fixed-state initializer.');
        assert(evidence.all_nine&&evidence.period_stride_match&&evidence.policy_section_match, ...
            'ContinuationSeed:Admission','Require fresh all-nine, matching policy/section, and bounded saved T/stride differences.');
        evidence.point_check_pass=true;
        if ~isempty(PointCheck)
            assert((ischar(PointCheck)&&isrow(PointCheck))||(isstring(PointCheck)&&isscalar(PointCheck)), ...
                'ContinuationSeed:PointCheck','Use a named MATLAB file adapter, or empty.');
            checkName=char(PointCheck);checkFile=which(checkName);
            assert(~isempty(checkFile)&&endsWith(checkFile,'.m'),'ContinuationSeed:PointCheck','The named adapter must resolve to a MATLAB source file.');
            checkSHA=RoundSHA256_v3(checkFile);guard(limit);
            checkedBefore=literalRecord(freshOrbit);
            [pass,proof]=feval(checkName,freshOrbit,freshReport,limit);
            C1ScientificDigest_v3(proof); % Refuse runtime captures in saved proof.
            assert(islogical(pass)&&isscalar(pass),'ContinuationSeed:PointCheck','The adapter must return a scalar logical and a plain proof.');
            evidence.point_check_pass=pass;evidence.point_check_proof=proof;
            assert(exact(checkedBefore,literalRecord(freshOrbit)), ...
                'ContinuationSeed:PointCheckMutation','A source-check adapter must not edit the returned native record.');
            assert(strcmp(checkSHA,RoundSHA256_v3(checkFile)),'ContinuationSeed:PointCheckEpoch','PointCheck source changed during intake.');
            assert(pass,'ContinuationSeed:PointCheckRefused','The branch-specific source check refused the fresh orbit.');
        end
        guard(limit);evidence.timely=true;evidence.accepted=true;
    catch problem
        evidence.failure=struct('identifier',problem.identifier,'message',problem.message);
    end
    if ~isempty(sourceBefore)
        try
            evidence.raw_source_unchanged=exact(sourceBefore,literalRecord(orbit));
            if ~evidence.raw_source_unchanged,evidence.accepted=false;end
        catch problem
            evidence.accepted=false;
            evidence.failure=struct('identifier',problem.identifier,'message',problem.message);
        end
    end
    evidence.elapsed_seconds=toc(entered);
end

function r=literalRecord(o)
    r=struct('initial_state',o.initial_state,'initial_mode',o.initial_mode, ...
        'parameter',o.parameter,'period',o.period,'stride_displacement',o.stride_displacement, ...
        'section_chart',o.section_chart,'return_policy_name',o.return_policy_name, ...
        'return_multiplicity',o.return_multiplicity);
end
function yes=exact(a,b)
    yes=strcmp(C1ScientificDigest_v3(a),C1ScientificDigest_v3(b));
end
function yes=nine(r)
    fields={'full_closure','mode_closure','target_energy','trajectory_energy_variation', ...
        'unscaled_family_equations','family_constraint','physical_inequalities','primitive_identity','replay_determinism'};
    g=value(r,'acceptance_gates',struct());yes=isstruct(g)&&isscalar(g)&&all(isfield(g,fields));
    if yes,yes=all(cellfun(@(f)isequal(g.(f),true),fields));end
end
function v=value(s,key,fallback)
    v=fallback;if isstruct(s)&&isscalar(s)&&isfield(s,key),v=s.(key);end
end
function left=secondsLeft(limit)
    left=min(limit.deadline_unix_seconds-posixtime(datetime('now','TimeZone','UTC')), ...
        (limit.deadline_monotonic_ns-double(java.lang.System.nanoTime()))/1e9);
end
function guard(limit)
    assert(secondsLeft(limit)>0,'ContinuationSeed:Clock','The caller''s fixed intake clock expired.');
end
