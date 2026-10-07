# Round 4 production validation and bifurcation-completion report

Historical audit: the test sources, runners and generated test payloads cited
below were removed during the 2026-10-07 cleanup. These historical commands
and file lists are retained to explain the reported observations. Production
results remain in `4_Solution_Management/Examples_v3/Results_v3`; concise verification records and
the legacy file manifest remain in `Research_v3/Audits_v3`.

Date: 2026-08-11  
Reference commit: `a683f7f385a8d185517b63754aeb1d628c651d33`

## 1. Scope and claim boundary

This round extends the accepted `SLIP_Quadruped_v3` architecture. It does not
create a v4 framework, change the ten-parameter or fourteen-state quadruped
schemas, introduce event times or gait labels as root unknowns, or replace
the established simulator/map/residual/continuation APIs.

The completed source provides model-owned physical admissibility, explicit
atomic event-batch semantics, event-cluster topology, fail-closed hybrid
finite differences, symmetry-restricted and Bouligand derivative machinery,
bifurcation refinement, branch switching, a non-quadruped dissipative model,
and deterministic test/CI entry points.

The executed quadruped evidence validates:

- one nontrivial default-`HybridFiniteDifferenceJacobian_v3` correction in
  the left/right-invariant problem;
- 20 accepted simple-continuation points;
- 20 accepted pseudo-arclength points;
- three converged external step grids for the **left/right symmetry block**
  of the quadruped cycle-return map.

It does **not** establish a unique unrestricted Floquet matrix for the
structurally clustered orbit. The bounded searches did not locate an actual
grounded-apex orbit, multiple-apex quadruped cycle, contact/apex crossing,
genuinely non-simultaneous periodic orbit, physical bifurcation bracket, or
switched physical quadruped branch. Those cases remain unresolved and are
not replaced by synthetic evidence.

## 2. Reproducibility baseline

Before Round 4 changes:

- `HEAD` exactly matched the requested reference commit;
- `git status --short` was clean;
- `git diff --check` was clean;
- MATLAB was `25.2.0.3177638 (R2025b) Update 5` on `MACA64`;
- 47 installed MATLAB products were recorded;
- the complete pre-change suite executed in 35.060991583 s;
- 59 of 60 tests passed, one failed, and none were incomplete.

The sole baseline failure was
`TestHybridFramework_v3/everyRestoredLegacyFileRemainsPresent`: 70 files in
the historically restored Floquet tree were absent from the reference
commit. The actual baseline output is retained in
`Docs_v3/Round4_Prechange_Audit_v3.md`.

The 70 files were restored byte-for-byte from historical commit `c1aafb0`.
The historical `TestLegacyPreservationRound4_v3` verified every blob against
the manifest preserved at `Research_v3/Audits_v3/LegacyFloquetManifest_v3.tsv`.
No tracked v1/v2 file differed from the reference commit.

## 3. Implemented functionality

### 3.1 Model-owned physical admissibility

`1_Dynamic_Frameworks/Dynamics_v3/QuadrupedAdmissibility_v3.m` separates:

1. transient ODE-stage checks;
2. accepted integration-state checks;
3. post-reset checks;
4. section-return checks.

For leg (i), with

\[
\theta_i=\phi+\alpha_i,
\qquad
H_i=y+s_i\sin\phi,
\]

the swing-foot clearance is evaluated directly as

\[
c_i^{sw}=H_i-l_{0,i}\cos\theta_i.
\]

No swing quantity is computed by dividing through
\(\cos\theta_i\). For a stance leg only,

\[
L_i=\frac{H_i}{\cos\theta_i},
\qquad
\delta_i=l_{0,i}-L_i.
\]

Strict accepted-state conditions include

\[
c_i^{sw}\ge-\varepsilon_{sw},
\qquad
\delta_i\ge-\varepsilon_{st},
\qquad
L_i>L_{min}.
\]

The report also carries back/front hip clearances, torso clearance, finite
geometry, downward-orientation margins, post-reset guard residuals,
mode/guard complementarity residuals, per-leg validity, active tolerances,
failure reasons, and global/minimum physical margins. Small ODE stage
excursions use a separate configurable tolerance; accepted samples, event
states, resets, and section returns use the strict tolerances.

The margins propagate through `HybridSimulator_v3`, `PoincareMap_v3`,
`HybridOrbit_v3`, both continuation objects, and
`HybridBoundaryDetector_v3`. Physical boundary labels include:

- `swing_foot_penetration`;
- `torso_ground_contact`;
- `invalid_leg_geometry`;
- `contact_complementarity_loss`.

They are never labelled smooth Floquet bifurcations.

### 3.2 Ten-parameter quadruped swing dynamics

The preserved state and parameter schemas are

\[
x=[x,\dot x,y,\dot y,\phi,\dot\phi,
\alpha_{BL},\dot\alpha_{BL},\alpha_{BR},\dot\alpha_{BR},
\alpha_{FL},\dot\alpha_{FL},\alpha_{FR},\dot\alpha_{FR}]^T,
\]

\[
p=[k_{l,b},k_{l,f},k_{s,b},k_{s,f},l_{l,b},l_{l,f},
r_{sla,b},r_{sla,f},J_{pitch},l_{com}]^T.
\]

For each swing leg,

\[
\ddot\alpha_i=-\ddot\phi
-\frac{F_x\cos\theta_i+F_y\sin\theta_i}{l_i}
-\frac{s_i}{l_i}\ddot\phi\sin\alpha_i
+\frac{s_i}{l_i}\dot\phi^2\cos\alpha_i
-\frac{k_{s,i}}{l_i^2}(\alpha_i-r_{sla,i}),
\]

where (s_i=-l_{com}) for BL/BR and (s_i=1-l_{com}) for
FL/FR. Tests cover the zero-`rsla` limit, torque removal at
\(\alpha=r_{sla}\), distinct front/back parameters, and the biped limit.

### 3.3 Atomic event batches

`HybridSystemBase_v3.resolveEventBatch` is the generic extension point.

| Model behavior | Recorded semantics |
|---|---|
| Generic scalar-reset fallback | `ordered-sequential-fallback` |
| Quadruped distinct-leg batch | `commuting-independent-leg-resets` |
| Coupled synthetic impact | model-owned atomic reset |

The generic fallback deliberately preserves priority ordering and records
that choice. `Quadrupedal_Dynamics_v3` checks scalar reset and transition
products in alternate orders before certifying commutativity. The simulator
delegates one complete simultaneous batch to the model and stores batch
members, pre/post state, pre/post mode, semantics, commutativity evidence,
and per-event history. It no longer assumes that event priority is
physically irrelevant.

### 3.4 Event clusters and hybrid boundaries

`1_Dynamic_Frameworks/Simulation_v3/EventCluster_v3.m` groups events when their spread satisfies

\[
\max t_i-\min t_i\le
\max\{\varepsilon_{abs},\varepsilon_{rel}\max(1,|t_a|,|t_b|),
128\,\mathrm{eps}(\max(1,|t_a|,|t_b|))\}.
\]

Each accepted orbit stores cluster membership and names, center times,
maximum intra-cluster spread, minimum inter-cluster center gap, relative
phase, linear and cyclic cluster signatures, and section/cluster
coincidences. Comparing adjacent points distinguishes:

- `persistent_simultaneous_cluster`;
- `event_cluster_collision`;
- `event_cluster_split`;
- `event_cluster_merge`;
- `section_cluster_coincidence`.

A persistent structural BL/BR or four-leg cluster is not called an event
collision merely because its internal time spread is zero.

### 3.5 Hybrid finite differences and Floquet analysis

The default hybrid differentiator now requires compatible cyclic,
section-relative, and cluster signatures, cycle completion, discrete closure,
return multiplicity, and guard/section transversality. For coordinate (i),

\[
h_i=r_j(1+|z_i|),
\]

with multiple candidate (r_j). It compares central estimates at (h) and
\(h/2\), optionally applying Richardson extrapolation,

\[
D_i=\frac{4D_{h/2}-D_h}{3}.
\]

Return multiplicity is now recorded for every stencil execution and checked
directly; it is not inferred from an event signature. At a section chart
boundary the forward and backward one-sided matrices, errors, multiplicities,
and adjacent signatures are retained separately. A central stencil crossing
`LO_FR < Apex` to `Apex < LO_FR` is rejected as a unique classical
derivative even when its cyclic signature is unchanged.

`FloquetAnalysis_v3` differentiates the complete accepted cycle map
\(P_C\), including guard-time variation and resets. It reports no reliable
classical matrix at a chart coincidence, topology change, multiplicity
change, mode-closure failure, grazing condition, unresolved cluster order,
or non-invariant supplied subspace.

