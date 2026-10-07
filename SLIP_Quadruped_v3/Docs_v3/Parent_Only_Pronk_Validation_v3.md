# Parent-only pronk attachment validation

The v2 validation stage strengthens the numerical evidence for a local
attachment to vertical PIP. It does not assume either candidate is a daughter
branch, establish derivatives outside synchrony, or infer the requested global
gait network. The registered energy domain and ten physical parameters stay
fixed. During execution, old stage reports and their prediction/daughter files
were archived by filename before new results were written; none of those
states was loaded as a seed. Byte-identical archive copies and temporary test
artifacts were removed during the 2026-10-07 cleanup. The earlier root-level
`pronk_daughter_1_*.mat` and `pronk_daughter_2_*.mat` results remain as historical
research records, alongside the current v2 daughter trajectories, prediction
records, stage report and independent audit. The earlier results are superseded
by the v2 validation and do not establish an attachment certificate.

## The reduced problem and conditional theorem

At the baseline matched front/hind leg parameters and `lcom=.5`, the subspace
`phi=dphi=0`, identical four-leg angles/rates, and identical four-leg contact
modes is invariant. The spring-force pitch torques cancel there. The restriction
expresses identical leg motion; it does not assert an `S4` symmetry of the full
quadruped. The physical flight apex, after horizontal translation and phase
removal, has coordinates

\[
v=(\dot x,\alpha,\dot\alpha),\qquad
y=E-\tfrac12\dot x^2.
\]

Thus `P_E(v)` has three independent state coordinates at fixed energy. Define
`F(E,v)=P_E(v)-v`. The vertical family satisfies `F(E,0)=0`. At a simple critical
point, write `A=D_v F=DP_E-I`, with unit right and left kernels `v_*` and `w_*`.
The finite-dimensional range condition in the simple-eigenvalue theorem is

\[
w_*^T A_E v_*\ne0.
\]

This derivative includes the energy-dependent apex height and parent orbit;
it is not the derivative of a frozen-height map, and E is a conserved family
coordinate rather than a changed physical model parameter. Removing the
energy-neutral coordinate before computing this kernel prevents the structural
unit multiplier from being mistaken for symmetry breaking.

Conditional on the synchronized return chart being sufficiently smooth and
on the rank/range hypotheses holding, the local theorem gives a nontrivial
curve `v(s)=s*v_*+o(s)`. At baseline rest angles zero, horizontal reflection
combined with fore/hind exchange acts as `v -> -v` and preserves E. With the
amplitude gauge `v_*^T v=s`, uniqueness of the local curve gives
`E(-s)=E(s)` and `v(-s)=-v(s)`. If the smoothness is sufficient and the leading
nonlinear coefficient is nonzero, `E(s)-E_*=c*s^2+o(s^2)`. Numerical quadratic
scaling supports this nondegeneracy; it is not a proof of a cubic coefficient
or of the required smoothness. A degenerate local attachment can fail this
specific validation gate without being disproved.

Synchronized perturbations preserve the four-contact cluster. They can reduce
each touchdown/liftoff to one transverse guard in the invariant subspace.
Agreement of those finite differences does not establish a classical full
derivative when nonsynchronous perturbations split the contacts. That full
cluster question remains separate.

## Registered numerical evidence in version 2

`DiscoverPronkFromPIP_v3` freezes critical directions, left kernels, mixed
derivative diagnostics, validation settings, and amplitudes before correcting
any daughter trial. It scans 16 deterministic energy points and refines only
sign changes of `det(DP_E-I)`, up to the registered limit of two connections.
Even-multiplicity and tangent +1 crossings, multiple crossings inside a grid
interval, and intervals with unavailable derivatives can be missed. This is
explicitly a bounded sign-change search.

