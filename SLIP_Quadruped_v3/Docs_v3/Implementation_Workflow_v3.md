# Implementation and numerical workflow

This document traces one periodic-orbit computation from its initial input to
the hybrid trajectory, Poincare return, root correction, continuation, and
stability analysis. It also distinguishes the legacy prescribed-time solver
from the independent v3 event-driven implementation.

## Dependency graph

```mermaid
flowchart TD
    Schema["Schema_v3/QuadrupedSchema_v3.m"]
    Adapters["Adapters_v3/*Adapter_v3.m"]
    Base["Dynamics_v3/HybridSystemBase_v3.m"]
    Quad["Dynamics_v3/Quadrupedal_Dynamics_v3.m"]
    Flow["ContinuousDynamics_v3.m"]
    Guards["GuardFunctions_v3.m"]
    Reset["ResetMap_v3.m"]
    Transition["ModeTransition_v3.m"]
    Detector["Simulation_v3/EventDetector_v3.m"]
    Simulator["Simulation_v3/HybridSimulator_v3.m"]
    Trajectory["Simulation_v3/Trajectory_v3.m"]
    Section["Orbit_v3/PoincareSection_v3.m"]
    Map["Orbit_v3/PoincareMap_v3.m"]
    Policy["Orbit_v3/*ReturnPolicy_v3.m"]
    Residual["Orbit_v3/PeriodicOrbitResidual_v3.m"]
    Orbit["Orbit_v3/HybridOrbit_v3.m"]
    Root["Numerics_v3/RootSolver_v3.m"]
    FD["Numerics_v3/*FiniteDifferenceJacobian_v3.m"]
    Continuation["Numerics_v3/*Continuation*_v3.m"]
    Floquet["Stability_v3/FloquetAnalysis_v3.m"]
    Boundaries["Stability_v3/*Detector_v3.m"]
    Graphics["Graphics_v3/*.m"]
    Example["Examples_v3/QuadrupedalExample_v3.m"]

    Schema --> Adapters
    Schema --> Quad
    Schema --> Flow
    Schema --> Guards
    Schema --> Reset
    Schema --> Transition
    Schema --> Graphics
    Base --> Quad
    Flow --> Quad
    Guards --> Quad
    Reset --> Quad
    Transition --> Quad
    Quad --> Detector
    Detector --> Simulator
    Simulator --> Trajectory
    Quad --> Simulator
    Section --> Map
    Policy --> Map
    Simulator --> Map
    Map --> Residual
    Residual --> Orbit
    Residual --> Root
    FD --> Root
    Root --> Continuation
    Residual --> Continuation
    Map --> Floquet
    FD --> Floquet
    Continuation --> Boundaries
    Floquet --> Boundaries
    Trajectory --> Graphics
    Orbit --> Graphics
    Adapters --> Example
    Root --> Example
    Residual --> Example
```

`HybridSystemBase_v3` is the generic contract. The quadruped is one assembly
of that contract; another biped or contact model can supply different flow,
guard, reset, transition, mode-validation, and admissibility callbacks without
changing the simulator, map, or numerical solvers.

## Legacy workflow versus v3

The legacy v2 root function
`SLIP_Quadruped/1_Dynamic_Frameworks/v2/Quadrupedal_ZeroFun_v2.m`
receives 13 initial-state entries, nine event-time unknowns, and seven model
parameters. It sorts the supplied touchdown, liftoff, and apex times, infers
contact from those intervals, integrates each prescribed segment, and includes
event-surface equations in the algebraic residual. Changing event order changes
the timing chart used by that root problem.

V3 does not call or modify that code. Its inputs are

\[
u=x(2{:}14),\qquad q_0,\qquad
p=[k_{l,b},k_{l,f},k_{s,b},k_{s,f},l_{l,b},l_{l,f},
rsla_b,rsla_f,j_{pitch},l_{com}]^T.
\]

There is no event-time vector. Starting from `(x0,q0)`, enabled guard roots
determine all event times and their order. Legacy saved data enter only through
the four explicit classes in `1_Dynamic_Frameworks/Adapters_v3/`.

## End-to-end quadruped entry point

