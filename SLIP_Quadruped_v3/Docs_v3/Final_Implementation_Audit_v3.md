# Final v3 implementation audit

Audit date: 2026-08-05. This report covers the independent implementation
under `SLIP_Quadruped_v3` and the verbatim legacy restoration. It distinguishes
the passing parameter-asymmetric v3 orbit from the unresolved direct replay of
the prescribed-event asymmetric legacy fixtures.

## File-by-file change summary

### Schema and adapters

| File | Responsibility |
|---|---|
| `Schema_v3/QuadrupedSchema_v3.m` | Sole source of state, parameter, leg, event, mode, root, and tangent ordering; validation and family expansion. |
| `Adapters_v3/LegacyStateAdapter_v3.m` | Exact old/new full-state and 13-coordinate permutations with round trips. |
| `Adapters_v3/LegacyModeAdapter_v3.m` | Explicit `[BL,FL,BR,FR]` to `[BL,BR,FL,FR]` conversion. |
| `Adapters_v3/LegacyEventAdapter_v3.m` | Converts every event through its name rather than retaining old numeric IDs. |
| `Adapters_v3/LegacyParameterAdapter_v3.m` | Seven-to-ten parameter conversion with explicit `semantic-rsla` and `v2-exact` policies. |

### Dynamics and simulation

| File | Responsibility |
|---|---|
| `Dynamics_v3/HybridSystemBase_v3.m` | Generic configurable \((Q,X,F,G,\Delta)\) interface, validation, adjacency, and canonicalization hooks. |
| `Dynamics_v3/Quadrupedal_Dynamics_v3.m` | Schema-owned quadruped assembly and strict collaborator-interface validation. |
| `Dynamics_v3/ContinuousDynamics_v3.m` | Ten-parameter body/swing/stance flow, diagnostics, infinite inertia, and tensile-stance admissibility. |
| `Dynamics_v3/GuardFunctions_v3.m` | Eight named mode-enabled directional guards and true Lie derivatives. |
| `Dynamics_v3/ResetMap_v3.m` | Massless-leg rate projection with singularity checks and simultaneous independent reset support. |
| `Dynamics_v3/ModeTransition_v3.m` | Named contact-bit transitions and explicit debug-only all-mode enumeration. |
| `Simulation_v3/EventDetector_v3.m` | Guard arming, ODE integration, earliest-event selection, direction checks, and simultaneous batching. |
| `Simulation_v3/HybridSimulator_v3.m` | Repeated flow/guard/reset/transition execution with accepted-state admissibility and stop handling. |
| `Simulation_v3/Trajectory_v3.m` | Right-continuous time/state/mode/event storage, concatenation, termination metadata, and reset samples. |

### Orbit, section, and return policies

| File | Responsibility |
|---|---|
| `Orbit_v3/PoincareSection_v3.m` | General section; apex is `dy=0`, `ddy<0`, with no flight restriction. |
| `Orbit_v3/ReturnPolicyBase_v3.m` | Crossing-acceptance contract separated from section geometry. |
| `Orbit_v3/FirstReturnPolicy_v3.m` | First directional section return. |
| `Orbit_v3/IteratedReturnPolicy_v3.m` | Geometric \(P^m\) return. |
| `Orbit_v3/EventCycleReturnPolicy_v3.m` | Mode closure plus per-leg touchdown/liftoff completion without prescribed ordering. |
| `Orbit_v3/SectionModeResolver_v3.m` | Previous chart plus local toggles for section-near, directionally consistent guards. |
| `Orbit_v3/PoincareMap_v3.m` | Repeated crossings until policy acceptance, with event/signature/coincidence/topology diagnostics. |
| `Orbit_v3/PeriodicOrbitResidual_v3.m` | Twelve independent periodic equations plus raw `dy` phase equation. |
| `Orbit_v3/HybridOrbit_v3.m` | State, mode, period, parameters, histories, Poincare state, trajectory, and stability; no gait label. |

### Numerics and stability

| File | Responsibility |
|---|---|
| `Numerics_v3/FiniteDifferenceJacobian_v3.m` | Smooth adaptive forward/central differences with baseline reuse. |
| `Numerics_v3/HybridFiniteDifferenceJacobian_v3.m` | `h`/`h/2` refinement, Richardson plateau, topology checks, one-sided labels, and reliability. |
| `Numerics_v3/RootSolver_v3.m` | Local modes, scaling, map cache, invalid-trial rejection, fsolve/trust-region Newton, counters, and Jacobian reuse. |
| `Numerics_v3/NumericalContinuation1D_v3.m` | Named/indexed parameter correction and complete branch/topology metadata. |
| `Numerics_v3/PseudoArclengthContinuation_v3.m` | Extended tangent, predictor/corrector, adaptive step, chart boundaries, and unresolved tangent marking. |
| `Stability_v3/FloquetAnalysis_v3.m` | Full-cycle reduced derivative, multipliers, optional ambient diagnostic, and selected-step reliability. |
| `Stability_v3/BifurcationDetector_v3.m` | Reliable finite multiplier matching and unit, period-doubling, and Neimark--Sacker candidates. |
| `Stability_v3/HybridBoundaryDetector_v3.m` | Grazing, collision, insertion/deletion, section, multiplicity/signature, and force boundaries. |

