classdef Quadrupedal_Dynamics_v3 < HybridSystemBase_v3
    %QUADRUPEDAL_DYNAMICS_V3 Component assembly for the legacy SLIP quadruped.
    %
    % The class defines model mathematics only.  It contains no gait name,
    % prescribed event order, apex mode, or simulation-loop policy.

    properties (SetAccess = private)
        ContinuousDynamicsComponent
        GuardFunctionsComponent
        ResetMapComponent
        ModeTransitionComponent
    end

    methods
        function obj = Quadrupedal_Dynamics_v3(components)
            transition = ModeTransition_v3();
            metadata = struct();
            metadata.StateDimension = 14;
            metadata.ParameterDimension = 7;
            metadata.ModeSet = transition.modeMatrix();
            metadata.StateNames = { ...
                'x', 'vx', 'y', 'vy', 'phi', 'dphi', ...
                'alphaBL', 'dalphaBL', 'alphaFL', 'dalphaFL', ...
                'alphaBR', 'dalphaBR', 'alphaFR', 'dalphaFR'};
            metadata.ParameterNames = { ...
                'k', 'ks', 'J', 'l', 'osa', 'lb', 'kr'};
            metadata.TranslationIndex = 1;
            metadata.PhaseIndex = 4;
            metadata.DefaultUnknownIndices = 2:14;
            metadata.DefaultPeriodicIndices = [2, 3, 5:14];
            metadata.DefaultTangentIndices = [2, 3, 5:14];
            obj@HybridSystemBase_v3(metadata);

            obj.ContinuousDynamicsComponent = ContinuousDynamics_v3();
            obj.GuardFunctionsComponent = GuardFunctions_v3();
            obj.ResetMapComponent = ResetMap_v3();
            obj.ModeTransitionComponent = transition;

            if nargin > 0 && ~isempty(components)
                obj.installComponents(components);
            end
        end

        function dx = flow(obj, t, x, q, p)
            x = obj.validateState(x);
            q = obj.validateMode(q);
            p = obj.validateParameter(p);
            dx = obj.ContinuousDynamicsComponent.evaluate(t, x, q, p);
            dx = obj.validateState(dx);
        end

        function guards = activeGuards(obj, t, x, q, p)
            x = obj.validateState(x);
            q = obj.validateMode(q);
            p = obj.validateParameter(p);
            guards = obj.GuardFunctionsComponent.active(t, x, q, p);
        end

        function guards = guardFunctions(obj, t, x, q, p)
            % Return all eight guards; inactive entries retain their true value.
            x = obj.validateState(x);
            q = obj.validateMode(q);
            p = obj.validateParameter(p);
            guards = obj.GuardFunctionsComponent.descriptors(t, x, q, p);
        end

        function xplus = reset(obj, eventId, t, xminus, qminus, p)
            xminus = obj.validateState(xminus);
            qminus = obj.validateMode(qminus);
            p = obj.validateParameter(p);
            xplus = obj.ResetMapComponent.apply( ...
                eventId, t, xminus, qminus, p);
            xplus = obj.validateState(xplus);
        end

        function qplus = transition(obj, eventId, qminus)
            qminus = obj.validateMode(qminus);
            qplus = obj.ModeTransitionComponent.apply(eventId, qminus);
            qplus = obj.validateMode(qplus);
        end

        function modes = modeCandidates(obj, varargin)
            % Canonical call: modeCandidates(x,q,p).  Shortened calls are also
            % accepted because this model's finite mode set is state-independent.
            if numel(varargin) > 3
                error('Quadrupedal_Dynamics_v3:InvalidCandidateInput', ...
                    'modeCandidates accepts at most x, q, and p.');
            elseif numel(varargin) == 3
                obj.validateState(varargin{1});
                obj.validateMode(varargin{2});
                obj.validateParameter(varargin{3});
            elseif numel(varargin) == 2
                obj.validateState(varargin{1});
                obj.validateMode(varargin{2});
            elseif isscalar(varargin) && ~isempty(varargin{1})
                value = varargin{1};
                if isnumeric(value) || islogical(value)
                    if numel(value) == 14
                        obj.validateState(value);
                    elseif numel(value) == 4
                        obj.validateMode(value);
                    else
                        error('Quadrupedal_Dynamics_v3:InvalidCandidateInput', ...
                            'Single input must be a 14-state or four-entry mode.');
                    end
                end
            end
            modes = obj.ModeTransitionComponent.candidates();
        end

        function x = validateState(~, x)
            if ~(isnumeric(x) && isreal(x) && isvector(x) ...
                    && numel(x) == 14 && all(isfinite(x(:))))
                error('Quadrupedal_Dynamics_v3:InvalidState', ...
                    'Quadruped state must be a finite real 14-vector.');
            end
            x = double(x(:));
        end

        function p = validateParameter(~, p)
            if ~(isnumeric(p) && isreal(p) && isvector(p) && numel(p) == 7)
                error('Quadrupedal_Dynamics_v3:InvalidParameter', ...
                    'Quadruped parameter must be a real 7-vector.');
            end
            p = double(p(:));
            if any(~isfinite(p([1, 2, 4, 5, 6, 7]))) ...
                    || ~(isfinite(p(3)) || isinf(p(3))) ...
                    || p(1) <= 0 || p(2) < 0 || p(3) <= 0 ...
                    || p(4) <= 0 || p(6) <= 0 || p(6) >= 1 || p(7) <= 0
                error('Quadrupedal_Dynamics_v3:InvalidParameter', ...
                    ['Parameters require k>0, ks>=0, J>0 (finite or Inf), ' ...
                    'l>0, finite osa, 0<lb<1, and kr>0.']);
            end
        end

        function q = validateMode(~, q)
            q = ModeTransition_v3.validateModeVector(q);
        end

        function catalog = eventCatalog(obj)
            catalog = obj.ModeTransitionComponent.eventCatalog();
        end

        function components = components(obj)
            components = struct( ...
                'continuous_dynamics', obj.ContinuousDynamicsComponent, ...
                'guards', obj.GuardFunctionsComponent, ...
                'reset_map', obj.ResetMapComponent, ...
                'mode_transition', obj.ModeTransitionComponent);
        end
    end

    methods (Access = private)
        function installComponents(obj, components)
            if ~isstruct(components) || ~isscalar(components)
                error('Quadrupedal_Dynamics_v3:InvalidComponents', ...
                    'Components must be supplied as a scalar structure.');
            end
            fields = { ...
                'ContinuousDynamicsComponent', ...
                'GuardFunctionsComponent', ...
                'ResetMapComponent', ...
                'ModeTransitionComponent'};
            aliases = { ...
                'continuous_dynamics', ...
                'guards', ...
                'reset_map', ...
                'mode_transition'};
            requiredMethods = {'evaluate', 'active', 'apply', 'apply'};

            for i = 1:numel(fields)
                if isfield(components, fields{i})
                    component = components.(fields{i});
                elseif isfield(components, aliases{i})
                    component = components.(aliases{i});
                else
                    continue;
                end
                if ~ismethod(component, requiredMethods{i})
                    error('Quadrupedal_Dynamics_v3:InvalidComponents', ...
                        '%s must provide method %s.', fields{i}, requiredMethods{i});
                end
                obj.(fields{i}) = component;
            end
        end
    end
end
