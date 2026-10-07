# Relative periodic orbits and local branching in the quadruped v3 model

These are conditional mathematical results and model-specific derivations.
They do not establish the requested gait network. The companion standalone
LaTeX source carries the same propositions and bibliography; campaign evidence
is reported separately. The research registration and model audit fix the
contact law and domain before numerical conclusions are drawn.

## Definition 1: the autonomous hybrid system

For fixed p, the system is `(Q,{Dq},{fq},{Ge},{Re},eligibility,batch rule)`.
`Q={0,1}^4` in BL,BR,FL,FR order. Dq includes physical inequalities and the
stance-rate manifold, not all of ambient `R^14`. fq is tangent to that
manifold. An eligible TD is the first descending zero of
`g_i=y+s_i sin(phi)-l0_i cos(phi+alpha_i)` while the leg swings; an eligible LO
is the first ascending zero while it stands. Re changes only the affected
angular rate, and the mode transition changes that leg's contact bit. Independent
same-time leg resets are applied as one batch. A complete trajectory records
continuous states on both event sides, modes, ordered clusters, and any
auxiliary state essential to future execution. Production v3 has no schedule
or additional history state. Single-valuedness, finite execution and regular
geometry are assumptions on the local domain; grazing/Zeno is not covered.

The default boundary convention is right-continuous: a section/contact
coincidence processes the contact batch before recording the section. Resets
need not be invertible. Thus local forward semiflows suffice for the orbit
arguments; a globally invertible smooth flow is not assumed.

## Proposition 1: physical mode coordinates and energy

Write H_i=y+s_i sin(phi), theta_i=phi+alpha_i, and
`xi_i=x+s_i cos(phi)+H_i tan(theta_i)`. On H_i>0 and cos(theta_i)>0,
`xi_dot=0` uniquely determines the stored stance rate

\[
r_i=-\dot\phi-\frac{\dot x-s_i\sin\phi\dot\phi+
(\dot y+s_i\cos\phi\dot\phi)\tan\theta_i}{H_i\sec^2\theta_i}.
\]

**Proof.** Differentiate xi and solve its affine equation in alpha_dot. Each
constraint `C_i=dalpha_i-r_i=0` has a unit derivative in its own rate variable,
so m stance rows have rank m. Body, angles and swing rates are independent;
substitution of r is a local retraction. The stance acceleration differentiates
r along fq, hence DC*fq=0. A grounded translation-gauged apex therefore has
12-m coordinates, if the apex remains transverse. xi is reconstructible and
translation-equivariant, so redundant anchors are unnecessary. The proof
fails at singular hip height or horizontal stance legs.

For finite j,
`E=0.5*(dx^2+dy^2+j*dphi^2)+y+sum_stance 0.5*k*(l0-L)^2`
is conserved. Indeed, fixed-foot kinematics gives `Ldot=d dot vHip`, with
d=(-sin(theta),cos(theta)). Spring power is -force dot vHip; body kinetic and
gravity power is the sum of force dot vHip, including torque*dphi. At TD/LO
L=l0, the added/removed spring potential is zero and body kinetic energy is
unchanged by a massless rate reset. For j=Inf, reduced energy instead obeys
`Edot=-torque*dphi`, and conservation is asserted only on dphi=0. Swing
oscillator variables have no finite body energy contribution in this model.

**Code.** `QuadrupedPhysicalChart_v3`, `QuadrupedEnergy_v3`, and
`TestPhysicalChartEnergy_v3` implement and test these contracts. A chart lift
does not establish force/clearance admissibility or event regularity.

## Definition 2: relative period, primitive period and marking

Horizontal translation acts by `rho_ell(x,q)=(x+ell*e_x,q)`; it also translates
inferred stance anchors. A relative periodic execution satisfies
`z(t+T)=rho_ell z(t)` for all t, including modes, reset-side ownership, event
sequence and auxiliary closure. Mean speed is ell/T, generally different from
initial dx. PIP additionally requires zero drift and synchronous vertical
full-state/contact motion, not just dx=0 at one apex.

