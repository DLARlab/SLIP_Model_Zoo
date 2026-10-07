function report=RepackCampaignCheckpoints_v3(outputDirectory)
%REPACKCAMPAIGNCHECKPOINTS_V3 Losslessly compress completed family checkpoints.
    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    oldPath=path;cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
    addpath(root,fullfile(root,'Numerics_v3'),fullfile(root,'Orbit_v3'), ...
        fullfile(root,'Simulation_v3'));
    if nargin<1,outputDirectory=fullfile(root,'Research_v3','runs','full');end
    outputDirectory=V3OutputPath_v3(outputDirectory);
    files=dir(fullfile(outputDirectory,'family_*.mat'));report=struct([]);
    for k=1:numel(files)
        file=fullfile(files(k).folder,files(k).name);data=load(file);
        data.branch=PseudoArclengthContinuation_v3().refreshBranchSummary(data.branch);
        assert(size(data.branch.x,2)==data.branch.count ...
            &&size(data.branch.p,2)==data.branch.count ...
            &&numel(data.branch.period)==data.branch.count ...
            &&numel(data.branch.solver_info)==data.branch.count);
        data.branch=CompactResearchBranch_v3(data.branch);
        temporary=[file,'.compressed.mat'];timer=tic;
        save(temporary,'-struct','data','-v7');loaded=load(temporary,'branch');
        assert(numel(loaded.branch.points)==numel(data.branch.points));
        for j=1:numel(data.branch.points)
            before=data.branch.points(j);after=loaded.branch.points(j);
            keys={'time','state','mode','event_history','event_batches'};
            for fieldIndex=1:numel(keys)
                key=keys{fieldIndex};
                assert(isequaln(before.orbit.trajectory.(key),after.orbit.trajectory.(key)));
            end
            assert(isequaln(before.x,after.x)&&isequaln(before.p,after.p));
            assert(isequaln(before.tangentInfo.extendedJacobian,after.tangentInfo.extendedJacobian));
        end
        info=dir(temporary);movefile(temporary,file,'f');
        item=struct('artifact',files(k).name,'points',numel(data.branch.points), ...
            'bytes_before',files(k).bytes,'bytes_after',info.bytes, ...
            'verified_exact_primary_trajectory_and_extended_jacobian',true, ...
            'verified_summary_arrays_match_full_point_count',true, ...
            'elapsed_seconds',toc(timer));
        if isempty(report),report=item;else,report(end+1)=item;end %#ok<AGROW>
        fprintf('Compressed %s: %d to %d bytes, %d points\n',files(k).name,files(k).bytes,info.bytes,item.points);
    end
    fid=fopen(fullfile(outputDirectory,'checkpoint_compression.json'),'w');
    if fid<0,error('RepackCampaignCheckpoints_v3:Output','Cannot write verification');end
    closeFile=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end
