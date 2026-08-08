# Robust Floquet analysis for the v2 quadrupedal SLIP model

This folder implements Floquet multipliers as eigenvalues of a reduced
Poincare return-map derivative. It is an adapter around the production v2
dynamics and event-timing solve; it does not modify or duplicate
`Quadrupedal_ZeroFun_v2.m`.

## Quick start

From the repository root in MATLAB:

```matlab
experimentRoot = fullfile('SLIP_Quadruped','3_Numerical_Continuation', ...
    '2_Floquet_Analysis_v2','experiments', ...
    'pronking_multigait_bifurcation');
addpath(experimentRoot)
experiment = main_Test_FloquetAnalysis();
```

All pronking-specific scripts, inputs, results, logs, and tests are packaged
under `experiments/pronking_multigait_bifurcation/`. Reusable Floquet-v2 code
remains in this folder and `utilities/`.

The default experiment uses the canonical pronking branch, evaluates broad
coverage plus the persistence neighborhoods
`[1 2 3 38:42 90 179 194:198 268 358]`, plots the reduced
multipliers and their distances from `+1`, `-1`, and the unit circle, runs the
persistent crossing detector, and compares against the stored `FDM_v2`
spectra. A custom configuration structure can override the branch file,
indices, finite-difference settings, plotting, and output file.

The experiment is deliberately expensive. With 12 section coordinates,
central differences at three step sizes require at least 72 perturbed strides
per continuation point, in addition to base-orbit validation and the nonlinear
event-timing solves.

### Reproduce the pronking-to-three-gait calculation

The complete multiway calculation, including critical-orbit refinement,
symmetry resolution, held-out branch comparison, nonlinear correction, plots,
and flat audit files, is:

```matlab
addpath(experimentRoot);
report = main_Test_PronkingMultiGaitBifurcation();
assert(strcmp(report.status,'verified'));
```

The reference MATLAB R2025b run refined the common critical orbit to

```text
dx = 4.43406193516227
```

not `dx = 5`. The nearby detector values around `4.43412` are interpolations
between saved continuation columns; the value above comes from correction of
the periodic orbit while tracking the complete near-`+1` invariant space. Its
reported bracket is `[4.43406193516227, 4.43406370981359]`, canonical residual
is `3.997e-14`, and critical multiplier uncertainty is `1.411e-10`.

For an independent replay of the saved nonlinear solutions:

```matlab
audit = main_HandValidate_PronkingBifurcation();
assert(audit.accepted);
```

That utility ignores the saved acceptance flags, reevaluates every corrected
22-variable orbit with `Quadrupedal_ZeroFun_v2(...,'skipSolve')`, calls the
normal production timing solver through `ValidatePeriodicOrbit`, and writes
`experiments/pronking_multigait_bifurcation/results/final/pronking_hand_validation_replay.csv`.

The result directory contains:

- `pronking_multigait_validation_results.mat`: authoritative full report;
- `pronking_critical_orbit.csv`: corrected common orbit;
- `pronking_branch_search_attempts.csv`: every predictor/corrector attempt;
- `pronking_branch_search_clusters.csv`: six persistent oriented clusters;
- `pronking_corrected_orbits.csv`: all 12 accepted solutions at two radii;
- `pronking_hand_validation_replay.csv`: independently recomputed checks;
- `pronking_multigait_validation_report.md`: compact numerical report;
- PNG and MATLAB FIG files for the spectrum, critical directions, held-out
  daughter comparison, and corrected daughter rays.

## Mathematical map

The integrated state has 14 components,

```text
[x, dx, y, dy, phi, dphi, alphaBL, dalphaBL, ...,
 alphaFL, dalphaFL, alphaBR, dalphaBR, alphaFR, dalphaFR].
```

The stored state `X` already removes the horizontal translation `x`, leaving
13 components corresponding to integrated columns `2:14`. The apex section is

\[
\Sigma = \{X:\;dy=0,\;\ddot y<0\}.
\]

Consequently `dy = X(3)` is normal to the section and is not an independent
coordinate. The implemented chart is

\[
\eta = X([1,2,4{:}13]) \in \mathbb{R}^{12}.
\]

For a trial section state, `BuildPoincareMap` calls the production dynamics
without `skipSolve`. That invokes the existing event-timing solver, integrates
one complete stride, and exposes the solved event times through `P(1:9)`. The
returned state is `Y(end,2:14)`, reduced with the same chart. Thus

