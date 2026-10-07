# Model equivalence audit: analytic contracts and replay gate

## Complete model identities

The intended autonomous model is
`v3-autonomous-first-directed-root-compressive-stance`. It enables TD exactly
for swing legs, LO exactly for stance legs, takes the earliest directed root,
and rejects accepted tensile stance and swing penetration. `HybridSimulator_v3`
owns root detection, atomic contact batches, pre/post-event records and
right-continuous section ownership. A gait name never determines events.

The protected legacy `Quadrupedal_ZeroFun_v2.m` instead sorts eight
orbit-specific contact times plus the cycle endpoint. Midpoint tests in each
scheduled interval choose contact mode; integration stops at those times even
if an eligible geometric root occurs earlier. It then projects a contacting
leg rate. This is a scheduled shooting problem. The parameter vector and
continuous equations alone do not turn it into the same autonomous hybrid
system on `(x,q)`.

The v3 parameter conversion is explicit:
`k_l_b=2*k*kr/(1+kr)`, `k_l_f=2*k/(1+kr)`, both swing stiffnesses `ks`, both
lengths `l`, pitching inertia `J`, and COM location `lb`. `v2-exact` sets both
rsla to zero because legacy parsed but did not use osa; `semantic-rsla`
activates osa. When osa is zero these coincide. Neither policy certifies
guard enablement, root selection, reset ownership or complete contact history.

## Component comparison and first-divergence criteria

| Contract | Required equality after schema mapping | Established analytically / executable check |
|---|---|---|
| State/mode order | old BL,FL,BR,FR -> BL,BR,FL,FR | Existing adapters are explicit permutations; schema/adapters tests exercise round trips |
| Parameters | physical values from each column, including front/back stiffness | Explicit adapter above; names are not evidence of values |
| Continuous body force/GRF | same lengths, axial forces, force directions and torque at same physical `(x,q,p)` | v3 equations are independently derived; pointwise comparisons cannot establish event equivalence |
| Swing law | same relative-angle equation and rest angle | v2-exact matches inactive-osa law; semantic-rsla changes nonzero-osa fixtures |
| Stance flow | same fixed-foot angular rates/accelerations on mode manifold | Existing tangency tests and new `TestPhysicalChartEnergy_v3`; off-manifold flows are not physical comparisons |
| Guards and direction | same zero surface and enabled descending TD / ascending LO | v3 uses state roots; legacy shooting may schedule either orientation |
| First root / eligibility | no earlier eligible root omitted | Must compare complete forward event logs; scheduled residual zero alone is insufficient |
| Reset values and ownership | affected rate projection, unchanged body state, simultaneous batch and same one-sided convention | Independent affected-leg rate projections commute; this does not prove full-flow derivative commutation |
| Domain | positive length, compression, nonpenetration, complementarity | Legacy accepts tensile intervals; v3 accepted-state checks reject them |
| Full cycle | states, modes, auxiliary closure, primitive period, drift and event word | Must independently replay and align phase/translation; no equivalence from one apex sample |

Each replay must preserve the original scheduled event log and the autonomous
event log. Its first divergence is the earliest of: initial invalid mode
domain; initial stance constraint violation; extra autonomous event; missing
scheduled event; guard sign/orientation mismatch; reset/state mismatch; or
closure failure. If initial state is already invalid, later event differences
are secondary diagnostics rather than a first-event certificate.

## Representative-family gate

| Source family | Source-specific comparison requirement | Initial evidence status (before current campaign replay) |
|---|---|---|
| ordinary PIP | exact vertical first-root cycle; all-four contacts | Analytically compatible for `1<E<20`; runtime threshold study required |
| P1 PK (`PK_20_2`) | compare all events, relative drift, rates and GRF | Existing v3 pronking fixture replay; does not certify every column or critical space |
| BD (BE/BG) | same mapped state/mode and all extra roots | Existing v3 positive-clearance BG regression rejects tensile stance; campaign samples determine first divergence |
| HB_front (FE/FG) | front spread and hind pairing; never swap F/H semantics | Scheduled asymmetric fixtures require replay; no imported label acceptance |
| HB_hind (HE/HG) | hind spread and front pairing | Same gate; fore/hind interchange requires fixed-p symmetry proof |
| GP (GE/GG) | complete four-leg history and primitive identity | Scheduled asymmetric fixture compatibility unresolved until replay |
| delayed PIP | additional continuous stance oscillator revolution | Analytically incompatible with compressive first-LO v3 law at every positive flight amplitude |
| `PK_B2_Parent` | distinct from P1 PK until connected; inspect all modes/GRF | Protected phase audit reports tensile records and extra roots; campaign must not import ancestry |
| B2 G / B2 E | same cycle after legitimate phase/gauge transport | Protected comparison reports equivalent apex views; v3 replay acceptance is separate |

