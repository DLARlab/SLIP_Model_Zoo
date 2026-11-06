function [pass,proof]=PKFlightPointCheck_v3(orbit,report,limit)
%PKFLIGHTPOINTCHECK_V3 Optional post-admission synchronous PK supplement.
% Never attach this checker to root/FD residual evaluations. It requires the
% actual admitted primary trajectory and its recorded second-replay profile.
% PASS remains conditional on the existing arithmetic cushions, not a formal
% floating-point certificate. Unsupported/split cohorts remain UNASSESSED.
    pass=false;
    proof=struct('schema','PK-post-admission-flight-point-check-v1', ...
        'profile',struct(),'profile_evidence',struct(),'flight',struct(), ...
        'pass',false,'failure',struct(),'new_admission_claimed',false);
    try
        assert(isa(orbit,'HybridOrbit_v3')&&isscalar(orbit), ...
            'PKPointCheck:Orbit','Use one actual admitted native orbit.');
        g=report.classification;
        assert(strcmp(g.validated_gait_type,'PK')&&g.flight_count_certain&&g.flight_count==1, ...
            'PKPointCheck:Family','This adapter supports admitted one-flight PK only.');
        [profile,owner]=RecordedOrbitReplayProfile_v3(orbit,report);
        proof.profile_evidence=owner;
        assert(owner.complete&&owner.retained_lineage_bound, ...
            'PKPointCheck:Profile','The actual second-replay profile and trajectory must be bound.');
        physical=QuadrupedAdmissibility_v3();
        options=struct('SwingPenetrationTolerance',physical.SwingPenetrationTolerance, ...
            'ArithmeticCushion',1e-12,'DerivativeCushion',1e-10,'CurvatureCushion',1e-8, ...
            'EventTimeTolerance',profile.EventTimeTolerance,'Limits',limit, ...
            'MaxWallSeconds',60,'IntervalMaxWallSeconds',30,'RequireOneFlightEventWord',true);
        proof.profile=struct('EventTimeTolerance',profile.EventTimeTolerance, ...
            'profile_path',owner.profile_path,'source_contract',owner.source_contract);
        proof.flight=CheckC1PKOrbitFlights_v3(orbit,orbit.parameter,options);
        pass=strcmp(proof.flight.status,'PASS')&&proof.flight.return_timely;
        proof.pass=pass;
    catch problem
        proof.failure=struct('identifier',problem.identifier,'message',problem.message);
    end
end
