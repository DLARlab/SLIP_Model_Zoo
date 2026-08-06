classdef LegacyEventAdapter_v3
    %LEGACYEVENTADAPTER_V3 Map legacy and v3 event IDs through names.

    methods (Static)
        function newIds = toV3(oldEvents)
            oldNames = LegacyEventAdapter_v3.oldEventNames();
            names = LegacyEventAdapter_v3.toNames(oldEvents, oldNames, ...
                'legacy');
            schema = QuadrupedSchema_v3.shared();
            newIds = zeros(size(names));
            for i = 1:numel(names)
                newIds(i) = schema.eventId(names{i});
            end
            newIds = LegacyEventAdapter_v3.restoreVectorShape( ...
                newIds, oldEvents);
        end

        function oldIds = fromV3(newEvents)
            schema = QuadrupedSchema_v3.shared();
            names = LegacyEventAdapter_v3.toNames( ...
                newEvents, schema.Event.Names, 'v3');
            oldNames = LegacyEventAdapter_v3.oldEventNames();
            oldIds = zeros(size(names));
            for i = 1:numel(names)
                oldIds(i) = find(strcmpi(names{i}, oldNames), 1);
            end
            oldIds = LegacyEventAdapter_v3.restoreVectorShape( ...
                oldIds, newEvents);
        end

        function names = normalizedNames(events, convention)
            if nargin < 2 || isempty(convention)
                convention = 'v3';
            end
            switch lower(strrep(char(convention), '_', '-'))
                case 'v3'
                    schema = QuadrupedSchema_v3.shared();
                    catalog = schema.Event.Names;
                case {'legacy', 'v2'}
                    catalog = LegacyEventAdapter_v3.oldEventNames();
                otherwise
                    error('LegacyEventAdapter_v3:InvalidConvention', ...
                        'Convention must be "v3" or "legacy".');
            end
            names = LegacyEventAdapter_v3.toNames( ...
                events, catalog, char(convention));
        end
    end

    methods (Static, Access = private)
        function names = oldEventNames()
            names = { ...
                'BL_TD', 'BL_LO', 'FL_TD', 'FL_LO', ...
                'BR_TD', 'BR_LO', 'FR_TD', 'FR_LO'};
        end

        function names = toNames(events, catalog, convention)
            if ischar(events) || (isstring(events) && isscalar(events))
                events = {char(events)};
            elseif isstring(events)
                events = cellstr(events);
            end
            if iscell(events)
                names = cell(size(events));
                for i = 1:numel(events)
                    if ~(ischar(events{i}) ...
                            || (isstring(events{i}) && isscalar(events{i})))
                        error('LegacyEventAdapter_v3:InvalidEvent', ...
                            'Event names must be text scalars.');
                    end
                    index = find(strcmpi(char(events{i}), catalog), 1);
                    if isempty(index)
                        error('LegacyEventAdapter_v3:InvalidEvent', ...
                            'Unknown %s event "%s".', ...
                            convention, char(events{i}));
                    end
                    names{i} = catalog{index};
                end
                return;
            end
            if ~(isnumeric(events) && isreal(events) ...
                    && all(isfinite(events(:))) ...
                    && all(events(:) == fix(events(:))) ...
                    && all(events(:) >= 1) ...
                    && all(events(:) <= numel(catalog)))
                error('LegacyEventAdapter_v3:InvalidEvent', ...
                    '%s event IDs must be integers from 1 through 8.', convention);
            end
            names = reshape(catalog(double(events(:))), size(events));
        end

        function values = restoreVectorShape(values, source)
            if ischar(source) || (isstring(source) && isscalar(source))
                values = values(1);
            elseif isnumeric(source) && isvector(source)
                values = reshape(values, size(source));
            end
        end
    end
end
