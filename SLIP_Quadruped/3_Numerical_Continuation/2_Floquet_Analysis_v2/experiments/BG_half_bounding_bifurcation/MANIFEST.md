# Package manifest

## Experiment-local source

- `BGHalfBoundingExperimentPaths.m`
- `main_Test_BGHalfBoundingBifurcation.m`
- `main_HandValidate_BGHalfBoundingBifurcation.m`
- `main_Refresh_BGHalfBoundingReferenceArtifacts.m`
- `tests/test_bg_half_bounding_bifurcation.m`

## Packaged inputs

- `data/parent_branch/BD1_20_2_BG.mat` — sole Stage-A parent input.
- `data/held_out_daughter_branches/BD1_20_2_HG.mat`
- `data/held_out_daughter_branches/BD1_20_2_FG.mat`

The daughter files are Stage-B validation inputs only.

## Numerical evidence

- `results/intermediate/parent_only_predictions.mat`
- `results/intermediate/parent_only_predictions_checkpoint.mat`
- `results/final/roadmap_bifurcation_robustness_results.mat`
- `results/final/roadmap_bifurcation_robustness_summary.csv`
- `results/final/roadmap_branch_switch_corrections.csv`
- `results/final/roadmap_hand_validation_replay.csv`
- `results/final/roadmap_bifurcation_robustness_report.md`
- `results/final/roadmap_floquet_crossings.{png,fig}`
- `results/final/roadmap_held_out_validation.{png,fig}`
- per-transition MAT files under `results/final/cases/`
- full-run, hand-replay, test, and integrity transcripts under `logs/`

Shared numerical and dynamics functions remain outside this experiment.
`SHA256SUMS` fingerprints every packaged regular file except itself.