Campaign-generated machine-readable compatibility tables and trajectories
supersede the initial evidence column only for their actual sampled columns.
An untested source column remains untested. A corrector finding a nearby
different admissible v3 orbit proves a v3 solution, not exact legacy replay.

The protected phase audit reports 1283/1358 B2 columns with extra swing guard
crossings, 164 with positive scheduled TD derivative, and 542 with tensile
vertical GRF. Those are historical counts, not a new exhaustive v3 scan.
They motivate the event-by-event gate. A fixed autonomous eligibility rule
would need explicit phase/history state to suppress orbit-dependent roots;
retaining a contact clock/oscillator phase would create a distinct augmented
model, whose additional state must close and be included in symmetry and
linearization. Such a model is not implemented here as an implicit fallback.

## Physical contact-mode manifold

Let `H_i=y+s_i sin(phi)`, `theta_i=phi+alpha_i`. On the chart `H_i>0` and
`cos(theta_i)>0`, a stance anchor is

\[
\xi_i=x+s_i\cos\phi+H_i\tan\theta_i.
\]

Differentiation gives

\[
\dot\xi_i=\dot x-s_i\sin\phi\dot\phi
 +(\dot y+s_i\cos\phi\dot\phi)\tan\theta_i
 +H_i\sec^2\theta_i(\dot\phi+\dot\alpha_i).
\]

Thus the independent stance constraint is

\[
C_i=\dot\alpha_i-r_i=0,\qquad
r_i=-\dot\phi-
\frac{\dot x-s_i\sin\phi\dot\phi+
(\dot y+s_i\cos\phi\dot\phi)\tan\theta_i}{H_i\sec^2\theta_i}.
\]

For mode q with m stance legs, the m constraint rows are independent because
each has derivative one with respect to its own stored stance rate and no
other stored leg-rate dependence. The mode manifold has dimension `14-m`.
Fixing horizontal translation and a regular apex gives dimension `12-m`,
provided those two constraints are independent of the stance rows. Flight
therefore has 12 physical section coordinates; all-stance apex has eight.
Additional energy or symmetry restrictions reduce dimension further when
their gradients have the required rank.

`QuadrupedPhysicalChart_v3` keeps all body/angle/swing-rate coordinates and
reconstructs the stance rates with r. `retract` is explicit and idempotent;
`create` rejects an off-manifold reference instead of silently changing it.
`lift` supplies admissible perturbations in a mode chart, `tangentBasis`
differentiates that lift with a step-halving diagnostic, and `flowTangency`
checks `DC*f` and `Dxi*f`. Physical geometry remains a separate admissibility
gate: a valid chart is not a proof of positive forces or clearance.

The stance flow sets `alpha_dot=r` and on `C=0` its acceleration satisfies
`dalpha_dot=Dr*f`, so `DC*f=0`. Existing formulas use a stored back-leg rate
inside acceleration before replacing the angle derivative; this extension
away from `C=0` is not a physical extra degree of freedom. Perturbing stored
stance rates independently can produce artificial return directions. At TD
the reset projects onto the new constraint manifold; at LO the projected
pre-event rate remains a legitimate swing initial rate. Body variables are
continuous. Independent same-time affected-leg reset maps commute because
their projection r depends only on body variables and that leg's angle.

Anchors need not be stored redundantly: xi is reconstructed from `(x,p)` and
is constant along stance. Horizontal translation `x -> x+ell` implies
`xi -> xi+ell`. On the downward-leg chart alpha can also be recovered locally
from `atan((xi-x-s cos(phi))/H)-phi`. The representation fails at zero hip
height/leg length and horizontal legs; changing inverse-tangent branches is a
chart change, not a hidden continuation fallback.

## Mechanical energy and infinite inertia

For finite j, define

\[
E_q=\tfrac12(\dot x^2+\dot y^2+j\dot\phi^2)+y+
\sum_{q_i=1}\tfrac12k_{l,i}(l_{0,i}-L_i)^2.
\]

