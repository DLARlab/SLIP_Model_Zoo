function summary=ExportScientificProgress_v3()
%EXPORTSCIENTIFICPROGRESS_V3 Plot executed evidence without promoting ancestry.
% This postprocessing reads versioned results and leaves their MAT files intact.
    here=fileparts(mfilename('fullpath'));roundFolder=fileparts(here);
    v3=fileparts(fileparts(roundFolder));taskFolder=fullfile(roundFolder,'tasks','full');
    V3LegacyAddPath_v3(fullfile(v3,'Research_v3','Drivers_v3'));
    summary=struct('created_utc',char(datetime('now','TimeZone','UTC')), ...
        'matlab_version',version,'accepted_daughter_records',0, ...
        'continuation_records',0,'distinct_gait_families',{{}}, ...
        'ancestry_or_global_completeness_inferred',false,'sources',{{}});
    figureHandle=figure('Visible','off','Color','w','Position',[50,50,1100,800]);
    cleanup=onCleanup(@()close(figureHandle)); %#ok<NASGU>
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    branchAxes=nexttile;hold(branchAxes,'on');grid(branchAxes,'on');
    xlabel(branchAxes,'Energy E');ylabel(branchAxes,'Mean drift / period');
    title(branchAxes,'Executed continuation traces (overlap does not prove ancestry)');
    branchFiles=V3Dir_v3(fullfile(taskFolder,'*','continuation.json'));
    for k=1:numel(branchFiles)
        file=fullfile(branchFiles(k).folder,branchFiles(k).name);item=jsondecode(fileread(V3Path_v3(file)));
        if isempty(item.energy),continue;end
        [~,name]=fileparts(branchFiles(k).folder);
        plot(branchAxes,item.energy,item.mean_speed,'-o','MarkerSize',3,'DisplayName',name);
        summary.continuation_records=summary.continuation_records+numel(item.energy);
        summary.sources{end+1}=relative(file); %#ok<AGROW>
    end
    daughterAxes=nexttile;hold(daughterAxes,'on');grid(daughterAxes,'on');
    set(daughterAxes,'XScale','log','YScale','log');
    xlabel(daughterAxes,'Absolute constrained amplitude');ylabel(daughterAxes,'Fresh full-state closure');
    title(daughterAxes,'Independently accepted signed daughter records');
    yline(daughterAxes,1e-8,'--','Acceptance threshold','HandleVisibility','off');
    shiftAxes=nexttile;hold(shiftAxes,'on');grid(shiftAxes,'on');
    xlabel(shiftAxes,'Signed constrained amplitude');ylabel(shiftAxes,'E - E_{critical}');
    title(shiftAxes,'Measured energy shifts; no normal-form claim');
    phaseFiles=V3Dir_v3(fullfile(taskFolder,'*','phase_checkpoint.mat'));colors=lines(max(1,numel(phaseFiles)));
    labels={};
    for k=1:numel(phaseFiles)
        file=fullfile(phaseFiles(k).folder,phaseFiles(k).name);loaded=load(V3Path_v3(file),'record');
        if ~isfield(loaded,'record')||~isfield(loaded.record,'amplitudes'),continue;end
        record=loaded.record;if isempty(record.amplitudes),continue;end
        accepted=record.amplitudes([record.amplitudes.accepted]);if isempty(accepted),continue;end
        [~,name]=fileparts(phaseFiles(k).folder);amplitudes=[accepted.signed_amplitude];
        closures=[accepted.full_closure];energies=[accepted.energy];speeds=[accepted.mean_speed];
        scatter(branchAxes,energies,speeds,30,colors(k,:),'filled','DisplayName',[name,' daughters']);
        scatter(daughterAxes,abs(amplitudes),max(closures,realmin),30,colors(k,:),'filled','DisplayName',name);
        scatter(shiftAxes,amplitudes,energies-record.critical_energy,30,colors(k,:),'filled','DisplayName',name);
        summary.accepted_daughter_records=summary.accepted_daughter_records+numel(accepted);
        labels=[labels,cellfun(@char,{accepted.gait},'UniformOutput',false)]; %#ok<AGROW>
        summary.sources{end+1}=relative(file); %#ok<AGROW>
    end
    spectrumAxes=nexttile;hold(spectrumAxes,'on');grid(spectrumAxes,'on');axis(spectrumAxes,'equal');
    theta=linspace(0,2*pi,300);plot(spectrumAxes,cos(theta),sin(theta),'k:','HandleVisibility','off');
    xlabel(spectrumAxes,'Real multiplier');ylabel(spectrumAxes,'Imaginary multiplier');
    title(spectrumAxes,'Full physical energy-leaf numerical spectra');
    targets={'imported_PK','PIP'};markers={'o','s'};spectrumColors=[0,.35,.62;.75,.23,.10];
    for k=1:numel(targets)
        file=fullfile(roundFolder,'theory',['floquet_service_',targets{k},'.mat']);
        if ~isfile(V3Path_v3(file)),continue;end
        loaded=load(V3Path_v3(file),'report');report=loaded.report;multipliers=report.energy_leaf.multipliers;
        scatter(spectrumAxes,real(multipliers),imag(multipliers),36,spectrumColors(k,:),markers{k},'filled', ...
            'DisplayName',sprintf('%s E=%.6f',targets{k},report.mechanical_energy));
        summary.sources{end+1}=relative(file); %#ok<AGROW>
    end
    file=fullfile(roundFolder,'theory','n0_full_physical_spectrum.json');
    if isfile(V3Path_v3(file))
        item=jsondecode(fileread(V3Path_v3(file)));multipliers=item.energy_leaf_multipliers;
        scatter(spectrumAxes,multipliers.real,multipliers.imag,36,[.33,.18,.6],'^','filled','DisplayName',sprintf('PIP n0 E=%.6f',item.energy));
        summary.sources{end+1}=relative(file);
    end
    for axesHandle=[branchAxes,daughterAxes,shiftAxes,spectrumAxes]
        set(axesHandle,'Color','w','XColor',[.15,.15,.15],'YColor',[.15,.15,.15]);
        axesHandle.Title.Color=[.1,.1,.1];axesHandle.Title.FontSize=10;
        axesHandle.XLabel.Color=[.15,.15,.15];axesHandle.YLabel.Color=[.15,.15,.15];
        axis(axesHandle,'tight');
        if ~isempty(findobj(axesHandle,'Type','Scatter'))||~isempty(branchFiles)
            legendHandle=legend(axesHandle,'Location','best','Interpreter','none','FontSize',7);
            set(legendHandle,'Color','w','TextColor',[.1,.1,.1],'EdgeColor',[.6,.6,.6]);
        end
    end
    summary.distinct_gait_families=unique(labels);
    summary.caption=['MATLAB postprocessing of accepted physical returns and saved derivative audits. ', ...
        'Branch overlaps, repeated records and near-unit spectra establish neither ancestry nor asymptotic stability. ', ...
        'Only versioned full-profile next-round continuation artifacts are plotted; historical points within each copied trace are retained. ', ...
        'Signed daughter panels retain original phase records; the two separately accepted accuracy replacements are documented in the completion audit.'];
    exportgraphics(V3Path_v3(figureHandle),fullfile(here,'scientific_progress.png'),'Resolution',180);
    savefig(V3Path_v3(figureHandle),fullfile(here,'scientific_progress.fig'));
    RoundSave_v3(fullfile(here,'scientific_progress.mat'),struct('summary',summary));
    RoundJSON_v3(fullfile(here,'scientific_progress.json'),summary);
    function name=relative(file)
        name=strrep(file(numel(v3)+2:end),filesep,'/');
    end
end
