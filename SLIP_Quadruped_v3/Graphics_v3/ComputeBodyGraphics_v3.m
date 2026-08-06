function [outlineX, outlineY, stripeFaces, vertices] = ...
        ComputeBodyGraphics_v3(bodyPose, lCom)
%COMPUTEBODYGRAPHICS_V3 Torso patch geometry for the normalized body.
%   Adapted from ComputeBodyGraphics.m in the v2 graphics toolbox.  The
%   torso is now exactly unit length and LCOM is measured from its back hip.

if ~(isnumeric(bodyPose) && numel(bodyPose) == 3 && ...
        all(isfinite(bodyPose(:))))
    error('ComputeBodyGraphics_v3:InvalidPose', ...
        'bodyPose must be [x;y;phi] or [x,y,phi].');
end
if ~(isscalar(lCom) && isfinite(lCom) && lCom > 0 && lCom < 1)
    error('ComputeBodyGraphics_v3:InvalidCOM', ...
        'lCom must lie strictly between zero and one.');
end

bodyPose = bodyPose(:);
halfHeight = 0.12;
back = -lCom;
front = 1 - lCom;
localVertices = [ ...
    back,  halfHeight; ...
    front, halfHeight; ...
    front,-halfHeight; ...
    back, -halfHeight];
rotation = [cos(bodyPose(3)), -sin(bodyPose(3)); ...
            sin(bodyPose(3)),  cos(bodyPose(3))];
vertices = (rotation * localVertices.').' + bodyPose(1:2).';
outline = vertices([1:4, 1], :);
outlineX = outline(:, 1).';
outlineY = outline(:, 2).';
stripeFaces = [1, 3; 2, 4];
end