\[
P_\Sigma(\eta)=\pi_\Sigma\!\left(\Phi_{E(\eta)}(X(\eta))\right),
\qquad
M=DP_\Sigma(\eta^\star)\in\mathbb{R}^{12\times12}.
\]

`ComputeFloquetFDM` evaluates every column with scaled central differences,

\[
M_i(h_i)=\frac{P_\Sigma(\eta^\star+h_i e_i)
                 -P_\Sigma(\eta^\star-h_i e_i)}{2h_i}.
\]

The state-dependent scales, nominal magnitude, and step multipliers are all
configurable. At least two step magnitudes are required. The result reports
successive matrix and column errors, and rejects a matrix when the requested
convergence tolerance is not met. It also compares the forward and backward
one-sided derivatives. This additional check is important at nonsmooth hybrid
boundaries: a central average can converge even when a Frechet derivative
does not exist.

## Why event times are solved but are not Floquet states

The nine stored timing variables parameterize touchdown, liftoff, and the
return time. For a perturbed section state they are determined implicitly by
the eight foot-contact equations and the apex equation. They therefore change
with `X`, and that response must be included when evaluating the return map.
They are not independent coordinates on the physical Poincare section.

The implementation re-solves them for every positive and negative state
perturbation, but differentiates only the 12 returned section coordinates. It
never takes eigenvalues of `[X;E]`, never perturbs an event time by hand, and
never treats a timing-solver Jacobian as a monodromy matrix.

## Validation and rejection rules

Before accepting a base orbit or a perturbed return, the code checks:

- finite, correctly sized dynamics outputs and a positive stride period;
- integration from zero through exactly one solved stride;
- all eight foot-contact residuals and the final apex residual, not merely the
  subset used by the production solver's solve-trigger test;
- `dy=0` at the initial and returned section points;
- `ddy<0` at both crossings, using the production vertical GRFs;
- periodic closure of the base orbit;
- repeatability of the solved event times;
- contact/event ordering relative to the base topology;
- finite-difference step convergence and agreement of the two one-sided
  directional derivatives.

Any failed postcondition rejects that Floquet evaluation with an explicit
identifier and retained diagnostics. An event-timing `fsolve` exit flag is not
available through the production public API, so convergence is certified by
its physical residual and repeatability postconditions.

### Simultaneous pronking events

Every supplied pronking solution has a four-event touchdown cluster and a
four-event liftoff cluster (spreads are approximately `1e-12`). A scalar sorted
permutation is therefore not a meaningful base topology. The validator first
builds coincident-event groups. Its strict policy rejects any splitting of a
group. Its grouped policy permits members of an existing group to reorder only
while they remain isolated from neighboring groups, records the split size,
and still requires forward/backward derivative agreement and multi-step
convergence.

Grouped acceptance is conditional evidence that the simultaneous reset acts
smoothly for this implementation; it is not a general theorem for simultaneous
impacts. Results with split clusters should be reported with their topology and
one-sided consistency metrics. If those metrics fail, the correct conclusion
is that no single unrestricted Floquet matrix was resolved at that point.

## Floquet multipliers are not continuation eigenvalues

These three objects have different meanings:

- **Floquet multipliers** are eigenvalues of the 12-by-12 derivative of the
  state return map on the apex section. They measure transverse, stride-to-
  stride perturbation growth.
- **Continuation Jacobian eigenvalues** belong to the nonlinear algebraic
  residual in the 22 variables `[X;E]`. They depend on the residual scaling and
  timing parameterization and are not stability multipliers.
- **The branch tangent** is a secant/null direction along a family of periodic
  solutions. At a fixed-point family it can generate a persistent `+1` mode;
  its presence alone is not an additional bifurcation direction.

`TrackMultipliers` performs a global minimum-cost match between adjacent
continuation points using multiplier distance and eigenvector overlap.
`DetectBifurcation` then brackets sign changes of real modes through `+1` and
`-1`, and modulus changes of a positive-imaginary complex member through the
unit circle. A candidate is reported only when the same tracked mode persists
on the requested number of neighboring points. For a `+1` crossing, the
critical eigenvector is compared with the local reduced branch tangent and
the near-`+1` invariant subspace; tangent-aligned crossings are classified and
excluded from additional-null-direction candidates by default.

Each accepted candidate contains its interpolated continuation coordinate,
multiplier, eigenvector, bracket, tracking score, persistence margins,
validation status, and (for `+1`) branch-tangent separation and null-space
multiplicity metrics. Numerical finite-difference errors remain attached to
the two bracketing orbit diagnostics in the experiment output.

