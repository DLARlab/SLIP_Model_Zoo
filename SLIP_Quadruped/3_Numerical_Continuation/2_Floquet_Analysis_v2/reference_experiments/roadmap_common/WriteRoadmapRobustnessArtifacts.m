function artifacts = WriteRoadmapRobustnessArtifacts(report, options)
%WRITEROADMAPROBUSTNESSARTIFACTS Write auditable experiment deliverables.
%
%   ARTIFACTS = WRITEROADMAPROBUSTNESSARTIFACTS(REPORT,OPTIONS) writes the
%   flat numerical summaries, human-readable report, and optional figures
%   for a completed roadmap robustness report. The authoritative final MAT
%   already contains every transition record, so redundant per-transition
%   MAT projections are deliberately not written.
%   This experiment-local writer is shared by the full production driver
%   and the reference-artifact refresh utility so both paths use identical
%   schemas and plots.

    if nargin < 2 || ~isstruct(options) || ~isscalar(options)
        error('WriteRoadmapRobustnessArtifacts:Options', ...
            'options must be a scalar structure.');
    end
    ValidateReport(report);
    outputDirectory = RequiredTextField(options,'OutputDirectory');
    makePlots = LogicalField(options,'MakePlots',true);
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end

    if isfield(report,'artifacts') && isstruct(report.artifacts) && ...
            isscalar(report.artifacts)
        artifacts = report.artifacts;
    else
        artifacts = struct();
    end
    artifacts.artifactFormat = 'MAT-v7-compressed';
    artifacts.outputDirectory = outputDirectory;
    staleFields = intersect(fieldnames(artifacts), ...
        {'caseResultsRoot','spectrumFig','validationFig'});
    if ~isempty(staleFields)
        artifacts = rmfield(artifacts,staleFields);
    end

    summaryTable = BuildSummaryTable(report);
    correctionsTable = BuildCorrectionsTable(report);
    summaryCsv = fullfile(outputDirectory, ...
        'roadmap_bifurcation_robustness_summary.csv');
    correctionsCsv = fullfile(outputDirectory, ...
        'roadmap_branch_switch_corrections.csv');
    writetable(summaryTable,summaryCsv);
    writetable(correctionsTable,correctionsCsv);
    artifacts.summaryCsv = summaryCsv;
    artifacts.correctionsCsv = correctionsCsv;

    markdown = fullfile(outputDirectory, ...
        'roadmap_bifurcation_robustness_report.md');
    WriteMarkdownReport(markdown,report,summaryTable);
    artifacts.markdownReport = markdown;

    if makePlots
        [spectrumFigure,validationFigure] = CreateFigures(report);
        figureCleanup = onCleanup(@()CloseFigures( ...
            spectrumFigure,validationFigure));
        spectrumPng = fullfile(outputDirectory, ...
            'roadmap_floquet_crossings.png');
        validationPng = fullfile(outputDirectory, ...
            'roadmap_held_out_validation.png');
        exportgraphics(spectrumFigure,spectrumPng,'Resolution',180);
        exportgraphics(validationFigure,validationPng,'Resolution',180);
        artifacts.spectrumPng = spectrumPng;
        artifacts.validationPng = validationPng;
    end
end

function ValidateReport(report)
    if ~isstruct(report) || ~isscalar(report)
        error('WriteRoadmapRobustnessArtifacts:Report', ...
            'report must be a scalar structure.');
    end
    required = {'version','status','completedAt','transitions', ...
        'analyses','validations','summary'};
    for k = 1:numel(required)
        if ~isfield(report,required{k})
            error('WriteRoadmapRobustnessArtifacts:ReportField', ...
                'report lacks required field %s.',required{k});
        end
    end
    count = numel(report.transitions);
    if count < 1 || numel(report.analyses) ~= count || ...
            numel(report.validations) ~= count
        error('WriteRoadmapRobustnessArtifacts:ReportCount', ...
            'Transition, analysis, and validation counts must agree.');
    end
end