[`QuadrupedalExample_v3.m`](../4_Solution_Management/Examples_v3/QuadrupedalExample_v3.m) performs
the executable workflow.

1. `resolveFixture` loads one saved v2 branch point as an initial guess.
2. `LegacyStateAdapter_v3.toV3Unknown` applies the exact old-to-new state
   permutation. `LegacyParameterAdapter_v3.toV3` applies either `v2-exact` or
   `semantic-rsla`; `LegacyModeAdapter_v3.toV3` converts the contact order.
3. `QuadrupedSchema_v3.shared` provides every index and name.
4. The example constructs `Quadrupedal_Dynamics_v3`,
   `HybridSimulator_v3`, the downward apex `PoincareSection_v3`, an explicit
   `EventCycleReturnPolicy_v3`, `SectionModeResolver_v3`,
   `PoincareMap_v3`, and `PeriodicOrbitResidual_v3`.
5. `RootSolver_v3.solve` optionally corrects the 13 continuous coordinates.
6. `PeriodicOrbitResidual_v3.createOrbit` packages the accepted execution in
   `HybridOrbit_v3`; optional stability calls `FloquetAnalysis_v3.analyze`.

`InitialUnknownPerturbation` exists for regression and solver studies. It
allows a converted fixture to be deliberately moved off its root so that a
test can demonstrate a genuine correction rather than only verifying an
already-converged stored seed.

## One event-driven hybrid segment

The mathematical state is `(t,x,q,p)`. One simulator iteration follows this
call sequence.

```text
HybridSimulator_v3.simulate
  -> EventDetector_v3.integrate
       -> system.activeGuards(t0,x0,q,p)
       -> ode45(@(t,x) system.flow(t,x,q,p))
            -> Quadrupedal_Dynamics_v3.flow
                 -> ContinuousDynamics_v3.evaluate
       -> ODE event callback
            -> Quadrupedal_Dynamics_v3.activeGuards
                 -> GuardFunctions_v3.descriptors
                 -> GuardFunctions_v3.attachFlowDerivatives
       -> earliest directional event and simultaneous batch
  -> system.reset(eventId,t_event,x-,q-,p)
       -> ResetMap_v3.apply
  -> system.transition(eventId,q-)
       -> ModeTransition_v3.apply
  -> Trajectory_v3.recordEvent and append post-reset sample
  -> restart integration from (t_event,x+,q+)
```

### Flow evaluation

[`ContinuousDynamics_v3.evaluate`](../1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m)
validates the canonical vectors, expands family parameters in
`[BL,BR,FL,FR]` order, computes hip geometry and stance compression, sums body
force and pitch torque, evaluates either the swing equation or fixed-foot
stance constraint for each leg, and returns the 14-vector `dxdt`. It does not
clamp negative force. `assertAdmissible` is called on accepted integration
samples and post-reset states, so an execution that has passed a liftoff
surface and retained a tensile stance leg is rejected.

### Guard arming and first-event selection

[`GuardFunctions_v3`](../1_Dynamic_Frameworks/Dynamics_v3/GuardFunctions_v3.m) creates all eight
named descriptors, but the current contact bit enables only touchdown or
liftoff for each leg. Touchdown has direction `-1`; liftoff has direction
`+1`. `attachFlowDerivatives` records the true Lie derivative `Dg*F`, including
the projected stance rate.

[`EventDetector_v3.integrate`](../1_Dynamic_Frameworks/Simulation_v3/EventDetector_v3.m) freezes
the active descriptor IDs during one smooth mode. A guard starting at zero is
unarmed until it first enters the pre-crossing interior; this prevents a reset
surface from immediately retriggering without adding artificial time. The ODE
solver stops at the earliest armed directional root. Other guards within the
event-value/time tolerances and with a consistent directional derivative join
the simultaneous batch. Priority only makes simultaneous reset application
deterministic; it is not a gait schedule.

### Reset, transition, and trajectory