## Critical-orbit refinement

Detector candidates are bracketed, interpolated estimates; they are not
corrected periodic orbits at an exact multiplier crossing. Refine an accepted
candidate before constructing a branch predictor:

```matlab
types = {experiment.candidates.Type};
candidate = experiment.candidates(find(strcmp(types,'-1'),1));

refineOptions = struct( ...
    'FloquetOptions',experiment.config.FloquetOptions, ...
    'CoordinateTolerance',1e-6, ...
    'MultiplierTolerance',1e-6, ...
    'ThrowOnFailure',false);

[zCritical,refinement] = RefineCriticalOrbit( ...
    experiment,candidate,refineOptions);
assert(refinement.accepted, strjoin(refinement.rejectionReasons,newline));
```

The branch form is

```matlab
[zCritical,refinement] = RefineCriticalOrbit(branch,candidate,options);
```

where `branch` may be a 29-by-N continuation array, a scalar structure with a
`results` array, or an experiment structure containing `branchFile` and
`sampleIndices`. Candidate indices from `DetectBifurcation` are local to the
sampled experiment; the refiner verifies their continuation-coordinate values
before mapping them to full-branch columns. `options.BracketIndices` provides
an explicit two-column map when coordinate matching is ambiguous. The
explicit-endpoint form is

```matlab
[zCritical,refinement] = RefineCriticalOrbit( ...
    zLeft,zRight,parameters,candidate,options);
```

Here `zLeft` and `zRight` are 22-vectors `[X;E]`, and `parameters` is either a
shared 7-vector or a 7-by-2 endpoint array. On success, `zCritical` is the
corrected 22-vector; the seven physical parameters are returned separately in
`refinement.parameters`. On rejection, `zCritical` is empty and the reason is
recorded in `refinement.rejectionReasons`. Set `ThrowOnFailure=true` when a
rejection should be raised as a MATLAB error.

For each trial continuation coordinate, the refiner corrects the full
periodic-orbit variables `[X;E]`, recomputes the reduced 12-by-12 Floquet map,
and follows the candidate mode by eigenvector or invariant-subspace overlap.
Acceptance requires all of the following:

- a converged canonical periodic-orbit correction at the prescribed `X(1)`;
- agreement with the authoritative event times obtained by the normal
  production timing solve;
- valid apex crossings and unchanged event topology;
- an accepted multi-step, central-difference Floquet matrix;
- preservation of the tracked mode or repeated-mode subspace;
- agreement of the critical multiplier between the two finest derivative
  matrices within `CriticalMultiplierUncertaintyTolerance` (which defaults
  to `MultiplierTolerance`), with the Richardson matrix-error estimate
  retained in the diagnostics;
- a signed multiplier residual below `MultiplierTolerance`, repeated-root
  spread below `ClusterSpreadTolerance`, and final bracket width below
  `CoordinateTolerance`.

Physical parameters must be fixed across the bracket by default. Setting
`AllowParameterInterpolation=true` imposes a linear endpoint parameter law;
the software cannot infer a continuation law, so this option should be used
only when that linear law is part of the posed problem.

A production check on pronking columns `38:42`, using finite-difference
factors `[2 1]` and `CoordinateTolerance=1e-5`, refined the period-doubling
point to `dx=0.612222442715` with multiplier `-0.999999831097`. The final
coordinate bracket was `8.371e-6`, the coarse/fine multiplier uncertainty was
`1.260e-8`, the Richardson Frobenius estimate was `8.998e-9`, the canonical
residual was `4.361e-13`, and the corrected event times agreed exactly with
the authoritative timing solve at the reported precision.

### Continuation-coordinate limitation

The current corrector fixes `X(1)=dx` and refines along that scalar coordinate.
It is appropriate only on a locally monotone branch segment for which `dx`
uniquely labels nearby periodic orbits. The two bracket columns must be
adjacent by default. Near a fold in `dx`, two solutions can share the same
coordinate and the fixed-`dx` formulation is not a valid local chart; use a
pseudo-arclength/hyperplane critical-orbit formulation instead. Disabling the
adjacency check does not cure this geometric limitation.

### Repeated `+1` modes and predictor readiness