function tableValue = BuildSummaryTable(report)
    count = numel(report.transitions);
    ID = strings(count,1); Parent = strings(count,1); Daughter = strings(count,1);
    ExpectedGait = strings(count,1); BrokenPair = strings(count,1);
    DetectedDx = NaN(count,1); RefinedDx = NaN(count,1);
    MultiplierResidual = NaN(count,1); Confidence = NaN(count,1);
    SVDNullity = NaN(count,1); MaxFDError = NaN(count,1);
    MaxFBMismatch = NaN(count,1); MaxTimingResidual = NaN(count,1);
    OddResidual = NaN(count,1); PairSwapError = NaN(count,1);
    AcceptedCorrections = zeros(count,1);
    CoordinateDifference = NaN(count,1); LinearAlignment = NaN(count,1);
    MinimumCorrectionAlignment = NaN(count,1); OrbitDistance = NaN(count,1);
    ParentOnlyAccepted = false(count,1); HeldOutAccepted = false(count,1);
    for k = 1:count
        spec = report.transitions(k);
        analysis = report.analyses(k);
        validation = report.validations(k);
        ID(k)=spec.ID; Parent(k)=spec.ParentCode; Daughter(k)=spec.DaughterCode;
        ExpectedGait(k)=spec.ExpectedGaitAbbreviation;
        BrokenPair(k)=spec.ExpectedBrokenPair;
        ParentOnlyAccepted(k)=LogicalField(analysis,'accepted',false);
        HeldOutAccepted(k)=LogicalField(validation,'accepted',false);
        if ParentOnlyAccepted(k)
            DetectedDx(k)=NestedNumber(analysis, ...
                {'candidate','ContinuationParameter'},NaN);
            RefinedDx(k)=NestedNumber(analysis, ...
                {'refinement','coordinate'},NaN);
            MultiplierResidual(k)=NestedNumber(analysis, ...
                {'refinement','multiplierResidual'},NaN);
            Confidence(k)=NestedNumber(analysis, ...
                {'candidate','ConfidenceScore'},NaN);
            SVDNullity(k)=NestedNumber(analysis, ...
                {'refinement','branchSwitchReadinessDiagnostics', ...
                 'svdNullity'},NaN);
            MaxFDError(k)=FiniteMaximum(NestedValue(analysis, ...
                {'scan','convergence','derivativeRelativeError'},NaN));
            MaxFBMismatch(k)=FiniteMaximum(NestedValue(analysis, ...
                {'scan','convergence','forwardBackwardRelativeError'},NaN));
            MaxTimingResidual(k)=FiniteMaximum(NestedValue(analysis, ...
                {'scan','convergence','timingResidual'},NaN));
            OddResidual(k)=NestedNumber(analysis, ...
                {'symmetry','criticalOddResidual'},NaN);
            PairSwapError(k)=NestedNumber(analysis, ...
                {'signPairSymmetry','maximumScaledPairSwapError'},NaN);
            if isfield(analysis,'attempts') && isstruct(analysis.attempts) && ...
                    ~isempty(analysis.attempts) && ...
                    isfield(analysis.attempts,'acceptedBranchPoint')
                AcceptedCorrections(k)=nnz( ...
                    [analysis.attempts.acceptedBranchPoint]);
            end
        end
        CoordinateDifference(k)=FieldNumber(validation, ...
            'coordinateDifference',NaN);
        LinearAlignment(k)=FieldNumber(validation, ...
            'linearDirectionAlignment',NaN);
        MinimumCorrectionAlignment(k)=FieldNumber(validation, ...
            'minimumCorrectionDirectionAlignment',NaN);
        OrbitDistance(k)=FieldNumber(validation,'scaledOrbitDistance22',NaN);
    end
    tableValue = table(ID,Parent,Daughter,ExpectedGait,BrokenPair, ...
        DetectedDx,RefinedDx,MultiplierResidual,Confidence,SVDNullity, ...
        MaxFDError,MaxFBMismatch,MaxTimingResidual,OddResidual, ...
        PairSwapError,AcceptedCorrections,CoordinateDifference, ...
        LinearAlignment,MinimumCorrectionAlignment,OrbitDistance, ...
        ParentOnlyAccepted,HeldOutAccepted);
end

function tableValue = BuildCorrectionsTable(report)
    rows = sum(arrayfun(@(a)AttemptCount(a),report.analyses));
    Transition = strings(rows,1); Amplitude = NaN(rows,1); Sign = NaN(rows,1);
    PredictorAccepted = false(rows,1); CorrectorAccepted = false(rows,1);
    BranchPointAccepted = false(rows,1); Gait = strings(rows,1);
    TransverseFraction = NaN(rows,1); CanonicalResidual = NaN(rows,1);
    ReturnResidual = NaN(rows,1); EventTimeError = NaN(rows,1);
    RejectionStage = strings(rows,1); RejectionMessage = strings(rows,1);
    cursor = 0;
    for k = 1:numel(report.analyses)
        attempts = report.analyses(k).attempts;
        for j = 1:numel(attempts)
            cursor=cursor+1;
            item=attempts(j);
            Transition(cursor)=report.transitions(k).ID;
            Amplitude(cursor)=FieldNumber(item,'amplitude',NaN);
            Sign(cursor)=FieldNumber(item,'sign',NaN);
            PredictorAccepted(cursor)=LogicalField(item,'predictorAccepted',false);
            CorrectorAccepted(cursor)=LogicalField(item,'correctorAccepted',false);
            BranchPointAccepted(cursor)=LogicalField(item, ...
                'acceptedBranchPoint',false);
            Gait(cursor)=string(FieldText(item,'gaitAbbreviation',''));
            TransverseFraction(cursor)=FieldNumber(item,'transverseFraction',NaN);
            CanonicalResidual(cursor)=NestedNumber(item, ...
                {'correctorInfo','canonicalResidualNorm'},NaN);
            ReturnResidual(cursor)=NestedNumber(item, ...
                {'correctorInfo','mapValidation','returnResidualNorm'},NaN);
            EventTimeError(cursor)=NestedNumber(item, ...
                {'correctorInfo','mapValidation','eventTimeError'},NaN);
            RejectionStage(cursor)=string(FieldText(item,'rejectionStage',''));
            RejectionMessage(cursor)=string(FieldText(item,'rejectionMessage',''));
        end
    end
    tableValue = table(Transition,Amplitude,Sign,PredictorAccepted, ...
        CorrectorAccepted,BranchPointAccepted,Gait,TransverseFraction, ...
        CanonicalResidual,ReturnResidual,EventTimeError, ...
        RejectionStage,RejectionMessage);
