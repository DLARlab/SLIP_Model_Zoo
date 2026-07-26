classdef TestEventTimingRegulation < matlab.unittest.TestCase
    % Characterization tests for the current circular-time implementation.

    properties (TestParameter)
        InputShape = {'row', 'column'}
    end

    properties
        RepositoryRoot
    end

    methods (TestClassSetup)
        function addRepositoryPaths(testCase)
            here = fileparts(mfilename('fullpath'));
            testCase.RepositoryRoot = fileparts(fileparts(here));
            addpath(genpath(fullfile(testCase.RepositoryRoot, 'SLIP_Quadruped')));
            addpath(fullfile(testCase.RepositoryRoot, 'tools', 'audit'));
        end
    end

    methods (Test)
        function preservesShapeAndLength(testCase, InputShape)
            timings = [0.1 0.4 0.2 0.5 0.3 0.6 0.7 0.9 1.0];
            if strcmp(InputShape, 'column')
                timings = timings.';
            end
            actual = EventTimingRegulation(timings);
            testCase.verifySize(actual, size(timings));

            stateAndTiming = [(1:13), timings(:).'];
            if strcmp(InputShape, 'column')
                stateAndTiming = stateAndTiming.';
            end
            actual = EventTimingRegulation(stateAndTiming);
            testCase.verifySize(actual, size(stateAndTiming));
        end

        function isIdempotentForPositivePeriod(testCase, InputShape)
            timings = [-1.9 2.4 0 1.0 3.3 -4.4 0.25 0.75 1.0];
            if strcmp(InputShape, 'column')
                timings = timings.';
            end
            once = EventTimingRegulation(timings);
            twice = EventTimingRegulation(once);
            testCase.verifyEqual(twice, once, 'AbsTol', 10 * eps);
        end

        function isInvariantUnderIntegerPeriodShifts(testCase)
            timings = [0.1 0.4 0.2 0.5 0.3 0.6 0.7 0.9 1.0].';
            shifts = [-3 2 1 -4 5 -6 7 -8].';
            shifted = timings;
            shifted(1:8) = shifted(1:8) + shifts * timings(9);
            testCase.verifyEqual(EventTimingRegulation(shifted), ...
                EventTimingRegulation(timings), 'AbsTol', 50 * eps);
        end

        function eventAtPeriodMapsToZero(testCase)
            timings = [1 0.4 0.2 0.5 0.3 0.6 0.7 0.9 1];
            actual = EventTimingRegulation(timings);
            testCase.verifyEqual(actual(1), 0);
            testCase.verifyEqual(actual(9), 1);
        end

        function zeroPeriodPropagatesNonfiniteTimings(testCase)
            % CHARACTERIZATION OF CURRENT DEFECT: no invalid-period error.
            timings = [0.1 0.4 0.2 0.5 0.3 0.6 0.7 0.9 0];
            actual = EventTimingRegulation(timings);
            testCase.verifyTrue(all(isnan(actual(1:8))));
            testCase.verifyEqual(actual(9), 0);
        end

        function negativePeriodIsSilentlyAccepted(testCase)
            % CHARACTERIZATION OF CURRENT DEFECT: a negative period is retained.
            timings = [0.1 0.4 0.2 0.5 0.3 0.6 0.7 0.9 -1];
            actual = EventTimingRegulation(timings);
            testCase.verifyTrue(all(isfinite(actual)));
            testCase.verifyEqual(actual(9), -1);
        end

        function nanPeriodPropagatesNaNs(testCase)
            % CHARACTERIZATION OF CURRENT DEFECT: NaN is not rejected.
            timings = [0.1 0.4 0.2 0.5 0.3 0.6 0.7 0.9 NaN];
            actual = EventTimingRegulation(timings);
            testCase.verifyTrue(all(isnan(actual)));
        end

        function infinitePeriodIsSilentlyAccepted(testCase)
            % CHARACTERIZATION OF CURRENT DEFECT: Inf period is retained.
            timings = [0.1 0.4 0.2 0.5 0.3 0.6 0.7 0.9 Inf];
            actual = EventTimingRegulation(timings);
            testCase.verifyEqual(actual, timings);
        end

        function infiniteEventPropagatesNaN(testCase)
            % CHARACTERIZATION OF CURRENT DEFECT: Inf event is not rejected.
            timings = [Inf 0.4 0.2 0.5 0.3 0.6 0.7 0.9 1];
            actual = EventTimingRegulation(timings);
            testCase.verifyTrue(isnan(actual(1)));
            testCase.verifyEqual(actual(2:end), timings(2:end));
        end

        function rejectsUnsupportedLength(testCase)
            testCase.verifyError(@() EventTimingRegulation(zeros(1, 8)), ...
                'EventTimingRegulation:InvalidInput');
        end

        function contactMembershipUsesStrictOpenIntervals(testCase)
            testCase.verifyFalse(round1ContactMembership(0.2, 0.2, 0.8));
            testCase.verifyTrue(round1ContactMembership(0.5, 0.2, 0.8));
            testCase.verifyFalse(round1ContactMembership(0.8, 0.2, 0.8));
        end

        function wrappedAndCoincidentContactMembership(testCase)
            testCase.verifyTrue(round1ContactMembership(0.9, 0.8, 0.2));
            testCase.verifyTrue(round1ContactMembership(0.1, 0.8, 0.2));
            testCase.verifyFalse(round1ContactMembership(0.5, 0.8, 0.2));
            testCase.verifyFalse(round1ContactMembership(0.5, 0.4, 0.4));
        end
    end
end