The primitive relative period is the smallest positive T after horizontal
translation reduction. A shorter return combined with leg relabeling is a
spatiotemporal symmetry unless a further quotient is explicitly declared.
Repeated traversals and identical geometric traces with different contact
histories are distinct from primitive orbit identity.

The downward-apex geometry is dy=0 and ddy<0. A BL-relative mark is the last
qualifying downward apex strictly preceding a specified occurrence of BL_TD,
with no intervening BL_TD. Occurrence index, mode, orientation, section ID,
cluster ownership and return multiplicity are part of the chart. A local
chart requires that this identity persist for nearby nonperiodic states;
selection never minimizes a periodic residual. Multiple BL contacts require
explicit occurrence marking. A fixed event-phase shooting gauge is a
different object from a state-defined section.

## Assumption A: regular itinerary neighborhood

There is an open neighborhood in independent physical section coordinates
on which the same finite eligible itinerary, marked return and mode closure
persist. Flows, domains, guards and resets are C^r, r>=1; every encountered
event and the selected section are transverse; geometry is regular and no
other earlier enabled guard intrudes. For simultaneous events, this assumption
applies only after an appropriate regular extension is established. Smoothness
on the synchrony submanifold alone is not enough for split-event directions.

## Proposition 2: local return regularity

Under A with isolated events, the marked return is C^r.

**Proof.** If `g(phi_q(t,x))=0` at a transverse event, the implicit-function
theorem gives a local C^r event time tau(x), with

\[
D\tau=-\frac{Dg\,D_x\varphi_q}{Dg\,f_q}.
\]

Compose the variable-time flow, reset and next mode, finitely many times;
apply the same argument to the terminal section time. Then compose chart
lifts, translation reduction and chart extraction. Each operation is C^r
on its stated open domain, so their composition is C^r. This derivation
uses no inverse reset.