end

function WriteMarkdownReport(filename,report,summary)
    handle = fopen(filename,'w');
    if handle < 0
        error('WriteRoadmapRobustnessArtifacts:MarkdownFile', ...
            'Unable to open %s.',filename);
    end
    cleanup = onCleanup(@()fclose(handle));
    fprintf(handle,'# Roadmap secondary-bifurcation robustness report\n\n');
    fprintf(handle,'Generated: `%s`  \nStatus: **%s**\n\n', ...
        report.completedAt,report.status);
    fprintf(handle,'%s\n\n',report.summary.message);
    fprintf(handle,['This is a retrospective, targeted-window robustness ' ...
        'experiment. Window locations were calibrated from the historical ' ...
        'roadmap. For each transition, its designated daughter data were ' ...
        'excluded from that transition''s Stage-A Floquet, refinement, and ' ...
        'correction calculation, then consulted in Stage B after that ' ...
        'parent prediction was frozen. FG and HE also serve as parents in ' ...
        'separate later transitions. This is not an exhaustive blind scan.\n\n']);
    fprintf(handle,['| transition | refined dx | lambda residual | SVD nullity ' ...
        '| max FD error | max timing residual | pair | odd residual ' ...
        '| corrections | daughter alignment | status |\n']);
    fprintf(handle,'|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|\n');
    for k = 1:height(summary)
        fprintf(handle,['| %s | %.12g | %.3e | %g | %.3e | %.3e | %s | ' ...
            '%.3e | %d | %.6f | %s |\n'], ...
            summary.ID(k),summary.RefinedDx(k),summary.MultiplierResidual(k), ...
            summary.SVDNullity(k),summary.MaxFDError(k), ...
            summary.MaxTimingResidual(k),summary.BrokenPair(k), ...
            summary.OddResidual(k),summary.AcceptedCorrections(k), ...
            summary.LinearAlignment(k), ...
            Ternary(summary.ParentOnlyAccepted(k) && ...
                summary.HeldOutAccepted(k),'validated','rejected'));
    end
    fprintf(handle,'\n## Interpretation\n\n');
    fprintf(handle,['Each accepted multiplier is from the 12-state reduced ' ...
        'apex return map. Event times were solved for every perturbation and ' ...
        'lifted into branch predictors, but were not Floquet coordinates. ' ...
        'The exact refined SVD nullity—not the detector''s loose candidate ' ...
        'multiplicity—verifies one tangent plus one additional mode.\n\n']);
    fprintf(handle,['The two corrected signs persist at multiple radii, pass ' ...
        'the canonical residual and an independent Poincare-map check, have ' ...
        'the expected gait label, and map into one another under the broken ' ...
        'front/hind leg swap. Daughter alignment is evaluated separately for ' ...
        'both signs at the smallest persistent accepted radius.\n\n']);
    fprintf(handle,'## Limitation: folded parent coordinates\n\n');
    fprintf(handle,['BG, BE, FG, and HE fold in `dx`. The selected adjacent ' ...
        'brackets were verified to be locally monotone before ' ...
        '`RefineCriticalOrbit` fixed `X(1)=dx`. Branch-wide discovery ' ...
        'requires a pseudo-arclength critical-orbit refiner and is not ' ...
        'claimed here.\n']);
end

