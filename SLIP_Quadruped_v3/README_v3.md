# SLIP Quadruped v3

`SLIP_Quadruped_v3` is an additive hybrid-periodic-orbit framework. It does
not replace the legacy v1/v2 simulators, continuation scripts, graphics, or
saved data. Legacy vectors enter v3 only through explicit adapters.

The framework models

\[
\mathcal H=(Q,X,F,G,\Delta),
\]

with mode-dependent flow \(\dot x=F_q(t,x,p)\), directional guards,
event-specific resets, and separate discrete transitions. It never receives a
gait name or a prescribed contact order.

## Architecture

```mermaid
flowchart LR
    S["Schema_v3<br/>one coordinate contract"]
    A["Adapters_v3<br/>explicit v2 conversion"]
    D["Dynamics_v3<br/>F, G, reset, transition"]
    M["Simulation_v3<br/>earliest-event integration"]
    O["Orbit_v3<br/>section, return policy, residual"]
    N["Numerics_v3<br/>root solve and continuation"]
    T["Stability_v3<br/>Floquet and boundaries"]
    G["Graphics_v3<br/>trajectory/event consumers"]
    E["Examples_v3 and Tests_v3"]

    S --> D
    S --> A
    S --> G
    S --> E
    A --> E
    D --> M --> O --> N --> T
    M --> G
    O --> G
    N --> E
    T --> E
    G --> E
```

The principal runtime path is:

```text
(x0,q0,p)
  -> Quadrupedal_Dynamics_v3.flow
  -> EventDetector_v3: earliest enabled directional guard
  -> ResetMap_v3(x-,q-,event)
  -> ModeTransition_v3(q-,event)
  -> Trajectory_v3 event/mode history
  -> PoincareMap_v3: next section crossing
  -> ReturnPolicyBase_v3: accept or continue
  -> PeriodicOrbitResidual_v3
  -> RootSolver_v3 / continuation / Floquet analysis
```

The complete dependency graph and function-by-function execution trace,
including the legacy prescribed-event workflow, are in
[`Implementation_Workflow_v3.md`](Docs_v3/Implementation_Workflow_v3.md).
The permanent file-by-file implementation and verification record is
[`Final_Implementation_Audit_v3.md`](Docs_v3/Final_Implementation_Audit_v3.md).

## Canonical schema

`Schema_v3/QuadrupedSchema_v3.m` is the sole source of coordinate, leg,
event, parameter, and root-chart ordering.

The 14-state vector is

```text
1 x       2 dx       3 y         4 dy
5 phi     6 dphi     7 alphaBL   8 dalphaBL
9 alphaBR 10 dalphaBR 11 alphaFL 12 dalphaFL
13 alphaFR 14 dalphaFR
```

The contact mode is `q=[qBL;qBR;qFL;qFR]`, with `0` for swing and `1`
for stance. The event catalog is:

```text
1 BL_TD  2 BL_LO  3 BR_TD  4 BR_LO
5 FL_TD  6 FL_LO  7 FR_TD  8 FR_LO
```

The ten parameters are:

```text
1 k_l_b   2 k_l_f   3 k_s_b   4 k_s_f   5 l_l_b
6 l_l_f   7 rsla_b  8 rsla_f  9 j_pitch 10 l_com
```

Family parameters expand in `[BL,BR,FL,FR]` order. The 13 root coordinates
are states `2:14`; state 1 is the horizontal-translation gauge. Independent
periodic and section-tangent coordinates are `[2,3,5:14]`, and state 4 is the
phase coordinate.

See
[`State_Parameter_Event_Conventions_v3.md`](Docs_v3/State_Parameter_Event_Conventions_v3.md)
for the complete tables and validation rules.

## Hybrid quadruped model

For leg \(i\), let

\[
s_i\in\{-l_{com},1-l_{com}\},\qquad
\theta_i=\phi+\alpha_i,\qquad
L_i=\frac{y+s_i\sin\phi}{\cos\theta_i}.
\]

The stance compression and axial force are
\(\delta_i=l_{0,i}-L_i\) and \(\lambda_i=k_{l,i}\delta_i\). Negative
compression is not clamped; accepted tensile stance states are reported as
inadmissible. Body acceleration follows

