function inContact = round1ContactMembership(t, touchdown, liftoff)
%ROUND1CONTACTMEMBERSHIP Transcription of current production contact logic.
%   This audit-only helper intentionally preserves the strict-open interval
%   behavior used in Quadrupedal_ZeroFun_v2 and ComputeJoint_LegLA. It is not
%   a proposed canonical contact API.

    inContact = ((t > touchdown & t < liftoff & touchdown < liftoff) | ...
        ((t < liftoff | t > touchdown) & touchdown > liftoff));
end
