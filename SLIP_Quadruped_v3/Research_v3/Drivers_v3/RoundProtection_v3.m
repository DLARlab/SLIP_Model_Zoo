function report=RoundProtection_v3(action)
%ROUNDPROTECTION_V3 Fresh starting-checkout protection, including added files.
% The existing shell manifest records pre-existing working changes. Importing
% it does not reset that baseline; a new baseline is captured only if absent.
    if nargin<1,action='verify';end
    v3=V3Root_v3(mfilename('fullpath'));repo=fileparts(v3);
    folder=fullfile(v3,'Research_v3','next_round','baseline');if ~isfolder(V3Path_v3(folder)),mkdir(V3Path_v3(folder));end
    baselineFile=fullfile(folder,'protected_manifest.mat');
    if ~isfile(V3Path_v3(baselineFile))
        shellFile=fullfile(folder,'protected_files.sha256');
        if isfile(V3Path_v3(shellFile))
            lines=splitlines(string(fileread(V3Path_v3(shellFile))));records=struct('path',{},'sha256',{});
            for k=1:numel(lines)
                token=regexp(char(lines(k)),'^([0-9a-f]{64})  \./(.*)$','tokens','once');
                if isempty(token),continue;end
                records(end+1)=struct('path',token{2},'sha256',token{1}); %#ok<AGROW>
            end
            origin='imported fresh initial shell SHA baseline including working changes';
        else
            paths=protectedPaths(repo);records=struct('path',{},'sha256',{});
            for k=1:numel(paths),records(k)=struct('path',paths{k},'sha256',RoundSHA256_v3(fullfile(repo,paths{k})));end
            origin='fresh MATLAB capture';
        end
        baseline=struct('schema_version','fresh-protection-v3-1','origin',origin, ...
            'created_utc',char(datetime('now','TimeZone','UTC')),'records',records);
        save(V3Path_v3(baselineFile),'baseline','-v7');RoundJSON_v3(fullfile(folder,'protected_manifest.json'),baseline);
    end
    loaded=load(V3Path_v3(baselineFile),'baseline');baseline=loaded.baseline;
    verificationFolder=folder;
    epochFile=fullfile(v3,'Audits_v3','Folder_Organization','protection_epoch.json');
    if isfile(epochFile)
        epoch=jsondecode(fileread(epochFile));
        if ~strcmp(epoch.original_manifest_sha256,RoundSHA256_v3(baselineFile))
            error('RoundProtection_v3:EpochReference','The immutable research protection reference changed after organization.');
        end
        % A separate, explicit cleanup epoch retains the original ledger and
        % protects the current working state, including pre-existing deletions.
        originalPaths={baseline.records.path};epochPaths={epoch.records.path};
        if ~all(ismember(epochPaths,originalPaths)) ...
                ||~isequal(sort(setdiff(originalPaths,epochPaths)),sort(epoch.pre_existing_missing_paths(:).'))
            error('RoundProtection_v3:EpochCoverage','The cleanup epoch does not reconcile with the original reference.');
        end
        for k=1:numel(epoch.records)
            prior=find(strcmp(originalPaths,epoch.records(k).path),1);
            if ~strcmp(epoch.records(k).sha256,baseline.records(prior).sha256)
                error('RoundProtection_v3:EpochChecksum','A retained protected checksum differs from the original reference.');
            end
        end
        baseline=epoch;verificationFolder=fileparts(epochFile);
    end
    paths=protectedPaths(repo);expected={baseline.records.path};
    report=struct('schema_version','fresh-protection-v3-1','action',char(action), ...
        'checked_utc',char(datetime('now','TimeZone','UTC')),'baseline_count',numel(expected), ...
        'current_count',numel(paths),'added',{setdiff(paths,expected)}, ...
        'missing',{setdiff(expected,paths)},'changed',{{}},'passed',false, ...
        'baseline_origin',baseline.origin);
    for k=1:numel(baseline.records)
        rec=baseline.records(k);file=fullfile(repo,rec.path);
        if isfile(V3Path_v3(file))&&~V3HashMatches_v3(rec.sha256, file)
            report.changed{end+1}=rec.path;
        end
    end
    report.passed=isempty(report.added)&&isempty(report.missing)&&isempty(report.changed);
    RoundJSON_v3(fullfile(verificationFolder,'protected_verification.json'),report);
    if ~report.passed,error('RoundProtection_v3:Violation','Protected paths changed, missing, or newly added. Inspect fresh verification.');end
end
function paths=protectedPaths(repo)
    paths=walk(repo,'');paths=sort(paths);
end
function paths=walk(root,prefix)
    listing=V3Dir_v3(fullfile(root,prefix));paths={};
    for k=1:numel(listing)
        name=listing(k).name;if any(strcmp(name,{'.','..','.git'})),continue;end
        relative=fullfile(prefix,name);
        if isempty(prefix)&&strcmp(name,'SLIP_Quadruped_v3'),continue;end
        if listing(k).isdir,paths=[paths,walk(root,relative)]; %#ok<AGROW>
        else,paths{end+1}=strrep(relative,filesep,'/');end %#ok<AGROW>
    end
end