At a cluster, feasible split itineraries can have different selection
derivatives. A continuous finite selection representation with sufficiently
smooth extensions yields a piecewise derivative, with its order cone;
zeroth-order compatibility must be checked first. Burden et al.'s result
requires event-selected vector fields with uniformly transverse event
functions and smooth extensions on an open common domain. A reset model on
different physical manifolds does not satisfy those assumptions merely by
using deterministic tie-breaking; an embedding or direct extension argument
is required. [Primary source, definitions 1–2 and theorem 3](https://arxiv.org/html/1407.1775v3).

## Proposition 3: fixed points and complete periodic executions

Assume A, a single-valued execution, translation equivariance, a consistent
mark and a cycle domain which selects the specified primitive return.
Fixed points of the translation-reduced marked map correspond to primitive
relative periodic executions in that domain.

**Proof.** A fixed point closes independent coordinates; the physical lift
reconstructs dependent rates, section/gauge close, and the policy checks mode,
events and auxiliary closure. The unreduced terminal state differs only by
ell in x. Autonomy and equivariance allow successive forward copies shifted
by ell, so the execution repeats relatively. The cycle-domain minimality
assumption excludes shorter complete returns. Conversely, a primitive relative
periodic execution meeting this mark returns after its declared primitive
cycle; subtracting its drift and extracting the same chart returns the
initial coordinates. This proves both directions without invertibility.

**Limitation.** One TD and LO per leg plus mode closure alone does not prove
minimality. `EventCycleReturnPolicy_v3` supplies a complete-event contract;
an independent primitive-period check remains necessary. If it selects an
iterate, fixed points also include repeated covers. Squaring a return map
turns a -1 multiplier into +1, so a repeated cover can create a false ordinary
branching signal.

## Proposition 4: actual symmetries and transported section actions

At arbitrary admissible p, independent BL/BR and FL/FR exchanges preserve
flows, domains, guards, resets and batch rules: paired parameters and hip
offsets coincide. These generate `C2 x C2`. Horizontal translation is a
continuous symmetry. The torso geometry generally excludes S4.

At l_com=.5, equal front/back stiffnesses and lengths, and
rsla_b=-rsla_f, the combined horizontal reflection/fore-hind swap is also a
symmetry: `x,dx,phi,dphi,alpha_i,dalpha_i` change sign and the front/back
labels exchange. Substitution in hip geometry, forces, torque, swing law,
guards and rate projection proves compatibility; compression and clearance
are preserved. For unequal parameters this is at most a mapping between
models, not a fixed-p symmetry. A pure fore/hind permutation is not assumed.
Time reversal has not been proved: noninvertible rate projection at TD makes
a global reversal inference invalid.

**Proof of solution transport.** Apply a valid symmetry to each continuous
segment; equivariant fq satisfies the transformed ODE. Equivariant guards and
eligibility select the transformed event, and equivariant resets/batches give
the transformed post-state. Induction gives the whole admissible solution.

If a symmetry preserves a marked section and policy, uniqueness gives
`P*A_g=A_g*P`. Otherwise use the phase-transport chart map J_g, defined by
following the transformed solution to the corresponding marked occurrence.
On overlap where that identity is unchanged, maps obey the corresponding
conjugacy `P_g=J_g*P*J_g^{-1}`. Proving a coherent action on one chart requires
consistent occurrence and phase composition; BL marking alone supplies no
automatic global equivariance.

Define spatiotemporal isotropy on the translation-reduced complete orbit by
`H={ (g,theta): g*zbar(t)=zbar(t+theta*T) for every t }`.
Pointwise spatial isotropy has theta zero; reversing symmetry is separate.
Equal TD timings do not establish full-state isotropy. Report symmetry loss
by subgroup inclusion up to conjugacy only after full-state/mode transport is
verified. Maximal isotropy does not imply a unique root family.

## Proposition 5: independent local branching

For a centered parent family `F(0,mu)=0`, suppose F is C^2 on an open
neighborhood in independent residual coordinates. Let `L=D_u F(0,mu*)` be
Fredholm index zero with one-dimensional kernel span(v) and cokernel, and
require `D_mu,u F*v` outside Range(L). Then a nontrivial local solution curve
exists with leading state direction v. These are a sufficient, deliberately
strong regularity version of the centered Crandall–Rabinowitz hypotheses;
their theorem 1.7 has more specific partial-derivative requirements.
[Original paper, theorem 1.7](https://jxshix.people.wm.edu/2013-taiwan/crandall-rabinowitz-1971-JFA.pdf).

**Proof sketch.** Split u=a*v+w using a kernel complement and split the
codomain into range and cokernel. The range equation determines w(a,mu)
by the implicit-function theorem. Dividing the scalar cokernel equation by
a extends at a=0; transversality makes its derivative in mu nonzero. A second
implicit-function argument gives mu(a) and w(a,mu(a)).

A pitchfork needs more: an involution acting by a->-a on the critical sector,
compatible residual equivariance, and sufficient higher regularity with
nonzero coefficients in `a*(c*(mu-mu*)+d*a^2+...)`. c*d nonzero gives the
quadratic parameter-amplitude scaling and the two reflected daughters.
A +1 multiplier alone verifies none of these coefficients or regularity
hypotheses. At event-order boundaries, a C^2 extension in the daughter
directions must be proved, or the result remains a nonsmooth candidate.

For a multi-dimensional critical space K, the same range reduction leaves
an equation `Psi(a,mu)=0` in K with its induced group representation.
Decompose into symmetry sectors and evaluate its nonlinear coefficients;
one-dimensional simple-branch conditions do not apply to the entire K.
Restricting to a fixed-point sector is justified only if the residual/map
actually preserve it and the restricted kernel/cokernel satisfy the theorem.
The protected P1 reference reports three tangent-free b/f/h critical modes;
six corrected historical rays are numerical evidence in that model, not an
automatic simple-eigenvalue theorem or autonomous v3 discovery.

## Linearization and structural neutral directions

For an isolated transverse autonomous reset event, varying its event time
and comparing perturbed executions at a common post-event time yields

\[
S=DR+\frac{(f^+-DR f^-)n^T}{n^T f^-},\qquad n=\nabla g.
\]

This assumes differentiable guards/resets, transversality and a stable local
event sequence; the reset Jacobian alone misses timing sensitivity.
[Kong et al., sections III-A–III-C](https://arxiv.org/html/2306.06862v3).

Compose flow variational matrices and saltations in chronological order.
Apply the terminal section correction
`PiSigma=I-f*nSigma'/(nSigma'*f)` once, followed by the actual translation
gauge and physical coordinate extraction. Inject initial perturbations using
the derivative B of the physical lift. If event times have already been
redetected in a finite difference of the return map, do not apply a second
timing correction. Physical mode dimensions can change across events;
ambient variational extensions must ultimately restrict to physical tangent
spaces, not be interpreted as independent stored-rate directions.

For regular augmented shooting guard equations H(x,tau)=0,
`D_x tau=-H_tau^{-1}H_x` and
`D_x F_eff=F_x-F_tau H_tau^{-1}H_x`. Use that same lift for critical directions.
Eigenvalues of the joint shooting residual Jacobian are not Floquet multipliers.

When `E(P(u))=E(u)` and DE is nonzero, differentiating gives
`DE*DP=DE`: energy supplies a structural left unit eigenvector. A differentiable
fixed-p family of fixed points also has `DP*u_s=u_s`; varying p adds a P_p
term and does not automatically create a state-only right neutral vector.
Phase and horizontal translation are removed by the section and gauge.
On a fixed-energy chart, remove one coordinate and one dependent closure
equation using rank, rather than append an energy equation to redundant
periodicity equations. Never remove a chosen number of eigenvalues nearest 1.

At clusters retain each feasible cone-dependent selection derivative if
continuity and piecewise regularity hold. Commuting instantaneous resets alone
do not show equality of flow/time-sensitivity products or C^2 smoothness.
Separate selection spectra alone do not establish stability of a sequence of
cone transitions; a common contraction norm is a sufficient alternative.

## Exact vertical benchmark and limitations

At baseline p, w=sqrt(40), yeq=.975 and a=.025. For E>1, set
v=sqrt(2*(E-1)) and theta=atan2(v/w,a). First-LO stance duration is
`(2*pi-2*theta)/w`; flight is 2*v. Scheduled histories add
`n*2*pi/w`. Positive leg length requires `1<E<20`. Every n>=1 requires
missing the first eligible LO and a tensile stance interval. Therefore these
delayed histories cannot be copied into the compressive autonomous model.
At E->1 their limits are multiple covers of a grazing all-stance oscillator,
not proved regular connections. The full derivation is in the model audit.

Local theorems cannot imply global connectivity, unique maximally symmetric
roots, exhaustive class/orbit discovery or dynamic stability. Disconnected
components, higher primitive periods, additional symmetry types, secondary
bifurcations and singular boundaries remain possible. Numerical absence
within the registered budget is unresolved. A complete H_global claim would
need substantial additional global certification.

## Verified primary literature

The following originals were inspected online on 2026-10-07. No cited source
proves a quadruped gait network.

1. M. G. Crandall and P. H. Rabinowitz, *Bifurcation from Simple Eigenvalues*,
   Journal of Functional Analysis 8 (1971), 321–340. DOI
   [10.1016/0022-1236(71)90015-2](https://doi.org/10.1016/0022-1236(71)90015-2).
   Theorem 1.7, pp. 325–326; sufficient C^2 formulation above.
2. N. J. Kong, J. J. Payne, J. Zhu and A. M. Johnson, *Saltation Matrices:
   The Essential Tool for Linearizing Hybrid Dynamical Systems*, Proceedings
   of the IEEE 112(6) (2024), 585–608. [Author manuscript](https://arxiv.org/html/2306.06862v3),
   equation 9 and event assumptions 11.
3. S. A. Burden, S. S. Sastry, D. E. Koditschek and S. Revzen,
   *Event-Selected Vector Field Discontinuities Yield Piecewise-Differentiable
   Flows*. [Author manuscript](https://arxiv.org/html/1407.1775v3), definitions
   1–2 and theorem 3. Its discontinuous-vector-field domain is not a blanket
   theorem for arbitrary noninvertible resets or grazing.
