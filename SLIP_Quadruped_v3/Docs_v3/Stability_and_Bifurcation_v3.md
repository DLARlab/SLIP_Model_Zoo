# Stability and bifurcation analysis in v3

## Full-cycle map

Stability is defined for the map accepted by the configured return policy,
not necessarily for the first subsequent geometric apex.  If an event cycle
contains two downward apex crossings, the accepted map is

\[
P_C=P_1^{(2)}\circ P_1^{(1)},\qquad
DP_C=DP_1^{(2)}DP_1^{(1)}.
\]

`FloquetAnalysis_v3` differentiates `PoincareMap_v3.evaluate`, so the
derivative includes continuous evolution, event-time changes, resets, mode
transitions, and the final section projection for the complete accepted cycle.
The production matrix uses the section-tangent, horizontal-translation-reduced
coordinates supplied by the system schema.  The ambient derivative is an
optional diagnostic and is disabled by default.

## Hybrid finite-difference reliability

`HybridFiniteDifferenceJacobian_v3` evaluates central differences at `h` and
`h/2` for several coordinate-scaled candidate steps.  A column is accepted on
a stable step plateau only when the executions have compatible cycle
completion, return multiplicity, discrete closure, cyclic event signature,
and sufficient guard and section transversality.  For central differences,

\[
D(h)=\frac{P_C(x+h e_i)-P_C(x-h e_i)}{2h},
\]

and the consistency estimate is

\[
e_i=\frac{\|D(h/2)-D(h)\|}{\max(1,\|D(h/2)\|)}.
\]

When enabled, the selected estimate is the central Richardson value

\[
D_i=\frac{4D(h/2)-D(h)}{3}.
\]

If only one side retains the baseline topology, the implementation can report
a one-sided piecewise-smooth derivative.  Such a column is useful diagnostic
information but is not labelled a unique classical Floquet derivative.  A
Floquet result is unreliable if any required column lacks refinement
convergence, if topology or return multiplicity changes, if cycle completion
or discrete closure fails, or if an event/section is nearly grazing.
An exact or tolerance-level section/event coincidence is likewise reported as
unreliable because the selected local return chart is not differentiable in
the classical sense at that point.

## Floquet multipliers

For a reliable reduced matrix `DP_C`, the multipliers are

\[
\lambda_j=\operatorname{eig}(DP_C),\qquad
\rho=\max_j|\lambda_j|,\qquad
m=1-\rho.
\]

The orbit is classified as stable when `m` is positively separated from zero,
unstable when it is negatively separated, and marginal near zero.  This label
does not replace the per-column reliability report.

## Smooth multiplier crossings

`BifurcationDetector_v3` uses Hungarian multiplier matching with an optional
eigenvector-similarity penalty.  It only uses intervals whose endpoint
Floquet results are reliable and whose hybrid topology is compatible.

The reported smooth candidates are:

| Crossing | Reported type |
|---|---|
| real multiplier through `+1` | `unit_multiplier_candidate` |
| real multiplier through `-1` | `period_doubling_candidate` |
| complex-conjugate pair through the unit circle | `Neimark_Sacker_candidate` |

A unit multiplier does **not** by itself identify a saddle-node.  Fold,
pitchfork, transcritical, and symmetry-breaking branch points can all produce
`lambda=+1`.  Further classification requires branch geometry, Jacobian rank,
symmetry information, or nonlinear tests.

## Nonsmooth hybrid boundaries

`HybridBoundaryDetector_v3` separately brackets guard grazing, event
collisions, event insertion/deletion, section/event coincidence, section-mode
changes, return-multiplicity changes, cyclic-signature changes, and loss of
stance-force admissibility.  These are hybrid boundaries and are never
automatically reclassified as smooth Floquet bifurcations.

Continuation should reduce its step at such a boundary, switch to a valid
neighboring section chart when available, and avoid presenting a smooth
tangent or Floquet matrix at an unresolved nonsmooth point.