The parent derivative uses finite-difference steps `1e-4` and `5e-5`, with
internal half-step comparisons. Relative per-column error reports are converted
to absolute matrix error estimates using the column norms. The mixed derivative
uses E steps `1e-4` and `5e-5`. Its uncertainty estimate combines the difference
of those energy stencils, the endpoint matrix errors divided by the energy
step, and an estimate of critical-kernel orientation uncertainty. These are
engineering step-refinement estimates, not rigorous interval enclosures.

The support label requires all of the following numerical gates:

- Reliable central parent derivatives, a resolved one-dimensional kernel,
  and left-kernel transversality exceeding the reported error estimate.
- At least three accepted amplitudes of each sign, alignment with the parent
  critical direction, approach to the critical energy, and resolved quadratic
  energy scaling at at least two amplitudes of each sign.
- Genuine nonlinear correction at the largest registered amplitude `.01`
  on both signs. A perturbation whose initial residual already passes the
  tolerance does not satisfy this requirement by itself.
- Full physical closure at `1e-8`, a tighter independent replay, agreement of
  section-relative event signatures, and a resolved period comparison.
- Complete trajectory departure from vertical PIP, synchronized motion/contact
  histories, one TD and LO per leg, a single circular flight interval, and
  the primitive-cycle check within its declared bound.
- Agreement of paired signed apex states, energies, periods, and mean speeds
  under the proven baseline reflection action.

Solve integration uses relative/absolute tolerances `1e-11/1e-13`; replay uses
`2e-12/2e-14`. The independent root tolerance is `1e-10`. The physical closure
gate remains `1e-8`. All failed trials keep their corrected states, reasons,
derivative diagnostics and solver counters. Accepted solve and replay orbits
keep their full trajectories and event logs; only duplicated finite-difference
solver traces are summarized in checkpoints.

Nonzero drift is a phase-independent witness of lost combined reflection:
reflection reverses mean speed, whereas time phase and translation do not.
Identical paired-leg trajectories retain the two independent left/right leg
exchanges. The departure test also uses coordinates that are identically zero
along every phase of the vertical parent. These observations support a distinct
restricted orbit and its symmetry loss; they do not prove another full-system
isotropy type by a gait label.

Physical trajectory comparisons retain the first and last samples at each
event time. The simulator also records ordered simultaneous-reset intermediate
states at that same time; those virtual zero-duration rows can contain partial
contact modes and partly projected rates. They do not represent a flow interval
or break physical synchrony. `PronkTrajectoryEvidence_v3` excludes only those
internal rows and retains both physical one-sided values, every positive-duration
sample, and the complete event log. An initial v2 diagnostic mistakenly tested
all raw rows. `AuditPronkAttachments_v3` preserves the pre-audit report and
original numerical artifacts, recomputes the physical histories from saved full
replay trajectories, independently checks closure/energy/manifold residuals and
the critical matrix diagnostics, and reapplies the same registered support gates.
It does not change numerical states, predictions, or validation thresholds.

## Verification and physical-history correction

Five initial `TestPronkAttachmentEvidence_v3` tests passed under MATLAB R2025b
before the rerun. Their
independent analytic example is the scalar pitchfork, with two transverse
coordinates. They verify a resolved example and reject small-residual trials
without genuine correction, a double kernel/unresolved transversality, failed
tighter replay or contact history, and a finite-amplitude detached curve.
After the intermediate-reset-row diagnostic defect was identified during the
rerun, all six tests passed with an added check of physical one-sided synchrony
through an ordered four-leg simultaneous reset, retaining a true
positive-duration split as a counterexample.
These are status-contract tests, not quadruped branch evidence.

A physical two-point smoke check evaluated the parent derivatives at both
registered endpoint energies, `1.0001` and `3`, under the v2 integration
tolerances. Both were reliable. It requested zero refined connections and
therefore did not test or establish either critical attachment. Those temporary
test logs and smoke artifacts were removed during cleanup. The aggregate
verification record is `Research_v3/Audits_v3/final_summary.json`; physical
attachment evidence comes from the retained campaign trajectories and
independent audit described below.

## Audited outcome on 2026-10-07

