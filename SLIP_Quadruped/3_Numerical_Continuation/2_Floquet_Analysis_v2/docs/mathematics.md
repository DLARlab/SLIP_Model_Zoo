# Mathematical foundation

This document defines the objects computed by Floquet v2 and the evidence
needed to turn a spectral event into a daughter-branch claim. The existing
hybrid dynamics and its event-time solver are reused without modification.

## Reduced apex Poincare map

The integrated dynamics include a horizontal position coordinate. Horizontal
translation is a continuous symmetry, so that coordinate is absent from the
stored 13-state model vector `X`. The oriented apex section is

\[
\Sigma=\{X:\dot y=0,\ \ddot y<0\}.
\]

The equality fixes `X(3)=dy`, the section-normal coordinate. The inequality
selects the descending apex crossing and prevents mixing the two orientations
of `dy=0`. A chart on the independent section coordinates is

\[
q=\pi_\Sigma(X)=X([1,2,4{:}13])\in\mathbb R^{12}.
\]

For fixed physical parameters \(p\), let \(E(q,p)\in\mathbb R^9\) be the
event times determined by the production timing equations, and let
\(\Phi\) denote the complete hybrid stride. The implemented return map is

\[
P_\Sigma(q;p)=
\pi_\Sigma\!\left(\Phi(X(q),E(q,p);p)\right).
\]

For a periodic orbit \(q^\star=P_\Sigma(q^\star;p)\), the Floquet matrix and
multipliers are

\[
M=DP_\Sigma(q^\star;p)\in\mathbb R^{12\times12},
\qquad \lambda_j\in\operatorname{eig}(M).
\]

Only this reduced state-return derivative is diagonalized. Neither physical
parameters nor event times are appended to `M`.

## Event-time response is implicit in the map

Hybrid event times change when the section state changes. If the timing
equations are written as

\[
G(q,E;p)=0,
\]

then, wherever the implicit-function assumptions hold,

\[
DE(q;p)=-G_E^{-1}G_q.
\]

Floquet v2 does not form this expression. For every positive and negative
state perturbation, it calls the normal production entry point and lets the
existing solver determine the appropriate event times. The resulting timing
response is therefore included in \(DP_\Sigma\), but `E` is not a Floquet
state.

This distinction is essential. Diagonalizing a Jacobian in `[X;E]` would
measure the conditioning of a chosen algebraic periodic-orbit formulation,
not stride-to-stride state growth on the Poincare section.

Event times return later in branch switching. A state direction induces a
timing direction, and the nonlinear corrector uses the complete periodic-orbit
variables `[X;E]`. That does not change the definition of `M`.

## Scaled central finite differences

For relative levels \(\eta_1>\cdots>\eta_L>0\) and positive state scales
\(s_i\), the coordinate steps are

\[
h_{i\ell}=\eta_\ell\max(|q_i|,s_i),
\]

subject to a machine-precision-based minimum absolute step. Each column is
computed by

\[
M_i(h_{i\ell})=
\frac{P_\Sigma(q+h_{i\ell}e_i)-
      P_\Sigma(q-h_{i\ell}e_i)}{2h_{i\ell}}.
\]

`floquet.computeFDM` requires at least two distinct levels and selects the
finest central matrix only after validation. It reports:

- successive Frobenius-relative matrix changes;
- successive relative changes for every derivative column;
- an \(O(h^2)\) Richardson error estimate from the two finest levels;
- observed central-difference order when at least three levels are available;
- the finest forward/backward mismatch for every direction.

The one-sided estimates are

\[
D_i^+(h)=\frac{P(q+he_i)-P(q)}{h},\qquad
D_i^-(h)=\frac{P(q)-P(q-he_i)}{h}.
\]

Their disagreement is checked separately because a central average may appear
stable even when the two perturbations lie in different hybrid sectors. The
default requested relative levels are `1e-6*[4 2 1]`; all tolerances and state
scales are configurable through the options struct.

## Validation of a map derivative

Before finite differencing, `floquet.validatePeriodicOrbit` performs one
production apex-to-apex stride and requires:

- finite 22-variable orbit data `[X;E]` and seven physical parameters;
- all nine timing residuals below tolerance;
- repeatability of solved event times and the returned section state;
- a positive period and one complete, nondecreasing stride;
- `dy=0` at the initial and returned points;
- negative vertical acceleration at both section crossings;
- valid labeled or clustered event topology; and
- full 13-state non-translational periodic closure.

