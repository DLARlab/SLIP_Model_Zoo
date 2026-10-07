classdef SymmetryRestrictedFloquet_v3
    %SYMMETRYRESTRICTEDFLOQUET_V3 Floquet map on a supplied invariant basis.
    %   Perturbations have the form eta = B*z. The returned multipliers are
    %   explicitly labelled as multipliers of that symmetry block; they are
    %   not presented as the unrestricted hybrid Floquet spectrum.

    properties
        Subspace
        Analyzer = []
        RequireInvariantBase = true
        InvarianceTolerance = 1e-8
        RequireClusterPreservation = true
        BlockName = 'Fix(g)'
    end

    methods
        function obj = SymmetryRestrictedFloquet_v3(subspace, options)
            if nargin < 1 || ~isa(subspace, 'SymmetrySubspace_v3')
                error('SymmetryRestrictedFloquet_v3:Subspace', ...
                    'A SymmetrySubspace_v3 object is required.');
            end
            if nargin < 2 || isempty(options)
                options = struct();
            end
            obj.Subspace = subspace;
            names = fieldnames(options);
            for index = 1:numel(names)
                if ~isprop(obj, names{index})
                    error('SymmetryRestrictedFloquet_v3:Option', ...
                        'Unknown option "%s".', names{index});
                end
                obj.(names{index}) = options.(names{index});
            end
            if isempty(obj.Analyzer)
                obj.Analyzer = FloquetAnalysis_v3();
            end
            if ~isa(obj.Analyzer, 'FloquetAnalysis_v3')
                error('SymmetryRestrictedFloquet_v3:Analyzer', ...
                    'Analyzer must be a FloquetAnalysis_v3 object.');
            end
        end

        function result = analyze(obj, map, x, q, p, options)
            if nargin < 6
                options = struct();
            end
            x = x(:);
            if obj.Subspace.AmbientDimension ~= numel(x)
                error('SymmetryRestrictedFloquet_v3:Dimension', ...
                    'The symmetry action and state dimensions differ.');
            end
            invariance = obj.Subspace.invarianceResidual(x);
            if obj.RequireInvariantBase && any(invariance > obj.InvarianceTolerance)
                error('SymmetryRestrictedFloquet_v3:NonInvariantBase', ...
                    ['The base state does not lie in the requested fixed ', ...
                     'subspace within tolerance.']);
            end
            options.TangentBasis = obj.Subspace.Basis;
            result = obj.Analyzer.analyze(map, x, q, p, options);
            result.derivativeModel = 'symmetry-restricted-classical';
            result.derivative_model = result.derivativeModel;
            result.symmetryRestricted = true;
            result.symmetryBlock = obj.BlockName;
            result.symmetry_block = obj.BlockName;
            result.symmetrySubspaceName = obj.Subspace.Name;
            result.symmetryBasis = obj.Subspace.Basis;
            result.symmetryComplementBasis = obj.Subspace.ComplementBasis;
            result.baseInvarianceResidual = invariance;
            result.clusterPreserved = obj.clusterPreserved(result);
            if obj.RequireClusterPreservation && ~result.clusterPreserved
                result.reliable = false;
                result.stability = 'unresolved';
                result.stable = false;
                result.warning = ['Symmetry-restricted perturbations did ', ...
                    'not preserve the baseline event-cluster signature.'];
            end
            block = struct('name', obj.BlockName, ...
                'basis', obj.Subspace.Basis, ...
                'matrix', result.poincareMatrix, ...
                'multipliers', result.multipliers, ...
                'reliable', result.reliable);
            result.symmetryBlocks = block;
            result.multipliersBySymmetryBlock = struct( ...
                matlab.lang.makeValidName(obj.BlockName), ...
                result.multipliers);
        end
    end

    methods (Access = private)
        function preserved = clusterPreserved(~, result)
            preserved = true;
            baseInfo = result.baseMapInfo;
            baseSignature = SymmetryRestrictedFloquet_v3.memberAny( ...
                baseInfo, {'event_cluster_signature', ...
                'cluster_signature'}, '');
            if isempty(baseSignature)
                preserved = false;
                return
            end
            finiteDifference = result.finiteDifference;
            if ~isstruct(finiteDifference) || ...
                    ~isfield(finiteDifference, 'columns')
                preserved = false;
                return
            end
            columns = finiteDifference.columns;
            for columnIndex = 1:numel(columns)
                selectedIndex = columns(columnIndex).selectedCandidate;
                candidates = columns(columnIndex).candidates;
                if isempty(candidates) || ~isfinite(selectedIndex) || ...
                        selectedIndex < 1 || selectedIndex > numel(candidates)
                    preserved = false;
                    return
                end
                selected = candidates(selectedIndex);
                if ~isfield(selected, 'clusterSignatures')
                    preserved = false;
                    return
                end
                signatures = selected.clusterSignatures;
                signatures = signatures(~cellfun(@isempty, signatures));
                if numel(signatures) < 4 || any(~strcmp( ...
                        char(baseSignature), signatures))
                    preserved = false;
                    return
                end
            end
        end
    end

    methods (Static, Access = private)
        function value = memberAny(source, names, default)
            value = default;
            if ~isstruct(source)
                return
            end
            for index = 1:numel(names)
                if isfield(source, names{index}) && ...
                        ~isempty(source.(names{index}))
                    value = source.(names{index});
                    return
                end
            end
        end
    end
end