function [spectrumFigure,validationFigure] = CreateFigures(report)
    spectrumFigure = figure('Visible','off','Color','w', ...
        'Name','Roadmap Floquet crossings');
    transitionCount = max(1,numel(report.analyses));
    columnCount = min(3,max(1,ceil(sqrt(transitionCount))));
    rowCount = ceil(transitionCount/columnCount);
    layout = tiledlayout(spectrumFigure,rowCount,columnCount, ...
        'TileSpacing','compact','Padding','compact');
    for k = 1:numel(report.analyses)
        ax = nexttile(layout); hold(ax,'on');
        analysis = report.analyses(k);
        if isfield(analysis,'scan') && isfield(analysis.scan,'tracks')
            x = analysis.scan.continuationCoordinate;
            lambda = analysis.scan.tracks.Multipliers;
            for row = 1:size(lambda,1)
                plot(ax,x,real(lambda(row,:)),'Color',[0.72 0.72 0.72], ...
                    'LineWidth',0.7);
            end
            yline(ax,1,'k--','LineWidth',1);
            if LogicalField(analysis,'accepted',false)
                plot(ax,analysis.refinement.coordinate,1,'ro', ...
                    'MarkerFaceColor','r');
            end
            ylim(ax,[0.75 1.25]);
        end
        title(ax,strrep(report.transitions(k).ID,'_','\_'));
        xlabel(ax,'dx'); ylabel(ax,'Re(\lambda)'); grid(ax,'on');
    end
    title(layout,'Reduced Poincare-map +1 crossings');

    validationFigure = figure('Visible','off','Color','w', ...
        'Name','Held-out roadmap validation');
    x = 1:numel(report.validations);
    alignment = arrayfun(@(v)FieldNumber(v, ...
        'linearDirectionAlignment',NaN),report.validations);
    correction = arrayfun(@(v)FieldNumber(v, ...
        'minimumCorrectionDirectionAlignment',NaN),report.validations);
    distance = arrayfun(@(v)FieldNumber(v, ...
        'scaledOrbitDistance22',NaN),report.validations);
    tiledlayout(validationFigure,2,1, ...
        'TileSpacing','compact','Padding','compact');
    ax1=nexttile;
    bar(ax1,x,[alignment(:),correction(:)]); ylim(ax1,[0 1.05]);
    yline(ax1,0.8,'k--'); grid(ax1,'on'); ylabel(ax1,'absolute cosine');
    legend(ax1,{'Floquet vs daughter','corrections vs daughter'}, ...
        'Location','southoutside','Orientation','horizontal');
    set(ax1,'XTick',x,'XTickLabel',{report.transitions.ID});
    xtickangle(ax1,25);
    ax2=nexttile;
    bar(ax2,x,distance); grid(ax2,'on');
    ylabel(ax2,'scaled 22-state distance');
    set(ax2,'XTick',x,'XTickLabel',{report.transitions.ID});
    xtickangle(ax2,25);
end

function CloseFigures(varargin)
    for k = 1:nargin
        if isgraphics(varargin{k})
            close(varargin{k});
        end
    end
end

function count = AttemptCount(analysis)
    count = 0;
    if isstruct(analysis) && isscalar(analysis) && ...
            isfield(analysis,'attempts') && isstruct(analysis.attempts)
        count = numel(analysis.attempts);
    end
end

function value = RequiredTextField(input,name)
    value = FieldText(input,name,'');
    if isempty(value)
        error('WriteRoadmapRobustnessArtifacts:TextField', ...
            '%s must be nonempty text.',name);
    end
end

function value = LogicalField(input,name,default)
    value = default;
    if ~isstruct(input) || ~isscalar(input) || ~isfield(input,name)
        return
    end
    candidate = input.(name);
    if isscalar(candidate) && (islogical(candidate) || ...
            (isnumeric(candidate) && isreal(candidate) && ...
             isfinite(candidate) && any(candidate == [0 1])))
        value = logical(candidate);
    end
end

function value = FieldNumber(input,name,default)
    if isstruct(input) && isscalar(input) && isfield(input,name) && ...
            isnumeric(input.(name)) && isreal(input.(name)) && ...
            isscalar(input.(name))
        value = input.(name);
    else
        value = default;
    end
end

function value = FieldText(input,name,default)
    if isstruct(input) && isscalar(input) && isfield(input,name) && ...
            (ischar(input.(name)) || ...
             (isstring(input.(name)) && isscalar(input.(name))))
        value = char(string(input.(name)));
    else
        value = default;
    end
end

function value = NestedNumber(input,names,default)
    value = NestedValue(input,names,default);
    if ~(isnumeric(value) && isreal(value) && isscalar(value))
        value = default;
    end
end

function value = NestedValue(input,names,default)
    value = input;
    for k = 1:numel(names)
        if ~isstruct(value) || ~isscalar(value) || ~isfield(value,names{k})
            value = default;
            return
        end
        value = value.(names{k});
    end
end

function value = FiniteMaximum(values)
    if ~isnumeric(values) || ~isreal(values)
        value = NaN;
        return
    end
    values = values(:);
    values = values(isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = max(values);
    end
end

function value = Ternary(condition,a,b)
    if condition, value=a; else, value=b; end
end