Near-repeated real `+1` or `-1` roots are matched as an invariant subspace,
not as individually meaningful eigenvectors. This makes refinement insensitive
to arbitrary rotations of a numerically degenerate eigenbasis. A repeated
subspace can yield an accepted critical orbit, but it does not select a unique
symmetry-breaking direction. Accordingly, `refinement.branchSwitchReady` is
true only for a one-dimensional, real, additional `+1` direction that remains
sufficiently separated from the verified continuation tangent. For a repeated
`+1` subspace it is false, `refinement.branchSwitchReadyReason` explains why,
and a symmetry or phase condition must select a direction before correction.

When the flag is true, the refiner supplies predictor-ready `eigenData`:

```matlab
if refinement.branchSwitchReady
    mapOptions = experiment.config.FloquetOptions;
    mapOptions.ReferenceTopology = refinement.topology;
    predictorOptions = struct( ...
        'Amplitude',1e-3, ...
        'MapOptions',mapOptions, ...
        'ExpectedTopology',refinement.topology, ...
        'RequireAdditionalNullDirection',true);

    [deltaZ,~,predictorInfo] = PredictBranchDirection( ...
        refinement.X,refinement.E,refinement.parameters, ...
        refinement.eigenData,predictorOptions);

    correctorOptions = struct( ...
        'MapOptions',mapOptions, ...
        'ExpectedTopology',refinement.topology);
    [zSwitched,correctorInfo] = CorrectBranchSwitch( ...
        refinement.X,refinement.E,refinement.parameters, ...
        predictorInfo,correctorOptions);
end
```

`deltaZ=[deltaX;deltaE]` is constructed by re-solving event timing for the
state perturbation. The raw Floquet eigenvector alone is never passed to the
periodic-orbit corrector. The built-in same-stride switching path remains
limited to an additional `+1` direction; `-1` and complex crossings require
problem-specific two-stride or invariant-circle formulations.

## Multiway pronking branch switch

The pronking point is a repeated-root case, so a single raw eigenvector is not
a well-defined branch direction. `main_Test_PronkingMultiGaitBifurcation`
tracks the full four-dimensional near-`+1` space, identifies and excludes the
continuation tangent, and resolves the remaining three dimensions with the
exact hind- and front-leg swap projectors. In the order

```text
[bounding b, front-spread f, hind-spread h]
```

the full symmetry-sector ranks are `[2 1 1 0]` and the tangent-free ranks are
`[1 1 1 0]`. The full invariant space is authoritative: individual numerical
eigenvectors may rotate inside the repeated eigenspace.

`PredictBranchDirection` uses `TimingLiftMode='one-sided-sector'` here. The
positive and negative directions legitimately reverse event order when a
simultaneous pronking cluster splits, so a central timing lift would compare
two different hybrid sectors. For each oriented state seed, the production
timing solver determines the event-time perturbation on that same sector.
Event times enter the complete nonlinear predictor and correction variables,
but never enter the Floquet eigensystem.

`CorrectPronkingGaitBranch` appends symmetry and signed critical-amplitude
conditions outside the unchanged dynamics core:

- B fixes nonzero `b` and enforces both left/right leg-pair symmetries;
- F fixes nonzero `f` and enforces the hind-pair symmetry, leaving the front
  pair split;
- H fixes nonzero `h` and enforces the front-pair symmetry, leaving the hind
  pair split.

Both the apex leg states and their touchdown/liftoff times are included in the
symmetry residual. The augmented systems are overdetermined and therefore use
Levenberg-Marquardt, followed by exact acceptance tests on the unweighted
canonical residual, symmetry residual, signed amplitude, apex section,
Poincare closure, event topology, gait class, and agreement between corrected
and production-solved event times. This external adapter avoids the dynamics
core's mutually exclusive constraint chain.

The deterministic search uses `+/-b` and two signs in each exact `b-f` and
`b-h` plane at radii `1e-2` and `5e-3`. These seeds use no daughter branch
data. A ray is retained only if its oriented critical-space cluster persists
at both radii. The reference run obtained 12 accepted corrections and exactly
six persistent clusters:

| Gait class | Persistent directions in `[b f h]` |
|---|---|
| Bounding | approximately `[+1,0,0]` and `[-1,0,0]` |
| Front-spread half-bound | `[-0.84237,+/-0.53890,0]` |
| Hind-spread half-bound | `[-0.84531,0,+/-0.53427]` |

The maximum canonical residual over those clusters is `1.893e-13`; the
maximum scaled Poincare return residual is `4.313e-14`. The independently
loaded historical BE/BG/FE/FG/HE/HG secants were used only afterward as a
held-out check. Their critical-subspace alignments are `0.99986`--`0.999996`,
and all six saved periodic orbits pass production-map validation.