### 3.6 Symmetry and nonsmooth cluster derivatives

`SymmetrySubspace_v3` constructs fixed and complementary representation
subspaces. `SymmetryRestrictedFloquet_v3` differentiates

\[
\eta=Bz
\]

and verifies that the selected (h,h/2) stencil preserves the intended
cluster topology and has acceptably small transverse leakage. Multipliers
are explicitly labelled by symmetry block.

`EventClusterDerivative_v3` enumerates nearby event orders and retains the
Bouligand set

\[
\mathcal{B}P_C=\{M_\sigma:\sigma\text{ is an admissible ordering}\}.
\]

Incompatible matrices are never averaged. A unique matrix is returned only
when all reliable admissible limits agree. For model-based enumeration,
supplying a Boolean filter is not enough to certify the guard-time cone; the
predicate must return affirmative cone-resolution evidence. Thus the actual
quadruped reset test establishes commuting independent reset products, but
does not overstate them as a resolved unrestricted full-cycle derivative.

### 3.7 Root solving and continuation

`RootSolver_v3` retains mode as a discrete candidate and solves only
continuous unknowns. It records initial/final residuals, map and function
evaluations, cache hits, Jacobian evaluations, selected finite-difference
steps, per-column reliability, mode resolution, accepted corrections, and
invalid trials. Section modes are resolved locally from the previous mode
and section-near guards; the solver does not enumerate all 16 modes.

Both continuation implementations carry return policy, multiplicity, cyclic,
section-relative and cluster signatures, cluster diagnostics, admissibility
margins, solver statistics, and stability. An exact section/event boundary
is retained as an accepted branch point but has no claimed smooth tangent or
Floquet matrix. Pseudo-arclength continuation rejects an initial point that
is itself an unresolved chart boundary.

### 3.8 Bifurcation refinement

`BifurcationDetector_v3` brackets multiplier crossings only when both
endpoints explicitly report reliable, complete, compatible topology. It
checks both interval endpoints and fails closed on missing structured data.

For a unit-multiplier candidate, `BifurcationRefiner_v3` solves the
Moore--Spence equations

\[
F(u,\mu)=0,
\qquad F_u(u,\mu)v=0,
\qquad c^Tv=1.
\]

It computes a left null vector (w), normalizes (w^Tv=1), and evaluates

\[
a=w^TF_\mu,
\qquad
b=\tfrac12 w^TF_{uu}[v,v].
\]

A fold is classified only when both coefficients exceed their tolerances.
If (a\approx0), the result explicitly requests additional
pitchfork/transcritical/symmetry information. Period-doubling refinement
uses \((DP_C+I)v=0\). Neimark--Sacker refinement requires an explicitly
selected nonreal candidate, conjugacy, unit modulus, and nonzero critical
angle. Every refiner is fail-closed on unreliable topology, chart
coincidence, or unresolved event ordering.

### 3.9 Branch switching

`BranchSwitching_v3` forms the signed predictors

\[
u_\pm=u_*\pm\epsilon v
\]

and applies augmented correction with branch separation and optional
deflation. A child must be distinct from its parent, close the full event
cycle and mode, be physically admissible, have a small residual, and carry
complete cyclic/section/cluster signatures, positive integer multiplicity,
and explicit negative evidence for chart/coincidence/unresolved-ordering
hazards.

The doubled return problem is

\[
P_C^2(u,\mu)-u=0,
\qquad
\|P_C(u,\mu)-u\|>arepsilon_{P1}.
\]

The period-one exclusion is enforced during correction and subsequent
pseudo-arclength continuation. Symmetry breaking projects the critical
vector into the relevant complementary representation subspace and reports
parent/child stabilizers; \(\lambda=1\) alone is never called a pitchfork.

### 3.10 Second generic hybrid model

`4_Solution_Management/Examples_v3/Models/BipedalHybridModel_v3.m` has state dimension 2 and
parameter dimension 5, with no dependency on `QuadrupedSchema_v3`:

\[
x=[y,\dot y]^T,
\qquad
p=[g,k,c,e_{td},J_{lo}]^T.
\]

