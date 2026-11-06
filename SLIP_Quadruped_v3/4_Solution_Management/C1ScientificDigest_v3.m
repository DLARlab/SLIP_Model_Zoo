function [digest,schema]=C1ScientificDigest_v3(value)
%C1SCIENTIFICDIGEST_V3 Deterministic digest of a plain scientific projection.
% Binds class, shape, realness, raw numeric bits, field order and missingness.
% Numeric bytes and length frames use little endian on every host. It does
% not decide numerical equivalence, admission, physical identity or ancestry.
% No MAT file, runtime object, callback, sparse expansion or text conversion
% of floating-point values participates in this representation.
    schema='C1-plain-scientific-digest-v1';
    engine=java.security.MessageDigest.getInstance('SHA-256');
    [~,~,nativeEndian]=computer;
    assert(ischar(nativeEndian)&&isscalar(nativeEndian)&&ismember(nativeEndian,'BL'), ...
        'C1ScientificDigest:Endian','The native byte order must be explicitly B or L.');
    bigEndian=strcmp(nativeEndian,'B');
    text(schema);walk(value,0);
    digest=lower(reshape(dec2hex(typecast(engine.digest(),'uint8'),2).',1,[]));

    function walk(v,depth)
        assert(depth<=128,'C1ScientificDigest:Depth','Projection nesting exceeds the declared bound.');
        allowed=isnumeric(v)||islogical(v)||ischar(v)||isstring(v)||iscell(v)||isstruct(v);
        assert(allowed&&~issparse(v),'C1ScientificDigest:Class', ...
            'Only dense plain numeric/logical/text/cell/struct projections are supported.');
        text(class(v));shape=size(v);count(numel(shape));frames(uint64(shape));
        if isnumeric(v)
            types={'double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64'};
            assert(any(strcmp(class(v),types)),'C1ScientificDigest:NumericClass','Unsupported numeric class.');
            bytes(uint8(isreal(v)));numeric(real(v(:)));
            if ~isreal(v),numeric(imag(v(:)));end
        elseif islogical(v)
            bytes(uint8(v(:)));
        elseif ischar(v)
            frames(uint16(v(:)));
        elseif isstring(v)
            for k=1:numel(v)
                absent=ismissing(v(k));bytes(uint8(absent));
                if ~absent,text(char(v(k)));end
            end
        elseif iscell(v)
            for k=1:numel(v),walk(v{k},depth+1);end
        else
            names=fieldnames(v);count(numel(names));
            for k=1:numel(names),text(names{k});end
            for k=1:numel(v)
                for j=1:numel(names),walk(v(k).(names{j}),depth+1);end
            end
        end
    end
    function text(v)
        assert(ischar(v)&&(isrow(v)||isempty(v)),'C1ScientificDigest:Text','Labels and string contents are character rows or empty text.');
        count(numel(v));frames(uint16(v(:)));
    end
    function count(v)
        assert(isscalar(v)&&isfinite(v)&&v>=0&&v==fix(v)&&v<=flintmax, ...
            'C1ScientificDigest:Length','The frame length is not an exactly representable nonnegative integer.');
        frames(uint64(v));
    end
    function numeric(v)
        % Do not coerce the source numeric class or canonicalize NaN/-0 bits.
        frames(v);
    end
    function frames(v)
        if bigEndian&&~ismember(class(v),{'int8','uint8'}),v=swapbytes(v);end
        bytes(typecast(v(:),'uint8'));
    end
    function bytes(v)
        if ~isempty(v),engine.update(typecast(uint8(v(:)),'int8'));end
    end
end
