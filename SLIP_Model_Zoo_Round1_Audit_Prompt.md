# Codex Round 1 Prompt — SLIP_Model_Zoo Baseline and Scientific Audit

## Repository

- Repository: `https://github.com/DLARlab/SLIP_Model_Zoo`
- Primary scope: `SLIP_Quadruped/`
- Work on the current checked-out commit and branch.

## Role

Act simultaneously as:

1. A senior researcher in hybrid dynamical systems, legged-locomotion modeling, periodic-orbit computation, nonlinear equation solving, and numerical continuation.
2. A senior numerical analyst experienced with conditioning, scaling, Jacobians, adaptive integration, convergence studies, and reproducible scientific computing.
3. A senior MATLAB scientific-software reviewer experienced with dependency analysis, profiling, testing, data schemas, and maintainable research software.

## Round 1 objective

Execute **only the baseline and audit work** described below. This round is intentionally audit-first.

Do **not** modify production numerical behavior. Do not refactor the dynamics, residual equations, solvers, continuation algorithms, gait classifier, visualization, or GUI in this round.

You may add isolated audit infrastructure, tests, and documentation needed to reproduce findings, provided those additions do not alter existing runtime behavior.

The goals of Round 1 are to:

- Establish a reproducible numerical and software baseline.
- Inventory the current repository and its actual dependencies.
- Formalize the implemented hybrid dynamical system.
- Audit the periodic-orbit residual and its dimensions/rank.
- Audit event-time regulation and contact-mode logic.
- Measure major execution costs without optimizing them yet.
- Produce a prioritized, evidence-backed plan for later implementation rounds.

Stop after completing Round 1. Do not proceed into solver redesign, continuation refactoring, GUI decomposition, or large file moves.

---

# Operating rules

## 1. Repository instructions and environment

1. Inspect every applicable `AGENTS.md` file before doing any work and follow the most specific instructions for each path.
2. Record:
   - Current commit SHA
   - Current branch
   - Initial `git status`
   - Operating system
   - MATLAB release
   - Available MATLAB toolboxes
   - Whether a display session is available
   - Random-number-generator state or seed used by any audit script
3. If MATLAB, a required toolbox, or a display is unavailable:
   - Do not fabricate runtime, solver, profiling, or graphics results.
   - Perform the static portion of the audit.
   - Add or propose the missing harness where appropriate.
   - Report the exact blocker and the exact command that should be run in a suitable environment.

## 2. Scientific safety

Do not silently change any of the following:

- Equations of motion
- Coordinate or sign conventions
- Contact semantics
- Touchdown or liftoff handling
- Reset or velocity-projection maps
- Periodicity conditions
- Poincaré section
- Gait definitions
- Solver tolerances
- ODE tolerances
- Continuation metrics
- Acceptance thresholds
- Existing valid reference results
- The documented 29-row `results` format

Do not modify existing `.mat`, `.fig`, or `.mlx` research artifacts.

Record hashes or equivalent checks for representative reference artifacts before and after the audit so that unintended changes can be detected.

## 3. Evidence standard

Classify every finding as one of:

- `CD`: Confirmed defect established directly from source or execution
- `ND`: Numerically demonstrated defect
- `LD`: Likely defect requiring model-owner confirmation
- `NR`: Numerical robustness risk
- `PH`: Performance hypothesis requiring measurement
- `AD`: Architecture or extensibility debt
- `RG`: Reproducibility, dependency, data, or documentation gap

Assign independently:

- Severity: `P0`, `P1`, `P2`, or `P3`
- Confidence: `confirmed`, `high`, `medium`, or `low`

Every finding must include:

- Finding ID
- Classification
- Severity
- Confidence
- Exact file and line
- Relevant entry point or code path
- Evidence, reproduction, or mathematical argument
- Root cause
- Scientific or software consequence
- Minimal correction proposed for a later round
- Regression test required
- Whether the proposed correction would change model semantics

Do not present a candidate problem as confirmed until it has been verified.

## 4. Permitted changes in Round 1

Permitted additions include:

