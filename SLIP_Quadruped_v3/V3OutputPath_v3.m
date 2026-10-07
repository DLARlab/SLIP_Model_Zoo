function output=V3OutputPath_v3(output)
%V3OUTPUTPATH_V3 Canonical confinement for research files and directories.
    root=fileparts(mfilename('fullpath'));
    if ~(ischar(output)||(isstring(output)&&isscalar(output)))
        error('V3OutputPath_v3:InvalidPath','Output path must be a text scalar.');
    end
    canonicalRoot=char(java.io.File(root).getCanonicalPath());
    output=char(java.io.File(char(V3Path_v3(output))).getCanonicalPath());
    if ~startsWith(output,[canonicalRoot,filesep])
        error('V3OutputPath_v3:OutsideV3','Output must resolve inside SLIP_Quadruped_v3.');
    end
end