Flight uses \(\ddot y=-g\), stance uses
\(\ddot y=-g-ky-c\dot y\), touchdown applies
\(\dot y^+=e_{td}\dot y^-\), and liftoff applies
\(\dot y^+=\dot y^-+J_{lo}\). A model-specific apex section and
alternating two-leg stride policy complete the generic root, continuation,
and Floquet pipeline. The model is dissipative and actively forced, so it is
not energy conservative.

## 4. Actual quadruped numerical validation

The executed artifact is
`4_Solution_Management/Examples_v3/Results_v3/Round4_Quadruped_Production_Study_v3.mat`; its full
human-readable numerical index, including all three 8-by-8 matrices and
multipliers, is
`4_Solution_Management/Examples_v3/Results_v3/Round4_Quadruped_Production_Study_v3.md`.

Execution environment: MATLAB R2025b Update 5, MACA64. Initial production
wall time was 1375.7943515 s; bounded searches added 187.954 s. No prescribed
event time or gait label was used.

### 4.1 Continuation

The nine-point forward-secant homotopy was seed preparation only and is
excluded from validated point counts.

| Study | Accepted | Parameter interval (`k_l_f`) | Max residual | Min physical margin | Map evals | Invalid trials |
|---|---:|---:|---:|---:|---:|---:|
| Simple, hybrid FD | 20/20 | 10.16 to 10.14 | 5.5632380161e-9 | 9.9999917843e-9 | 1611 | 0 |
| Pseudo-arclength, hybrid FD | 20/20 | 10.14 to 10.2600771895 | 4.2813447232e-10 | 9.9999906741e-9 | 1501 | 0 |

Both branches retained one return, no section/cluster coincidence, and the
same signatures:

```text
cyclic: BL_LO&BR_LO>BL_TD&BR_TD>FL_TD&FR_TD>FL_LO&FR_LO
section: BL_TD&BR_TD>FL_TD&FR_TD>FL_LO&FR_LO>BL_LO&BR_LO
cluster: BL_TD&BR_TD>FL_TD&FR_TD>FL_LO&FR_LO>BL_LO&BR_LO
```

### 4.2 Default hybrid-Jacobian correction

`RootSolver_v3` was constructed without replacing its installed
`HybridFiniteDifferenceJacobian_v3`. The left/right-invariant reduced
problem made a mandatory correction:

| Quantity | Executed value |
|---|---:|
| Initial residual | 1.074501598183342e-5 |
| Final residual | 1.999040932787466e-10 |
| Map evaluations | 435 |
| Function evaluations | 439 |
| Cache hits | 4 |
| Jacobian evaluations | 2 |
| Accepted Newton corrections | 2 |
| Invalid trials | 0 |
| Mode candidates | 1 |
| Reliable columns | 9/9 |

The selected steps and per-column errors are stored in the production report
and MAT artifact. A post-removal metadata preflight independently corrected
3.6232041151e-6 to 3.7957009983e-9 with one reliable Jacobian and one accepted
correction.

### 4.3 Symmetry-restricted Floquet convergence

All calculations differentiate the accepted full-cycle map on the
left/right-invariant 8-dimensional section chart. ODE tolerances were
`RelTol=1e-9`, `AbsTol=1e-11`; guard transversality was
0.3944034137465895, section transversality was 1, and every grid used 97 map
evaluations.

| Candidate-step grid | Reliable | Matrix difference to finer grid | Matched multiplier difference |
|---|---:|---:|---:|
| `[3e-3,1e-3,3e-4]` | yes | 1.403019109886042e-7 | 4.988706114872343e-10 |
| `[1e-3,3e-4,1e-4]` | yes | 2.173278454024572e-9 | 5.442815223645985e-11 |
| `[3e-4,1e-4,3e-5]` | yes | reference | reference |

The matrices and matched multipliers converge under refinement, but they are
the multipliers of a supplied symmetry block. The near-unit block multiplier
is not classified as a fold, pitchfork, transcritical, period-doubling, or
Neimark--Sacker point.

### 4.4 Bounded physical searches

The unrestricted topology-aware HybridFD search used:

- `k_l_f = [10.14, 6.084, 2.028]`;
- `l_l_f = [1, 1.225, 1.45]`;
- `k_s_f = [20, 10, 0]`.

Only each starting point was accepted: 3 accepted observations and 6 rejected
corrections. Structured causes were maximum iterations, FL/FR stance tension,
and section-return FL/FR swing-foot penetration plus complementarity loss.

