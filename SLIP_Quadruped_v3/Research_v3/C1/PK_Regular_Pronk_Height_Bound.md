# Marked-apex height bound for exact regular pronk motion

This note derives a conditional, speed-independent bound for the native model:
the BL-marked apex height satisfies **H >= L0** in the exact class specified
below. It does not establish that a saved, tolerance-qualified PK solution
belongs to that class. It makes no present-data endpoint, grazing, branch
completion, global PK exclusion, or range-coverage claim.

The user boundary `H < 0.5*L0` remains a separate strict stopping rule for
admitted continuation points. This theorem neither changes that rule nor
changes any residual, admission tolerance, return policy, or contact law.

## Exact hypotheses

Consider one relative-periodic native cycle, with horizontal translation
removed but all other raw state coordinates periodic. Assume:

1. The torso is exactly upright throughout: `phi = dphi = 0`. All four legs
   have identical raw angles and rates, common rest length `L0 > 0`, and the
   same contact mode. The parameters preserve this invariant subspace; take
   identical positive axial stiffness `k_l` and nonnegative swing stiffness
   `k_s`. The native normalization is body mass `m = 1`, gravity `g = 1`.
2. The cycle has exactly one positive-duration all-four stance interval and
   one positive-duration all-flight interval, with genuine TD and LO at
   uncompressed length. Stance is regular, fixed-foot, compressive, and
   nontrivial: `0 < r <= L0`, compression is positive on some interval, and
   the continuous raw angle stays in one branch `cos(alpha) > 0`.
3. Resets preserve body position, body velocity, and raw leg angle. Leg
   angular-rate resets are allowed exactly as in the native model.
4. Flight is swing-foot nonpenetrating at every time, not merely at saved
   samples: `y - L0*cos(alpha) >= 0`. There are no intervening contacts,
   zero-duration mode switches, slipping anchors, or omitted contact events.
5. The marked section obeys the unchanged BL rule: the last transverse
   downward COM apex strictly before the next BL touchdown, with one BL TD
   per mode-closed return.

These hypotheses are stronger than a PK label or finite all-nine admission.
The all-flight/stance topology, continuous inequalities, exact invariance,
and raw periodicity must not be inferred from the initial apex alone.

