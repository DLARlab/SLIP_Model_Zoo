function UpdateQuadrupedOscillators_v3(handles, time)
%UPDATEQUADRUPEDOSCILLATORS_V3 Move the shared cycle-time marker on each leg.
% TIME uses the trajectory time coordinate, including successive strides.
    if ~isgraphics(handles.Axes), return; end
    angle = 2*pi*(time-handles.StartTime)/handles.Period+handles.PhaseOffset;
    for leg = 1:numel(handles.Markers)
        if isgraphics(handles.Markers(leg))
            set(handles.Markers(leg), 'XData', handles.Center(leg, 1)+handles.Radius*cos(angle), ...
                'YData', handles.Center(leg, 2)+handles.Radius*sin(angle));
        end
    end
end