[`ResetMap_v3.apply`](../1_Dynamic_Frameworks/Dynamics_v3/ResetMap_v3.m) leaves body position and
velocity continuous and projects only the affected massless-leg angular rate
onto zero horizontal foot velocity. [`ModeTransition_v3.apply`](../1_Dynamic_Frameworks/Dynamics_v3/ModeTransition_v3.m)
then toggles the event leg. The simulator records `x-`, `x+`, `q-`, `q+`, guard
name, time, and transversality in [`Trajectory_v3`](../1_Dynamic_Frameworks/Simulation_v3/Trajectory_v3.m).
Duplicate event times are retained when a state or mode jumps, giving
right-continuous post-event data without interpolating through a reset.

## From hybrid simulation to a Poincare map

[`PoincareSection_v3.apex`](../4_Solution_Management/PoincareSection_v3.m) defines

\[
h(x,p)=dy=0,\qquad \dot h=ddy<0.
\]

It never checks whether the legs are airborne. The private
`PoincareMap_v3.nextSectionCrossing` operation prevents immediate return in
three phases: leave the initial section, reach the opposite side to rearm,
then locate the next downward crossing. Every phase calls the complete hybrid
simulator, so contact events remain active.

[`PoincareMap_v3.evaluate`](../4_Solution_Management/PoincareMap_v3.m) repeatedly calls that
next-crossing operation. After each candidate, it passes the cumulative
right-continuous mode and automatically generated event history to the chosen
return policy:

- `FirstReturnPolicy_v3` accepts candidate one;
- `IteratedReturnPolicy_v3` accepts candidate `m`;
- `EventCycleReturnPolicy_v3` accepts the first candidate with mode closure
  and at least one touchdown and one liftoff for every model-described leg.

A rejected intermediate apex is recorded and integration continues. At a
section/contact coincidence, physical resets and transitions are processed
before the section record. Output includes period, all candidate crossings,
accepted index, return multiplicity, event and mode sequences, counts,
section-relative and cyclic signatures, coincidence records, transversality,
and admissibility margins.

## Periodic residual

[`PeriodicOrbitResidual_v3`](../4_Solution_Management/PeriodicOrbitResidual_v3.m)
reconstructs a 14-state section point from `u` by fixing `x(1)=0`. It projects
a copy onto the section, evaluates the accepted full-cycle map `P_C`, and
forms

\[
R(u,p,q)=
\begin{bmatrix}
P_C(x,q,p)_{[2,3,5{:}14]}-x_{[2,3,5{:}14]}\\
dy_{raw}
\end{bmatrix}.
\]

The 12 return equations omit horizontal translation and the section-normal
coordinate; the thirteenth equation is the phase condition evaluated on the
unprojected input. The discrete mode stays outside `u`. Invalid integration,
incomplete cycle, tensile stance, or failed mode closure is metadata for
structured trial rejection, not a fabricated finite physical residual.

## Root solving

[`RootSolver_v3.solve`](../3_Numerical_Continuation/1_Root_Solving/RootSolver_v3.m) first asks the residual's
`SectionModeResolver_v3` for local charts. It retains the supplied/previous
mode and only toggles guards near the section with directionally consistent
events. It does not enumerate all 16 quadruped modes unless an exhaustive
provider is explicitly requested.

For each candidate mode, `solveOne`:

1. scales the continuous unknowns and parameters;
2. evaluates and caches the baseline map using a solve-local key;
3. rejects nonfinite or invalid hybrid executions through `safeObjective`;
4. builds a Jacobian using `HybridFiniteDifferenceJacobian_v3` by default;
5. calls `fsolve` with the available Jacobian, or the custom damped
   Levenberg--Newton/trust-region corrector;
6. re-evaluates the final state and reports function, map, cache, invalid
   trial, and Jacobian counts.

The custom step solves

\[
(J^TJ+\lambda\,\operatorname{diag}d)s=-J^TR,
\]

clips `s` to the trust radius, and backtracks it. An invalid hybrid trial is
rejected and the step is reduced. A valid residual decrease expands the trust
region and reduces damping. Optional Broyden updates are used only while
topology remains compatible; a topology or reliability change forces a fresh
Jacobian.

[`FiniteDifferenceJacobian_v3`](../3_Numerical_Continuation/1_Root_Solving/FiniteDifferenceJacobian_v3.m)
is the smooth-function utility. It uses

