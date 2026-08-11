# New parent-branch workflow template

Copy this directory to a writable experiment directory, edit
`ExperimentConfig.m`, and treat the supplied parent branch as unlabeled. The
template runs the same five-stage workflow used by the GUI and public
`floquet.workflow.*` API. It does not contain expected bifurcation locations,
gait labels, or daughter data in stages 1--4.

If the copied directory is not below the Floquet-v2 repository tree, set
`configuredFloquetRoot` in `ExperimentConfig.m` to the absolute directory
that contains `+floquet/`. In-tree copies discover that root automatically.

The canonical numerical and artifact contracts are documented in
[`../../docs/workflow.md`](../../docs/workflow.md) and
[`../../docs/artifact_schema.md`](../../docs/artifact_schema.md).

## Layout

```text
<workflow-output>/
  ExperimentConfig.m
  AddFloquetWorkflowPath.m
  main_RunDiscovery.m
  main_RefineCandidates.m
  main_FindDaughterBranches.m
  main_ContinueDaughterBranches.m
  main_ValidateExperiment.m
  data/
    parent_branch/
    held_out_daughter_branches/
  workflow_config.mat                 optional frozen config snapshot
  artifacts/
    01_discovery/
      floquet_analysis.mat
      candidate_inventory.csv
      rejected_points.csv
      rejected_intervals.csv
    02_refinement/
      refined_candidates.mat
      refinement_summary.csv
    03_seed_search/
      daughter_seed_search.mat
      daughter_seed_attempts.csv
    04_daughter_branches/
      inventory.mat
      inventory.csv
      <candidate>/<ray>/branch.mat
    05_validation/
      validation_report.mat
      validation_summary.csv
  checkpoints/
  views/                              optional derived GUI/publication views
  logs/                              optional, generated, not authority
```

## Configure and run

Place exactly one authoritative branch MAT file in `data/parent_branch/`. It
must contain a real `29-by-N` `results` matrix with finite state/event-time
rows and finite parameters, except that pitch inertia may be positive `Inf`.
Pass its path to `ExperimentConfig`. The public factory fingerprints the file
immediately; no hand-maintained empty hash state is permitted.

Run discovery over the complete parent branch:

```matlab
cd('/absolute/path/to/my_workflow');
parentFile = fullfile(pwd,'data','parent_branch','my_parent.mat');
config = ExperimentConfig(parentFile);
analysis = main_RunDiscovery(config);
```

Stop and inspect the Stage-1 MAT and CSV evidence. Only then record stable
candidate IDs and explicitly authorize refinement:

```matlab
config = ExperimentConfig(parentFile);
config.Selection.CandidateIDs = {'plus1_c0195_c0196'};
config.Selection.Confirmed = true;
refined = main_RefineCandidates(config);
seeds = main_FindDaughterBranches(config);
```

Review all signed, multi-amplitude corrected seeds. Continuation requires two
accepted corrections at distinct amplitudes on the same oriented ray, plus an
explicit SHA-bound ray selection:

```matlab
state = floquet.workflow.inspect(config);
row = state.Continuation.RayCatalog.Rows(1); % choose after reviewing all rows
config.Continuation.RaySelections = struct( ...
    'RayID', row.RayID, ...
    'SeedAttemptIndices', row.DistinctAttemptIndices(1:2), ...
    'SeedAmplitudes', row.DistinctAmplitudes(1:2), ...
    'SourceSeedSHA256', state.Continuation.RayCatalog.SourceSeedSHA256);
config.Continuation.Enabled = true;
config.Continuation.Confirmed = true;
daughterReport = main_ContinueDaughterBranches(config);
```

The first catalog row above is illustrative, not an automatic scientific
choice. Opposite signs are separate rays and are never paired as two
continuation seeds.

Use a separate Stage-5 config copy to introduce held-out daughter data or a
gait-specific validator. Never expose those references to stages 1--4:

```matlab
validationConfig = ExperimentConfig(parentFile);
validationConfig.Validation.ReferenceDaughterBranchFiles = { ...
    fullfile(validationConfig.ExperimentRoot, 'data', ...
    'held_out_daughter_branches', 'reference.mat')};
validationConfig.Validation.Function = @myHeldOutValidator;
validation = main_ValidateExperiment(validationConfig);
```

Stage 5 checks numerical continuation evidence generically. A physical gait
identity claim requires an independent, experiment-specific validator.

The numbered stage MAT files are the sole numerical authority for a new
experiment. CSV, PNG, GUI exports, and logs are derived views; do not create a
second monolithic result MAT containing copies of all five stages.

## Scientific gates

- Stage 1 rejects invalid periodic orbits, timing failures, topology changes,
  invalid apex returns, and unconverged finite differences.
- Stage 2 refines an actual Floquet crossing on corrected periodic orbits; a
  detector interpolation is not a critical orbit.
- Stage 3 converts a reduced Floquet direction to a full `[deltaX;deltaE]`
  predictor using the production timing solver, then applies a nonlinear
  periodic-orbit corrector.
- Stage 4 continues only explicitly confirmed, persistent same-ray seeds.
- Stage 5 independently revalidates saved points and, when configured, applies
  a quarantined held-out comparison.

A simple additional real `+1` mode uses the generic predictor/corrector. A
repeated kernel requires a supplied invariant-subspace resolver and usually a
symmetry-adapted corrector. `-1` and complex crossings require period-doubled
or torus-specific formulations and are not silently treated as same-stride
daughter branches. A bracket that folds in `dx` requires an arclength critical
orbit formulation.

Artifacts are immutable by default. Set overwrite controls only after
reviewing the exact stage and ray targets. Checkpoints are resumable only when
their v2 schema, parent hash, configuration, evaluator provenance, and
upstream artifact hashes all match.
