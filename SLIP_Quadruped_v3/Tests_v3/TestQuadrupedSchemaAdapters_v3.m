classdef TestQuadrupedSchemaAdapters_v3 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addV3Paths(testCase)
            v3Root = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(v3Root, 'Schema_v3'));
            addpath(fullfile(v3Root, 'Dynamics_v3'));
            addpath(fullfile(v3Root, 'Adapters_v3'));
            testCase.addTeardown(@() rmpath( ...
                fullfile(v3Root, 'Adapters_v3'), ...
                fullfile(v3Root, 'Dynamics_v3'), ...
                fullfile(v3Root, 'Schema_v3')));
        end
    end

    methods (Test)
        function exactStateAndRootSchema(testCase)
            schema = QuadrupedSchema_v3();
            expected = { ...
                'x', 'dx', 'y', 'dy', 'phi', 'dphi', ...
                'alphaBL', 'dalphaBL', 'alphaBR', 'dalphaBR', ...
                'alphaFL', 'dalphaFL', 'alphaFR', 'dalphaFR'};
            testCase.verifyEqual(schema.State.Names, expected);
            testCase.verifyEqual([ ...
                schema.State.x, schema.State.dx, schema.State.y, ...
                schema.State.dy, schema.State.phi, schema.State.dphi, ...
                schema.State.alphaBL, schema.State.dalphaBL, ...
                schema.State.alphaBR, schema.State.dalphaBR, ...
                schema.State.alphaFL, schema.State.dalphaFL, ...
                schema.State.alphaFR, schema.State.dalphaFR], 1:14);
            testCase.verifyEqual(schema.Root.TranslationIndex, 1);
            testCase.verifyEqual(schema.Root.PhaseIndex, 4);
            testCase.verifyEqual(schema.Root.UnknownIndices, 2:14);
            testCase.verifyEqual(schema.Root.PeriodicIndices, [2, 3, 5:14]);
            testCase.verifyEqual(schema.Root.TangentIndices, [2, 3, 5:14]);
        end

        function exactParameterSchemaAndValidation(testCase)
            schema = QuadrupedSchema_v3();
            expected = { ...
                'k_l_b', 'k_l_f', 'k_s_b', 'k_s_f', ...
                'l_l_b', 'l_l_f', 'rsla_b', 'rsla_f', ...
                'j_pitch', 'l_com'};
            testCase.verifyEqual(schema.Parameter.Names, expected);
            testCase.verifyFalse(any(strcmp('kr', schema.Parameter.Names)));
            testCase.verifyFalse(any(strcmp('osa', schema.Parameter.Names)));

            valid = [100; 80; 2; 3; 1; 0.9; 0.1; -0.2; Inf; 0.45];
            testCase.verifyEqual(schema.validateParameter(valid), valid);
            testCase.verifyError(@() schema.validateParameter(valid(1:9)), ...
                'QuadrupedSchema_v3:InvalidParameter');
            invalid = valid;
            invalid(schema.Parameter.k_l_b) = 0;
            testCase.verifyError(@() schema.validateParameter(invalid), ...
                'QuadrupedSchema_v3:InvalidParameter');
            invalid = valid;
            invalid(schema.Parameter.k_s_f) = -1;
            testCase.verifyError(@() schema.validateParameter(invalid), ...
                'QuadrupedSchema_v3:InvalidParameter');
            invalid = valid;
            invalid(schema.Parameter.l_com) = 1;
            testCase.verifyError(@() schema.validateParameter(invalid), ...
                'QuadrupedSchema_v3:InvalidParameter');

            invalidCases = { ...
                schema.Parameter.k_l_f, 0; ...
                schema.Parameter.k_s_b, -eps; ...
                schema.Parameter.l_l_b, 0; ...
                schema.Parameter.l_l_f, 0; ...
                schema.Parameter.rsla_b, NaN; ...
                schema.Parameter.rsla_f, Inf; ...
                schema.Parameter.j_pitch, 0; ...
                schema.Parameter.j_pitch, NaN; ...
                schema.Parameter.l_com, 0};
            for caseIndex = 1:size(invalidCases, 1)
                invalid = valid;
                invalid(invalidCases{caseIndex, 1}) = ...
                    invalidCases{caseIndex, 2};
                testCase.verifyError(@() schema.validateParameter(invalid), ...
                    'QuadrupedSchema_v3:InvalidParameter');
            end
        end

        function exactLegEventAndExpansionOrder(testCase)
            schema = QuadrupedSchema_v3();
            testCase.verifyEqual(schema.Leg.Names, {'BL', 'BR', 'FL', 'FR'});
            testCase.verifyEqual(schema.Event.Names, { ...
                'BL_TD', 'BL_LO', 'BR_TD', 'BR_LO', ...
                'FL_TD', 'FL_LO', 'FR_TD', 'FR_LO'});
            p = [10; 20; 3; 4; 0.8; 1.2; 0.1; -0.2; 2; 0.4];
            expanded = schema.expandParameters(p);
            testCase.verifyEqual(expanded.k_l, [10; 10; 20; 20]);
            testCase.verifyEqual(expanded.k_s, [3; 3; 4; 4]);
            testCase.verifyEqual(expanded.l_0, [0.8; 0.8; 1.2; 1.2]);
            testCase.verifyEqual(expanded.rsla, [0.1; 0.1; -0.2; -0.2]);
            testCase.verifyEqual(expanded.s, [-0.4; -0.4; 0.6; 0.6]);
        end

        function legacyStateAndModeRoundTrips(testCase)
            oldX = (1:14).';
            newX = LegacyStateAdapter_v3.toV3State(oldX);
            testCase.verifyEqual(newX, oldX( ...
                [1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 9, 10, 13, 14]));
            testCase.verifyEqual( ...
                LegacyStateAdapter_v3.fromV3State(newX), oldX);

            oldU = (1:13).';
            newU = LegacyStateAdapter_v3.toV3Unknown(oldU);
            testCase.verifyEqual(newU, oldU( ...
                [1, 2, 3, 4, 5, 6, 7, 10, 11, 8, 9, 12, 13]));
            testCase.verifyEqual( ...
                LegacyStateAdapter_v3.fromV3Unknown(newU), oldU);

            oldQ = logical([1; 0; 1; 0]);
            newQ = LegacyModeAdapter_v3.toV3(oldQ);
            testCase.verifyEqual(newQ, oldQ([1, 3, 2, 4]));
            testCase.verifyEqual(LegacyModeAdapter_v3.fromV3(newQ), oldQ);
        end

        function legacyEventsMapThroughNames(testCase)
            oldIds = 1:8;
            expectedV3 = [1, 2, 5, 6, 3, 4, 7, 8];
            testCase.verifyEqual( ...
                LegacyEventAdapter_v3.toV3(oldIds), expectedV3);
            testCase.verifyEqual( ...
                LegacyEventAdapter_v3.fromV3(expectedV3), oldIds);
            testCase.verifyEqual(LegacyEventAdapter_v3.toV3('BR_LO'), 4);
            testCase.verifyEqual(LegacyEventAdapter_v3.fromV3('FL_LO'), 4);
        end

        function legacyParameterPoliciesAreExplicit(testCase)
            old = [100; 5; 2; 0.9; 0.2; 0.4; 3];
            [semantic, semanticReport] = ...
                LegacyParameterAdapter_v3.toV3(old, 'semantic-rsla');
            [exact, exactReport] = ...
                LegacyParameterAdapter_v3.toV3(old, 'v2-exact');
            schema = QuadrupedSchema_v3();

            ratio = semantic(schema.Parameter.k_l_b) ...
                / semantic(schema.Parameter.k_l_f);
            stiffnessSum = semantic(schema.Parameter.k_l_b) ...
                + semantic(schema.Parameter.k_l_f);
            testCase.verifyEqual(ratio, old(7), 'AbsTol', 10 * eps);
            testCase.verifyEqual(stiffnessSum, 2 * old(1), ...
                'AbsTol', 100 * eps);
            testCase.verifyEqual(semantic(schema.Parameter.rsla_b), old(5));
            testCase.verifyEqual(semantic(schema.Parameter.rsla_f), old(5));
            testCase.verifyEqual(semantic, ...
                [150; 50; 5; 5; 0.9; 0.9; 0.2; 0.2; 2; 0.4], ...
                'AbsTol', 100 * eps);
            testCase.verifyEqual(exact, ...
                [150; 50; 5; 5; 0.9; 0.9; 0; 0; 2; 0.4], ...
                'AbsTol', 100 * eps);
            testCase.verifyTrue(semanticReport.osa_activated_as_rsla);
            testCase.verifyFalse(semanticReport.osa_discarded);
            testCase.verifyEqual(exact(schema.Parameter.rsla_b), 0);
            testCase.verifyEqual(exact(schema.Parameter.rsla_f), 0);
            testCase.verifyFalse(exactReport.osa_activated_as_rsla);
            testCase.verifyTrue(exactReport.osa_discarded);
            testCase.verifyError(@() LegacyParameterAdapter_v3.toV3(old), ...
                'LegacyParameterAdapter_v3:PolicyRequired');
        end

        function assembledSystemUsesSchemaAndNamedTransition(testCase)
            schema = QuadrupedSchema_v3();
            system = Quadrupedal_Dynamics_v3();
            testCase.verifyEqual(system.StateDimension, schema.State.Dimension);
            testCase.verifyEqual(system.ParameterDimension, ...
                schema.Parameter.Dimension);
            testCase.verifyEqual(system.StateNames, schema.State.Names);
            testCase.verifyEqual(system.ParameterNames, schema.Parameter.Names);

            qplus = system.transition('BR_TD', false(4, 1));
            testCase.verifyEqual(qplus, logical([0; 1; 0; 0]));
            p = [100; 80; 4; 9; 1; 1.1; 0.1; -0.2; 2; 0.45];
            x = [0; 0.4; 0.9; 0; 0.05; 0.1; ...
                -0.1; 0; -0.1; 0; 0.1; 0; 0.1; 0];
            [dxdt, diagnostics] = system.flow(0, x, false(4, 1), p);
            testCase.verifySize(dxdt, [14, 1]);
            testCase.verifySize(diagnostics.per_leg_force_vectors, [2, 4]);
            testCase.verifyEqual(diagnostics.mode, false(4, 1));
        end
    end
end
