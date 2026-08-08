# Package manifest

Cryptographic file fingerprints are stored in `SHA256SUMS`.

## Experiment-specific source

- `PronkingExperimentPaths.m`
- `main_Test_FloquetAnalysis.m`
- `main_Test_PronkingMultiGaitBifurcation.m`
- `main_HandValidate_PronkingBifurcation.m`
- `ResolvePronkingCriticalSubspace.m`
- `CorrectPronkingGaitBranch.m`
- `ExplorePronkingBranchSwitch.m`
- `ValidatePronkingDaughterBranches.m`
- `tests/test_pronking_branch.m`
- `tests/test_pronking_multigait_prediction.m`

## Packaged inputs

- `data/pronking_branch/PK_20_2.mat` — primary 29-by-891 pronking branch.
- `data/held_out_daughter_branches/BD1_20_2_BE.mat`
- `data/held_out_daughter_branches/BD1_20_2_BG.mat`
- `data/held_out_daughter_branches/BD1_20_2_FE.mat`
- `data/held_out_daughter_branches/BD1_20_2_FG.mat`
- `data/held_out_daughter_branches/BD1_20_2_HE.mat`
- `data/held_out_daughter_branches/BD1_20_2_HG.mat`

The six daughter files are held-out validation inputs and are not prediction
or nonlinear-seeding inputs.

## Final numerical evidence

- `results/final/pronking_multigait_validation_results.mat`
- `results/final/pronking_multigait_validation_report.md`
- `results/final/pronking_multigait_validation_summary.csv`
- `results/final/pronking_critical_orbit.csv`
- `results/final/pronking_branch_search_attempts.csv`
- `results/final/pronking_branch_search_clusters.csv`
- `results/final/pronking_corrected_orbits.csv`
- `results/final/pronking_hand_validation_replay.csv`
- `results/final/pronking_critical_spectrum.{png,fig}`
- `results/final/pronking_critical_directions.{png,fig}`
- `results/final/pronking_daughter_validation.{png,fig}`
- `results/final/pronking_corrected_branch_rays.{png,fig}`

## Intermediate evidence

- `results/intermediate/pronking_symmetry_corrector_smoke.mat`
- `results/intermediate/pronking_six_arm_persistence.mat`

These intermediate MAT files are retained for provenance only. The
authoritative final MAT supersedes them.

## External reusable dependencies (not copied here)

- Shared Floquet-v2 functions in `../../`.
- Shared Floquet-v2 utilities in `../../utilities/`.
- Production quadruped dynamics in
  `../../../../1_Dynamic_Frameworks/v2/` relative to the continuation tree.
- Continuation and solution-management code in the existing repository.
- MATLAB Optimization Toolbox (`fsolve`).
