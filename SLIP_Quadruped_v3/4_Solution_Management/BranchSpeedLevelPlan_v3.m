function plan=BranchSpeedLevelPlan_v3(signedVelocity,flightCount,options)
%BRANCHSPEEDLEVELPLAN_V3 Twenty-level intersection plan for one ordered curve.
% A polyline only brackets roots. MonotoneEdgesVerified registers the scope
% in which no additional speed extrema/intersections are unresolved.
% Count changes are gaps, never interpolated as one smooth topology segment.
    if nargin<3,options=struct();end
    v=signedVelocity(:).';f=flightCount(:).';n=numel(v);
    defaults=struct('DirectionTolerance',1e-10,'ConstantSpeedTolerance',1e-10, ...
        'FlightCountCertain',true(1,n),'MonotoneEdgesVerified',false(1,max(0,n-1)));
    options=merge(defaults,options);
    if n<1||numel(f)~=n||any(~isfinite(v))|| ...
            numel(options.FlightCountCertain)~=n||numel(options.MonotoneEdgesVerified)~=max(0,n-1)
        error('BranchSpeedLevelPlan_v3:Dimension','Supply finite signed velocities and one count/certainty per point and resolution per edge.');
    end
    validateattributes(options.DirectionTolerance,{'numeric'},{'scalar','finite','nonnegative'});
    validateattributes(options.ConstantSpeedTolerance,{'numeric'},{'scalar','finite','nonnegative'});
    flags=[options.FlightCountCertain(:);options.MonotoneEdgesVerified(:)];
    if any(~isfinite(flags)|~ismember(flags,[0,1]))
        error('BranchSpeedLevelPlan_v3:Resolution','Resolution/certainty flags must be explicit logical values, never NaN.');
    end
    certainty=logical(options.FlightCountCertain(:).')&isfinite(f)&f>=0&f==fix(f);
    resolved=logical(options.MonotoneEdgesVerified(:).');
    v(abs(v)<=options.DirectionTolerance)=0;
    cuts=find(~certainty(1:end-1)|~certainty(2:end)|f(1:end-1)~=f(2:end));
    runs=[1,cuts+1;nthEnd(cuts,n)];
    parts=struct([]);unresolved=struct('left_point',{},'right_point',{},'reason',{});
    for edge=cuts
        unresolved(end+1)=struct('left_point',edge,'right_point',edge+1, ...
            'reason','flight count changes or is unresolved; no cross-topology interpolation'); %#ok<AGROW>
    end
    reversals=struct('left_point',{},'right_point',{},'predictor_fraction',{});
    for run=1:size(runs,2)
        indices=runs(1,run):runs(2,run);path=indices;velocity=v(indices);
        % Insert predictor locations of direction reversals, then correct
        % zero speed independently when the plan is executed.
        for edge=fliplr(indices(1:end-1))
            if v(edge)*v(edge+1)<0
                fraction=-v(edge)/(v(edge+1)-v(edge));at=find(path==edge,1);
                path=[path(1:at),edge+fraction,path(at+1:end)]; %#ok<AGROW>
                velocity=[velocity(1:at),0,velocity(at+1:end)]; %#ok<AGROW>
                reversals(end+1)=struct('left_point',edge,'right_point',edge+1, ...
                    'predictor_fraction',fraction); %#ok<AGROW>
            end
        end
        if numel(path)==1
            parts=append(parts,makePart(path,velocity,f(indices(1)),certainty(indices(1)),resolved,options));continue
        end
        % Split at a zero that separates travel directions. Zero endpoints
        % belong to both adjacent portions, preserving the parent identity.
        boundary=1;
        for k=2:numel(path)-1
            left=find(velocity(1:k-1)~=0,1,'last');right=find(velocity(k+1:end)~=0,1,'first');
            if velocity(k)==0&&~isempty(left)&&~isempty(right)&& ...
                    sign(velocity(left))~=sign(velocity(k+right))
                parts=append(parts,makePart(path(boundary:k),velocity(boundary:k), ...
                    f(indices(1)),all(certainty(indices)),resolved,options));boundary=k;
            end
        end
        parts=append(parts,makePart(path(boundary:end),velocity(boundary:end), ...
            f(indices(1)),all(certainty(indices)),resolved,options));
    end
    for k=1:numel(parts),parts(k).partition_index=k;end
    plan=struct('schema_version','branch-speed-level-plan-v3.1','partitions',parts, ...
        'unresolved_count_boundaries',unresolved,'direction_reversals',reversals, ...
        'source_point_count',n,'options',options, ...
        'intersection_scope','All intersections of each registered monotone continuation edge; nonlinear correction is required.');
end
function ends=nthEnd(cuts,n),ends=[cuts,n];end
function part=makePart(path,v,count,certain,resolved,options)
    U=abs(v);span=max(U)-min(U);applicable=numel(path)>1&&span>options.ConstantSpeedTolerance;
    direction=unique(sign(v(v~=0)));if isempty(direction),direction=0;end
    if numel(direction)>1,error('BranchSpeedLevelPlan_v3:Partition','A direction reversal remained inside a partition.');end
    levels=repmat(struct('target_speed',NaN,'intersections',struct([]), ...
        'resolution_complete',false,'reason',''),1,20);
    if applicable
        targets=linspace(min(U),max(U),20);
        for j=1:20
            target=targets(j);hits=struct([]);
            coveredEdges=unique(max(1,min(numel(resolved),floor(path(1:end-1)))));
            % An unresolved edge can hide an additional fold even when its
            % endpoint speeds do not bracket this particular target.
            complete=certain&&~isempty(resolved)&&all(resolved(coveredEdges));
            for segment=1:numel(path)-1
                a=U(segment);b=U(segment+1);low=min(a,b);high=max(a,b);
                numerical=64*eps(max([1,abs(a),abs(b),abs(target)]));
                if target<low-numerical||target>high+numerical,continue;end
                edge=min(floor(path(segment)),numel(resolved));
                edge=max(1,edge);
                edgeResolved=~isempty(resolved)&&resolved(edge);
                if abs(b-a)<=options.ConstantSpeedTolerance
                    if abs(target-a)<=numerical
                        complete=false;kind='constant_speed_segment';fraction=.5;
                    else,continue;end
                else
                    fraction=max(0,min(1,(target-a)/(b-a)));kind='bracketed_intersection';
                end
                position=path(segment)+fraction*(path(segment+1)-path(segment));
                left=floor(position);right=ceil(position);
                if left==right,predictorFraction=0;else,predictorFraction=position-left;end
                hit=struct('path_position',position,'left_point',left,'right_point',right, ...
                    'predictor_fraction',predictorFraction,'kind',kind, ...
                    'resolution_verified',edgeResolved&&~strcmp(kind,'constant_speed_segment'));
                if isempty(hits)||all(abs([hits.path_position]-position)>1e-11)
                    hits=append(hits,hit);
                else
                    at=find(abs([hits.path_position]-position)<=1e-11,1);
                    hits(at).resolution_verified=hits(at).resolution_verified&&hit.resolution_verified;
                end
                complete=complete&&hit.resolution_verified;
            end
            if isempty(hits),complete=false;end
            levels(j)=struct('target_speed',target,'intersections',hits, ...
                'resolution_complete',complete,'reason','');
            if ~complete,levels(j).reason='Missing intersection, unresolved edge extremum, count, or constant-speed segment.';end
        end
    else
        for j=1:20,levels(j).reason='Constant-speed family or isolated point cannot provide twenty distinct speed locations.';end
    end
    part=struct('partition_index',0,'path_positions',path,'signed_velocity',v, ...
        'direction',direction,'primitive_flight_count',count,'flight_count_certain',certain, ...
        'applicable',applicable,'speed_range',[min(U),max(U)],'levels',levels);
end
function result=append(result,item)
    if isempty(result),result=item;else,result(end+1)=item;end
end
function result=merge(defaults,supplied)
    if ~isstruct(supplied)||~isscalar(supplied)||any(~ismember(fieldnames(supplied),fieldnames(defaults)))
        error('BranchSpeedLevelPlan_v3:Options','Unknown planning option.');
    end
    result=defaults;keys=fieldnames(supplied);
    for k=1:numel(keys),result.(keys{k})=supplied.(keys{k});end
end
