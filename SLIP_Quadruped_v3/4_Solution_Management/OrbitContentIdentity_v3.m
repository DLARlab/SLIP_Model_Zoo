function identity=OrbitContentIdentity_v3(orbit)
%ORBITCONTENTIDENTITY_V3 Label-independent exact numerical record identity.
% This does not decide whether differently stored/rounded records represent
% the same physical cycle. Sampling separately checks numerical duplicates.
    schema=QuadrupedSchema_v3.shared();x=orbit.initial_state(:);x(schema.TranslationIndex)=0;
    values=[x;double(orbit.initial_mode(:));orbit.parameter(:);orbit.period;orbit.stride_displacement(:)];
    bytes=unicode2native([sprintf('%.17g,',values),char(orbit.return_policy_name)],'UTF-8');
    digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
    raw=typecast(digest.digest(),'uint8');hash=lower(reshape(dec2hex(raw,2).',1,[]));
    identity=['native-orbit-record:sha256:',hash];
end