Three gait classes and six directions are different statements. The two
directions in each class are oriented daughter rays related by the relevant
discrete symmetry; they are not six unrelated gait names.

## Branch prediction and correction

`PredictBranchDirection` lifts a critical reduced eigenvector into the
13-state representation with zero `dy` component. It evaluates positive and
negative trial states through `BuildPoincareMap`, circularly lifts the solved
event times about the base solution, and constructs

\[
\delta z = [\delta X;\delta E].
\]

Passing a detector candidate preserves its multiplier and null-direction
classification. If only a numeric eigenvector is supplied, the caller must
also provide its multiplier; an unlabeled real vector is rejected because it
cannot distinguish a supported `+1` switch from a `-1` mode.

`CorrectBranchSwitch` supplies `z^\star+\delta z` to an `fsolve` periodic-
orbit corrector. The corrector calls the production residual with `skipSolve`
because the event times are now nonlinear unknowns, and appends a scaled
predictor-hyperplane condition so it does not simply discard the switching
amplitude.

A same-stride periodic corrector is appropriate for an additional `+1` null
direction. A `-1` crossing requires a two-stride/period-doubled formulation,
and a complex unit-circle crossing normally predicts an invariant circle, not
a same-period orbit. The default corrector rejects those two cases; callers
must provide a problem-specific multi-stride or torus corrector rather than
misusing the raw Floquet eigenvector.

## Comparison with `FDM_v2`

The historical script differs in several consequential ways:

- it says "central" but evaluates only `X+h`;
- it uses one absolute step (`1e-6`) for every state;
- it includes the apex-normal `dy` coordinate and diagonalizes a 13-by-13
  matrix;
- it uses a duplicated dynamics file and hard-codes a timing symmetry, giving
  an overdetermined timing response different from the production map;
- it does not validate timing convergence, section direction, topology,
  periodic closure, or step convergence;
- it detects bifurcations by untracked threshold/count heuristics.

The stored legacy classifications are not ground truth. On the 358-point
pronking subset their reported candidate counts change from 3 at `h=1e-6`
and 3 at `h=1e-7`, to 7 at `h=1e-9` and roughly 100 at `h=1e-12`. That growth
with decreasing step is consistent with cancellation and timing-solver noise.
The new experiment never transfers those labels. It compares the spectra as
unordered sets (12 reduced values versus 13 legacy values) and reports new
candidates only after the return-map, convergence, topology, matching, and
persistence checks. In this precise sense the old threshold-only false
detections are removed; a legacy candidate is retained only if it is
independently reproduced by the validated detector.

### Reproduced reference run

With MATLAB R2025b, the default 17-point experiment and perturbation levels
`[4e-6, 2e-6, 1e-6]` accepted all 17 reduced matrices. The largest successive
central-matrix change was `9.0613e-6`; the largest finest-level
forward/backward mismatch was `1.1571e-4`, below the configured `5e-3`
rejection threshold. The persistent detector produced:

| Legacy neighborhood | Validated Floquet-v2 result |
| --- | --- |
| column 2 | No persistent signed crossing in columns 1:3 |
| column 40 | `-1` crossing at `dx = 0.612146814`, confidence `0.823` |
| column 196 | complex unit-circle crossing at `dx = 4.43409719`, confidence `0.855` |
| column 196 | three independent additional `+1` directions at `dx = 4.43412`, confidence `0.779`--`0.856` |

The three `+1` reports are not repeated labels for one eigenvector: their
interpolated critical vectors span a rank-three subspace. Two modes are an
almost degenerate pair, so their individual track labels are basis-dependent,
but the two-dimensional subspace is well resolved. This reference run
therefore reproduces the old neighborhoods 40 and 196 with physically typed
crossings, while the threshold-only label at column 2 is not retained.

## Reproducibility and tests

Experiment-specific inputs, scripts, logs, and generated results are packaged
under `experiments/`; shared mathematical and numerical functions remain in
this directory. The reference packages are:

- `experiments/pronking_multigait_bifurcation` verifies the multiple pronking
  +1 point and its six oriented B/F/H rays.
- `experiments/roadmap_bifurcation_robustness` tests six targeted secondary
  pair-symmetry-breaking transitions on BG, BE, FG, and HE parents, with
  each transition's designated daughter excluded from its Stage-A numerical
  analysis and introduced only for held-out validation.