Every finite-difference map evaluation repeats the timing, stride, section,
and topology tests relative to the accepted base topology. A failed
perturbation, derivative-convergence test, or forward/backward test rejects
the entire matrix. No eigenvalues are returned for a rejected matrix.

`TopologyMode='strict'` preserves the complete event-label ordering.
`TopologyMode='clustered'` allows reordering only among members of a nominal
simultaneous-event cluster and forbids interleaving between distinct clusters.
This is a conditional numerical policy, not a theorem that the return map is
differentiable at a simultaneous impact.

## Reliable intervals and multiplier tracking

`eig` supplies no continuation-wise ordering. The branch analyzer first marks
an adjacent interval reliable only when:

- both endpoint matrices are accepted;
- the source columns are adjacent in the original branch order;
- the endpoint base topologies are consistent; and
- any required fixed-parameter condition is satisfied.

Tracking restarts after an unreliable point or interval. It never bridges a
gap.

For a reliable adjacent pair, the tracker combines scaled multiplier distance
with phase-invariant eigenvector overlap:

\[
d_{ij}=\frac{|\lambda_i^k-\lambda_j^{k+1}|}
 {\max(1,|\lambda_i^k|,|\lambda_j^{k+1}|)},
\qquad
\rho_{ij}=\frac{|(v_i^k)^*v_j^{k+1}|}
 {\|v_i^k\|\,\|v_j^{k+1}\|},
\]

\[
C_{ij}=w_\lambda d_{ij}+w_v(1-\rho_{ij}).
\]

A global minimum-total-cost assignment is used, rather than independent
nearest-neighbor matches. Matched vectors are phase aligned. The assignment
gap and selected distances/overlaps are retained as confidence diagnostics.
At a repeated eigenvalue an individual eigenvector is basis-dependent; the
invariant subspace is the meaningful object.

## Persistent bifurcation detection

`floquet.detectBifurcations` detects signed crossings, not merely proximity to
a target. For real tracks it uses

\[
g_+(s)=\operatorname{Re}\lambda(s)-1,
\qquad
g_-(s)=\operatorname{Re}\lambda(s)+1,
\]

and for a genuinely complex track it uses

\[
g_u(s)=|\lambda(s)|-1.
\]

A candidate needs a reliable adjacent sign bracket and persistence on the
configured neighboring continuation points. The persistence window checks
signed excursion, real/complex type, point validity, interval validity, and
tracking quality. A complex unit-circle candidate additionally needs a
persistent conjugate companion. The lower-half-plane duplicate is not emitted
as a second physical candidate.

Linear interpolation provides a screening coordinate,

\[
\alpha=-\frac{g_L}{g_R-g_L},\qquad
s_c=(1-\alpha)s_L+\alpha s_R.
\]

This coordinate is not yet a corrected critical orbit. The saved detector
vector is also an interpolation of endpoint vectors, not an eigenvector of a
matrix evaluated at \(s_c\). Detector confidence is a reproducibility ranking
assembled from tracking, persistence, conjugacy, and tangent evidence; it is
not a probability or an error bound.

## The trivial family tangent at `+1`

For a smooth family of fixed points at fixed physical parameters,

\[
P_\Sigma(q(s);p)=q(s),
\]

differentiation gives

\[
(M-I)t=0,\qquad t=\frac{dq}{ds}.
\]

Thus the tangent to the already existing periodic-orbit family can occupy a
`+1` null direction. It is not, by itself, evidence of a daughter branch.

Candidate and tangent comparisons use the same scaled section metric. With a
positive diagonal scale \(S\),

\[
\widehat v=\frac{S^{-1}v}{\|S^{-1}v\|},\qquad
\widehat t=\frac{S^{-1}t}{\|S^{-1}t\|},
\]

and the implementation records their absolute overlap, the residual
orthogonal component, and the rank of `[t,v]`. A simple crossing may be
classified as tangent, additional, or unresolved.

The fixed-parameter qualification matters. If the stored branch also changes
\(p\), then

\[
(M-I)q_s+P_p p_s=0,
\]

so the state secant alone need not be a `+1` eigenvector. The branch analyzer
withholds tangent authority on parameter-varying intervals rather than making
an invalid classification.

At a repeated near-`+1` cluster, individual numerical vectors can rotate
under arbitrarily small perturbations. The detector therefore marks their
directions unresolved. Critical-orbit refinement must recompute the invariant
subspace and remove the verified family tangent. If more than one transverse
direction remains, symmetry projectors, a normal form, or another documented
direction resolver is required. The pronking reference case is such a
multiway point; its specialized direction resolution is evidence for that
experiment, not a generic eigenvector-selection rule.

