# Five-stage Floquet workflow

This is the reusable procedure for a new, unlabeled `29-by-N` continuation
branch. It starts from the complete parent branch, discovers spectral events
without daughter information, and separates numerical daughter evidence from
physical gait identification.

The same stage functions are used by the public MATLAB API, the reusable
template, and the GUI workbench.

## 1. Prepare a clean workflow root

Add the Floquet-v2 directory, not its recursive contents, to the MATLAB path:

```matlab
floquetRoot = fullfile(repoRoot,'SLIP_Quadruped', ...
    '3_Numerical_Continuation','2_Floquet_Analysis_v2');
addpath(floquetRoot)
```

The parent MAT file must contain one usable real `29-by-N` continuation array.
Rows `1:22` are periodic-orbit variables `[X;E]`; rows `23:29` are the seven
physical parameters. The public creator fingerprints the complete input and
builds a v2 configuration:

```matlab
[config,configFile,metadata] = floquet.workflow.create( ...
    parentBranchFile,outputRoot);
```

By default this saves `outputRoot/workflow_config.mat`. The configuration has
schema `floquet-workflow-config-v2`, artifact layout
`numbered-artifacts-v1`, and a frozen parent SHA-256. It contains no selected
bifurcation, expected gait, scan window, or daughter branch.
It is a configuration snapshot, not a numerical report.

For a new workflow, the five numbered MAT files documented below are the only
stage authorities. Do not assemble a second monolithic MAT containing copies
of their payloads. Combined summaries and GUI caches are optional derived
`views/`; downstream stages never consume them.

Use a new output root. A nonempty legacy `results/` tree or legacy
`workflow_config.mat` is rejected so that old and new artifact contracts are
not mixed.

## 2. Stage 1: full-parent discovery

Run discovery with:

```matlab
[analysis,state,config] = floquet.workflow.runStage(configFile,1);
```

Stage 1 calls the equivalent numerical operation

```matlab
analysis = floquet.analyzeBranch(parentBranchFile,[],analysisOptions);
```

The empty selection means every original branch column in exact continuation
order. The algorithm does not sort by `dx` or compact rejected points. Exact
ordered coverage `1:N` with the canonical production evaluator is required
for full-parent scientific authority. A subset scan remains useful for
diagnostics, but it is not a standardized discovery artifact.

For each column, Stage 1:

1. validates the saved periodic orbit with the production timing solver;
2. computes the scaled, multi-level central derivative of the 12-coordinate
   apex return map;
3. records accepted and rejected points without filling gaps;
4. validates event topology on adjacent source intervals;
5. globally matches multipliers and phase-aligns eigenvectors;
6. detects persistent `+1`, `-1`, and complex unit-circle brackets; and
7. attaches stable candidate IDs and writes audit tables.

The canonical result is
`artifacts/01_discovery/floquet_analysis.mat`. The candidate and rejection
CSV files are derived views; later stages read the MAT artifact.

### Review gate: candidate confirmation

Inspect both the flat table and the full diagnostics:

```matlab
state = floquet.workflow.inspect(config);
candidateTable = state.CandidateTable;
[inspection,payload] = floquet.inspectAnalysis(config.Files.Discovery);
```

Check, at minimum:

- accepted FDM masks and rejection reasons;
- derivative convergence and finest forward/backward mismatch;
- interval reliability and topology changes;
- multiplier assignment distances, overlaps, and restarts;
- signed persistence windows and conjugacy evidence;
- `+1` tangent classification and repeated-cluster status; and
- whether the bracket is locally usable in the current `dx` chart.

Then explicitly freeze only the candidate IDs to refine:

```matlab
[config,state] = floquet.workflow.confirmCandidates(config,candidateIDs);
```

This function returns an updated in-memory configuration. It does not mutate
a MAT file. The GUI persists reviewed choices through its workflow controls;
scripted callers must continue with, or deliberately save, the returned
configuration.

## 3. Stage 2: critical-orbit refinement

Run:

```matlab
[refinementReport,state,config] = ...
    floquet.workflow.runStage(config,2);
```

For every confirmed bracket, Stage 2 corrects the periodic orbit at trial
coordinates, recomputes the reduced FDM, and follows the intended mode or
invariant subspace. Acceptance requires a valid signed bracket, corrected
orbit, fixed topology, converged derivative, small multiplier uncertainty,
adequate mode/subspace overlap, target residual, and final coordinate width.

