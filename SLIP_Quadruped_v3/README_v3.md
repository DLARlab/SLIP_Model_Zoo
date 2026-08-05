# SLIP Model Zoo v3 hybrid framework

The v3 code is an additive, event-driven framework.  It does not modify or
replace the legacy quadruped GUI, prescribed-event solver, continuation code,
or saved data.  Every new MATLAB source file has the `_v3` suffix.

## Mathematical contract

A model is represented as a hybrid dynamical system

\[
\mathcal H=(Q,X,F,G,\Delta),
\]

where `HybridSystemBase_v3` owns a mode set `Q`, a continuous state space
`X`, mode-dependent flows `F`, directional and mode-enabled guards `G`, reset
maps `Delta`, and a separate mode-transition policy.  The components are
function-handle based, so models do not need to be conservative,
Lagrangian, autonomous, or tied to a particular contact law.

`HybridSimulator_v3` repeatedly:

1. integrates `xdot = F_q(t,x,p)`;
2. locates the earliest active directional guard;
3. clusters guards that occur at the same time within tolerance;
4. applies each reset and mode transition in declared priority order; and
5. continues from the resulting hybrid state.

The simulator never receives a gait name or a prescribed event order.  A
gait may be classified later from `Trajectory_v3.event_history`.

## Dependency direction

```text
Dynamics_v3
  -> Simulation_v3
  -> Orbit_v3
  -> Numerics_v3
  -> Stability_v3
  -> Examples_v3 and Tests_v3
```

The main runtime path is:

```text
HybridSystemBase_v3
  -> EventDetector_v3
  -> HybridSimulator_v3
  -> PoincareMap_v3
  -> PeriodicOrbitResidual_v3
  -> RootSolver_v3
  -> HybridOrbit_v3
```

Continuation uses the same residual and root solver.  Floquet analysis
finite-differences the same event-driven Poincare map, so event-time
sensitivity, resets, and mode changes are part of the derivative.

## Poincare section and return map

`PoincareSection_v3` defines `h(x,p)=0` and a crossing direction through the
Lie derivative.  The quadruped apex is

\[
h(x,p)=v_y,\qquad L_{F_q}h=a_y<0.
\]

There is no flight or fixed-mode requirement.  To avoid accepting the
initial point as its own return, `PoincareMap_v3` observes departure to the
negative side, re-arms on the positive side, and then accepts the next
downward crossing.  It returns the next continuous state and discrete mode,
period, event sequence, mode sequence, trajectory, and symmetry drift.

If a contact guard and the section coincide, hybrid resets and transitions
are processed before the returned right-continuous mode is stored.

## Relative-periodic quadruped residual

The legacy integrated state is

```text
[x vx y vy phi dphi alphaBL dalphaBL alphaFL dalphaFL
 alphaBR dalphaBR alphaFR dalphaFR]'
```

and the saved 13-vector omits horizontal position.  Running solutions have
nonzero horizontal drift, while the apex return map already constrains the
section-normal coordinate.  A literal ambient
`[P(x)-x; h(x)]` would therefore force zero stride and contain redundant
equations.

The square compatibility residual uses

```matlab
x = [0; u];                    % u is the legacy 13-vector
xs = section.project(x);
I = [2, 3, 5:14];             % quotient x and remove section normal vy
R = [P(xs)(I) - xs(I);
     x(4)];
```

Thus there are 12 independent return equations and one phase equation for
13 unknowns.  `PeriodicOrbitResidual_v3.ambientResidual` exposes the literal
full-state expression for diagnostics only.  Discrete closure
`q_return == q_initial` is an admissibility condition, not a continuous
equation.  Mode candidates are reconsidered during continuation, allowing a
liftoff or touchdown to pass through the section.

## Quadruped compatibility

`Quadrupedal_Dynamics_v3` uses:

- 14 continuous states;
- seven parameters `[k,ks,J,l,osa,lb,kr]`;
- contact mode `[BL,FL,BR,FR]` in `{0,1}^4`;
- events `BL_TD`, `BL_LO`, `FL_TD`, `FL_LO`, `BR_TD`, `BR_LO`,
  `FR_TD`, and `FR_LO`;
- the legacy stiffness split and massless fixed-foot stance constraint; and
- the legacy angular-rate projection at both touchdown and liftoff.

The parsed legacy neutral swing angle `osa` remains unused in the compatibility
flow because the production model restores swing legs toward zero.  A new
contact, actuation, damping, or swing policy should be implemented as another
hybrid-system component rather than by changing the compatibility model.

## Numerical methods

- `FiniteDifferenceJacobian_v3` uses
  `sqrt(eps)*(1+abs(z(i)))` and supports forward or central differences.
- `RootSolver_v3` uses `fsolve` when the Optimization Toolbox is available
  and otherwise uses damped finite-difference Newton steps.
- `NumericalContinuation1D_v3` performs corrected parameter stepping with a
  previous solution as its seed.
- `PseudoArclengthContinuation_v3` corrects one active scalar parameter (or
  a one-dimensional parameter path) together with the state and obtains an
  oriented tangent from the null space of `[R_x R_mu]`.
- `FloquetAnalysis_v3` reports multipliers of the hybrid Poincare map on the
  section-tangent, translation-quotient chart.  Its ambient Jacobian is a
  diagnostic because it contains nonphysical normal/symmetry directions.
- `BifurcationDetector_v3` matches multipliers between neighboring branch
  points and detects crossings through `+1`, `-1`, and the complex unit
  circle, with an interpolated parameter estimate.

## Migration and execution

Add the v3 directories to the MATLAB path without removing the legacy tree:

```matlab
root = '/path/to/SLIP_Model_Zoo';
addpath(genpath(fullfile(root, 'Dynamics_v3')));
addpath(genpath(fullfile(root, 'Simulation_v3')));
addpath(genpath(fullfile(root, 'Orbit_v3')));
addpath(genpath(fullfile(root, 'Numerics_v3')));
addpath(genpath(fullfile(root, 'Stability_v3')));
addpath(genpath(fullfile(root, 'Examples_v3')));
```

Run `QuadrupedalExample_v3` to evaluate a stored legacy orbit with
state-triggered events.  The default PK fixture has physically first
touchdowns that agree with the old schedule.  Some prescribed-event legacy
orbits contain earlier ground crossings that v2 intentionally ignored; those
require a model-owned contact-admissibility rule before they can be migrated
as first-event hybrid trajectories.  Run the tests with:

```matlab
results = runtests(fullfile(root, 'Tests_v3'));
assertSuccess(results);
```

Imported legacy event times are regression expectations only.  They are not
unknowns or inputs to the v3 simulator or periodic-orbit solver.
