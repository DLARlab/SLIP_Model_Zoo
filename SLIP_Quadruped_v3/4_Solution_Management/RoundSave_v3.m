function RoundSave_v3(file,data)
%ROUNDSAVE_V3 Atomic lossless compressed MAT checkpoint below100MB.
    file=V3OutputPath_v3(file);folder=fileparts(file);if ~isfolder(V3Path_v3(folder)),mkdir(V3Path_v3(folder));end
    temporary=[file,'.partial.mat'];save(V3Path_v3(temporary),'-struct','data','-v7');
    details=V3Dir_v3(temporary);
    if details.bytes>=100000000
        delete(V3Path_v3(temporary));error('RoundSave_v3:ArtifactSize','Checkpoint exceeded the registered100MB artifact limit.');
    end
    movefile(V3Path_v3(temporary),V3Path_v3(file),'f');
end