- Audit documentation under `docs/`
- Isolated audit scripts under `tools/` or `tools/audit/`
- Non-invasive tests under `tests/` or `tests/round1/`
- Machine-readable audit output under a clearly named generated-output directory that is ignored by Git

Do not edit production implementation files unless a minimal edit is strictly necessary to make the audit harness executable. If such an edit appears necessary, stop and report it rather than making the change.

Avoid unrelated formatting, renaming, file moves, and cleanup.

---

# Workstream 0 — Reproducible environment and baseline

## 0.1 Static and dependency checks

Run or prepare the following, as available:

- MATLAB Code Analyzer or `checkcode` over all `.m` files
- `runtests`
- `which -all` for important public function names
- Required-product or dependency analysis
- Search-path inspection and path-shadowing checks
- `git diff --check`

At minimum, inspect name resolution for:

- `SLIP_Quadruped_GUI`
- `Quadrupedal_ZeroFun_v2`
- `SolveQuadrupedalZE`
- `NumericalContinuation1D_Quadruped_v2`
- `NumericalContinuation2D_Quadruped_v2`
- `ParameterVarying2D_Quadruped_v2`
- `EventTimingRegulation`
- `Gait_Identification`
- `Func_alphaB_VA_v2`
- `Func_alphaF_VA_v2`

Report duplicate definitions, shadowed functions, missing entry points, and undocumented toolbox dependencies.

## 0.2 Reference cases

Select a small set of representative stored solutions from the repository without changing them. Prefer cases that collectively exercise:

- A valid periodic solution
- Wrapped event times
- At least two distinct gait classes
- A branch containing multiple columns
- A model parameter value away from a singular boundary

Document exactly which files and columns were selected and why.

## 0.3 Baseline executions

When the environment permits, record reproducible results for:

1. One residual-only evaluation.
2. One full-output stride simulation.
3. One periodic-orbit root correction from a nearby stored seed.
4. One very short 1-D continuation run with a strict iteration/point cap.
5. One gait-identification call on a single solution and one branch.
6. One invisible or headless graphics construction/update, if supported.

For each execution record:

- Exact command
- Input file and column
- Solver and ODE options
- Runtime
- Function evaluations
- Solver iterations
- Residual norm
- ODE output-point count or step count, where available
- Warnings and errors
- Files created
- Relevant side effects

Do not run an unbounded continuation or parameter scan.

---

# Workstream 1 — Current architecture and data contracts

## 1.1 Complete source inventory

Produce the current repository tree and classify every relevant file as:

- Production runtime code
- Symbolic derivation or code generator
- Generated code
- Experimental code
- Legacy compatibility code
- GUI or visualization code
- Solution-management or persistence code
- Example or reference data
- Documentation
- Apparently dead, stale, or unclassified code

For every source file, document:

- Purpose
- Public functions or classes
- Inputs and outputs
- Direct dependencies
- File-system or graphics side effects
- Whether it was statically inspected
- Whether it was executed
- Whether it is covered by a test
- Whether it was profiled
- Any blocker preventing deeper inspection

Do not claim complete coverage unless every relevant source file appears in the inventory.

## 1.2 Entry-point and dependency map

Build a call/dependency map beginning at:

- `SLIP_Quadruped_GUI`
- `Quadrupedal_ZeroFun_v2`
- `SolveQuadrupedalZE`
- `NumericalContinuation1D_Quadruped_v2`
- `NumericalContinuation2D_Quadruped_v2`
- `ParameterVarying2D_Quadruped_v2`
- `EventTimingRegulation`
- `Gait_Identification`
- Graphics constructors and update methods

Identify:

- Nested-function dependencies
- Duplicated local and standalone function definitions
- Global-state dependencies
- Dynamic path changes
- File-name conventions used as implicit APIs
- MAT-file variables used as implicit schemas

## 1.3 Canonical schema table

Create one canonical table defining:

- The 13-element initial-state vector
- The 9-element event-time vector
- The 7-element model-parameter vector
- The 14-element integrated state
- The 16-element output/visualization parameter vector
- The combined 22-element periodic-orbit unknown
- The 29-row saved branch format

For every entry include:

- Index
- Programmatic name
- Mathematical symbol
- Physical meaning
- Units or nondimensional units
- Validity constraints
- Whether the quantity is linear, circular, positive, bounded, or categorical

Locate every independent copy of these index definitions in the repository and report inconsistencies.

---

# Workstream 2 — Formal model and symbolic implementation audit

## 2.1 Formalize the implemented model

Represent the continuous dynamics as

\[
\dot y = f_{\sigma}(y,p),
\]

where `sigma` is the contact mode.

Document:

- Generalized coordinates
- Velocity coordinates
- Integrated state ordering
- Model parameters
- Hip and shoulder geometry
- Leg-angle convention
- Spring-length convention
- Force and torque signs
- Gravity convention
- Contact modes
- Touchdown and liftoff semantics
- Whether event times are prescribed unknowns or state-triggered events
- Reset or velocity-projection maps
- Poincaré section
- Periodicity map
- Nondimensionalization
- Continuous symmetries or conserved quantities

Explicitly distinguish:

- What the production code implements
- What comments/documentation claim
- What the symbolic derivation appears intended to derive
- What remains uncertain

## 2.2 Symbolic-source audit

Determine which symbolic files are authoritative, experimental, stale, or broken.

Verify, rather than assume, the following candidate problems:

### `SystemDynamics_Lagrangian.m`

- Undefined position or velocity symbols
- Generalized-force vector dimension consistency
- Use of explicit `inv(MassMatrix)` rather than a linear solve
- Internal consistency of the declared generalized coordinates and force terms
- Whether the generated outputs can currently be reproduced

### `SystemDynamics_Projection.m`

- Hind/front-leg copy-paste errors
- Symbolic limits with respect to undeclared variables
- Front-right foot geometry mixing back and front joint coordinates
- Solving velocity equations for acceleration variables
- Incorrect use of front/hind angular variables in torque entries
- Consistency between two-leg and four-leg derivations

### Generated stance functions

For `Func_alphaB_VA_v2` and `Func_alphaF_VA_v2`:

- Identify the generation source and exact input layout
- Check consistency with finite-difference holonomic constraints
- Check singular denominators
- Check whether duplicate local and standalone versions are identical
- Document how they should be regenerated

Do not repair the symbolic or generated files in Round 1. Report verified defects and the safest later repair strategy.

---

# Workstream 3 — Periodic-orbit residual audit

## 3.1 Formal residual definition

Define

\[
z = \begin{bmatrix}X\\E\end{bmatrix},
\qquad
F(z,p)=0,
\]

where `X` is the 13-element initial-state vector, `E` is the 9-element event-time vector, and `p` is the 7-element model-parameter vector.

Produce a residual table containing:

- Residual index
- Mathematical equation
- Code location
- Physical meaning
- Expected numerical scale
- Whether the equation is independent
- Conditions under which it is included

Include:

- Touchdown constraints
- Liftoff constraints
- Apex/Poincaré condition
- Periodicity conditions
- Infinite-inertia condition
- Optional gait/symmetry constraints
- Pseudo-arclength or radius constraints when used by callers

## 3.2 Dimension and rank analysis

For every supported configuration, determine:

\[
n_z = \dim z,
\qquad
n_F = \dim F,
\qquad
r = \operatorname{rank}(D_zF),
\qquad
 d = n_z-r.
\]

At representative valid solutions:

1. Approximate `D_zF` using documented finite-difference steps.
2. Repeat with multiple step sizes.
3. Report singular values.
4. Estimate numerical rank using justified absolute and relative thresholds.
5. Identify approximate null vectors.
6. Relate null vectors, where possible, to energy, phase, symmetry, redundancy, or an implementation defect.
7. Report row and column scaling sensitivity.

Do not assume that an overdetermined Levenberg-Marquardt solve is mathematically equivalent to a correctly formulated continuation corrector.

## 3.3 Mandatory repository-specific checks

Verify:

