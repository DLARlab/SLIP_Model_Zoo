# Manifest

## Experiment code

- `RoadmapRobustnessPaths.m`
- `RoadmapBifurcationCases.m`
- `ComputeRoadmapFloquetScan.m`
- `AnalyzeRoadmapBifurcationCase.m`
- `ResolveRoadmapSymmetryBreakingMode.m`
- `ValidateRoadmapSignPairs.m`
- `ValidateRoadmapTransition.m`
- `WriteRoadmapRobustnessArtifacts.m`
- `main_Test_RoadmapBifurcationRobustness.m`
- `main_Refresh_RoadmapReferenceArtifacts.m`
- `main_HandValidate_RoadmapBifurcations.m`
- `tests/test_roadmap_bifurcation_robustness.m`

## Packaged inputs

Each input is stored once in `data/branch_library/`:

- `BD1_20_2_BG.mat`
- `BD1_20_2_BE.mat`
- `BD1_20_2_FE.mat`
- `BD1_20_2_FG.mat`
- `BD1_20_2_HE.mat`
- `BD1_20_2_HG.mat`
- `BD1_20_2_GG.mat`
- `BD1_20_2_GE.mat`

Roles are transition-specific and are declared only in
`RoadmapBifurcationCases.m`. In particular, FG and HE are held-out daughters
for BG/BE tests and parent inputs for the galloping tests.

## Shared code intentionally not copied

The package calls the shared `ComputeFloquetFDM`, `BuildPoincareMap`,
`DetectBifurcation`, `RefineCriticalOrbit`, `PredictBranchDirection`,
`CorrectBranchSwitch`, utility functions, continuation residual, and v2 hybrid
dynamics from `2_Floquet_Analysis_v2/` and the existing repository framework.

Generated files are listed in `README.md`. `SHA256SUMS` covers the completed
package so copied inputs, numerical results, figures, logs, and scripts can be
checked during manual handoff.

## Reference artifacts

- `results/intermediate/parent_only_predictions.mat`
- `results/intermediate/parent_only_predictions_checkpoint.mat`
- `results/final/roadmap_bifurcation_robustness_results.mat`
- `results/final/roadmap_bifurcation_robustness_summary.csv`
- `results/final/roadmap_branch_switch_corrections.csv`
- `results/final/roadmap_hand_validation_replay.csv`
- `results/final/roadmap_bifurcation_robustness_report.md`
- spectrum and held-out validation figures in PNG and MATLAB FIG formats
- six `results/final/cases/<transition>/<transition>_result.mat` files
- full experiment, hand replay, fast/full test, cross-regression, and package
  integrity logs under `logs/`