\[
h_i=\sqrt{\epsilon}(1+|u_i|),
\quad J_i=\frac{R(u+h_ie_i)-R(u)}{h_i},
\]

or the central formula when requested, reusing the baseline. The hybrid
utility instead compares topology-compatible central estimates at several
scaled `h` and `h/2` values, selects the start of a stable plateau, and applies
Richardson extrapolation. One-sided topology-preserving estimates are labelled
piecewise smooth and unreliable as unique classical derivatives.

## Continuation

[`NumericalContinuation1D_v3.run`](../3_Numerical_Continuation/2_Continuation_Algorithms/NumericalContinuation1D_v3.m)
accepts a numeric parameter index or schema name. For every requested value it
copies `p`, changes only the active entry, solves from the preceding `u,q`, and
stores the full orbit, event/mode histories, signatures, counts, margins,
solver counters, schema, and optional Floquet result. A section-relative
signature, section mode, multiplicity, or coincidence change marks a hybrid
topology boundary even when the cyclic physical event sequence is unchanged.

[`PseudoArclengthContinuation_v3`](../3_Numerical_Continuation/2_Continuation_Algorithms/PseudoArclengthContinuation_v3.m)
first differentiates the extended residual with respect to `(u,mu)`. The
oriented null vector of this matrix is the predictor tangent. Its corrector
solves

\[
\begin{bmatrix}
R(u,p(\mu),q)\\
t^T((u,\mu)-(u_0,\mu_0))-ds
\end{bmatrix}=0.
\]

Failed correctors shrink `ds`. At a marked hybrid boundary the accepted orbit
is retained, the step shrinks, Jacobian reuse is cleared, and the stored
smooth tangent/Floquet result is explicitly unresolved. The incoming predictor
is used only internally to reach a neighboring smooth chart, where a new
classical tangent can be computed.

## Persistent branch search with root solving only

The C1 campaign uses the existing
[`RunC1Continuation_v3`](../Research_v3/C1/RunC1Continuation_v3.m) and
[`RunC1ContinuationQueue_v3`](../Research_v3/C1/RunC1ContinuationQueue_v3.m)
above the shared `PeriodicSolutionSolver_v3` admission service. The queue owns
immutable source adoption; a continuation call owns one output branch and its
recoverable frontier. These responsibilities are reusable for other families.
The synchronous-PK phase acquisition chart is family-specific and must not be
applied to bounding, half-bounding or galloping without a separate derivation.

For a physical section chart with coordinates `u` of dimension `d`, choose a
regular energy pivot `j` and form

\[
 F(u,E)=\big[(P(u)-u)_{i\ne j};\ H(u)-E\big]=0.
\]

This has `d` equations and `d+1` unknowns when mechanical energy `E` is free.
Add one independent continuation selector to obtain a square root problem.
The C1 state-secant selector uses a scaled chord between the last two admitted
states; its energy coefficient is zero. Energy is still solved jointly with
the state. Full nongauge closure, including the omitted pivot equation, must
pass independently after correction. In legacy v2, `E` instead denotes event
times: `E(9)=tAPEX` is supplied to each residual call and may be solved in the
outer coupled `[X;E]` system. Those two meanings of `E` are not interchangeable.

Select `Algorithm='root-newton'` explicitly for a root-only campaign. That
mode requires a finite square system and solves the direct Newton equation;
its registered step fractions safeguard the residual domain. It does not use
the least-squares/Levenberg method described in the general solver overview
above. Matrix reuse and Broyden updates accelerate acquisition only. They
neither establish a classical derivative nor certify a bifurcation.

The experiment workflow is:

1. Adopt a real physical source edge with literal states, modes, parameters,
   owners, NativeIDs, marked section and complete return policy. Inventory
   retained charts, event cohorts, multiplicities and raw-angle contexts;
   filenames and overlapping speed ranges do not identify a family.
2. Predict from the current owned pair, correct the square family system and
   admit through the original native return service. Record correction size,
   actual progress, tangent turn, solver effort and every admission gate.
   A separate forced-phase root is a predictor until this handoff succeeds.
