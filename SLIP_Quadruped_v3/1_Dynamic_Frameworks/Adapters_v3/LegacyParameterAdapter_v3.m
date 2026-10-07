classdef LegacyParameterAdapter_v3
    %LEGACYPARAMETERADAPTER_V3 Convert seven v2 parameters to ten v3 ones.

    methods (Static)
        function [pNew, report] = toV3(pOld, policy)
            if nargin < 2 || isempty(policy)
                error('LegacyParameterAdapter_v3:PolicyRequired', ...
                    ['Choose an explicit rsla policy: "semantic-rsla" ' ...
                    'or "v2-exact".']);
            end
            pOld = LegacyParameterAdapter_v3.validateLegacy(pOld);
            policy = LegacyParameterAdapter_v3.normalizePolicy(policy);

            linearScale = pOld(1);
            torsionalScale = pOld(2);
            pitchInertia = pOld(3);
            uncompressedLength = pOld(4);
            oldSwingAngle = pOld(5);
            comLocation = pOld(6);
            stiffnessRatio = pOld(7);

            backLinearStiffness = ...
                2 * linearScale * stiffnessRatio / (1 + stiffnessRatio);
            frontLinearStiffness = ...
                2 * linearScale / (1 + stiffnessRatio);
            switch policy
                case 'semantic-rsla'
                    backRestSwingAngle = oldSwingAngle;
                    frontRestSwingAngle = oldSwingAngle;
                    activated = true;
                    discarded = false;
                case 'v2-exact'
                    backRestSwingAngle = 0;
                    frontRestSwingAngle = 0;
                    activated = false;
                    discarded = oldSwingAngle ~= 0;
            end

            schema = QuadrupedSchema_v3.shared();
            parameter = schema.Parameter;
            pNew = zeros(parameter.Dimension, 1);
            pNew(parameter.k_l_b) = backLinearStiffness;
            pNew(parameter.k_l_f) = frontLinearStiffness;
            pNew(parameter.k_s_b) = torsionalScale;
            pNew(parameter.k_s_f) = torsionalScale;
            pNew(parameter.l_l_b) = uncompressedLength;
            pNew(parameter.l_l_f) = uncompressedLength;
            pNew(parameter.rsla_b) = backRestSwingAngle;
            pNew(parameter.rsla_f) = frontRestSwingAngle;
            pNew(parameter.j_pitch) = pitchInertia;
            pNew(parameter.l_com) = comLocation;
            pNew = schema.validateParameter(pNew);

            report = struct( ...
                'policy', policy, ...
                'osa_value', oldSwingAngle, ...
                'osa_nonzero', oldSwingAngle ~= 0, ...
                'osa_activated_as_rsla', activated, ...
                'osa_discarded', discarded, ...
                'old_parameter_names', {{ ...
                    'k', 'ks', 'J', 'l', 'osa', 'lb', 'kr'}}, ...
                'new_parameter_names', {schema.Parameter.Names}, ...
                'schema_metadata', schema.metadata());
            if oldSwingAngle == 0
                report.message = ...
                    'Legacy osa is zero; both policies produce zero rsla.';
            elseif activated
                report.message = ...
                    'Legacy osa was activated as rsla_b and rsla_f.';
            else
                report.message = ...
                    'Legacy osa was discarded to reproduce v2 production dynamics.';
            end
        end

        function policy = normalizePolicy(policy)
            if ~(ischar(policy) || (isstring(policy) && isscalar(policy)))
                error('LegacyParameterAdapter_v3:InvalidPolicy', ...
                    'rsla conversion policy must be a text scalar.');
            end
            policy = lower(strrep(strrep(char(policy), '_', '-'), ' ', '-'));
            if ~any(strcmp(policy, {'semantic-rsla', 'v2-exact'}))
                error('LegacyParameterAdapter_v3:InvalidPolicy', ...
                    'Policy must be "semantic-rsla" or "v2-exact".');
            end
        end
    end

    methods (Static, Access = private)
        function pOld = validateLegacy(pOld)
            if ~(isnumeric(pOld) && isreal(pOld) && isvector(pOld) ...
                    && numel(pOld) == 7)
                error('LegacyParameterAdapter_v3:InvalidParameter', ...
                    'Legacy parameter must be [k ks J l osa lb kr].');
            end
            pOld = double(pOld(:));
            if any(~isfinite(pOld([1, 2, 4, 5, 6, 7]))) ...
                    || ~(isfinite(pOld(3)) || isinf(pOld(3))) ...
                    || pOld(1) <= 0 || pOld(2) < 0 ...
                    || pOld(3) <= 0 || pOld(4) <= 0 ...
                    || pOld(6) <= 0 || pOld(6) >= 1 ...
                    || pOld(7) <= 0
                error('LegacyParameterAdapter_v3:InvalidParameter', ...
                    ['Legacy parameters require k>0, ks>=0, J>0 or Inf, ' ...
                    'l>0, finite osa, 0<lb<1, and kr>0.']);
            end
        end
    end
end
