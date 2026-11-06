function identity=NamedDatasetIdentity_v3(study,abbreviation,parameter,branchIdentity)
%NAMEDDATASETIDENTITY_V3 Naming tokens and stable full-parameter identity.
% PIP has C0. C1/C2 are one/two physical flights, not BL occurrences.
% A branch identity is independent of its changing point/modal labels.
    if nargin<4,branchIdentity='';end
    schema=QuadrupedSchema_v3.shared();p=schema.validateParameter(parameter);abbr=char(abbreviation);
    if isempty(regexp(abbr,'^(PIP|PK|[BHFG][GEMU][0-9]+)$','once'))
        error('NamedDatasetIdentity_v3:Label','A current compact label or PK/PIP exception is required.');
    end
    if strcmp(abbr,'PIP'),study=0;
    elseif ~ismember(study,[1,2])
        error('NamedDatasetIdentity_v3:Continuum','Ordinary C1/C2 data require measured one/two-flight placement.');
    end
    if ~ismember(abbr,{'PIP','PK'})
        count=str2double(regexp(abbr,'[0-9]+$','match','once'));
        if count~=study,error('NamedDatasetIdentity_v3:Flights','Filename continuum must agree with the primitive point/modal flight count.');end
    end
    id=sprintf('C%d',study);
    conventional=p(1)==p(2)&&p(3)==p(4)&&p(5)==1&&p(6)==1 ...
        &&p(7)==0&&p(8)==0&&p(10)==.5;
    if conventional
        parameters=sprintf('%s_%s_%s',token(p(1)),token(p(3)),token(p(9)));
    else
        values=arrayfun(@token,p(:).','UniformOutput',false);
        parameters=['p10_',strjoin(values,'_')];
    end
    filename=sprintf('%s_%s_%s.mat',id,abbr,parameters);
    exact=arrayfun(@(value)sprintf('%.17g',value),p(:).','UniformOutput',false);
    stable=sprintf('%s|p10:%s|branch:%s',id,strjoin(exact,','),char(branchIdentity));
    identity=struct('continuum_id',id,'continuum_number',study,'abbreviation',abbr, ...
        'physical_parameter',p,'physical_parameter_tokens',{exact},'stable_branch_identity',char(branchIdentity), ...
        'stable_dataset_id',stable,'dataset_key',[stable,'|display:',abbr], ...
        'filename',filename,'common_stiffness_filename',conventional, ...
        'parameter_token_definition','Common tokens require native lengths 1, rest angles 0, COM .5 and paired stiffnesses; otherwise all ten ordered parameters appear.');
end
function value=token(number)
    if isinf(number),value='Inf';return;end
    % Seventeen significant digits preserve distinct binary double inputs.
    value=sprintf('%.17g',number);value=strrep(value,'-','m');
    value=strrep(value,'.','p');value=strrep(value,'+','');
end
