function budget=AbsoluteRunBudget_v3(config,previous)
%ABSOLUTERUNBUDGET_V3 Map fixed authorized UTC deadlines to this native JVM.
% Restarting recalibrates a clock; it never renews the configured UTC interval.
    if nargin<2,previous=[];end
    keys={'grant_id','start_utc','research_deadline_utc','deadline_utc'};
    assert(isstruct(config)&&isscalar(config)&&all(isfield(config,keys)), ...
        'AbsoluteRunBudget:Config','Supply the grant identity and fixed UTC deadlines.');
    for k=1:numel(keys)
        assert(ischar(config.(keys{k}))&&isrow(config.(keys{k}))&&~isempty(config.(keys{k})), ...
            'AbsoluteRunBudget:Config','Budget labels must be nonempty character rows.');
    end
    start=unix(config.start_utc);science=unix(config.research_deadline_utc);finish=unix(config.deadline_utc);
    assert(start<science&&science<=finish,'AbsoluteRunBudget:Order','Fixed UTC deadlines must be ordered.');
    if ~isempty(previous)
        for k=1:numel(keys)
            assert(isfield(previous,keys{k})&&strcmp(previous.(keys{k}),config.(keys{k})), ...
                'AbsoluteRunBudget:Resume','A restart must retain the same grant and UTC interval.');
        end
    end
    capture=struct('utc_unix_seconds',posixtime(datetime('now','TimeZone','UTC')), ...
        'monotonic_ns',double(java.lang.System.nanoTime()),'pid',feature('getpid'));
    assert(capture.utc_unix_seconds>=start&&capture.utc_unix_seconds<finish, ...
        'AbsoluteRunBudget:Expired','The configured fixed grant is not active.');
    budget=config;budget.schema='absolute-UTC-native-budget-v1';budget.capture=capture;
    budget.deadline_unix_seconds=finish;budget.research_deadline_unix_seconds=science;
    budget.deadline_monotonic_ns=capture.monotonic_ns+(finish-capture.utc_unix_seconds)*1e9;
    budget.research_deadline_monotonic_ns=capture.monotonic_ns+(science-capture.utc_unix_seconds)*1e9;
    budget.recalibration_scope='Current-JVM calibration to unchanged absolute UTC deadlines; not a fresh duration grant.';
end
function value=unix(text)
    value=posixtime(datetime(text,'InputFormat',"yyyy-MM-dd'T'HH:mm:ss'Z'",'TimeZone','UTC'));
end