- `experiments/BG_half_bounding_bifurcation` independently packages BG -> HG
  and BG -> FG.
- `experiments/BE_half_bounding_bifurcation` independently packages BE -> FE
  and BE -> HE.
- `experiments/FG_GG_bifurcation` independently packages FG -> GG.
- `experiments/GE_HE_bifurcation` independently packages HE -> GE; the folder
  name preserves the requested pair label, while all metadata and code use
  the correct HE-parent direction.

The four split packages contain local parent and held-out-daughter data,
their own scripts, tests, numerical evidence, figures, transcripts, and
checksums. They reuse the consolidated package's analysis implementation
rather than duplicating reusable functions. Supplied results are explicitly
marked frozen projections of the validated consolidated run; invoking a
package's `main_Test_*` script performs a fresh parent-only calculation and
held-out validation from that package's local inputs.

The secondary roadmap parents fold in `X(1)=dx`. Their package verifies that
each selected adjacent bracket is locally monotone before using the existing
fixed-`dx` critical refiner. This is valid for the packaged targeted tests but
does not constitute a branch-wide blind discovery method; that requires a
pseudo-arclength critical-orbit corrector.

The canonical data file is

```text
P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/
    1_Roadmap/PK_20_2.mat
```

Its first 358 columns are exactly the legacy comparison branch
`2_FloquetAnalysis/BD1_20_2_PK.mat`. Model parameters are constant, so the
experiment uses initial horizontal speed `X(1)` as its displayed continuation
coordinate. The default indices include points on both sides of the old saved
candidate neighborhoods 40 and 196. Legacy index 2 is close to the start of
the supplied branch; columns 1:3 do not establish a persistent signed
crossing, so it is not accepted merely because a multiplier is close to the
unit circle.

Run the bounded tests with:

```matlab
suite = testsuite(fullfile(experimentRoot,'tests'), ...
    'IncludeSubfolders', true);
results = run(suite)
```

The ordinary suite checks schema, section reduction, scaling, multiplier
tracking, persistent crossing logic, symmetry resolution, sector timing lift,
and corrector rejection rules. Enable the production finite-difference test
with:

```matlab
setenv('SLIP_RUN_LONG_FLOQUET_TESTS','1');
```

The complete critical-orbit/held-out validation and the still more expensive
two-radius nonlinear replay are separately gated:

```matlab
setenv('SLIP_RUN_BRANCH_SWITCH_TESTS','1');
setenv('SLIP_RUN_PRONKING_GAIT_CORRECTOR_TESTS','1');
```

The final production gate reruns the full refinement rather than trusting a
previous MAT file. For routine manual inspection, use the much faster
`main_HandValidate_PronkingBifurcation` replay instead.

### Suggested hand checks

1. Open `pronking_branch_search_clusters.csv` and verify six rows, all
   persistent, with class counts `[2 2 2]` and two radii per row.
2. Open `pronking_branch_search_attempts.csv` and verify 12 accepted rows,
   requested and final gait classes equal, finite signed target amplitudes,
   production timing agreement, and small canonical/return residuals.
3. Inspect `pronking_corrected_orbits.csv` for the complete `[X;E]` values;
   do not reconstruct an orbit from a raw Floquet eigenvector.
4. Run `main_HandValidate_PronkingBifurcation` and compare its freshly written
   audit CSV with the saved attempt table.
5. Inspect `pronking_corrected_branch_rays.png`: each of the six oriented rays
   must contain one point at each radius and approach the same critical orbit
   as the radius decreases.
6. Treat the detector coordinate near `4.43412` as a bracket estimate and the
   corrected value `4.43406193516227` as the reported bifurcation orbit.

## Known limitations

- Grazing events make timing sensitivities singular and are rejected when
  transversality/convergence diagnostics fail.
- A changed contact sequence means the two perturbations sample different
  smooth pieces; no single Floquet matrix is reported.
- Simultaneous impacts may not define a unique unrestricted derivative. The
  grouped policy and one-sided check diagnose, but cannot remove, this model
  limitation.
- Near multiple eigenvalues, individual eigenvectors are ill-conditioned.
  Tracking confidence and invariant-subspace/tangent metrics should be used
  instead of interpreting a single vector in isolation.
- The production event-timing solver hides its `fsolve` exit status. This
  layer uses strict residual and repeatability postconditions but cannot report
  its internal iteration history without changing the core.