### Graphics and examples

| File | Responsibility |
|---|---|
| `Graphics_v3/GraphicsDataAdapter_v3.m` | Normalizes trajectory/orbit inputs without the packed legacy contract. |
| `Graphics_v3/ComputeBodyGraphics_v3.m` | Schema-based torso geometry. |
| `Graphics_v3/ComputeJointLegGeometry_v3.m` | Mode-aware stance/swing leg geometry with family lengths and `l_com`. |
| `Graphics_v3/ComputeLegGraphics_v3.m` | Per-leg drawable geometry in canonical order. |
| `Graphics_v3/ComputePhaseDiagram_v3.m` | Contact phases from event history and accepted period. |
| `Graphics_v3/ResampleHybridTrajectory_v3.m` | Uniform reset-safe right-continuous frames and exact event frames. |
| `Graphics_v3/SLIP_Animation_Quad_v3.m` | Headless/classic/UI animation and optional video export. |
| `Graphics_v3/SLIP_GRF_Quad_v3.m` | Diagnostic GRFs in `[BL,BR,FL,FR]` order. |
| `Graphics_v3/SLIP_PeriodicOrbit_Quad_v3.m` | Periodic body/orbit visualization. |
| `Graphics_v3/SLIP_Trajectories_Quad_v3.m` | Canonical torso/back/front state plots. |
| `Graphics_v3/OutputCLASS_v3.m` | V3 graphics output container retaining attribution. |
| `Examples_v3/QuadrupedalExample_v3.m` | Fixture conversion, event-cycle map, optional seed perturbation, root correction, counters, and optional Floquet call. |
| `Examples_v3/QuadrupedalGraphicsExample_v3.m` | Noninteractive animation, trajectory, GRF, orbit, and phase-diagram example. |

### Tests and documentation

| File | Responsibility |
|---|---|
| `Tests_v3/TestQuadrupedSchemaAdapters_v3.m` | Exact schemas, all event mappings, validation edges, policies, and round trips. |
| `Tests_v3/TestQuadrupedDynamicsContracts_v3.m` | Body/swing equations, families, guards, resets, constraints, admissibility, and Lie derivatives. |
| `Tests_v3/TestReturnPolicies_v3.m` | First/iterated/event-cycle return, two apexes, grounded apex, coincidences, and local charts. |
| `Tests_v3/TestNumericsStabilityContracts_v3.m` | Smooth/hybrid differences, root context/cache, continuation names, candidates, and boundaries. |
| `Tests_v3/TestHybridFramework_v3.m` | Perturbed PK solve, discovered and parameter-asymmetric cycles, FR_LO/apex transition, full-cycle Floquet, and reliability rejection. |
| `Tests_v3/TestGraphics_v3.m` | Invisible figure/UIAxes construction, updates, geometry, order, lengths, and phases. |
| `Tests_v3/createSyntheticHybridSystem_v3.m` | Analytic radial and event/section-ordering systems. |
| `Tests_v3/createSyntheticReturnPolicySystem_v3.m` | Analytic two-apex, coincident, local-resolver, and radial systems. |
| `Tests_v3/legacyRestoredFiles_v3.m` | Static 70-file restoration manifest. |
| `README_v3.md` | Architecture, canonical mathematics, use, migration, scope, and limitations. |
| `Docs_v3/Quadruped_EOM_v3.md` | Parameter table and body/swing/reset derivations and biped limit. |
| `Docs_v3/State_Parameter_Event_Conventions_v3.md` | Exact coordinate, mode, event, root, and tangent tables. |
| `Docs_v3/Migration_v2_to_v3.md` | Permutations, policies, event names, metadata, and loading example. |
| `Docs_v3/Poincare_and_Cycle_Definition_v3.md` | Geometric and policy returns, multiple apexes, coincidences, and signatures. |
| `Docs_v3/Stability_and_Bifurcation_v3.md` | Full-cycle derivative, reliability, crossings, and nonsmooth boundaries. |
| `Docs_v3/Implementation_Workflow_v3.md` | Complete dependency and function-by-function legacy/v3 trace. |
| `Docs_v3/Legacy_Restoration_Audit_v3.md` | Every restored legacy file and exact blob-hash audit. |
| `Docs_v3/Final_Implementation_Audit_v3.md` | File-by-file implementation summary, executed evidence, and unresolved fixture-migration clause. |

