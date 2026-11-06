classdef C1StoredComponentSource_v3
%C1STOREDCOMPONENTSOURCE_V3 Read immutable native occurrences through a view.
% A graph plan supplies selectors and virtual bookkeeping, never native
% trajectories or newly inferred relations. Each load uses the unchanged
% public reader of the original FILE/SHA/INDEX source. Nothing is cached.
    methods (Static)
        function view=prepare(reference)
            reference=C1StoredComponentSource_v3.checked(reference);
            variables=whos('-file',reference.file);names={variables.name};
            raw=ismember('branch_index',names);planned=ismember('component_plan',names);
            assert(xor(raw,planned),'StoredComponentSource:Kind', ...
                'Use one actual BranchSolutionFile or an explicit graph-plan file.');
            if raw
                ix=BranchSolutionFile_v3.index(reference.file);count=numel(ix.points);
                catalogue={struct('file',reference.file,'sha256',reference.sha256, ...
                    'point_metadata',{cellfun(@(p)p.metadata,ix.points,'UniformOutput',false)})};
                nodes=cell(count,1);
                for k=1:count
                    nodes{k}=struct('source_number',1,'source_index',k, ...
                        'point',ix.points{k},'native_ID','');
                end
                kind='raw-branch';planScope=struct();
            else
                assert(isequal(sort(names),{'component_plan','plan_digest'}), ...
                    'StoredComponentSource:DigestVariable', ...
                    'Use only the standalone graph plan and its complete typed digest.');
                saved=builtin('load',reference.file,'component_plan','plan_digest');p=saved.component_plan;
                assert(strcmp(C1ScientificDigest_v3(p),saved.plan_digest) ...
                    &&isstruct(p)&&isscalar(p)&&all(isfield(p, ...
                    {'schema','completed','source_posthash','view_index','source_catalog','nodes'})) ...
                    &&strcmp(p.schema,'C1-stored-component-graph-plan-v1') ...
                    &&isequal(p.completed,true)&&isequal(p.source_posthash,true), ...
                    'StoredComponentSource:Plan','Use the complete hash-bound graph-only plan, without promoting a raw-copy attempt.');
                ix=p.view_index;catalogue=p.source_catalog;nodes=p.nodes;
                assert(iscell(catalogue)&&iscolumn(catalogue)&&~isempty(catalogue) ...
                    &&iscell(nodes)&&iscolumn(nodes)&&numel(nodes)==numel(ix.points), ...
                    'StoredComponentSource:PlanRows','The graph plan needs literal ordered source and occurrence rows.');
                kind='composite-graph-plan';planScope=struct('schema',p.schema, ...
                    'completed',p.completed,'source_posthash',p.source_posthash, ...
                    'scope','Only source/graph planning completed; no native trajectory-copy or fresh scientific admission is certified.');
                for k=1:numel(ix.points)
                    assert(~isfield(ix.points{k},'whole_public_data_readback_verified') ...
                        ||isequal(ix.points{k}.whole_public_data_readback_verified,false), ...
                        'StoredComponentSource:VirtualStorageClaim', ...
                        'A virtual occurrence must not claim a new completed native trajectory materialization/readback.');
                end
            end
            assert(isstruct(ix)&&isscalar(ix)&&all(isfield(ix,{'points','edges','metadata'})) ...
                &&iscell(ix.points)&&iscolumn(ix.points)&&iscell(ix.edges), ...
                'StoredComponentSource:Index','A prepared source view needs one explicit virtual or stored index.');
            inputs=cell(numel(catalogue),1);
            for k=1:numel(catalogue)
                c=catalogue{k};assert(isstruct(c)&&isscalar(c) ...
                    &&all(isfield(c,{'file','sha256','point_metadata'}))&&iscell(c.point_metadata), ...
                    'StoredComponentSource:Catalogue','Every selector must bind its complete original source catalogue row.');
                inputs{k}=C1StoredComponentSource_v3.checked(struct('file',c.file,'sha256',c.sha256));
            end
            for k=1:numel(nodes)
                n=nodes{k};assert(isstruct(n)&&isscalar(n)&&all(isfield(n, ...
                    {'source_number','source_index','point','native_ID'})), ...
                    'StoredComponentSource:Selector','An occurrence needs its literal original selector and expected native identity.');
                validateattributes(n.source_number,{'numeric'},{'real','finite','scalar','integer','positive','<=',numel(catalogue)});
                validateattributes(n.source_index,{'numeric'},{'real','finite','scalar','integer','positive','<=',numel(catalogue{n.source_number}.point_metadata)});
                assert(ischar(n.native_ID)&&(isrow(n.native_ID)||isempty(n.native_ID)) ...
                    &&isstruct(n.point)&&isscalar(n.point)&&isfield(n.point,'metadata'), ...
                    'StoredComponentSource:SelectorIdentity','Keep an explicit native ID and original point metadata for each planned occurrence.');
                if planned,assert(~isempty(n.native_ID),'StoredComponentSource:MissingPlanID','A planned occurrence must retain its acquired native ID.');end
            end
            recipes=C1StoredComponentSource_v3.recipes();
            view=struct('schema','C1-stored-component-source-view-v1','kind',kind, ...
                'reference',reference,'index',ix,'source_catalog',{catalogue}, ...
                'nodes',{nodes},'input_references',{[inputs;{reference};recipes]}, ...
                'recipe_references',{recipes}, ...
                'plan_scope',planScope,'native_cache_retained',false, ...
                'acquisition_scope','One original source group per caller acquisition; no universal16-record memory bound or cross-pass native cache is claimed.');
        end

        function ix=index(view)
            C1StoredComponentSource_v3.validateView(view);ix=view.index;
        end

        function groups=groups(view,indices)
            C1StoredComponentSource_v3.validateView(view);
            indices=C1StoredComponentSource_v3.indices(indices,numel(view.nodes));
            sourceNumbers=cellfun(@(n)n.source_number,view.nodes(indices));
            ordered=unique(sourceNumbers,'stable');groups=cell(numel(ordered),1);
            for k=1:numel(ordered)
                positions=find(sourceNumbers==ordered(k));
                groups{k}=struct('source_number',ordered(k),'positions',positions, ...
                    'indices',indices(positions),'native_record_count',numel(positions));
            end
        end

        function [orbits,reports,metadata]=load(view,indices)
            C1StoredComponentSource_v3.validateView(view);
            indices=C1StoredComponentSource_v3.indices(indices,numel(view.nodes));
            count=numel(indices);orbits=cell(count,1);reports=orbits;metadata=orbits;
            partitions=C1StoredComponentSource_v3.groups(view,indices);
            for k=1:numel(partitions)
                group=partitions{k};original=cellfun(@(n)n.source_index,view.nodes(group.indices));
                c=view.source_catalog{group.source_number};
                source=C1StoredComponentSource_v3.checked(struct('file',c.file,'sha256',c.sha256));
                [native,nativeReports,nativeMetadata]=BranchSolutionFile_v3.loadSolutions(c.file,original);
                assert(isequal(size(native),[numel(group.indices),1]) ...
                    &&isequal(size(nativeReports),size(native))&&isequal(size(nativeMetadata),size(native)), ...
                    'StoredComponentSource:PublicRows','The original public source acquisition must preserve requested order and column cells.');
                for j=1:numel(group.indices)
                    globalIndex=group.indices(j);node=view.nodes{globalIndex};slot=group.positions(j);
                    if ~isempty(node.native_ID)
                        assert(strcmp(OrbitContentIdentity_v3(native{j}),node.native_ID), ...
                            'StoredComponentSource:NativeID','The actual original source record differs from the planned native identity.');
                    end
                    C1StoredComponentSource_v3.same(nativeMetadata{j},node.point.metadata);
                    C1StoredComponentSource_v3.same(nativeMetadata{j},c.point_metadata{node.source_index});
                    orbits{slot}=native{j};reports{slot}=nativeReports{j};
                    metadata{slot}=view.index.points{globalIndex}.metadata;
                end
                C1StoredComponentSource_v3.checked(source);
                clear native nativeReports nativeMetadata
            end
        end
    end

    methods (Static,Access=private)
        function validateView(view)
            assert(isstruct(view)&&isscalar(view)&&all(isfield(view, ...
                {'schema','kind','reference','index','source_catalog','nodes','input_references'})) ...
                &&strcmp(view.schema,'C1-stored-component-source-view-v1') ...
                &&ismember(view.kind,{'raw-branch','composite-graph-plan'}), ...
                'StoredComponentSource:View','Use only an explicit prepared immutable source view.');
        end

        function out=indices(value,count)
            assert(isnumeric(value)&&isreal(value)&&(isvector(value)||isempty(value)) ...
                &&all(isfinite(value(:)))&&all(value(:)==fix(value(:))) ...
                &&all(value(:)>=1)&&all(value(:)<=count), ...
                'StoredComponentSource:Bounds','Source selectors must be bounded positive integer indices.');
            out=value(:);
        end

        function r=checked(r)
            assert(isstruct(r)&&isscalar(r)&&isequal(sort(fieldnames(r)),{'file';'sha256'}) ...
                &&ischar(r.file)&&isrow(r.file)&&ischar(r.sha256)&&isrow(r.sha256) ...
                &&~isempty(regexp(r.sha256,'^[0-9a-f]{64}$','once')), ...
                'StoredComponentSource:Reference','Use an exact original FILE/SHA reference.');
            assert(strcmp(r.file,char(java.io.File(r.file).getCanonicalPath())) ...
                &&strcmp(r.file,char(java.io.File(V3Path_v3(r.file)).getCanonicalPath())) ...
                &&isfile(r.file)&&strcmp(RoundSHA256_v3(r.file),r.sha256), ...
                'StoredComponentSource:Changed','A consumed original source or graph recipe changed.');
        end

        function refs=recipes()
            names={'C1StoredComponentSource_v3','BranchSolutionFile_v3','OrbitContentIdentity_v3', ...
                'C1ScientificDigest_v3','RoundSHA256_v3','V3Path_v3','V3Root_v3'};
            refs=cell(numel(names),1);
            for k=1:numel(names),file=which(names{k});refs{k}=C1StoredComponentSource_v3.checked(struct('file',file,'sha256',RoundSHA256_v3(file)));end
        end

        function same(a,b)
            assert(strcmp(C1ScientificDigest_v3(a),C1ScientificDigest_v3(b)), ...
                'StoredComponentSource:Metadata','An original metadata value differs from its exact planned source selector.');
        end
    end
end