The detector interpolation is therefore never treated as the critical orbit.
The generic refiner defaults to `X(1)=dx`. For a branch with constant speed,
set `ContinuationParameterRow=2` to use a locally monotone apex-height chart
and use the same height coordinate in the analyzer and candidate bracket.
`ContinuationParameterName` supplies its diagnostic label. All endpoint
mapping, trial constraints, stopping widths, and final tangent estimates use
the selected physical coordinate.

An optional `ParentCorrector(guess,Para,coordinate,context)` returns a corrected
22-vector and diagnostics containing a positive `exitflag` and the Jacobian
of independent parent residuals **including the coordinate equation**. This
supports a justified symmetry embedding without sending its restrictions into
the physical event solver or the full 12-by-12 Floquet derivative. The refiner
checks full column rank after column normalization, then independently checks
the complete canonical residual, coordinate, topology, and normal solved
timing. Put construction restrictions in this hook, not `FloquetOptions`.

If height ceases to be transverse, `ContinuationCoordinateFunction=@(z)...`
can instead specify a fixed local hyperplane
`tHat'*((lift(z)-zReference)./stateScale)`, with fixed scales, fixed unit tangent,
and event times lifted continuously about the same reference. The parent
corrector must solve that same chart equation; changing the analyzer's display
coordinate alone is insufficient. See `help floquet.refineCriticalOrbit` for
the hook context and diagnostics contract.

A simple additional real `+1` mode can become branch-switch-ready. A repeated
kernel may yield an accepted critical orbit but not a unique physical
direction. In that case configure an independently justified
`Refinement.ConfigureGroup` and/or `BranchSwitch.DirectionResolver`; do not
select an arbitrary eigenvector from the repeated basis.

The canonical result is
`artifacts/02_refinement/refined_candidates.mat`.

## 4. Stage 3: timing-aware seed search

Run:

```matlab
[seedReport,state,config] = floquet.workflow.runStage(config,3);
```

For each branch-switch-ready direction, Stage 3 evaluates both configured
signs and multiple amplitudes. The default simple-`+1` path:

1. embeds the reduced section direction in `deltaX`, keeping `deltaX(3)=0`;
2. calls the existing timing solver for the perturbed state;
3. obtains the induced `deltaE` in a local circular timing chart;
4. forms `deltaZ=[deltaX;deltaE]`;
5. applies the nonlinear periodic-orbit corrector; and
6. independently validates the corrected orbit and topology.

Opposite signs are distinct oriented rays. The algorithm does not assume that
`+v` and `-v` are two amplitudes on one ray. A raw Floquet vector alone is not
a complete predictor.

The standard corrector is intentionally limited to an additional real `+1`
direction of the one-stride map. Configure an explicit custom formulation for
period doubling, a torus, or an experiment-specific repeated-kernel branch
point.

The canonical result is
`artifacts/03_seed_search/daughter_seed_search.mat`.

### Review gate: continuation-ray confirmation

Inspect the seed report and ray catalog:

```matlab
state = floquet.workflow.inspect(config);
catalog = state.Continuation.RayCatalog;
```

A continuation ray needs two accepted corrections at distinct amplitudes on
the same `RayID`. Review the corrected residuals, topology, amplitude
persistence, direction alignment, and provenance. Then construct explicit
selections bound to the Stage-3 SHA-256 and confirm them:

```matlab
selection = struct( ...
    'RayID',catalog.Rows(1).RayID, ...
    'SeedAttemptIndices',catalog.Rows(1).DistinctAttemptIndices(1:2), ...
    'SeedAmplitudes',catalog.Rows(1).DistinctAmplitudes(1:2), ...
    'SourceSeedSHA256',catalog.SourceSeedSHA256);
[config,state] = floquet.workflow.confirmRays(config,selection);
```

The first row above is illustrative, not an automatic selection rule. The API
checks ray identity, distinct amplitudes, acceptance, and source digest.

## 5. Stage 4: daughter continuation

Run:

```matlab
[daughterReport,state,config] = ...
    floquet.workflow.runStage(config,4);
```

Stage 4 supplies each confirmed same-ray seed pair to
`floquet.continueDaughterBranch`. It checks seed periodicity and topology,
continues the pair, validates configured output points, and verifies local
same-ray geometry. Large branch matrices are saved once at