The tighter stage ended with `budget_exhausted`, after approximately 910 s
inside the driver (900 s registered budget, checked between numerical calls).
The external ledger includes MATLAB/setup overhead. All 16 grid energies were
sampled, four sign-change brackets were found, the first two were refined, and
all ten signed amplitude trials at each refined point were completed. The other
two brackets were left unrefined under the registered two-connection limit.
The bounded stop status is preserved after audit.

Both refined connections pass all registered numerical support gates after
physical one-sided history reassessment. The parent kernels and mixed
derivatives were independently recomputed from the stored matrices, and saved
full replay trajectories were checked independently of their residual report.

| Quantity | First restricted attachment | Second restricted attachment |
|---|---:|---:|
| Critical E | 1.555165251642665 | 1.695950836167137 |
| Critical E uncertainty estimate | 7.49e-8 | 1.73e-7 |
| Second singular value of `DP_E-I` | 1.00429233 | 0.79094631 |
| Kernel singular value | 3.73e-9 | 1.42e-9 |
| Absolute matrix error estimate | 8.03e-8 | 1.61e-7 |
| Left-kernel transversality | 1.13160722 | 0.95344438 |
| Transversality error estimate | 4.27e-4 | 8.63e-4 |
| Accepted signed trials | 5 per sign | 5 per sign |
| Maximum full replay closure | 8.58e-12 | 1.78e-11 |
| Maximum energy error on saved replay | 1.84e-12 | 2.12e-12 |
| Maximum physical stance-constraint error | 2.64e-15 | 2.59e-15 |
| Fitted coefficient in `E-E*=c*s^2` | 0.20234464 | 0.17303931 |
| Maximum relative resolved energy-fit error | 0.00203 | 0.00125 |
| Mean-speed magnitude at `abs(s)=.01` | 0.00648547 | 0.00595473 |

All values use the model's nondimensional coordinates. The energy fits resolve
only the `.003` and `.01` amplitudes above the conservative critical-energy
uncertainty threshold. The smaller amplitudes approach the parent within that
uncertainty; their small residuals do not independently establish an exact
bifurcation limit. At `.01`, initial residuals `3.45e-7` and `5.05e-7` required
two solver iterations and decreased below `6e-16`, before tighter replay. Both
signs had genuine corrections. The paired signed states/energies/periods/speeds
agreed exactly at reported precision. The physical paired-leg motion error
over all replay one-sided histories was at most `1.73e-18`.

Each replay had one TD and LO per leg, one circular flight interval, nonzero
drift, and primitive status `primitive_within_checked_bound` with cover bound
eight. Six virtual internal reset rows per orbit caused the original raw-row
synchrony failure. The audit removed those rows from the comparison while
retaining both physical event sides, every positive-duration sample, and the
entire source trace and event log. Saved full-trajectory closure matched the
reported replay closure exactly. All original numerical states, frozen parent
predictions, and validation thresholds were preserved.

The first parent critical point has restricted multipliers approximately
`(+0.9999999912, -0.9999999906, 0)`. The additional `-1` multiplier is within
the matrix uncertainty and is a material second critical direction for
dynamical analysis. It does not enlarge the kernel of `DP_E-I` or invalidate
the conditional fixed-point attachment theorem, but it precludes claiming an
isolated one-center dynamical normal form or deciding stability from this
attachment check. A possible flip/period-two family remains unexamined. At the
second point the remaining restricted multipliers are approximately
`(-0.1905344,0)`.

## Exact resonance check and unprocessed spectral candidate

The simultaneous restricted `+1/-1` pair has an independent analytical
explanation. This derivation applies to the vertical parent at baseline p,
the synchronized pronk restriction, the physical first-liftoff law, and
`1<E<20`. Set `nu=sqrt(2*(E-1))`, `omega=sqrt(20)`,
`C=cos(omega*nu)`, and `S_f=sin(omega*nu)`. Each half-flight lasts `nu`.
At first order, fixed-energy apex perturbations have no vertical displacement,
and the vertical guard/section times have zero variation: their angle dependence
has zero derivative at alpha zero. Flight leg motion obeys
`delta_alpha_ddot=-20*delta_alpha`.

