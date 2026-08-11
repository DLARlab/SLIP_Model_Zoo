# PK multi-gait bifurcation reference experiment

This package is a reproducible, targeted reference calculation for the
pronking (`PK`) branch. It is not a generic `floquet.workflow.Session`
workspace and is not resumable through `workflow_config.mat`. The generated
`reference_experiment_config.mat` records that distinction explicitly.

Only `data/parent_branch/PK_20_2.mat` is passed into reduced-Floquet
construction, critical-orbit refinement, repeated-`+1` resolution, and local
ray correction. The six daughter MAT files are used only by the separate
held-out comparison. The current report assembly evaluates that comparison
before the nonlinear search, but no daughter data or validation output is
passed into search directions, timing lifts, correctors, or ray clustering.

## Reference result

The verified reference record reports:

- corrected critical coordinate `dx = 4.43406193516227`;
- `dim ker(M-I) = 4` before removing the parent-branch tangent;
- a three-dimensional tangent-free critical space with bounding (`b`), front
  spread (`f`), and hind spread (`h`) coordinates;
- six persistent oriented rays with class counts `[B F H] = [2 2 2]`;
- held-out critical-space alignments from `0.99986` to `0.999996`.

The detector value near `dx = 4.43412` is an interpolation inside the saved
branch-column bracket. The corrected critical orbit, not that interpolation,
is the reported bifurcation point.

## Numerical configuration

- Parent branch: the `29-by-891` array in
  `data/parent_branch/PK_20_2.mat`.
- Continuation coordinate: initial horizontal speed `dx = X(1)`.
- Critical scan columns: `194:198`.
- Reduced apex-section dimension: 12; event times are solved by the existing
  production solver but are not Floquet coordinates.
- Central-FDM base magnitude: `5e-7`; factors: `[8 4 2 1]`.
- Nonlinear correction radii: `[1e-2 5e-3]`.
- Search: deterministic symmetry grid using parent data only.
- Dynamics core modified: no.

## Layout and authority

```text
PK_multigait_bifurcation/
├── reference_experiment_config.mat
├── data/
│   ├── parent_branch/PK_20_2.mat
│   └── held_out_daughter_branches/BD1_20_2_{BE,BG,FE,FG,HE,HG}.mat
├── artifacts/
│   ├── 01_discovery/
│   ├── 02_refinement/
│   ├── 03_seed_search/
│   ├── 04_daughter_branches/
│   └── 05_validation/
├── checkpoints/                 transient interrupted-run recovery
├── views/                       optional user-facing projections
└── logs/                        optional local transcripts, never frozen
```

`artifacts/05_validation/pronking_multigait_validation_results.mat` is the
authoritative specialized report. `validation_report.mat` is its compact
`floquet-reference-validation-index-v3` evidence/provenance index; it does not
embed another complete report. Other stage MAT/CSV files are compressed
reference projections with `floquet-reference-*-v2` schemas; they must not be
passed to the generic workflow resume API. The `04_daughter_branches` record
contains corrected local rays and held-out alignment evidence, not newly
continued global daughter curves.

Experiment-specific source is deliberately local:

- `PronkingExperimentPaths.m` owns relocatable package paths;
- `main_Test_FloquetAnalysis.m` computes and tracks the reduced-map FDMs;
- `main_Test_PronkingMultiGaitBifurcation.m` assembles the experiment;
- `ResolvePronkingCriticalSubspace.m` resolves the repeated kernel;
- `ExplorePronkingBranchSwitch.m` and `CorrectPronkingGaitBranch.m` search
  and correct the six symmetry rays;
- `ValidatePronkingDaughterBranches.m` performs held-out comparison;
- `main_HandValidate_PronkingBifurcation.m` independently replays corrected
  orbits;
- `main_Walkthrough_PronkingMultiGaitBifurcation.m` is the sectioned manual
  reproduction; and
- `WritePronkingStageArtifacts.m` writes the numbered retrospective views.