\[
\ddot x=-\sum_iq_i\lambda_i\sin\theta_i,
\quad
\ddot y=\sum_iq_i\lambda_i\cos\theta_i-1,
\quad
\ddot\phi=\frac{\sum_iq_i s_i\lambda_i\cos\alpha_i}{j_{pitch}}.
\]

The swing equation is

\[
\ddot\alpha_i=
-\ddot\phi
-\frac{F_x\cos\theta_i+F_y\sin\theta_i}{l_i}
-\frac{s_i}{l_i}\ddot\phi\sin\alpha_i
+\frac{s_i}{l_i}\dot\phi^2\cos\alpha_i
-\frac{k_{s,i}}{l_i^2}(\alpha_i-rsla_i).
\]

Touchdown and liftoff use the same geometric surface

\[
g_i=y+s_i\sin\phi-l_{0,i}\cos(\phi+\alpha_i)=0,
\]

with mode enablement and crossing direction distinguishing the events. A
massless-leg reset leaves body position and velocity continuous and projects
the affected leg rate onto zero horizontal foot velocity. Full derivations,
the biped limit, stance constraint, and diagnostics are in
[`Quadruped_EOM_v3.md`](Docs_v3/Quadruped_EOM_v3.md).

## Section crossing versus cycle completion

The apex section is geometrically

\[
h(x,p)=dy=0,\qquad \dot h=ddy<0.
\]

It imposes no flight or fixed-mode condition. `PoincareMap_v3` first finds a
directional section crossing, then asks an explicit return policy whether the
crossing completes the desired map:

- `FirstReturnPolicy_v3` accepts the first crossing;
- `IteratedReturnPolicy_v3` accepts crossing \(m\);
- `EventCycleReturnPolicy_v3` accepts the first right-continuous crossing
  with mode closure and at least one touchdown and liftoff for every leg.

Direct quadruped maps default to `EventCycleReturnPolicy_v3`; generic hybrid
systems default to `FirstReturnPolicy_v3`. An explicitly supplied policy is
never replaced later by residual or stability construction.

The event-cycle policy permits intermediate apexes and imposes no event order.
At a section/contact coincidence, physical transitions are processed once and
the post-event section mode is stored. All candidate crossings, accepted
multiplicity, event counts, signatures, transversality, and coincidence data
are returned. See
[`Poincare_and_Cycle_Definition_v3.md`](Docs_v3/Poincare_and_Cycle_Definition_v3.md).

## Periodic root problem

With `u=x(2:14)` and the horizontal gauge fixed at `x(1)=0`, the square
relative-periodic residual is

\[
R(u,p,q)=
\begin{bmatrix}
\Pi\big(P_C(x,q,p)-x\big)\\
dy_{raw}
\end{bmatrix},
\qquad \Pi=[2,3,5{:}14].
\]

It has 12 independent periodicity equations and one phase equation. The
discrete section mode remains outside the numerical unknown vector. A local
section-mode resolver retains the previous chart and toggles only guards near
the section with consistent directions; exhaustive `allModes()` is available
only as an explicit diagnostic.

`RootSolver_v3` supplies state/parameter scaling, solve-local map caching,
structured invalid-trial rejection, fsolve and damped trust-region Newton
paths, counters, and optional Jacobian/Broyden reuse. Event times and event
order are never root unknowns.

## Continuation and stability

`NumericalContinuation1D_v3` accepts a parameter index or name and corrects
each requested value from the preceding solution. `PseudoArclengthContinuation_v3`
augments the periodic residual with

\[
t^T\big((u,p)-(u_0,p_0)\big)-ds=0.
\]

Accepted points store states, parameters, section mode, period, full event
history, cycle-return policy, return multiplicity, candidate/accepted apex
indices, both topology signatures, event counts, transversality, solver
statistics, Floquet data, and schema metadata. Topology changes are marked and
trigger step reduction instead of a fabricated smooth tangent.

`HybridFiniteDifferenceJacobian_v3` compares central derivatives at \(h\) and
\(h/2\), selects a coordinate-scaled plateau, optionally applies Richardson
extrapolation, and validates full-cycle topology. One-sided results are marked
piecewise smooth and are not called unique classical derivatives. Hybrid
Floquet analysis also requires explicit closure, completion, multiplicity,
signature, and transversality evidence; omitted metadata cannot certify a
reliable derivative.

