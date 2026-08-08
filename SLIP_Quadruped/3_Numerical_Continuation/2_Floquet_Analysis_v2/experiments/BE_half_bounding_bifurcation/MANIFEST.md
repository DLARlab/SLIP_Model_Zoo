# Package manifest

## Experiment-local source

- `BEHalfBoundingExperimentPaths.m`
- `main_Test_BEHalfBoundingBifurcation.m`
- `main_HandValidate_BEHalfBoundingBifurcation.m`
- `main_Refresh_BEHalfBoundingReferenceArtifacts.m`
- `tests/test_be_half_bounding_bifurcation.m`

## Packaged inputs

- `data/parent_branch/BD1_20_2_BE.mat` — sole Stage-A parent input.
- `data/held_out_daughter_branches/BD1_20_2_FE.mat`
- `data/held_out_daughter_branches/BD1_20_2_HE.mat`

The daughter files are Stage-B validation inputs only.

## Numerical evidence

- parent-only MAT and checkpoint under `results/intermediate/`
- authoritative `results/final/roadmap_bifurcation_robustness_results.mat`
- summary, corrections, hand-replay, and Markdown projections
- Floquet and held-out-validation figures in PNG and FIG formats
- per-transition MAT files under `results/final/cases/`
- full-run, hand-replay, test, and integrity transcripts under `logs/`

Shared numerical and dynamics functions remain outside this experiment.
`SHA256SUMS` fingerprints every packaged regular file except itself.