On the fixed-foot manifold `Ldot_i=d_i dot v_Hi`, where
`d_i=(-sin(theta_i),cos(theta_i))`. The stance spring derivative is
`-lambda_i Ldot_i=-f_i dot v_Hi`. Kinetic-plus-gravity derivative is
`sum f_i dot v_Hi`, because `tau*dphi` is exactly the hip rotational power.
These cancel. TD/LO occurs at `L_i=l0_i`, so the entering/leaving spring has
zero potential; the massless rate reset does not change body kinetic energy.
Consequently E is conserved across every regular directed transition and
independent simultaneous zero-compression batch. No swing oscillator energy
is added: its infinitesimal inertia/stiffness scale does not produce a finite
reaction torque or energy term in these body equations.

At `j=Inf`, the implementation sets `ddphi=0`. The finite-j expression is
undefined for nonzero dphi and must not be evaluated as `Inf*0`. The reduced
body/translational-plus-spring energy satisfies
`Edot_reduced=-tau*dphi`. It is conserved on the invariant `dphi=0` subspace
but generally not for a spinning torso. `QuadrupedEnergy_v3` reports this
identity and applicability explicitly. If pitch is an unwrapped real
coordinate, relative periodic closure at infinite j requires `dphi*T=0`, hence
dphi zero. If pitch is instead quotiented modulo `2*pi`, a rotating variant
needs a separately declared winding convention and does not inherit this
conservation claim automatically.

## Exact delayed-history obstruction

At baseline p and vertical synchrony, stance obeys
`yddot=40(1-y)-1`, flight `yddot=-1`. Set
`w=sqrt(40)`, `yeq=39/40`, `a=1/40`,
`v=sqrt(2(E-1))`, `theta=atan2(v/w,a)`. After descending TD at y=1,

\[
y(t)=y_{eq}+a\cos(wt)-(v/w)\sin(wt).
\]

Its first ascending y=1 root has duration
`S0=(2*pi-2*theta)/w`; the flight duration is `2*v`. Appending n complete
stance revolutions gives

\[
T_n(E)=\frac{2\pi-2\theta}{w}+2v+n\frac{2\pi}{w}.
\]

Minimum y is `yeq-sqrt(a^2+2(E-1)/40)`, so positive leg length requires
`1<E<20`. For every n>=1 and E>1, the extra revolution includes
`ymax=yeq+sqrt(a^2+2(E-1)/40)>1`, hence tensile stance. More immediately,
the autonomous law has already executed LO at S0. Delaying it requires
suppression of an eligible transverse root. These are complete contact-history
differences, not multiple complete cycles: each scheduled Tn has one flight
interval and extra stance oscillations.

At E decreasing to 1, `Tn -> (n+1)*2*pi/w`, while the common all-stance
geometric oscillator has minimal period `2*pi/w`. Event transversality
vanishes and the delayed representation becomes a multiple cover. This proves
a specific incompatibility and explains the shared grazing limit. It does
not prove no route can leave vertical synchrony and connect admissible
families elsewhere.

## Executed contract audit

The historical `TestPhysicalChartEnergy_v3` suite ran under MATLAB R2025b and
all six tests passed. Test sources and generated test logs were removed during
the 2026-10-07 cleanup; the aggregate verification record is retained in
`Research_v3/Audits_v3/final_summary.json`.
The tests cover all 16 mode dimensions/explicit lift closure; four-leg flow
tangency and translated anchors; tangent matrix actions; finite-j energy
in every mode; TD/LO zero-compression energy jumps; and infinite-j power
balance with/without dphi. This establishes local contracts, not a physical
branch network or unrestricted contact-cluster regularity.

Eight further `TestResearchNumericalContracts_v3` tests passed after review
of the energy-family and Floquet integration. They independently exercise
grounded default dimension/eigenvector lift, rejection of stored-rate bases,
physical-coordinate treatment of manifold curvature, explicit chart options,
energy-pivot chart failure, pronking invariance requirements, rank-deficient
continuation rejection, and rejection of a small independent residual with
failed full physical closure. The chart identity-map cases are synthetic,
not actual grounded periodic quadruped evidence. Two checkpoint tests also
passed: `CompactResearchBranch_v3` preserves complete primary trajectories
and rejected states/reasons while summarizing duplicate diagnostic traces
without mutating handle orbits. These are recorded execution facts; the
removed test harness is not required by the physical-chart or energy services.

Six `TestPronkAttachmentEvidence_v3` tests subsequently passed, bringing this
agent's targeted contract tests to 22. A two-point physical parent-map smoke
check under tighter integration also returned reliable derivatives at both
registered energy endpoints; it intentionally refined no connections. The
v2 validation gates and their conditional interpretation are specified in
`Parent_Only_Pronk_Validation_v3.md`. These checks do not validate the later
critical-point campaign or establish a quadruped attachment by themselves.
