classdef TestEventBatchSemantics_v3 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function configurePaths(testCase) %#ok<MANU>
            v3Root = fileparts(fileparts(mfilename('fullpath')));
            folders = {'Schema_v3', 'Dynamics_v3', 'Simulation_v3', ...
                'Tests_v3'};
            for index = 1:numel(folders)
                addpath(fullfile(v3Root, folders{index}));
            end
        end
    end

    methods (Test)
        function genericFallbackExposesOrderDependence(testCase)
            system = orderedFallbackSystem();
            [x12, q12, info12] = system.resolveEventBatch( ...
                [1, 2], 0, 1, 0, []);
            [x21, q21, info21] = system.resolveEventBatch( ...
                [2, 1], 0, 1, 0, []);

            testCase.verifyEqual(x12, 3);
            testCase.verifyEqual(x21, 4);
            testCase.verifyEqual(q12, 3);
            testCase.verifyEqual(q21, 3);
            testCase.verifyNotEqual(x12, x21);
            testCase.verifyEqual(info12.semantics, ...
                "ordered-sequential-fallback");
            testCase.verifyEqual(info21.semantics, ...
                "ordered-sequential-fallback");
            testCase.verifyFalse(info12.atomic);
            testCase.verifyTrue(info12.fallback);
            testCase.verifyEqual(info12.event_states_after, {2; 3});
            testCase.verifyEqual(info21.event_states_after, {2; 4});
        end

        function quadrupedIndependentResetsCommute(testCase)
            system = Quadrupedal_Dynamics_v3();
            [x, p] = quadrupedFixture();
            q = false(4, 1);

            [forwardState, forwardMode, forwardInfo] = ...
                system.resolveEventBatch({'BL_TD', 'FR_TD'}, ...
                    0, x, q, p);
            [reverseState, reverseMode, reverseInfo] = ...
                system.resolveEventBatch({'FR_TD', 'BL_TD'}, ...
                    0, x, q, p);

            testCase.verifyEqual(forwardState, reverseState, ...
                'AbsTol', 2e-14);
            testCase.verifyEqual(forwardMode, reverseMode);
            testCase.verifyEqual(forwardMode, logical([1; 0; 0; 1]));
            testCase.verifyEqual(forwardInfo.semantics, ...
                "commuting-independent-leg-resets");
            testCase.verifyEqual(reverseInfo.semantics, ...
                "commuting-independent-leg-resets");
            testCase.verifyTrue(forwardInfo.commutativity_checked);
            testCase.verifyTrue(forwardInfo.reset_order_commutes);
            testCase.verifyTrue(forwardInfo.transition_order_commutes);
            testCase.verifyTrue( ...
                forwardInfo.independent_rate_projection_verified);
            testCase.verifyLessThanOrEqual( ...
                forwardInfo.commutativity_error, ...
                forwardInfo.commutativity_tolerance);
        end

        function coupledAtomicResetIgnoresEventPriority(testCase)
            firstPriority = AtomicBatchSyntheticSystem_v3([1, 2]);
            secondPriority = AtomicBatchSyntheticSystem_v3([2, 1]);
            simulator = HybridSimulator_v3(struct('MaxStep', 0.05));

            [trajectory12, result12] = simulator.simulate( ...
                firstPriority, 0, 0, [], [0, 1.2]);
            [trajectory21, result21] = simulator.simulate( ...
                secondPriority, 0, 0, [], [0, 1.2]);

            testCase.verifyTrue(result12.success);
            testCase.verifyTrue(result21.success);
            testCase.verifyEqual(result12.final_state, ...
                result21.final_state, 'AbsTol', 1e-12);
            testCase.verifyEqual(result12.final_mode, result21.final_mode);
            testCase.verifyEqual(trajectory12.event_batches(1).semantics, ...
                "coupled-atomic-test-reset");
            testCase.verifyEqual(trajectory21.event_batches(1).semantics, ...
                "coupled-atomic-test-reset");
            testCase.verifyEqual(trajectory12.event_batches(1).state_after, 11, ...
                'AbsTol', 1e-11);
            testCase.verifyEqual(trajectory21.event_batches(1).state_after, 11, ...
                'AbsTol', 1e-11);
        end

        function simultaneousBatchHasCompleteHistory(testCase)
            system = AtomicBatchSyntheticSystem_v3([2, 1]);
            simulator = HybridSimulator_v3(struct('MaxStep', 0.05));
            [trajectory, result] = simulator.simulate( ...
                system, 0, 0, [], [0, 1.2]);

            testCase.verifyTrue(result.success);
            testCase.verifyNumElements(trajectory.event_batches, 1);
            testCase.verifyNumElements(trajectory.event_history, 2);
            batch = trajectory.event_batches(1);
            testCase.verifyEqual(batch.time, 1, 'AbsTol', 1e-10);
            testCase.verifyEqual(batch.event_names, ...
                ["impact_2"; "impact_1"]);
            testCase.verifyEqual(batch.priorities, [1; 2]);
            testCase.verifyEqual(batch.state_before, 1, 'AbsTol', 1e-10);
            testCase.verifyEqual(batch.state_after, 11, 'AbsTol', 1e-10);
            testCase.verifyEqual(batch.mode_before, 0);
            testCase.verifyEqual(batch.mode_after, 3);
            testCase.verifyTrue(batch.batch_info.atomic);
            testCase.verifyEqual(result.physical_event_batch_count, 1);
            testCase.verifyNumElements(result.event_batches, 1);

            history = trajectory.event_history;
            testCase.verifyEqual([history.time].', [1; 1], ...
                'AbsTol', 1e-10);
            testCase.verifyEqual(string({history.type}).', ...
                ["impact_2"; "impact_1"]);
            metadata = [history.metadata];
            testCase.verifyEqual( ...
                [metadata.event_batch_index], [1, 1]);
            testCase.verifyEqual( ...
                [metadata.event_batch_position], [1, 2]);
            testCase.verifyEqual( ...
                string({metadata.event_batch_semantics}), ...
                ["coupled-atomic-test-reset", ...
                 "coupled-atomic-test-reset"]);
        end
    end
end

function system = orderedFallbackSystem()
    config = struct( ...
        'StateDimension', 1, ...
        'ParameterDimension', 0, ...
        'ModeSet', (0:3).', ...
        'StateNames', {{'x'}}, ...
        'ParameterNames', {{}}, ...
        'FlowFunction', @(t, x, q, p) 0, ...
        'ActiveGuardsFunction', @(t, x, q, p) struct([]), ...
        'ResetFunction', @orderedScalarReset, ...
        'TransitionFunction', @bitTransition);
    system = HybridSystemBase_v3(config);
end

function xplus = orderedScalarReset(eventId, t, xminus, qminus, p) %#ok<INUSD>
    if eventId == 1
        xplus = 2 * xminus;
    elseif eventId == 2
        xplus = xminus + 1;
    else
        error('TestEventBatchSemantics_v3:UnknownEvent', ...
            'Unknown ordered-fallback event.');
    end
end

function qplus = bitTransition(eventId, qminus)
    qplus = double(bitset(uint8(qminus), eventId, true));
end

function [x, p] = quadrupedFixture()
    x = [ ...
        0; 0.45; 0.90; -0.05; 0.08; 0.20; ...
        -0.10; 0.03; 0.02; -0.04; ...
        -0.10; 0.03; 0.02; -0.04];
    p = [100; 80; 4; 9; 1.0; 1.1; 0.1; -0.2; 2; 0.45];
end
