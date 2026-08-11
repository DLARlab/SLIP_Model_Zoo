classdef TestReturnPolicies_v3 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addFrameworkPaths(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            folders = {'Schema_v3', 'Dynamics_v3', 'Simulation_v3', 'Orbit_v3', ...
                'Tests_v3'};
            for i = 1:numel(folders)
                addpath(fullfile(root, folders{i}));
            end
        end
    end

    methods (Test)
        function firstReturnIsNotAutomaticallyAFullCycle(testCase)
            system = createSyntheticReturnPolicySystem_v3('two-apex');
            [section, simulator] = testCase.components();
            map = PoincareMap_v3(system, section, simulator, ...
                FirstReturnPolicy_v3(), testCase.mapOptions());

            [xNext, info] = map.evaluate([1; 0], 0, []);

            testCase.verifyEqual(xNext, [1; 0], 'AbsTol', 2e-7);
            testCase.verifyEqual(info.period, 1, 'AbsTol', 2e-7);
            testCase.verifyEqual(info.return_multiplicity, 1);
            testCase.verifyEqual(info.final_mode, 1);
            testCase.verifyFalse(info.discrete_closed);
            testCase.verifyEqual(info.event_sequence, "L1_TD");
            testCase.verifyEqual(info.accepted_crossing_index, 1);
        end

        function eventCycleRejectsIntermediateAndAcceptsSecondApex(testCase)
            system = createSyntheticReturnPolicySystem_v3('two-apex');
            [section, simulator] = testCase.components();
            map = PoincareMap_v3(system, section, simulator, ...
                EventCycleReturnPolicy_v3(), testCase.mapOptions());

            [xNext, info] = map.evaluate([1; 0], 0, []);

            testCase.verifyEqual(xNext, [1; 0], 'AbsTol', 3e-7);
            testCase.verifyEqual(info.period, 2, 'AbsTol', 3e-7);
            testCase.verifyEqual(info.return_multiplicity, 2);
            testCase.verifyEqual(info.accepted_crossing_index, 2);
            testCase.verifyEqual(info.accepted_apex_index, 2);
            testCase.verifyEqual(info.candidate_section_count, 2);
            testCase.verifyEqual(info.candidate_apex_count, 2);
            testCase.verifyTrue(info.discrete_closed);
            testCase.verifyEqual(info.final_mode, 0);
            testCase.verifyNumElements(info.candidate_section_crossings, 2);
            testCase.verifyFalse(info.candidate_section_crossings(1).accepted);
            testCase.verifyTrue(info.candidate_section_crossings(2).accepted);
            testCase.verifyEqual(info.event_sequence, ["L1_TD"; "L1_LO"]);
            testCase.verifyEqual( ...
                info.event_counts_per_leg.touchdown_count, 1);
            testCase.verifyEqual( ...
                info.event_counts_per_leg.liftoff_count, 1);
            testCase.verifyNotEmpty(info.section_relative_event_signature);
            testCase.verifyNotEmpty(info.cyclic_event_signature);
        end

        function fullCyclePeriodicResidualIsZero(testCase)
            system = createSyntheticReturnPolicySystem_v3('two-apex');
            [section, simulator] = testCase.components();
            map = PoincareMap_v3(system, section, simulator, ...
                EventCycleReturnPolicy_v3(), testCase.mapOptions());
            residual = PeriodicOrbitResidual_v3(map, [1; 0]);

            [value, details] = residual.evaluateWithInfo([1; 0], [], 0);

            testCase.verifyEqual(value, zeros(2, 1), 'AbsTol', 3e-7);
            testCase.verifyTrue(details.valid);
            testCase.verifyEqual(details.return_multiplicity, 2);
            testCase.verifyEqual(details.return_policy_name, ...
                'event-cycle-return');
            testCase.verifyEqual(details.candidate_section_count, 2);
            testCase.verifyEqual(details.candidate_apex_count, 2);
            testCase.verifyEqual(details.accepted_crossing_index, 2);
            testCase.verifyEqual(details.accepted_apex_index, 2);
            orbit = residual.createOrbit([1; 0], [], 0, details);
            testCase.verifyEqual(orbit.return_policy, ...
                'EventCycleReturnPolicy_v3');
            testCase.verifyEqual(orbit.return_policy_name, ...
                'event-cycle-return');
            testCase.verifyEqual(orbit.return_multiplicity, 2);
            testCase.verifyEqual(orbit.candidate_section_count, 2);
            testCase.verifyEqual(orbit.candidate_apex_count, 2);
            testCase.verifyEqual(orbit.accepted_crossing_index, 2);
            testCase.verifyEqual(orbit.accepted_apex_index, 2);
            testCase.verifyEqual(orbit.event_counts.touchdown_count, 1);
            testCase.verifyNotEmpty(orbit.cyclic_event_signature);
            testCase.verifyTrue(isfield(orbit.topology_margins, ...
                'section_transversality'));
        end

        function iteratedPolicyComputesSecondIterate(testCase)
            system = createSyntheticReturnPolicySystem_v3('two-apex');
            [section, simulator] = testCase.components();
            map = PoincareMap_v3(system, section, simulator, ...
                IteratedReturnPolicy_v3(2), testCase.mapOptions());

            [~, info] = map.evaluate([1; 0], 0, []);

            testCase.verifyEqual(info.period, 2, 'AbsTol', 3e-7);
            testCase.verifyEqual(info.return_multiplicity, 2);
            testCase.verifyEqual(info.accepted_crossing_index, 2);
        end

        function sectionCoincidentEventsAreRightContinuousAndCountedOnce(testCase)
            system = createSyntheticReturnPolicySystem_v3('coincident');
            [section, simulator] = testCase.components();
            map = PoincareMap_v3(system, section, simulator, ...
                EventCycleReturnPolicy_v3(), testCase.mapOptions());

            [~, info] = map.evaluate([1; 0], 0, []);

            testCase.verifyEqual(info.return_multiplicity, 2);
            testCase.verifyEqual(info.final_mode, 0);
            testCase.verifyNumElements(info.event_history, 2);
            testCase.verifyNumElements(info.section_coincident_events, 1);
            testCase.verifyEqual( ...
                string(info.section_coincident_events.type), "L1_LO");
            testCase.verifyEqual( ...
                info.event_counts_per_leg.touchdown_count, 1);
            testCase.verifyEqual( ...
                info.event_counts_per_leg.liftoff_count, 1);
        end

        function apexDoesNotRequireAnAerialMode(testCase)
            system = createSyntheticReturnPolicySystem_v3('two-apex');
            [section, simulator] = testCase.components();
            map = PoincareMap_v3(system, section, simulator, ...
                FirstReturnPolicy_v3(), testCase.mapOptions());

            [~, info] = map.evaluate([1; 0], 0, []);

            testCase.verifyEqual(info.final_mode, 1);
            testCase.verifyTrue(section.isValidCrossing( ...
                info.return_time, info.raw_return_state, info.final_mode, ...
                [], system));
        end

        function modeResolverUsesOnlySectionNearGuards(testCase)
            system = createSyntheticReturnPolicySystem_v3('resolver');
            [section, simulator] = testCase.components();
            resolver = SectionModeResolver_v3(struct( ...
                'SectionModeTolerance', 1e-6));
            options = testCase.mapOptions();
            options.ModeResolver = resolver;
            map = PoincareMap_v3(system, section, simulator, ...
                FirstReturnPolicy_v3(), options);

            [modes, report] = map.modeCandidates([1; 0], [0; 0], []);
            [allModes, allReport] = map.allModes([1; 0], [0; 0], []);

            testCase.verifyNumElements(modes, 2);
            testCase.verifyEqual(modes{1}, logical([0; 0]));
            testCase.verifyEqual(modes{2}, logical([1; 0]));
            testCase.verifyNumElements(allModes, 4);
            testCase.verifyFalse(report.all_modes_attempted);
            testCase.verifyTrue(allReport.all_modes_attempted);
            testCase.verifyTrue(report.guards(1).eligible);
            testCase.verifyFalse(report.guards(2).eligible);
            testCase.verifyNotEmpty(report.candidates(2).reason);
        end

        function crossingAndEventLimitsAreEnforced(testCase)
            system = createSyntheticReturnPolicySystem_v3('two-apex');
            [section, simulator] = testCase.components();
            options = testCase.mapOptions();
            options.MaxSectionCrossings = 1;
            map = PoincareMap_v3(system, section, simulator, ...
                EventCycleReturnPolicy_v3(), options);

            testCase.verifyError(@() map.evaluate([1; 0], 0, []), ...
                'PoincareMap_v3:MaxSectionCrossings');
        end

        function evaluationContextTightensIntegratorTolerances(testCase)
            system = createSyntheticReturnPolicySystem_v3('two-apex');
            section = PoincareSection_v3.apex(2);
            simulator = HybridSimulator_v3(struct( ...
                'RelTol', 1e-6, 'AbsTol', 1e-8));
            map = PoincareMap_v3(system, section, simulator, ...
                FirstReturnPolicy_v3(), testCase.mapOptions());
            context = struct('suggestedRelativeTolerance', 1e-9, ...
                'finiteDifferenceStep', 1e-5, 'label', 'test-column');

            [~, info] = map.evaluateWithOptions([1; 0], 0, [], context);

            testCase.verifyEqual(info.integration_overrides.RelTol, 1e-9);
            testCase.verifyEqual(info.integration_overrides.AbsTol, 1e-10, ...
                'AbsTol', eps(1e-10));
            testCase.verifyEqual(info.evaluation_options.label, ...
                'test-column');
        end

        function localResolverTraversesInverseLiftoffChart(testCase)
            schema = QuadrupedSchema_v3.shared();
            system = Quadrupedal_Dynamics_v3();
            section = PoincareSection_v3.apex(schema.State.dy);
            map = PoincareMap_v3(system, section, HybridSimulator_v3(), ...
                FirstReturnPolicy_v3(), struct('ModeResolver', ...
                SectionModeResolver_v3(struct( ...
                    'SectionModeTolerance', 1e-8))));
            p = [10; 10; 1; 1; 1; 1; 0; 0; 2; 0.5];
            x = zeros(schema.State.Dimension, 1);
            x(schema.State.alphaFR) = 0.3;
            x(schema.State.dalphaFR) = 1;
            x(schema.State.y) = cos(0.3);
            qPostLiftoff = false(schema.Leg.Count, 1);

            [modes, diagnostics] = map.modeCandidates( ...
                x, qPostLiftoff, p);

            testCase.verifyNumElements(modes, 2);
            expectedPreLiftoff = qPostLiftoff;
            fr = find(strcmp('FR', schema.Leg.Names), 1);
            expectedPreLiftoff(fr) = true;
            testCase.verifyEqual(modes{2}, expectedPreLiftoff);
            eligibleIds = [diagnostics.guards( ...
                [diagnostics.guards.eligible]).id];
            testCase.verifyEqual(eligibleIds, schema.eventId('FR_LO'));
            testCase.verifyFalse(diagnostics.all_modes_attempted);
        end

        function quadrupedMapDefaultsDirectlyToEventCycle(testCase)
            schema = QuadrupedSchema_v3.shared();
            map = PoincareMap_v3(Quadrupedal_Dynamics_v3(), ...
                PoincareSection_v3.apex(schema.State.dy), ...
                HybridSimulator_v3());
            testCase.verifyClass(map.ReturnPolicy, ...
                'EventCycleReturnPolicy_v3');
            testCase.verifyFalse(map.ReturnPolicyWasExplicit);

            residual = PeriodicOrbitResidual_v3( ...
                map, zeros(schema.State.Dimension, 1)); %#ok<NASGU>

            testCase.verifyClass(map.ReturnPolicy, ...
                'EventCycleReturnPolicy_v3');
        end

        function genericMapDefaultsToFirstReturn(testCase)
            system = createSyntheticReturnPolicySystem_v3('two-apex');
            [section, simulator] = testCase.components();
            map = PoincareMap_v3(system, section, simulator, ...
                testCase.mapOptions());

            testCase.verifyClass(map.ReturnPolicy, ...
                'FirstReturnPolicy_v3');
            testCase.verifyFalse(map.ReturnPolicyWasExplicit);
        end

        function explicitQuadrupedFirstReturnIsPreserved(testCase)
            schema = QuadrupedSchema_v3.shared();
            map = PoincareMap_v3(Quadrupedal_Dynamics_v3(), ...
                PoincareSection_v3.apex(schema.State.dy), ...
                HybridSimulator_v3(), FirstReturnPolicy_v3());
            testCase.verifyTrue(map.ReturnPolicyWasExplicit);

            residual = PeriodicOrbitResidual_v3( ...
                map, zeros(schema.State.Dimension, 1)); %#ok<NASGU>

            testCase.verifyClass(map.ReturnPolicy, ...
                'FirstReturnPolicy_v3');
        end
    end

    methods (Static, Access = private)
        function [section, simulator] = components()
            section = PoincareSection_v3.apex(2, struct( ...
                'DerivativeTolerance', 1e-9));
            simulator = HybridSimulator_v3(struct( ...
                'RelTol', 1e-11, 'AbsTol', 1e-13, ...
                'EventValueTolerance', 1e-9, ...
                'EventTimeTolerance', 1e-10));
        end

        function options = mapOptions()
            options = struct('MaxReturnTime', 2.5, ...
                'MaxSectionCrossings', 4, 'MaxCycleEvents', 8, ...
                'ArmTolerance', 1e-7);
        end
    end
end