- Whether `SolveQuadrupedalZE.m` calls a current, resolvable residual entry point.
- Whether `EnforceEventTimingQuad` checks the same residual equations that its inner solve attempts to zero.
- Whether optional constraints are mutually exclusive because of `elseif`, and whether that matches the intended API.
- Whether a struct accepted by the parser is accepted by downstream constraint logic.
- Whether the neutral swing-angle parameter is used by the dynamics.
- Whether residual length changes correctly under infinite pitch inertia.
- Whether residual length changes correctly under optional symmetry constraints.
- Whether all `fsolve` callers use residuals with dimensions compatible with their unknown vectors.
- Whether nonfinite residuals and invalid trial states are rejected explicitly.

Do not correct these issues in Round 1. Establish evidence and design regression tests.

---

# Workstream 4 — Hybrid integration, event-time regulation, and contact logic

## 4.1 Event-time representation

Audit `EventTimingRegulation` and every equivalent implementation.

Check:

- Positive, finite stride period
- Behavior for zero or negative period
- Behavior for NaN or Inf
- Idempotence
- Invariance under adding integer multiples of the period
- Row-vector and column-vector preservation
- Events exactly at `0`
- Events exactly at `T`
- Equal touchdown and liftoff
- Multiple-period offsets

Where possible, add non-invasive tests for the mathematical properties

\[
R(R(E))=R(E)
\]

and

\[
R(E+kT)=R(E), \qquad k\in\mathbb{Z}.
\]

## 4.2 Contact interval semantics

Identify the exact interval convention used for stance:

- Open
- Closed
- Left-closed/right-open
- Another convention

Check consistency across:

- Production dynamics
- GRF computation
- Visualization kinematics
- Gait identification
- Phase diagrams
- Continuation diagnostics

Audit:

- Wrapped stance intervals
- Simultaneous events
- Coincident touchdown/liftoff
- Zero-duration stance
- Full-period stance
- Event-order ties
- Boundary behavior immediately before and after an event
- Sorting stability for equal event times

Do not consolidate the duplicated contact logic in Round 1. Document every copy and any behavioral differences.

## 4.3 Singularities and invalid parameter regions

Locate and document all divisions or nonlinear transformations that become singular or invalid, including:

- `cos(alpha + phi)` near zero
- Nonpositive `tAPEX`
- Nonpositive leg length
- Zero or negative inertia
- Invalid stiffness ratio `kr`
- Nonfinite stiffness parameters
- Singular denominators in generated stance functions

Determine whether invalid states are:

- Prevented by input validation
- Rejected by residual evaluation
- Allowed to propagate as NaN/Inf
- Caught only by `fsolve`
- Silently accepted

## 4.4 Force and contact assumptions

Without changing equations, determine:

- Whether stance springs are intended to be unilateral
- Whether negative spring compression can generate tensile ground forces
- Whether contact validity is checked separately from prescribed event timing
- Whether GRF sign conventions match force signs used in the ODE
- Whether the same force law is independently reimplemented in multiple files

Record unresolved physical assumptions explicitly for model-owner review.

---

# Workstream 13 — Performance baseline only

Do not optimize production code in Round 1.

Measure or instrument the following where possible:

1. Residual-only evaluation
2. Full-output simulation
3. One periodic-orbit `fsolve`
4. One accepted continuation correction or a safely capped continuation attempt
5. Gait identification on one solution and one branch
6. One graphics update
7. MAT-file branch-catalog loading

Report:

- Wall-clock time
- Function evaluations
- Solver iterations
- ODE calls or output sizes
- Major call-stack contributors
- File-I/O volume
- Memory observations where available

Investigate, but do not yet fix:

- Unconditional trajectory and GRF generation during residual-only calls
- Repeated ODE integrations caused by numerical Jacobians
- Repeated contact, force, and kinematic computations
- Dynamic array growth
- Repeated full MAT-file loads
- Fixed-resolution timeline construction in gait identification
- Historical branch comparisons with possible quadratic growth
- Checkpoint frequency and cost
- Excessive graphics geometry or redraws
- GUI status-update cost

Classify unmeasured suspicions as `PH`, not as confirmed performance defects.

---

# Round 1 tests

Add only non-invasive tests that characterize current behavior or reproduce confirmed defects.

Prioritize:

- State/event/parameter schema dimensions
- Event-regulation idempotence
- Event-regulation period-shift invariance
- Invalid-period behavior
- Circular contact membership
- Residual dimensions for supported configurations
- Residual finite/nonfinite behavior
- Current entry-point resolution
- Generated stance functions versus finite-difference constraints
- Representative stored-solution residuals
- Reference-artifact hash preservation

A characterization test may document current incorrect behavior, but clearly mark it as such and do not encode an incorrect result as the intended permanent contract.

---

# Required Round 1 deliverables

Create or update the following, adapting names only if repository instructions require another convention:

## Documentation

- `docs/repository-audit-round1.md`
- `docs/model-audit-round1.md`
- `docs/data-schema-round1.md`
- `docs/performance-baseline-round1.md`

These may be combined into fewer files if that materially improves clarity, but the required sections must remain present.

## Audit tooling

- `tools/runRound1Audit.m` or an equivalent reproducible audit entry point
- Any helper scripts under `tools/audit/`

## Tests

- `tests/round1/` containing non-invasive characterization and audit tests

## Generated audit output

Place logs, profiles, temporary reports, and hashes under a clearly named ignored directory, such as:

- `artifacts/round1-audit/`

Do not commit large generated profiles or copies of reference data unless explicitly justified.

---

# Required contents of `docs/repository-audit-round1.md`

1. Executive summary
2. Environment and exact commands run
3. Initial Git state
4. Source inventory and file classification
5. Entry-point and dependency map
6. Canonical data-schema table
7. Formal model summary
8. Symbolic-source audit
9. Residual-equation table
10. Residual dimension and Jacobian-rank analysis
11. Event/contact-semantics audit
12. Singularity and invalid-input audit
13. Performance baseline
14. Findings table
15. Uncertainties requiring model-owner input
16. Prioritized plan for later rounds
17. Files added in Round 1
18. Confirmation that production numerical files and reference artifacts were not modified

---

# Later-round plan to propose, but not execute

At the end of Round 1, propose a sequence such as:

1. Confirmed broken references and crashing code paths
2. Canonical schema and input validation
3. Exact circular-time/contact helper
4. Shared kinematics and force implementation
5. Residual-only versus full-output execution split
6. Root-solver scaling, diagnostics, and Jacobian work
7. One-dimensional continuation refactoring and validation
8. Parameter-scan architecture and checkpoint safety
9. Gait-classification exact interval logic
10. Visualization consistency and smoke tests
11. GUI state/controller extraction
12. Repository documentation, CI, and release hygiene

For each proposed round, give:

- Scope
- Preconditions
- Main risks
- Expected files
- Required regression tests
- Whether model semantics may change

---

# Final response format

Return:

1. Concise executive summary
2. Environment and commands executed
3. Added audit files
4. Highest-severity confirmed findings
5. Important unresolved scientific questions
6. Baseline numerical and performance results
7. Test results
8. Confirmation that production numerical code and reference data were not modified
9. Recommended Round 2 scope

Cite exact files and lines for every finding. Cite terminal output for every test, solver, or benchmark claim.

---

# Round 1 acceptance criteria

Round 1 is complete only if:

- Every relevant source file is inventoried and classified.
- Every major public entry point is resolved or identified as missing/stale.
- The state, event, parameter, integrated-state, and saved-result schemas are documented.
- The implemented hybrid model is described separately from intended or documented behavior.
- Every residual component is mapped to code and mathematics.
- Residual dimensions are reported for all supported configurations.
- Jacobian singular values and numerical rank are reported for at least one representative valid solution when MATLAB is available.
- Event wrapping and contact interval semantics are explicitly documented.
- Candidate singularities and invalid parameter regions are cataloged.
- A reproducible performance baseline exists, or exact environment blockers are reported.
- Findings distinguish confirmed defects from risks and hypotheses.
- No production numerical behavior was intentionally changed.
- Existing `.mat`, `.fig`, and `.mlx` reference artifacts are unchanged.
- The final Git diff contains only focused audit infrastructure, tests, and documentation.
- A prioritized Round 2 plan is provided.

Stop after satisfying these criteria.