3. Persist every earned native admission before fallible capture/report work
   or a batch write. Publish captured points in a bounded batch, then verify
   the installed records before clearing the pending queue. Save the new
   frontier pair in the same checkpoint transition. An unknown commit is a
   reconciliation hold, never a reason to rerun the root or append blindly.
4. Adapt radius using the solver that actually performed the correction.
   When a phase corrector hands an already-converged point to native Newton,
   zero native iterations do not mean zero correction effort. Keep phase,
   native validation, replay and storage timings separate.
5. On restart, first reconcile pending work, then validate the persisted pair
   and output generation. Restore radius/method state only with a compatible
   recorded controller context; otherwise record an explicit reset. Keep
   cumulative run accounting without copying the full journal recursively.
6. Assign each frontier an evidence-based disposition: continued, qualified
   numerical overlap, local physical/chart boundary, requested stopping rule,
   or unresolved obstruction. Budget yields, point caps and invalid finite
   differences are not physical endpoints. A height stop is evaluated at the
   declared marked apex; the current PK rule is strictly `H < 0.5 L0`.

For an out-of-place checkpoint, exact restart also requires its original input
source generation:
`RunC1Continuation_v3` checks `configuration.source_file`, its source indices and
source identity before adopting the saved current pair. Keep that source while
promising an exact restart. To retire a bulky source, first retain and verify a
small ordinary Branch store containing a real committed pair, keep the old
checkpoint and history unchanged, and declare a fresh owned fork through the
same Run/Queue APIs. Record the new controller context and any reset explicitly.
Changing an old checkpoint's source SHA or indices does not establish a restart.
The configuration also binds the original grant ID, start and deadlines.
Under the current API, a newly authorized grant therefore requires an explicitly
declared fresh fork with the old checkpoint/history retained as provenance;
automatic same-path adoption across grants has not been verified. A new grant
must not silently replace the clocks in an old checkpoint.

A Core29 export supports loading, display and seed transport. Its reduced
reports alone do not establish that a retained numerical-overlap proof can be
revalidated. Preserve the endpoint reports and actual predecessor records
required by that proof, including the full historical classifier for the old
GateB contract, in an essential authority before retiring the raw store.
Record retired paths and their replacement locators while preserving
literal historical references. An old frontier journal can omit isolated saved
solutions; account for the retained source stores as well as its registered
frontiers before making a finite-search completion claim.

Keep one fixed campaign deadline across workers and resumes, with a delivery
reserve. All scientific evaluation and campaign orchestration are MATLAB-native.
Freeze numerical providers for a worker's lifetime and start a fresh process
after source changes. Measure full admitted-and-stored throughput, including
failed attempts; a fast root alone is not a fast validated seed.

Near grazing, repeated finite-step replays establish repeatability but do not
guarantee discovery of a substep double crossing. A model-derived guard study
must state its interval, stationary-root search, endpoint checks and completeness
limits. A regular signed clearance change along the periodic family can
establish a local chart boundary; it cannot exclude every other PK component
or prove global maximality. Preserve
historical admission flags separately from any newly found limitation.

Retain one result MAT per declared connected component, a persistent frontier,
the core methods and decisive audits. Preserve physical edges, exact record
links, qualified aliases and numerical seams as separate graph layers; imported
initializer points do not acquire an edge by being adjacent in a file.
Regenerating trajectories requires fresh replay; new continuation or admission
claims require fresh admission. Loading and display retain historical status.
Remove consumed tests, caches and temporary stages after their last consumer
releases them.
See [the storage contract](Compact_Branch_Storage_v3.md) and the
[current campaign evidence](../Research_v3/C1/Methodology_20261030/PK30h_20261101_Campaign.md)
for implemented epochs, actual checks and remaining limitations.

### Conditional clearance bounds during all-leg flight

[`AllFlightClearanceBounds_v3`](../Research_v3/C1/AllFlightClearanceBounds_v3.m)
checks a literal fixed all-flight smooth extension without integration or root
search. It accepts asynchronous leg angles and a nonzero raw pitch rate; it
does not project a saved state onto a synchronous or zero-pitch model. The
caller supplies the actual swing-penetration tolerance, parent deadlines and
an explicit conditional arithmetic-error allowance.

