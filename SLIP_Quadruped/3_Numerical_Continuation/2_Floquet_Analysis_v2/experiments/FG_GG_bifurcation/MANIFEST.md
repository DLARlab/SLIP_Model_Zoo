# Package manifest

## Experiment-local source

- `FGGGExperimentPaths.m`
- `main_Test_FGGGBifurcation.m`
- `main_HandValidate_FGGGBifurcation.m`
- `main_Refresh_FGGGReferenceArtifacts.m`
- `tests/test_fg_gg_bifurcation.m`

## Packaged inputs

- `data/parent_branch/BD1_20_2_FG.mat` — sole Stage-A parent input.
- `data/held_out_daughter_branches/BD1_20_2_GG.mat` — Stage B only.

## Numerical evidence

- parent-only MAT and checkpoint under `results/intermediate/`
- authoritative final MAT plus summary/correction/replay CSVs and Markdown
- Floquet and held-out-validation figures in PNG and FIG formats
- `results/final/cases/fg_to_gg/fg_to_gg_result.mat`
- full-run, hand-replay, test, and integrity transcripts under `logs/`

Shared numerical and dynamics functions remain outside this experiment.
`SHA256SUMS` fingerprints every packaged regular file except itself.