## Exact final schemas

- State: `[x,dx,y,dy,phi,dphi,alphaBL,dalphaBL,alphaBR,dalphaBR,alphaFL,dalphaFL,alphaFR,dalphaFR]`.
- Mode: `[qBL;qBR;qFL;qFR]`, where `0=swing`, `1=stance`.
- Events: `[BL_TD,BL_LO,BR_TD,BR_LO,FL_TD,FL_LO,FR_TD,FR_LO]`.
- Parameters: `[k_l_b,k_l_f,k_s_b,k_s_f,l_l_b,l_l_f,rsla_b,rsla_f,j_pitch,l_com]`.
- Root coordinates: `x(2:14)`; translation gauge `x(1)=0`.
- Periodic/tangent indices: `[2,3,5:14]`; phase index `4` (`dy`).

## Swing equation and cycle completion

With `theta_i=phi+alpha_i` and `s_i=-l_com` for back legs or `1-l_com`
for front legs,

\[
\ddot\alpha_i=-\ddot\phi
-\frac{F_x\cos\theta_i+F_y\sin\theta_i}{l_i}
-\frac{s_i}{l_i}\ddot\phi\sin\alpha_i
+\frac{s_i}{l_i}\dot\phi^2\cos\alpha_i
-\frac{k_{s,i}}{l_i^2}(\alpha_i-rsla_i).
\]

The event-cycle policy accepts the first downward apex whose right-continuous
mode closes and for which every model-described leg has at least one touchdown
and one liftoff. Event ordering and intermediate apexes are discovered.

## Executed evidence

- MATLAB R2025b full suite: 55 total, 55 passed, 0 failed, 0 incomplete.
- Final focused hybrid/continuation class after the last production fixes: 10/10 passed.
- Perturbed converted PK solve:
  - initial residual infinity norm: `3.368938463295043e-06`;
  - final residual infinity norm: `2.963680412193526e-10`;
  - period: `1.564520217496343`;
  - two iterations, one accepted correction, one Jacobian evaluation;
  - 15 map evaluations, 18 function evaluations, 3 cache hits;
  - one local mode candidate;
  - events: `BL_TD, BR_TD, FL_TD, FR_TD, BL_LO, BR_LO, FL_LO, FR_LO`;
  - one touchdown and one liftoff per leg.
- Corrected parameter-asymmetric v3 orbit:
  - `k_l_b=10`, `k_l_f=10.02`, residual infinity norm
    `2.450835888401226e-09`, period `1.532276626995541`;
  - 43 map evaluations, 48 function evaluations, one local mode candidate;
  - touchdown times `0.466115574908` (back) and `0.466398616887`
    (front); liftoff times `1.06616105764` (back) and
    `1.06587800576` (front);
  - exactly one touchdown and one liftoff per leg, with discrete closure.
- Direct legacy-fixture diagnostic: BG column 204 is converted with the
  explicit state/mode/parameter adapters, starts with every swing-foot guard
  above `0.1`, and is then structurally rejected as
  `ContinuousDynamics_v3:TensileStance` when event discovery inserts the
  contact execution suppressed by its prescribed schedule. This is an
  executed migration diagnostic, not a successful-orbit claim.
- Analytic two-apex Floquet case:
  - computed multiplier `0.3011942118980038`, exact `exp(-1.2)=0.3011942119122021`;
  - absolute error `1.42e-11`;
  - selected step `2e-4`, estimated refinement error `7.88535903240017e-09`;
  - central Richardson, reliable classical derivative, 9 map evaluations.
- MATLAB Code Analyzer parsed all 53 `.m` files: 6 files carried 23
  advisory unused/performance/style diagnostics, with no parser errors.
- `git diff --check`: clean.
- Legacy: 70 expected, 70 present, zero `HEAD^` blob mismatches, and zero
  tracked v1/v2 modifications.

## Unresolved fixture-migration clause and limitations

The actual asymmetric-orbit behavior in Requirement L is exercised by the
passing parameter-continuation regression above. Its direct-fixture clause is
not claimed: sampled BE/BG/FE/FG/GE/GG/HE/HG roadmap points were generated for
the prescribed-event legacy formulation. V3 discovers additional contact
crossings that their schedule suppresses; subsequent rate projection and
unilateral-force validation can expose tensile stance or a singular stance
constraint. The suite therefore audits the old fixture and separately proves
a genuine v3 asymmetric cycle, but it does not describe the old fixture as a
successful integrated replay.

The stance acceleration retains validated legacy symbolic formulas rather
than a general DAE/contact solver. Full quadruped Floquet analysis is available
but disabled in the default example; the reported multiplier is an analytic
hybrid regression. At grazing, collision, coincidence, or topology changes, a
unique classical derivative can fail to exist, and v3 leaves the tangent and
Floquet result unresolved.