In the model's nondimensional time, body flight satisfies
`y(t)=y0+dy0*t-t^2/2` and `phi(t)=phi0+omega*t`. For one leg with hip offset
`s`, resting length `L`, torsional stiffness `k_s` and rest angle `r`,

\[
 \ddot\alpha+\nu^2(\alpha-r)=(s/L)\omega^2\cos\alpha,
 \qquad \nu=\sqrt{k_s}/L.
\]

Let `alphaH` be the unforced harmonic solution with the same literal initial
angle and rate, and let `c=abs(s/L)*omega^2`. The zero-stiffness limit is linear,
not a division by zero. Duhamel's formula gives
`abs(alpha-alphaH)<=c*t^2/2` and
`abs(dalpha-dalphaH)<=c*t`. These bounds retain the nonzero-spin forcing.
The guard is `g=y+s*sin(phi)-L*cos(phi+alpha)`, so its difference from the
harmonic-reference guard is at most `L*c*t^2/2`.

Over duration `T`, bounds
`A=abs(alpha0-r)+abs(dalpha0)*T+c*T^2/2`,
`W=nu*abs(alpha0-r)+abs(dalpha0)+c*T` and `Q=nu^2*A+c` give

\[
 |\ddot g|\le M_2=1+|s|\omega^2+L\big[(|\omega|+W)^2+Q\big].
\]

On a cell `[a,b]`, subtract the endpoint forcing-error bounds from the
harmonic-reference endpoint guards, take their minimum, and subtract
`M2*(b-a)^2/8`. This bounds the guard throughout the cell in real arithmetic.
The implementation also subtracts the caller's arithmetic allowance from each
cell lower bound and adds it to pointwise upper bounds. It subdivides unresolved
cells within fixed depth, cell-count and time caps, retaining unresolved intervals
when a cap or nonfinite bound prevents a conclusion.

This is conditional numerical evidence: the supplied allowance must bound the
total propagated error of each final scalar bound expression. The helper does
not establish that hypothesis or use outward-rounded interval arithmetic.
Its formal-coverage flag therefore remains false. Nonpenetration at a negative
tolerance also does not exclude an earlier guard zero or establish hybrid event
ownership. Neither a returned bound nor its software tests create an admission,
a continuation edge, a branch endpoint or a completeness claim.

## Stability and bifurcations

[`FloquetAnalysis_v3.analyze`](../3_Numerical_Continuation/3_Bifurcation_Analysis/FloquetAnalysis_v3.m)
differentiates the same accepted full-cycle map on the section-tangent,
translation-reduced coordinates. The default topology-aware derivative
returns selected steps, error estimates, difference type, and per-column
reliability. Multipliers are eigenvalues of that reduced full-cycle matrix.

[`BifurcationDetector_v3`](../3_Numerical_Continuation/3_Bifurcation_Analysis/BifurcationDetector_v3.m) matches
finite reliable multipliers between compatible points and detects bracketed
crossings of `+1`, `-1`, or a complex-pair modulus through one. Nonfinite or
unreliable points break, rather than poison, multiplier tracks.
[`HybridBoundaryDetector_v3`](../3_Numerical_Continuation/3_Bifurcation_Analysis/HybridBoundaryDetector_v3.m)
separately reports grazing, event collision/insertion/deletion,
section/event coincidence, mode/multiplicity/signature change, and stance-force
admissibility loss. Those boundaries are not automatically smooth
bifurcations.

## Post-processing

[`HybridOrbit_v3`](../4_Solution_Management/HybridOrbit_v3.m) stores initial state/mode,
period, parameters, event/mode history, Poincare state, trajectory, and
stability. It contains no gait label. Files in [`2_Graphic_ToolBox/Graphics_v3`](../2_Graphic_ToolBox/Graphics_v3)
consume recorded modes, events, and dynamics diagnostics; they never reconstruct
contact from prescribed event-time inputs. Gait classification, if desired,
is a separate post-processing operation on event history.
