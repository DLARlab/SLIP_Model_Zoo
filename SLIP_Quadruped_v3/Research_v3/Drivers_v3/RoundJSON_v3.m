function RoundJSON_v3(file,value)
%ROUNDJSON_V3 Atomic, v3-confined, human-readable evidence export.
    file=V3OutputPath_v3(file);folder=fileparts(file);
    if ~isfolder(V3Path_v3(folder)),mkdir(V3Path_v3(folder));end
    temporary=[file,'.partial'];fid=fopen(V3Path_v3(temporary),'w');
    if fid<0,error('RoundJSON_v3:Write','Cannot write %s.',temporary);end
    close=onCleanup(@()fclose(fid));
    fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
    clear close;movefile(V3Path_v3(temporary),V3Path_v3(file),'f');
end
