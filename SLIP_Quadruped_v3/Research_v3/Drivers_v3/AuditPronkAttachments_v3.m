function [report,audit]=AuditPronkAttachments_v3(outputDirectory)
%AUDITPRONKATTACHMENTS_V3 Reassess completed stage data from full saved orbits.
% Numerical states, frozen predictions, settings, and source orbit artifacts
% stay intact. Physical left/right event histories replace an erroneous raw
% row synchrony diagnostic; the original report is preserved before rewriting.
    root=V3Root_v3(mfilename('fullpath'));
    originalPath=path;pathCleanup=onCleanup(@()path(originalPath));
    V3LegacyAddPath_v3(root,fullfile(root,'Research_v3','Drivers_v3'));
    folders={'Schema_v3','Dynamics_v3','Simulation_v3','Orbit_v3','Numerics_v3'};
    for k=1:numel(folders),V3LegacyAddPath_v3(fullfile(root,folders{k}));end
    if nargin<1||isempty(outputDirectory)
        outputDirectory=fullfile(root,'Research_v3','runs','full');
    end
    outputDirectory=V3OutputPath_v3(outputDirectory);
    checkpoint=V3OutputPath_v3(fullfile(outputDirectory,'pip_pk_local_checkpoint.mat'));
    jsonFile=V3OutputPath_v3(fullfile(outputDirectory,'pip_pk_local.json'));
    loaded=load(V3Path_v3(checkpoint),'report');report=loaded.report;
    if strcmp(report.status,'running')
        error('AuditPronkAttachments_v3:Running','Wait until the numerical stage has stopped before auditing.');
    end
    if ~strcmp(report.schema_version,'parent-only-pronk-validation-v3-2')
        error('AuditPronkAttachments_v3:Version','This audit applies to the v2 validation stage.');
    end
    stamp=char(datetime('now','TimeZone','UTC','Format','yyyyMMdd''T''HHmmssSSS'));
    archiveDirectory=V3OutputPath_v3(fullfile(outputDirectory,['before_pronk_history_audit_',stamp]));
    mkdir(V3Path_v3(archiveDirectory));
    copyfile(V3Path_v3(checkpoint),V3Path_v3(fullfile(archiveDirectory,'pip_pk_local_checkpoint.mat')));
    copyfile(V3Path_v3(jsonFile),V3Path_v3(fullfile(archiveDirectory,'pip_pk_local.json')));
    audit=struct('schema_version','independent-pronk-artifact-audit-v3-1', ...
        'utc',char(datetime('now','TimeZone','UTC')),'pre_audit_archive',archiveDirectory, ...
        'numerical_states_changed',false,'frozen_predictions_changed',false, ...
        'registered_settings_changed',false,'connections',struct([]));
    schema=QuadrupedSchema_v3.shared();
    for connectionIndex=1:numel(report.connections)
        connection=report.connections(connectionIndex);A=connection.derivative.matrix-eye(3);
        trans=connection.transversality;stencils=trans.stencils;
        mixed=(stencils{3}.matrix-stencils{4}.matrix)/trans.energy_step;
        recomputedTrans=connection.left_kernel.'*mixed*connection.critical_direction;
        lambda=eig(connection.derivative.matrix);[unitDistance,order]=sort(abs(lambda-1));
        item=struct('critical_energy',connection.critical_energy, ...
            'right_kernel_residual',norm(A*connection.critical_direction), ...
            'left_kernel_residual',norm(connection.left_kernel.'*A), ...
            'recomputed_transversality',recomputedTrans, ...
            'transversality_record_difference',abs(recomputedTrans-trans.estimate), ...
            'unit_multiplier_distance',unitDistance(1),'other_unit_multiplier_gap',unitDistance(2), ...
            'multipliers_real',real(lambda(order)),'multipliers_imag',imag(lambda(order)), ...
            'status_before',connection.status,'status_after','','points',struct([]));
        for pointIndex=1:numel(connection.amplitudes)
            entry=connection.amplitudes(pointIndex);
            sourceFile=V3OutputPath_v3(fullfile(outputDirectory,entry.artifact));
            values=load(V3Path_v3(sourceFile),'replayOrbit','orbit','entry');
            if isempty(values.replayOrbit),continue;end
            orbit=values.replayOrbit;data=HybridCycleData_v3.unpack(orbit);
            [~,first]=unique(data.time,'stable');[~,last]=unique(data.time,'last');rows=unique([first;last]);
            closure=data.state(end,:)-data.state(1,:);closure(schema.State.x)=0;
            rawClosure=norm(closure,inf);energy=zeros(numel(rows),1);maximumConstraint=0;
            for rowIndex=1:numel(rows)
                row=rows(rowIndex);
                [energy(rowIndex),energyInfo]=QuadrupedEnergy_v3.evaluate( ...
                    data.state(row,:).',data.mode(row,:).',orbit.parameter);
                maximumConstraint=max(maximumConstraint, ...
                    energyInfo.physical_mode_report.maximum_constraint_residual);
            end
            energyError=max(abs(energy-entry.energy));
            entry.trajectory_distinction=PronkTrajectoryEvidence_v3(orbit);
            if rawClosure>report.validation_settings.full_closure_tolerance
                entry.converged=false;entry.reason='independent full saved-trajectory closure audit failed';
            end
            entry.physical_history_audit_artifact=sprintf('pronk_history_audit_%d_%+.6g.mat', ...
                connectionIndex,entry.signed_amplitude);
            point=struct('signed_amplitude',entry.signed_amplitude, ...
                'source_artifact',entry.artifact,'saved_trajectory_full_closure',rawClosure, ...
                'reported_replay_closure_difference',abs(rawClosure-entry.replay_full_closure), ...
                'maximum_energy_error',energyError,'maximum_stance_constraint_error',maximumConstraint, ...
                'omitted_virtual_reset_rows',entry.trajectory_distinction.omitted_internal_same_time_reset_rows, ...
                'synchronized_physical_history',entry.trajectory_distinction.synchronized_contact_history, ...
                'paired_motion_error',entry.trajectory_distinction.paired_leg_motion_error);
            auditFile=V3OutputPath_v3(fullfile(outputDirectory,entry.physical_history_audit_artifact));
            save(V3Path_v3(auditFile),'entry','point');
            if isempty(item.points),item.points=point;else,item.points(end+1)=point;end
            % Add the audit link to the struct array without removing fields.
            connection.amplitudes(pointIndex).trajectory_distinction=entry.trajectory_distinction;
            connection.amplitudes(pointIndex).physical_history_audit_artifact=entry.physical_history_audit_artifact;
            connection.amplitudes(pointIndex).converged=entry.converged;
            connection.amplitudes(pointIndex).reason=entry.reason;
        end
        connection.evidence=PronkAttachmentEvidence_v3(connection,report.validation_settings);
        connection.status=connection.evidence.status;item.status_after=connection.status;
        report.connections(connectionIndex)=connection;
        if isempty(audit.connections),audit.connections=item;else,audit.connections(end+1)=item;end
    end
    report.diagnostic_audit=audit;
    fid=fopen(V3Path_v3(jsonFile),'w');
    if fid<0,error('AuditPronkAttachments_v3:Output','Cannot open report output.');end
    cleanup=onCleanup(@()fclose(fid));
    fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
    save(V3Path_v3(checkpoint),'report','-v7');
    auditFile=V3OutputPath_v3(fullfile(outputDirectory,'pip_pk_local_independent_audit.mat'));
    save(V3Path_v3(auditFile),'audit');
end
