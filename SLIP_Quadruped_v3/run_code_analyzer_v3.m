function report = run_code_analyzer_v3(outputDirectory)
%RUN_CODE_ANALYZER_V3 Run MATLAB Code Analyzer over the complete v3 tree.
%   The complete issue table is persisted for review.  The CI gate fails on
%   analyzer errors (including parser errors); warnings and informational
%   performance advice remain visible artifacts but are not misrepresented
%   as runtime test failures.

    v3Root = fileparts(mfilename('fullpath'));
    if nargin < 1 || isempty(outputDirectory)
        outputDirectory = fullfile( ...
            v3Root, 'Docs_v3', 'TestResults_v3');
    end
    outputDirectory = char(outputDirectory);
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end

    report = codeIssues(v3Root);
    issueTable = report.Issues;
    writetable(issueTable, fullfile( ...
        outputDirectory, 'code-analyzer-issues-v3.csv'));
    save(fullfile(outputDirectory, 'code-analyzer-report-v3.mat'), ...
        'report');

    fprintf('Code Analyzer inspected %d files and reported %d issues.\n', ...
        numel(report.Files), height(issueTable));
    if ~isempty(issueTable)
        disp(issueTable(:, {'Severity', 'CheckID', 'Location', ...
            'LineStart', 'Description'}));
    end
    if ~isempty(issueTable) && ...
            any(lower(string(issueTable.Severity)) == "error")
        error('run_code_analyzer_v3:AnalyzerError', ...
            'MATLAB Code Analyzer reported one or more source errors.');
    end
end