A four-attempt left/right-breaking multistart used amplitudes `1e-3` and
`1e-2`. The two smaller attempts hit the iteration limit; the two larger
attempts converged to residual 2.22872e-9 but returned to the clustered
branch. No genuinely non-simultaneous production orbit was found.

Therefore the following actual quadruped requirements remain unresolved:

- grounded apex;
- multiple-apex full cycle and actual FirstReturn/EventCycle comparison;
- physical contact event crossing the apex;
- refined section/contact coincidence;
- unrestricted classical Floquet matrix for a split cluster;
- full-cycle quadruped guard-time ordering limits;
- physical bifurcation bracket/refinement;
- physical quadruped branch switch.

## 5. Synthetic numerical validation

Synthetic analytic tests validate machinery without being counted as the
physical cases above:

- structural four-event and bilateral clusters, split/merge, and collision;
- order-dependent sequential resets and coupled atomic reset semantics;
- equal and incompatible Bouligand ordering matrices;
- equal cyclic but incompatible section-relative signatures, with both
  one-sided chart matrices retained;
- two-apex FirstReturn versus EventCycle behavior;
- symmetry fixed/complement bases and block leakage rejection;
- Moore--Spence unit refinement and (a,b) coefficients;
- zero-(a) rejection of a fold label;
- period-doubling and candidate-directed Neimark--Sacker refinement;
- signed unit-multiplier branch switching and symmetry projection;
- doubled-return period-two correction and hard period-one exclusion.

## 6. Actual second-model validation

The biped test class executed an event-discovered alternating stride with
physical event history, a nontrivial corrected root, a three-point parameter
branch, and a Floquet result. Static source inspection in the test fails if
generic numerics import or inspect `QuadrupedSchema_v3`. All six biped tests
passed in the final complete suite.

## 7. Test and source-hygiene results

### 7.1 Final deterministic suite

Historical command (the runner was removed during cleanup):

```matlab
cd SLIP_Quadruped_v3
results = run_all_tests_v3();
```

Actual final result:

```text
MATLAB: 25.2.0.3177638 (R2025b) Update 5
Platform: MACA64
Elapsed seconds: 164.306587792
Total: 137
Passed: 137
Failed: 0
Incomplete: 0
```

Historical generated outputs (removed during cleanup):

- `Docs_v3/TestResults_v3/junit-results-v3.xml`;
- `Docs_v3/TestResults_v3/matlab-test-results-v3.mat`;
- `Docs_v3/TestResults_v3/test-summary-v3.txt`.

No test is reported as passed unless it was executed. Production artifact
tests load the recorded long study and do not pretend to rerun its 26-minute
calculation in the ordinary suite.

### 7.2 Required-test coverage

| Requirement | Evidence | Status |
|---|---|---|
| 1--3 physical admissibility | `TestQuadrupedAdmissibility_v3` | passed |
| 4 independent reset commutativity | `TestEventBatchSemantics_v3` | passed |
| 5 coupled atomic reset | `TestEventBatchSemantics_v3` | passed |
| 6--7 structural/collision/split/merge clusters | `TestEventClusters_v3` | passed |
| 8 section-relative mismatch | `TestNumericsStabilityContracts_v3` | passed |
| 9 default hybrid root correction | production artifact, symmetry restricted | passed for symmetric case; non-sim case unresolved |
| 10 actual 20-point simple continuation | production artifact | passed |
| 11 actual 20-point pseudo-arclength | production artifact | passed |
| 12 grounded apex | bounded physical search | not found |
| 13 multiple apex | bounded physical search | not found |
| 14 event/apex crossing | bounded physical search; synthetic chart test separate | not found physically |
| 15 production Floquet convergence | three artifact grids | passed for symmetry block |
| 16 symmetry-restricted Floquet | `TestSymmetryFloquet_v3` plus artifact | passed |
| 17 incompatible ordering matrices | `TestEventClusterDerivative_v3` | passed synthetically; actual full-cycle quadruped cone unresolved |
| 18--20 refinement | `TestBifurcationRefiner_v3` | passed synthetically |
| 21--22 branch switching/period-one exclusion | `TestBranchSwitching_v3` | passed synthetically |
| 23 generic non-quadruped pipeline | `TestGenericBipedModel_v3` | passed actually |
| 24 legacy preservation | manifest hash test and no tracked v1/v2 diff | passed |

