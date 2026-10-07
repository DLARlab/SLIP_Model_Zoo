# Native campaign integration of the opposed-spread two-cycle

This is a prepared integration plan at the 2026-10-07 writer handoff. It registers no campaign task, changes no running MATLAB function and charges no master budget. Implementation waits for the root agent's full-writer release and a canonical validation summary that matches every current solver source hash.

The separately frozen [theory registration](../Research_v3/next_round/opposed_spread_period_two_registration.json) contains four signed exact predictors at resonances n0 and n1. Its completed [physical audit](../P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Opposed_Spread/Theory/opposed_spread_period_two_audit.json) passed for all four: two positive-duration flights, 16 actual contacts, primitive cover1, and full BL2 closure at most `1.86e-12`. It used zero Newton steps. Its 86.48-second standalone time is outside the master account. The [restricted theorem](Restricted_PIP_Opposed_Spread_Period_Two_v3.md) proves existence for `0<|A|<.01` at n0 through n8 in the exact baseline model. The actual gait label remains `unclassified/ambiguous`; a B2, F2, H2 or G2 assignment is unsupported.

## Registration and dispatch

Extend the existing period-two registry with an explicit correction method. Preserve the existing n1 and n0 measured front/hind records and indices1/2. Append the four opposed-spread records in their frozen order, carrying:

- the exact predictor ID, artifact, variable and SHA256;
- method `exact-opposed-spread-twisted-restriction`;
- the theory registration and passed physical-audit paths;
- the original exact parameters, signed angle, resonance, occurrence2 and required flight count2;
- the independently frozen method registration for campaign admission/correction under the current solver epoch.

The dispatcher selects a dedicated `RunOpposedSpreadPeriodTwo_v3` driver for the new method. Existing measured sector records continue through `RunFamilySectorCorrections_v3`. The standing driver must retain each old phase/artifact when a diagnosed repair changes a source or numerical method. A retry never rewrites the theory predictor.

## Shared correction service

The executed solver pilot supplies this existing interface:

```matlab
oneFamily = EnergyFamilyResidual_v3( ...
    PeriodicOrbitResidual_v3(oneBLMap, predictor.state), ...
    predictor.state, predictor.mode, predictor.parameter);
twoFamily = EnergyFamilyResidual_v3( ...
    PeriodicOrbitResidual_v3(twoBLMap, predictor.state), ...
    predictor.state, predictor.mode, predictor.parameter);
constraint = struct('reference', predictor.amplitude_reference, ...
    'normal', predictor.amplitude_normal, ...
    'target', predictor.signed_kernel_coordinate);
residual = OpposedSpreadFamilyResidual_v3(oneFamily, twoFamily, constraint);
coordinates = [predictor.a; predictor.b; predictor.energy];
[solution, report] = PeriodicSolutionSolver_v3(seed, struct( ...
    'Residual', residual, 'Coordinates', coordinates, ...
    'AugmentedParameter', [predictor.parameter; predictor.energy], ...
    'MaxWallSeconds', remainingSlice, ...
    'ReplayIntegration', tighterReplay, 'SolverOptions', solverOptions));
```

Both maps are the actual baseline flight-apex maps. Their policy objects prescribe one and two BL touchdowns respectively. Both energy families use `Symmetry='none'`; the adapter owns the exact reduced lift. Newton corrects the BL1 twisted residual and signed amplitude in coordinates `(a,b,E)`. Its exposed `Map`, full orbit finalization and fresh service replay use the actual BL2 return. Use strict three-dimensional `HybridFiniteDifferenceJacobian_v3`; the measured BL2 event-order Jacobian belongs to a different Newton map and must not be injected here.

Freeze two distinct phases before simulation: exact predictor admission, then a meaningful amplitude-orthogonal perturbation. The pilot used `delta=1e-4` times `[-normal(2);normal(1);0]`. Record the initial physical residual and require at least one accepted Newton step for a claim of genuine nonlinear correction. Preserve the exact admission even if the perturbed correction fails. Both phases require fresh full closure, energy, stance, determinism, discrete closure, primitive-period and two-flight checks. `unclassified` does not invalidate a physically admitted orbit; it limits the descriptive-family claim.

## Restricted branch progression

The current generic branch extender does not implement the paired opposed-spread lift. Sending this seed through its full-space default would change the derivative problem and lose the theorem's exact restriction. A separate restricted branch phase can prospectively freeze signed-amplitude constraints in both directions, correct with the same adapter, and independently admit each physical BL2 orbit. Save the endpoint, last reliable Jacobian, actual cumulative coordinate arclength and each prospective constraint before execution. A point limit is a checkpoint, never an endpoint. Keep the sufficient `0<|A|<.01` theorem interval distinct from any wider exploratory amplitude domain.

Signed shrinking sequences may support a qualified numerical parent-attachment gate. Their amplitude, parent distance, energy distance, closure, labeled BL2 minimality and two-sided success must be checked independently. The exact analytic curve alone does not certify every finite computed record or a requested-family global connection. Any future unrestricted release is a separately registered experiment with its own physical derivative and admission gates.

## Typed graph

Add an analytic node `analytic_exact_restricted_period_two_existence` for each actually studied resonance, with theorem scope and proof/audit evidence. Add a separate numerical node `restricted_period_two_orbit` only after the campaign shared-service admission. Retain actual label `unclassified` and a descriptive scope `standing opposed-spread, zero drift, primitive BL2`.

The analytic parent edge describes proved local existence in the invariant restriction. The numerical parent edge remains `unresolved_candidate` until the independently recorded shrinking, two-sign attachment gate succeeds. An evidence edge may connect the analytic family to its measured restricted orbit without asserting requested-family ancestry. No B2/F2/H2/G2 target node or full-system stability certificate is promoted by this integration.

The campaign master counts only its new executed map/solver evaluations and charged task wall. The prior standalone theory and solver pilot remain separately reported. Exact admission and nonlinear correction are separate observation records, and duplicate physical orbit states do not become distinct discovered gait families.