Reusable numerics remain in `../../+floquet/`; production tests remain in
`../../tests/production/`. Inputs are the parent file above and the six
validation-only files
`data/held_out_daughter_branches/BD1_20_2_{BE,BG,FE,FG,HE,HG}.mat`.

## Reproduce and replay

From the repository root in MATLAB:

```matlab
floquetRoot = fullfile('SLIP_Quadruped','3_Numerical_Continuation', ...
    '2_Floquet_Analysis_v2');
experimentRoot = fullfile(floquetRoot,'reference_experiments', ...
    'PK_multigait_bifurcation');
addpath(floquetRoot,experimentRoot);

report = main_Test_PronkingMultiGaitBifurcation();
assert(strcmp(report.status,'verified'));
assert(report.nonlinearSearch.blindSixArmDiscoveryValidated);

audit = main_HandValidate_PronkingBifurcation();
assert(audit.accepted);
```

For an editor-driven, line-by-line explanation, open and run
`main_Walkthrough_PronkingMultiGaitBifurcation.m` one `%%` section at a time:

```matlab
edit main_Walkthrough_PronkingMultiGaitBifurcation.m
main_Walkthrough_PronkingMultiGaitBifurcation
```

Its safe default loads the frozen authoritative MAT result and independently
replays all 12 corrected periodic orbits without writing files. Change its
`executionMode` to `"recompute-package"` only when replacing the package-local
artifacts, reference configuration, and checksum record is intentional.
The walkthrough is pedagogical; it is not a resumable generic workflow.

Run and replay logging is disabled by default. Supply an explicit `LogFile`
option only for a local diagnostic transcript. Logs and MATLAB FIG files are
not frozen evidence; portable plots are PNG.

The hand replay does not trust saved acceptance flags. It reevaluates each
corrected 22-variable orbit with the production residual and timing solver,
checks Poincare closure and event topology, and reclassifies the gait symmetry.

Useful manual projections are all under `artifacts/05_validation/`:

1. `pronking_branch_search_clusters.csv` should contain six persistent rows.
2. `pronking_branch_search_attempts.csv` should contain 12 accepted non-parent
   corrections at two radii.
3. `pronking_corrected_orbits.csv` exposes all corrected orbit variables.
4. `pronking_multigait_validation_summary.csv` records all held-out alignments.
5. `pronking_corrected_branch_rays.png` shows the two corrected points on each
   oriented ray.

## Centralized production tests

Tests are owned by the clean Floquet-v2 test tree, not copied into this
reference package:

```matlab
setenv('SLIP_RUN_LONG_FLOQUET_TESTS','1');
testRoot = fullfile(floquetRoot,'tests','production');
suite = [testsuite(fullfile(testRoot,'test_pronking_branch.m')), ...
         testsuite(fullfile(testRoot,'test_pronking_multigait_prediction.m'))];
results = run(suite);
assert(~any([results.Failed]));
```

The optional branch-switch and gait-corrector subtests have their own gates:
`SLIP_RUN_BRANCH_SWITCH_TESTS=1` and
`SLIP_RUN_PRONKING_GAIT_CORRECTOR_TESTS=1`.

## Frozen provenance and integrity

The original evidence record used MATLAB R2025b Update 5 and repository
commit `f2e6859454afdba372decd40daf3a9cd61bb741c`. On 2026-08-05, the
regression reported 21 passing tests; the complete experiment ran from 10:07
to 10:13 EDT, and the independent replay accepted 12/12 corrected orbits at
10:14 EDT. These values describe the original run; generated MAT files carry
the timestamp, MATLAB version, and diagnostics of any later regeneration.

`SHA256SUMS` fingerprints package-owned source, inputs, numerical artifacts, CSV,
Markdown, PNG, configuration, and this README. It excludes optional logs,
MATLAB FIG files, and itself. Regenerate it only after intentionally freezing
a complete package record.

## Scope

This retrospective package validates local corrected periodic orbits and
their relation to known held-out branches. It does not rediscover the entire
parent branch from an unknown input, continue complete daughter branches, or
claim robustness at grazing, changed event topology, or simultaneous impacts.
Use the generic workflow for a new branch-wide analysis.