### 7.3 Code Analyzer and source hygiene

The historical `run_code_analyzer_v3` inspected 78 files and exited successfully. It reported
28 non-error findings: 12 warnings and 16 informational/performance findings;
there were no parser/analyzer errors. The historical generated table was
`Docs_v3/TestResults_v3/code-analyzer-issues-v3.csv` and was removed during
cleanup. The later research campaign's separate analyzer record remains in
`Research_v3/Audits_v3/code-analyzer-issues-v3.csv`; it describes a different
source snapshot and is not evidence for the 78-file count above.

Final `git diff --check` is clean. No tracked legacy v1/v2 file is modified.

### 7.4 CI status

The historical `.github/workflows/slip-quadruped-v3-tests.yml` recipe used MATLAB Actions to run:

1. source whitespace checks;
2. `run_all_tests_v3`;
3. `run_code_analyzer_v3`;
4. artifact upload.

The deterministic local runner passed. The GitHub Actions workflow was added
but was not pushed or remotely executed in this round, so CI is **not claimed
to be passing**. The test and analyzer runners were subsequently removed in
the 2026-10-07 cleanup; the old recipe is not a current validation instruction.

## 8. Numerical tolerances

Key defaults used by the framework are:

| Component | Tolerance/default |
|---|---:|
| Simulator `RelTol`, `AbsTol` | `1e-9`, `1e-11` |
| Event value/time | `1e-8`, `1e-10` |
| Simultaneous-event time | `1e-8` |
| Guard direction / arming | `1e-10`, `1e-9` |
| Cluster absolute / relative | `1e-10`, `128*eps` |
| Cluster collision screen | `1e-5` |
| Swing penetration | `1e-8` |
| Stance tension | `1e-8` |
| Minimum leg length | `1e-8` |
| Complementarity | `1e-8` |
| Post-reset guard | `1e-7` |
| ODE-stage surface excursion | `1e-5` |
| Root function / step / acceptance | `1e-9`, `1e-10`, `1e-7` |
| Hybrid FD candidate relative steps | `[1e-3,3e-4,1e-4,3e-5,1e-5,3e-6]` |
| Hybrid FD max estimated relative error | `5e-2` |
| Guard / section transversality | `1e-7`, `1e-8` |
| Moore--Spence residual acceptance | `1e-8` |
| Moore--Spence nondegeneracy | `1e-6` |
| Branch child residual / parent distance | `1e-8`, `1e-6` |
| Period-one exclusion | `1e-6` |

Study-specific grids and ODE tolerances are recorded per production point in
the MAT artifact rather than inferred from these defaults.

## 9. Files changed or added

### Modified existing v3 sources

- `1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m`
- `1_Dynamic_Frameworks/Dynamics_v3/HybridSystemBase_v3.m`
- `1_Dynamic_Frameworks/Dynamics_v3/Quadrupedal_Dynamics_v3.m`
- `1_Dynamic_Frameworks/Simulation_v3/HybridSimulator_v3.m`
- `1_Dynamic_Frameworks/Simulation_v3/Trajectory_v3.m`
- `4_Solution_Management/HybridOrbit_v3.m`
- `4_Solution_Management/PoincareMap_v3.m`
- `4_Solution_Management/PeriodicOrbitResidual_v3.m`
- `3_Numerical_Continuation/1_Root_Solving/HybridFiniteDifferenceJacobian_v3.m`
- `3_Numerical_Continuation/2_Continuation_Algorithms/NumericalContinuation1D_v3.m`
- `3_Numerical_Continuation/2_Continuation_Algorithms/PseudoArclengthContinuation_v3.m`
- `3_Numerical_Continuation/1_Root_Solving/RootSolver_v3.m`
- `3_Numerical_Continuation/3_Bifurcation_Analysis/BifurcationDetector_v3.m`
- `3_Numerical_Continuation/3_Bifurcation_Analysis/FloquetAnalysis_v3.m`
- `3_Numerical_Continuation/3_Bifurcation_Analysis/HybridBoundaryDetector_v3.m`
- `Tests_v3/TestHybridFramework_v3.m`
- `Tests_v3/TestNumericsStabilityContracts_v3.m`
- `Tests_v3/TestQuadrupedDynamicsContracts_v3.m`

### New v3 implementation sources

