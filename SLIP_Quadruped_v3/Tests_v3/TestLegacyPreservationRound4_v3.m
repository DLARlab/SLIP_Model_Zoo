classdef TestLegacyPreservationRound4_v3 < matlab.unittest.TestCase
    methods (Test)
        function restoredLegacyTreeMatchesAuditedBlobManifest(testCase)
            testsRoot = fileparts(mfilename('fullpath'));
            v3Root = fileparts(testsRoot);
            repositoryRoot = fileparts(v3Root);
            manifest = fullfile(testsRoot, ...
                'LegacyFloquetManifest_v3.tsv');
            lines = readlines(manifest);
            lines = lines(strlength(strtrim(lines)) > 0);

            testCase.verifyNumElements(lines, 70);
            for index = 1:numel(lines)
                tokens = regexp(char(lines(index)), ...
                    '^([0-9a-f]{40})\t(.+)$', 'tokens', 'once');
                testCase.assertNotEmpty(tokens, ...
                    sprintf('Malformed manifest line %d.', index));
                expected = tokens{1};
                relativePath = tokens{2};
                parts = strsplit(relativePath, '/');
                filename = fullfile(repositoryRoot, parts{:});
                testCase.assertTrue(isfile(filename), ...
                    sprintf('Missing restored legacy file: %s', relativePath));
                actual = TestLegacyPreservationRound4_v3.gitBlobHash(filename);
                testCase.verifyEqual(actual, expected, ...
                    sprintf('Legacy file changed: %s', relativePath));
            end

            restoredRoot = fullfile(repositoryRoot, 'SLIP_Quadruped', ...
                '3_Numerical_Continuation', '2_FloquetAnalysis');
            entries = dir(fullfile(restoredRoot, '**', '*'));
            testCase.verifyEqual(sum(~[entries.isdir]), 70);
        end
    end

    methods (Static, Access = private)
        function hash = gitBlobHash(filename)
            file = fopen(filename, 'rb');
            if file < 0
                error('TestLegacyPreservationRound4_v3:Read', ...
                    'Could not open %s.', filename);
            end
            closeFile = onCleanup(@() fclose(file));
            bytes = fread(file, Inf, '*uint8');
            header = unicode2native(sprintf('blob %d%c', ...
                numel(bytes), char(0)), 'UTF-8');
            digest = javaMethod('getInstance', ...
                'java.security.MessageDigest', 'SHA-1');
            digest.update(typecast(uint8(header(:)), 'int8'));
            digest.update(typecast(uint8(bytes(:)), 'int8'));
            raw = typecast(digest.digest(), 'uint8');
            hash = lower(reshape(dec2hex(raw, 2).', 1, []));
            clear closeFile
        end
    end
end