In stance, use the fixed-foot relative horizontal coordinate
`z=delta_x-delta_xi=-y*delta_alpha`. The linearized horizontal equation is

\[
z''=40\frac{1-y(t)}{y(t)}z.
\]

Let `H_E` transfer `(z,z')` over the first-liftoff stance interval. Its
Wronskian is constant, so `det(H_E)=1`. The vertical stance has
`y(t)=y(S_0-t)`, hence time-reversal of this scalar second-order equation gives
equal diagonal entries: `H_E=[[a,b],[c,a]]`. Touchdown projects the incoming
leg rate; liftoff has the same projected rate before and after its reset.
The half-flight maps and those physical projections give

\[
DP_E=L H_E B,\qquad
B=\begin{pmatrix}0&-C&-S_f/\omega\\1&0&0\end{pmatrix},\quad
L=\begin{pmatrix}
0&1\\
-C+\nu S_f/\omega&-S_f/\omega\\
\omega S_f+\nu C&-C
\end{pmatrix}.
\]

The two nonzero eigenvalues are those of `H_E B L`, where

\[
BL=\begin{pmatrix}
\cos(2\omega\nu)-(\nu/\omega)\sin(2\omega\nu)&\sin(2\omega\nu)/\omega\\
0&1
\end{pmatrix}.
\]

At odd full-flight swing phase `2*omega*nu=(2*n+1)*pi`, this is
`diag(-1,1)`. Therefore `H_E B L` has trace zero and determinant minus one,
so the restricted multipliers are exactly `(+1,-1,0)`. The spectral energies
are

\[
E_n=1+\frac{(2n+1)^2\pi^2}{160}.
\]

For `n=1`, the prediction is `1.555165247561277`, only `4.08e-9` below the
first refined numerical energy. A reconstruction of `H_E` from the stored
parent matrix reproduces the factorization within `1.10e-8`, below that
matrix's estimated error. This explains the observed simultaneous pair;
it does not certify the nonlinear attachment coefficient or a flip daughter.

For `n=0`, `E_0=1.061685027506809` is inside the registered domain and the first
coarse grid interval `[1.0001,1.1334266667]`. Its two sampled endpoint
determinants have the same sign, so the registered sign-change scan did not
refine this analytically located spectral critical point. This is a concrete
missed spectral candidate, beyond the generic warnings about an incomplete
grid. Neither its left-kernel transversality nor any daughter correction was
evaluated in the bounded campaign. The resonance at
`E_2=2.542125687670212` lies in the third, unrefined sign-change bracket.

These unprocessed observations are queued separately in
`Research_v3/parent_candidate_queue_v3.json`, together with the fourth unrefined
bracket. They are not counted as either of the two accepted numerical
attachments. The domain, cap, frozen predictions and campaign outcomes remain
unchanged; no additional daughter run is claimed.

## Scope of the local result

The recorded status for each connection is
`numerically_supported_restricted_attachment`. These are local attachments
within pronk synchrony. No transverse split-contact derivative, full-system
stability, ancestry of imported branches, coverage of other target classes,
or global network connectivity follows from them. The unrefined brackets near
`[2.46669,2.60002]` and `[2.73335,2.86667]`, tangent/even-multiplicity crossings,
and possible additional cycles remain unresolved.

The authoritative stage report is `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/Historical/pip_pk_local.json`;
`pip_pk_local_independent_audit.mat` stores the independent matrix/trajectory
audit. Separate `pronk_history_audit_*.mat` companions store corrected diagnostics
without editing the source orbit artifacts. Pre-audit reports remain under
`before_pronk_history_audit_*` for comparison. The compact numerical summary
and audit log are
`Research_v3/Audits_v3/pronk_independent_audit_summary.json` and
`Research_v3/Audits_v3/pronk_independent_v2_audit.log`.