- `1_Dynamic_Frameworks/Dynamics_v3/QuadrupedAdmissibility_v3.m`
- `1_Dynamic_Frameworks/Simulation_v3/EventCluster_v3.m`
- `3_Numerical_Continuation/2_Continuation_Algorithms/BranchSwitching_v3.m`
- `3_Numerical_Continuation/3_Bifurcation_Analysis/BifurcationRefiner_v3.m`
- `3_Numerical_Continuation/3_Bifurcation_Analysis/EventClusterDerivative_v3.m`
- `3_Numerical_Continuation/3_Bifurcation_Analysis/SymmetryRestrictedFloquet_v3.m`
- `3_Numerical_Continuation/3_Bifurcation_Analysis/SymmetrySubspace_v3.m`
- `4_Solution_Management/Examples_v3/QuadrupedalContinuationStudy_v3.m`
- `4_Solution_Management/Examples_v3/Models/BipedalHybridModel_v3.m`
- `4_Solution_Management/Examples_v3/Models/BipedStrideReturnPolicy_v3.m`
- `4_Solution_Management/Examples_v3/Models/BipedalHybridExample_v3.m`

### New tests and support data

- `Tests_v3/AtomicBatchSyntheticSystem_v3.m`
- `Tests_v3/LegacyFloquetManifest_v3.tsv`
- `Tests_v3/TestBifurcationRefiner_v3.m`
- `Tests_v3/TestBranchSwitching_v3.m`
- `Tests_v3/TestEventBatchSemantics_v3.m`
- `Tests_v3/TestEventClusterDerivative_v3.m`
- `Tests_v3/TestEventClusters_v3.m`
- `Tests_v3/TestGenericBipedModel_v3.m`
- `Tests_v3/TestLegacyPreservationRound4_v3.m`
- `Tests_v3/TestProductionQuadrupedContinuation_v3.m`
- `Tests_v3/TestProductionQuadrupedFloquet_v3.m`
- `Tests_v3/TestQuadrupedAdmissibility_v3.m`
- `Tests_v3/TestSymmetryFloquet_v3.m`

### Reports, runners, artifacts, and CI

- `Docs_v3/Round4_Prechange_Audit_v3.md`
- `Docs_v3/Round4_Methods_and_Workflow_v3.md`
- `Docs_v3/Round4_Production_Validation_Report_v3.md`
- `Docs_v3/TestResults_v3/*`
- `4_Solution_Management/Examples_v3/Results_v3/README_v3.md`
- `4_Solution_Management/Examples_v3/Results_v3/Round4_Quadruped_Production_Study_v3.mat`
- `4_Solution_Management/Examples_v3/Results_v3/Round4_Quadruped_Production_Study_v3.md`
- `run_all_tests_v3.m`
- `run_code_analyzer_v3.m`
- `.github/workflows/slip-quadruped-v3-tests.yml`

### Restored legacy content

- 70 historical files under
  `SLIP_Quadruped/3_Numerical_Continuation/2_FloquetAnalysis/`, restored
  exactly from `c1aafb0` and verified against the manifest.

Existing `QuadrupedSchema_v3`, adapters, return policies, graphics, v1/v2
sources, and public schemas remain intact.

## 10. Remaining limitations

1. The validated quadruped Floquet result is symmetry restricted. Generic
   perturbations split the structural left/right event pairs, and an
   unrestricted unique classical derivative has not been demonstrated.
2. Quadruped instantaneous independent reset products commute, but actual
   full-cycle guard-time/saltation ordering cones were not resolved on a
   structural quadruped orbit.
3. The physical search ranges were bounded, not exhaustive. They did not
   locate grounded-apex, multiple-apex, event/apex-crossing, or genuinely
   non-simultaneous periodic solutions.
4. No actual quadruped bifurcation bracket satisfied the eligibility
   conditions, so no physical Moore--Spence refinement or branch switch was
   attempted.
5. Neimark--Sacker refinement is implemented and analytically tested, but
   torus continuation is outside this round.
6. The restored legacy files fix the baseline preservation failure but remain
   historical code; the v3 production path does not import them.
7. Local MATLAB tests pass, but the new remote GitHub Actions workflow has
   not yet run.

These limitations are recorded as such; none is represented as a validated
fold, pitchfork, transcritical, period-doubling, Neimark--Sacker bifurcation,
new gait branch, or unrestricted robust quadruped Floquet spectrum.