`FloquetAnalysis_v3` differentiates the accepted full-cycle map on the
section-tangent, translation-reduced chart. `BifurcationDetector_v3` reports
`unit_multiplier_candidate`, `period_doubling_candidate`, and
`Neimark_Sacker_candidate` only on reliable topology-compatible intervals.
`HybridBoundaryDetector_v3` separately reports nonsmooth boundaries. Details
are in
[`Stability_and_Bifurcation_v3.md`](Docs_v3/Stability_and_Bifurcation_v3.md).

## Legacy migration

Use the four classes under `Adapters_v3`; never insert an old vector directly
into v3. `LegacyParameterAdapter_v3` requires an explicit policy:

```matlab
newU = LegacyStateAdapter_v3.toV3Unknown(oldU);
newQ = LegacyModeAdapter_v3.toV3(oldQ);
[newP, conversion] = LegacyParameterAdapter_v3.toV3(oldP, 'v2-exact');
```

`v2-exact` discards the formerly inactive neutral swing-angle value, while
`semantic-rsla` activates it as both family rest angles. The complete
permutations and conversion equations are in
[`Migration_v2_to_v3.md`](Docs_v3/Migration_v2_to_v3.md).

The 70 legacy files restored verbatim from the immediate parent commit,
together with their hash audit, are recorded in
[`Legacy_Restoration_Audit_v3.md`](Docs_v3/Legacy_Restoration_Audit_v3.md).

## Graphics

`Graphics_v3` consumes `Trajectory_v3` or `HybridOrbit_v3`, the ten-parameter
schema, recorded modes/events, and dynamics diagnostics. Contact phases are
not reconstructed from event-time inputs. The toolbox supports classic and UI
axes, invisible/headless construction, simple/detailed animation, optional
video export, diagnostics-based GRFs, and reset-safe right-continuous
resampling.

## Validation scope and current limitations

The converted PK fixture closes and is also tested after a deliberate
continuous-state perturbation so that the solver performs a genuine root
correction. A second executed regression continues that orbit from
`k_l_b=k_l_f=10` to `k_l_f=10.02`; the corrected orbit has distinct
front/back touchdown and liftoff times while retaining one event of each type
per leg and discrete closure. Full-cycle Floquet differentiation is exercised
on analytic event-free and two-apex hybrid systems; the default quadruped
example leaves the substantially more expensive quadruped Floquet calculation
disabled.

The available asymmetric v2 roadmap fixtures were generated with prescribed
event times and the legacy touchdown-rate treatment. For sampled BE/BG/FE/FG/
GE/GG/HE/HG points, v3 inserts contact crossings that the prescribed schedule
suppresses; subsequent rate projection and force validation can expose a
tensile stance or singular stance constraint. Weakening force admissibility or
ignoring those guards would hide a physical/model incompatibility. Thus actual
asymmetric-orbit behavior is tested, but the clause requiring direct use of an
available non-pronking legacy fixture remains an explicit migration gap rather
than a claimed successful replay. The suite converts and executes a
representative positive-clearance BG point and verifies its structured tensile
stance rejection, so this limitation is itself regression-tested.

The stance acceleration implementation preserves validated legacy symbolic
fixed-foot formulas; it is not a general constrained-mechanics DAE solver.
At grazing, event collision, or topology-changing boundaries, a unique
classical return-map derivative may not exist. V3 reports that loss of
smoothness and does not manufacture a Floquet matrix or continuation tangent.

## Run

From the repository root:

```matlab
v3 = fullfile(pwd, 'SLIP_Quadruped_v3');
addpath(genpath(v3));

% Explicitly converts the fixture, closes a full contact cycle, and refines.
[orbit, report, framework] = QuadrupedalExample_v3(struct('Refine', true));

% Optional graphics; no dialog is required.
views = QuadrupedalGraphicsExample_v3(orbit, ...
    'Visible', 'off', 'PlayAnimation', false);

results = runtests(fullfile(v3, 'Tests_v3'));
assertSuccess(results);
```

All new branch data carry state, parameter, leg, event, and schema-version
metadata. Gait classification remains post-processing of event history and is
not stored as a solved-orbit property.