```text
artifacts/04_daughter_branches/<candidate>/<ray>/branch.mat
```

The compact `inventory.mat` and `inventory.csv` summarize the attempts and
their provenance. An accepted record means a numerically continued branch
candidate. It does not, by itself, prove uniqueness or a particular gait
identity.

Stage 4 checkpoints only at safe ray boundaries. Resume validates the ordered
ray plan, Stage-3 digest, numerical options, completed branch-file digests, and
checkpoint schema before reusing any record.

## 6. Stage 5: independent validation

Stage 5 is the first stage allowed to use held-out daughter data or a
gait-specific validator. Configure those inputs only after discovery,
refinement, seed selection, and continuation are frozen:

```matlab
validationConfig = config;
validationConfig.Validation.ReferenceDaughterBranchFiles = { ...
    '/absolute/path/to/held_out_daughter.mat'};
validationConfig.Validation.Function = @myIndependentValidator;
[validationReport,state,validationConfig] = ...
    floquet.workflow.runStage(validationConfig,5);
```

Generic validation checks the stored continuation result, periodic orbit
evidence, topology evidence, and same-ray geometry. It does not establish a
gait label, branch uniqueness, or agreement with a historical curve. Those
claims require the independent project-specific validator and held-out data.

The canonical result is
`artifacts/05_validation/validation_report.mat`.

## Information barrier

Stages 1 through 4 are parent-only discovery and construction stages. Their
configuration must not contain:

- a daughter branch or daughter-derived direction;
- expected bifurcation indices or continuation coordinates;
- expected gait labels; or
- a hand-selected scan window derived from known answers.

The workflow validates this barrier before numerical execution. Held-out
references are quarantined to Stage 5. This separation prevents a successful
regression against known data from being mislabeled as blind discovery.

## Checkpoints, overwrite, and inspection

Stage-1 checkpoints store raw per-point computation state, not a final
analysis. Resume requires exact compatibility of the parent hash, selected
columns, FDM options, evaluator identity, MATLAB/implementation fingerprints,
and schema. Tracking and bifurcation detection are rerun after the point scan.

Stage-4 checkpoints store ray-boundary progress and the exact confirmed plan.
They do not authorize reuse of unclaimed branch files.

Artifacts are immutable by default. A stage with an existing valid artifact
is locked unless deliberate overwrite controls are enabled. Invalid or stale
artifacts are reported, not silently ignored. Use:

```matlab
state = floquet.workflow.inspect(configOrConfigFile);
```

to reconstruct readiness from the on-disk artifact chain without integrating
or writing anything.

## GUI workflow

Run:

```matlab
FloquetAnalysisGUI()
```

The **Analyze Workflow** tab loads a branch, creates or loads a workflow,
shows the parent branch and selected-point spectrum, and exposes Stages 1--5
in order. A selected-point FDM is a local diagnostic only; authoritative
detection always comes from a complete Stage-1 run. Candidate and ray
confirmations remain explicit review gates.

The **Analysis Viewer** tab opens a canonical Stage-1 MAT artifact or a
validated derived `FloquetData` cache. Viewing never recomputes the Floquet
matrix or changes candidate classification.

## Templates and examples

- `templates/new_branch_workflow` is a copyable script-based package for a
  new parent branch.
- `examples/blind_parent_profiles` contains parent-only option profiles. It
  does not encode expected bifurcation answers.
- `reference_experiments` contains targeted retrospective reproductions with
  known local questions and held-out comparisons.

Reference experiments are valuable regression and hand-validation evidence,
but they are not generic resumable workflows. Start a new branch with
`floquet.workflow.create` or the template, not by copying a reference
experiment's bracket, labels, or specialized direction resolver.

## Failure interpretation

A rejected FDM means no reliable local derivative was established under the
configured map/topology policy. A rejected interval means multiplier identity
was not propagated across it. An unresolved repeated `+1` cluster means the
spectral subspace is visible but no unique daughter direction has been
justified. A failed seed or continuation means the local spectral event did
not produce a validated daughter through the chosen formulation and amplitude;
it does not prove that no bifurcation exists.

For grazing, topology-changing, simultaneous-impact, period-doubled, torus, or
folded-coordinate cases, reformulate the mathematical problem instead of
weakening validation until an artifact passes.
