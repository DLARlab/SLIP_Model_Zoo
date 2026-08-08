# Pronking multi-gait bifurcation experiment

This folder is the complete experiment-specific record for the Floquet-v2
pronking calculation. It contains the pronking branch used for computation,
the six held-out daughter branches, pronking-only MATLAB drivers and helpers,
tests, final and intermediate numerical outputs, editable/portable figures,
and execution logs.

Reusable Poincare-map, finite-difference, multiplier-tracking, critical-orbit
refinement, branch-prediction, and validation functions are deliberately not
duplicated here. They remain two levels above this folder in
`2_Floquet_Analysis_v2/`, with shared helpers in `utilities/`. The experiment
therefore runs inside this repository but is not intended as a standalone copy
of the dynamics framework.

## Verified outcome

The packaged reference run supports the requested conclusion:

- corrected pronking bifurcation at `dx = 4.43406193516227`;
- `dim ker(M-I) = 4` before tangent removal;
- three additional critical coordinates: bounding `b`, front spread `f`, and
  hind spread `h`;
- 12 accepted nonlinear corrections at radii `1e-2` and `5e-3`;
- six persistent oriented clusters, with class counts `[B F H] = [2 2 2]`;
- maximum cluster canonical residual `1.893e-13`;
- maximum scaled Poincare-return residual `4.313e-14`;
- held-out daughter critical-space alignments from `0.99986` to `0.999996`;
- independent production-solver replay accepted all 12 corrected orbits.

The detector interpolation near `dx = 4.43412` is only the saved-column
bracket estimate. The corrected orbit above is the reported bifurcation point.

## Folder layout

```text
pronking_multigait_bifurcation/
├── README.md
├── MANIFEST.md
├── RUN_METADATA.md
├── PronkingExperimentPaths.m
├── main_Test_FloquetAnalysis.m
├── main_Test_PronkingMultiGaitBifurcation.m
├── main_HandValidate_PronkingBifurcation.m
├── ResolvePronkingCriticalSubspace.m
├── CorrectPronkingGaitBranch.m
├── ExplorePronkingBranchSwitch.m
├── ValidatePronkingDaughterBranches.m
├── data/
│   ├── pronking_branch/PK_20_2.mat
│   └── held_out_daughter_branches/BD1_20_2_{BE,BG,FE,FG,HE,HG}.mat
├── tests/
├── results/
│   ├── final/
│   └── intermediate/
└── logs/
```

`PK_20_2.mat` is the only branch used to construct the reduced Floquet maps,
refine the critical orbit, resolve the symmetry kernel, and seed nonlinear
corrections. The six daughter MAT files are never used in prediction or
correction; they are loaded afterward as a held-out validation set.

## Reproduce the full experiment

From the repository root in MATLAB:

```matlab
experimentRoot = fullfile('SLIP_Quadruped','3_Numerical_Continuation', ...
    '2_Floquet_Analysis_v2','experiments', ...
    'pronking_multigait_bifurcation');
addpath(experimentRoot);

report = main_Test_PronkingMultiGaitBifurcation();
assert(strcmp(report.status,'verified'));
assert(report.nonlinearSearch.blindSixArmDiscoveryValidated);
```

The default run reads only the packaged branch inputs and writes to
`results/final/`. It does not modify the dynamics core.

## Independent hand validation

```matlab
addpath(experimentRoot);
audit = main_HandValidate_PronkingBifurcation();
assert(audit.accepted);
```

This replay does not trust the saved acceptance flags. It reloads each
corrected 22-variable orbit, reevaluates the canonical residual, calls the
normal production timing solver, checks Poincare closure and topology, and
reclassifies B/F/H timing and apex-state symmetries. Its flat output is
`results/final/pronking_hand_validation_replay.csv`.

Recommended manual checks:

1. `pronking_branch_search_clusters.csv` has six persistent rows, two radii
   per row, and two rows for each B/F/H class.
2. `pronking_branch_search_attempts.csv` has 12 accepted non-parent attempts;
   requested and corrected classes agree.
3. `pronking_corrected_orbits.csv` contains all 22 orbit variables for each
   accepted point.
4. `pronking_multigait_validation_summary.csv` shows all six held-out daughter
   branches inside the predicted critical space.
5. `pronking_corrected_branch_rays.png` shows two points on each of six
   oriented rays, one at each correction radius.

## Tests

Run all packaged tests with the production finite-difference fixture enabled:

```matlab
setenv('SLIP_RUN_LONG_FLOQUET_TESTS','1');
setenv('SLIP_RUN_BRANCH_SWITCH_TESTS','0');
setenv('SLIP_RUN_PRONKING_GAIT_CORRECTOR_TESTS','0');

suite = testsuite(fullfile(experimentRoot,'tests'), ...
    'IncludeSubfolders',true);
results = run(suite);
assert(all([results.Passed]));
```

The two zero-valued gates avoid repeating the already packaged multi-minute
critical refinement during an ordinary regression run. Set either to `1` to
force its corresponding production workflow.

## Result authority

`results/final/pronking_multigait_validation_results.mat` is the authoritative
machine-readable record. CSV, Markdown, PNG, and FIG files are projections for
manual inspection. The two MAT files in `results/intermediate/` record earlier
single-purpose smoke/persistence runs and are not used to support the final
claim.

## Known scope

The package verifies local daughter periodic orbits and their connection to
the pronking critical space. It does not regenerate the entire global
continuation curve for each gait. Grazing, changed event topology, and
simultaneous-impact nonsmoothness remain rejection conditions documented in
the shared Floquet-v2 README.