Source basis: [flow and forces, lines 83–154](../../1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m#L83),
[fixed-foot geometry, lines 132–151](../../1_Dynamic_Frameworks/Dynamics_v3/QuadrupedPhysicalChart_v3.m#L132),
[rate-only resets, lines 50–64](../../1_Dynamic_Frameworks/Dynamics_v3/ResetMap_v3.m#L50),
[clearance and compression, lines 79–103](../../1_Dynamic_Frameworks/Dynamics_v3/QuadrupedAdmissibility_v3.m#L79),
and [BL marking, lines 2–8 and 62–80](../../4_Solution_Management/BLMarkedApexReturnPolicy_v3.m#L2).

## Speed-independent sign argument

During stance choose any leg and define its hip-relative horizontal
displacement from the fixed foot:

`xi = (x + s_i) - X_foot_i = -r*sin(alpha)`.

The upright hip offset `s_i` is constant, so `xi' = vx`. The native stance
force gives

`xi'' = A(t)*xi`, where `A(t) = 4*k_l*(L0-r)/r >= 0`.

In dimensional notation the coefficient is `4*k_l*(L0-r)/(m*r)`; the source
uses `m=1`. Regularity makes this coefficient finite and continuous on the
stance interval, and nontrivial compression makes it positive somewhere.
The horizontal force is zero in flight. Body-velocity continuity and
periodicity therefore give equal stance endpoint velocities
`xi'(TD) = xi'(LO) = V`. No lower bound on `|V|` is assumed.

For `V > 0`, an initial `xi(TD) >= 0` stays nonnegative with increasing
velocity, strictly increasing during nontrivial compression, contradicting
the equal endpoint velocities. Thus `xi(TD) < 0`. While `xi < 0`, if the
velocity first reached zero, the region `xi < 0, xi' <= 0` would retain the
trajectory forward in time; it could not recover the positive exit velocity.
After crossing `xi=0` with positive velocity, acceleration is nonnegative.
Hence `xi' > 0` throughout stance. If `xi(LO) <= 0`, the integral
`integral(A*xi dt)` would be strictly negative, again contradicting the equal
endpoint velocities. Consequently

`xi(TD) < 0 < xi(LO)`.

For `V < 0`, apply the same argument to `-xi`; the signs reverse. For `V=0`,
integration by parts gives

`-integral((xi')^2 dt) = integral(A*xi^2 dt) >= 0`.

Thus `xi` is constant; positive compression somewhere forces `xi=0`.
The excluded `A identically 0` case is not a nontrivial compressive stance.

For `V != 0`, one positive-cosine raw stance branch has an integer `j` with
`alpha(LO) < 2*pi*j < alpha(TD)` when `V>0`, with reversed inequalities when
`V<0`. Raw-angle continuity and raw periodicity force the following flight
to pass through `alpha=2*pi*j` internally. At that instant nonpenetration
requires `y >= L0`.

Flight has `y''=-1`. Its contact endpoint heights are strictly below `L0`
when `V != 0`, because the stance endpoint angles are not vertical and the
leg is uncompressed there. The flight therefore has a unique interior
downward apex with `H >= L0`. It is the last downward apex before the next
TD and hence is the marked apex. For `V=0`, the contact endpoint heights
both equal `L0`; a positive-duration ballistic flight has `H > L0`.

This proves `H >= L0` for every speed under the stated hypotheses. With
strictly positive swing clearance at every interior flight point, the bound
is strict. The proof uses no `V > sqrt(4*k_l)` work estimate, no time-reversal
symmetry of the orbit, and no swing-angle monotonicity assumption.

## Equality: clearance minimum or maximum?

For `V != 0`, exact equality `H=L0` forces the interior vertical-down swing
orientation `alpha=2*pi*j` to occur at the flight apex. Write its local time
as zero, angular speed as `a=alpha'(0)`, and swing-foot clearance as
`c(t)=y(t)-L0*cos(alpha(t))`. Then

`c(0)=c'(0)=0`, and `c''(0)=L0*a^2-1`.

The `-1` is ballistic COM acceleration; `L0*a^2` is the curvature from leg
rotation. The torsional acceleration term is multiplied by `sin(alpha)` and
therefore vanishes in this second derivative at vertical orientation.

- `L0*a^2 > 1`: a strict local clearance minimum, compatible locally with
  tangential grazing. This is necessary local evidence, not sufficient
  whole-cycle admissibility or proof of a branch endpoint.
- `L0*a^2 < 1`: a local clearance maximum at zero, with penetration on both
  sides. A stationary vertical leg (`a=0`) is in this inadmissible case.
- `L0*a^2 = 1`: second order alone is inconclusive, but the native swing law
  resolves it. In flight `alpha''=-omega^2*(alpha-alpha_eq)`, with
  `omega^2=k_s/L0^2 >= 0`. If `b=alpha''(0) != 0`, then
  `c'''(0)=3*L0*a*b != 0`, giving penetration on one side. If `b=0`,
  `c''''(0)=-L0*(a^4+4*omega^2*a^2)<0`, giving penetration on both sides.
  Thus exact two-sided nonpenetrating equality requires the first case.

These derivatives follow from [guard geometry and Lie derivatives, lines 99–137](../../1_Dynamic_Frameworks/Dynamics_v3/GuardFunctions_v3.m#L99)
and [the swing flow, lines 266–278](../../1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m#L266).
Nonnegative swing stiffness is part of the [native parameter contract, lines 159–180](../../1_Dynamic_Frameworks/Schema_v3/QuadrupedSchema_v3.m#L159).
For dimensional gravity `g`, replace the `1` in the curvature test by `g`.

## Native applicability and claim limits

Before applying this theorem to a particular frontier, retain:

- Actual source/point identity and parameters; common `L0`; exact versus
  tolerance-only upright/synchronous state and invariant-parameter facts.
  The current pronk constructor checks tolerances and keeps reference
  coordinates, so its name alone is not exact-invariance evidence:
  [EnergyFamilyResidual, lines 76–92 and 112–131](../../4_Solution_Management/EnergyFamilyResidual_v3.m#L76).
- Actual one-stance/one-flight event/cohort topology, positive durations,
  regular leg lengths/cosines/compression, raw angle branch, body-velocity
  continuity, full raw closure, energy and primitive/all-nine reports.
- Actual raw `H=y`, vertical acceleration and BL marking margins; finite
  uncertainty under unchanged independent fine profiles. A physical event's
  ordinary zero clearance is not an interior grazing witness.
- For an equality claim, the interior vertical-angle location, its distance
  from existing events, raw clearance and its first/second derivatives,
  actual contact mode, and consistency under fine integration. Saved grid
  minima do not certify continuous nonpenetration.

[GaitIdentification, lines 13–27](../../4_Solution_Management/GaitIdentification_v3.m#L13)
checks flight-count sensitivity, while its
[all-four audit, lines 244–269](../../4_Solution_Management/GaitIdentification_v3.m#L244)
explicitly describes numerical consistency rather than a general proof.
The earlier [conditional speed bound, lines 77–90](AuditC1PKRegularPronkSpeedBound_v3.m#L77)
has additional speed assumptions; this note supplies a different sign
argument, not a retrospective upgrade of that audit or of any saved point.

Outside the exact hypotheses, apex geometry alone gives no `H>=L0` bound:
at a local swing apex with `H<L0`, a sufficiently oblique leg can have
`H-L0*cos(alpha)>0`. This is only a locally admissible configuration, not a
constructed periodic BL1 counterexample. A grounded all-stance oscillation
can also have a downward apex below `L0`, but lacks the required flight and
BL touchdown return. Pitch, unequal legs, different event topology, a
different raw-angle closure rule, or loss of regularity require a separate
argument; they must not be silently included in this theorem.

A rephasing cannot remove actual penetration. Under these exact hypotheses
the flight apex is necessarily the marked last apex, so replacing it with a
grounded apex would not preserve the same marking. Any genuinely different
mode/chart handoff needs independent native qualification and explicit graph
provenance; it is not an ordinary edge obtained by relabelling a point.
