# Package manifest

## Experiment-local source

- `GEHEExperimentPaths.m`
- `main_Test_GEHEBifurcation.m`
- `main_HandValidate_GEHEBifurcation.m`
- `main_Refresh_GEHEReferenceArtifacts.m`
- `tests/test_ge_he_bifurcation.m`

## Packaged inputs

- `data/parent_branch/BD1_20_2_HE.mat` — sole Stage-A parent input.
- `data/held_out_daughter_branches/BD1_20_2_GE.mat` — Stage B only.

Although the package folder is named GE_HE, the numerical transition ID is
`he_to_ge`; parent/daughter provenance is never reversed.

## Numerical evidence

- parent-only MAT and checkpoint under `results/intermediate/`
- authoritative final MAT plus summary/correction/replay CSVs and Markdown
- Floquet and held-out-validation figures in PNG and FIG formats
- `results/final/cases/he_to_ge/he_to_ge_result.mat`
- full-run, hand-replay, test, and integrity transcripts under `logs/`

Shared numerical and dynamics functions remain outside this experiment.
`SHA256SUMS` fingerprints every packaged regular file except itself.