## Critical-orbit refinement

`floquet.refineCriticalOrbit` receives an adjacent branch bracket or explicit
endpoint orbits. At each trial continuation coordinate it:

1. interpolates state and circularly lifted event-time guesses;
2. corrects the full periodic-orbit variables `[X;E]` with the canonical
   residual and a prescribed `X(1)=dx` condition;
3. re-solves and validates the production return map;
4. recomputes the multi-level reduced Floquet matrix; and
5. follows the selected eigenvector or invariant subspace.

A safeguarded secant/bisection iteration narrows the signed crossing bracket.
Acceptance includes the corrected-orbit residual, topology, mode/subspace
overlap, finest-matrix multiplier uncertainty, target residual, and coordinate
bracket width.

The current scalar chart fixes `X(1)=dx`. It is valid only on a locally
monotone segment where `dx` identifies one nearby orbit. A fold in `dx` needs
a pseudo-arclength or hyperplane critical-orbit corrector; disabling adjacency
checks does not repair the geometry.

## Predictor, corrector, continuation, and validation

A verified reduced direction \(v\in\mathbb R^{12}\) is embedded into the
physical state with

\[
\delta X([1,2,4{:}13])\propto v,\qquad \delta X(3)=0.
\]

`floquet.predictBranchDirection` evaluates the perturbed state with the
production timing solver and lifts the solved times into a local circular
chart. If the timing probe uses `X +/- gamma*deltaX`, its central mode obtains

\[
\delta E\approx
\frac{E(X+\gamma\delta X)-E(X-\gamma\delta X)}{2\gamma},
\]

where the event times are first lifted around the base orbit. A documented
one-sided-sector lift is available when opposite perturbations are known to
split one simultaneous-event cluster into different admissible sectors. The
complete predictor is

\[
\delta z=\begin{bmatrix}\delta X\\\delta E\end{bmatrix},
\qquad z_{\mathrm{pred}}=z^\star+\delta z.
\]

`floquet.correctBranchSwitch` corrects `[X;E]` with the canonical periodic
residual and a predictor constraint, then independently validates the return
map. The built-in corrector accepts only a verified additional real `+1`
direction. It deliberately rejects:

- a tangent-aligned `+1` direction;
- a `-1` direction without a custom two-stride corrector; and
- a complex pair without a custom torus/normal-form corrector.

One corrected point is still not a daughter branch. Stage 3 searches both
signs and multiple amplitudes. Stage 4 requires two accepted seeds at distinct
amplitudes on the same oriented ray before calling
`floquet.continueDaughterBranch`. The continuation result is accepted only
with same-ray geometry, sufficient distinct points, periodic-orbit validation,
and fixed-topology evidence under the configured policy.

Stage 5 separates generic numerical validation from physical gait identity.
The generic validator can establish that saved branches contain validated
periodic orbits with the claimed local geometry. A claim such as “this is the
known gathered-suspension gallop branch” requires an independent,
experiment-specific comparison or classifier that was not used to select the
candidate or seed.

## Distinct linear objects

These quantities must not be conflated:

- **Floquet multipliers** are eigenvalues of the 12-by-12 reduced state-return
  derivative and measure apex-to-apex perturbation growth.
- **Continuation Jacobian eigenvalues** belong to an algebraic residual in
  `[X;E]` plus continuation constraints. They depend on residual scaling and
  timing parameterization and are not stability multipliers.
- **The branch tangent** is a direction along the existing solution family.
  At fixed parameters it can occupy a trivial `+1` null direction.
- **A branch-switch direction** is an independently verified transverse
  critical direction, lifted to `[deltaX;deltaE]` and corrected nonlinearly.

## Limitations

The central derivative represents one linear map only when the apex return is
locally differentiable with consistent topology. Grazing contact, simultaneous
impact/reset ambiguity, topology change, defective or highly repeated
spectra, and poor timing-equation conditioning can invalidate that assumption.
The software rejects detected inconsistencies, but numerical acceptance is
not an analytic proof of smoothness or bifurcation nondegeneracy.

A persistent crossing is a candidate spectral event. A complete bifurcation
claim additionally needs an accepted critical orbit, an appropriate
nondegeneracy/transversality argument, successful nonlinear branch correction,
continued daughter evidence, and independent validation appropriate to the
physical claim.
