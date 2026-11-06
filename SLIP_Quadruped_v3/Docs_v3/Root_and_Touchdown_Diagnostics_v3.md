# Root iterations and touchdown diagnostics

`RootSolver_v3` records actual objective callbacks in `iterationJournal`. Rows distinguish evaluations (including finite-difference probes and cache hits) from accepted solver bases. The native `fsolve` `OutputFcn` records its actual accepted iterates; the damped Newton solver records a base only after its decreasing, physically valid line-search trial is accepted. The validated initial base is registered at iteration zero. No reconstructed line segment or interpolated iterate is represented as an evaluated state.

Each compact row stores native and scaled coordinates, fixed parameters and scaling, native and free energy when the residual supplies them, scaled and unscaled equations, the full 13 nongauge closure components when available, selector error, event signatures, topology and physical margins, derivative reliability and selected finite-difference steps, elapsed time, and the native iteration controls available to that solver. Damped Newton exposes its damping, trust radius and line-search fraction. Native fsolve does not expose every internal trust/damping value; unavailable values are `NaN`. A finite derivative used during acquisition is recorded as unreliable if its reliability tests fail. The absence of an evaluated derivative on the initial-residual shortcut is not a derivative certificate.

The explicit `root-newton` mode solves square Newton equations directly and records accepted bases after the first physically valid trial. A valid full step may increase the residual; step halving is only a domain safeguard. Its `output.iterationDiagnostics` records actual returned trial validity, fractions, conditioning, linear backward error and refresh reasons. Residual tolerance is the sole success criterion. Damping/trust fields in the common journal are unavailable for this mode. The [direct-root contract](Periodic_Solution_Solver_v3.md#direct-newton-equation-solving) distinguishes it from the retained LM-based `newton` mode.

Invalid guard, chart, mode, section and integration trials remain invalid. Their residual is never replaced by a fabricated zero or fixed penalty. Finite admissible nonperiodic trials retain their actual nonzero residual. `lastAcceptedIterate`, `lastFiniteEvaluatedBase`, and `originalSeedFallback` are separate diagnostics. Finite-difference probes cannot overwrite the finite evaluated base. If fsolve throws, it retains the last accepted base and its residual, then a finite evaluated base if one exists, then the supplied seed. `fallbackSource` identifies the selected source; `fsolveFailure` retains the offending callback's coordinates, stage, exception and derivative evidence. The `auto` solver may start its subsequent Newton correction at that retained base.

The root status distinguishes `invalid_initial_return`, `invalid_trial_during_correction`, `derivative_failure`, `nonconverged_finite_residual`, `budget_refusal`, `failed_full_closure`, and `converged`. `PeriodicSolutionSolver_v3` propagates root statuses and distinguishes `failed_replay` from accepted admission. It preserves the existing primary/finalization/replay exception records and adds `failure_stage` and `retryable`. Research label qualification remains a separate gate on an admitted orbit; a failed requested gait label must not be rewritten as a numerical root failure.

## Equation and scaling scope

The existing physical mode chart removes horizontal translation, apex phase and dependent stance rates. Before explicit symmetry restrictions, its dimension is `d=12-n_stance`. The fixed-energy system remains

`F(u,E) = [(P(u)-u)_(i != j); H(u)-E] = 0`,

with `d` unknown coordinates and `d` equations at fixed energy. The energy pivot must satisfy the registered nonzero derivative condition at every trial. In a local regular neighborhood, energy conservation and closure of the other coordinates determine the omitted coordinate by the implicit function theorem. This argument requires local regularity and the same physical return; it does not establish full closure from a small reduced residual across arbitrary hybrid charts. Every correction therefore checks all 13 nongauge closure components, including the omitted component and reconstructed stance rates.

Freeing energy requires exactly one independent selector equation, giving `d+1` unknowns and equations. The existing linear `Constraint` selector is suitable for amplitude and arclength coordinates. Its historical `fixed-observable` option still denotes that same linear selector. Mean speed is nonlinear: it must be evaluated as the scalar horizontal displacement divided by the verified primitive period through a delegated nonlinear residual. A coordinate constraint must not be called a speed constraint.

Coordinates and equations retain the native nondimensional model units: mass and gravity equal one, angles are raw radians, and angular rates use native time. `StateScale` scales unknowns; the residual's registered `ResidualScale` divides equations. Scaling does not change the physical admission thresholds. Shared correction remains at most `1e-10` in the reduced equations and default full closure/energy/family/selector/stance admission remains `1e-8`.

## Contact observation without a law change

`TouchdownDiagnostics_v3` observes the native reset before post-reset validation, including a rejected reset that never enters the accepted trajectory. At each touchdown, with absolute angle `theta=phi+alpha`, it records the incoming guard slope and

`rdot_plus = hip_vy*cos(theta) - hip_vx*sin(theta)`,

`gdot_plus = cos(theta)*rdot_plus`.

Incoming downward guard motion does not imply post-reset compression. The report includes the independently evaluated native guard slope, its agreement with the contact identity, guard-surface residual, projected-rate error, continuous-coordinate reset error, and mode consistency. `strict_outward_post_reset` means `rdot_plus` exceeds the existing directional-derivative resolution; the unresolved band is explicit. It does not redefine grazing/equality dynamics, reject an otherwise admitted state, or change trajectories.

The simulator stores all touchdown observations in each batch, event metadata and result. `earliest_contact_obstruction` identifies the first resolved outward post-reset contact. A diagnostic failure retains this observation separately from the actual caught failure stage and keeps `pending_reset`, the rejected raw segment, last accepted state and original exception. Thus a later `TensileStance` can be traced to its earlier outward contact without claiming that the exception itself occurred earlier.

## Runnable controls

Run MATLAB from the repository root:

```matlab
addpath(genpath(fullfile(pwd,'SLIP_Quadruped_v3')));
evidence = RootContactDiagnosticsControls_v3();
```

The controls exercise the actual fsolve exception path after an accepted finite base, an invalid initial return, budget refusal, derivative failure with a preserved finite base, an open finite residual, omitted full closure, a finite scaled/unscaled Newton correction, and an incoming-downward contact whose native reset produces strictly outward stance motion. The simulator control requires failure evidence at that contact without changing the physical law. The original fsolve fallback control was executed before repair and failed `RootContactDiagnosticsControls_v3:LostAcceptedIterate`. The completed native MATLAB run passed all controls; the campaign retains [the red log](../Research_v3/NineHour_20261012/root_contact_red.log), [the completed controls log](../Research_v3/NineHour_20261012/root_sampling_controls.log), and [the evidence MAT](../Research_v3/NineHour_20261012/Evidence/root_contact_controls.mat).

`AuditNineHourContactPreservation_v3(root)` separately compares the eight fresh native returns to their stored accepted trajectories and verifies unchanged physical-law/detector/return-policy hashes against the registered initial source epoch. It reports matched event-time and one-sided reset-state differences at a declared `1e-7` comparison resolution; coarse linear saved-trajectory interpolation is diagnostic only. This audit reads completed replay evidence and makes no additional integrations.
