# Executed MATLAB research round (validation)

Starting commit `f53c39cca530d9782d00ba8699acb1d55484f7d8`; MATLAB `25.2.0.3177638 (R2025b) Update 5` on `MACA64`. Registration `07-Oct-2026 11:40:19` was saved before numerical experiments. Historical files in `Research_v3/runs/full` remain unchanged.

Current outcome: `partial_checkpoint`. Charged numerical task wall time 914.265 s of 1800 s; 413 function evaluations, 4 new point records and 0 accepted source records. Records can represent duplicate orbit states; these totals are not counts of distinct gait families.

Fresh next-round PIP signed-daughter evidence contains 0 accepted records, counted directly from executed amplitude artifacts independently of older task counters. Full-space bifurcation/stability and branch attachment retain their separate gates.

The requested connected P1/P2 network is not established. This finite search makes no global completeness or nonexistence claim. The two historical restricted PIP–PK attachments are preserved with their invariant-pronk qualification, separately from imported PK ancestry and full-system stability.

Prospective domain: E `[0.780615248, 250.669125]`, mean speed `[-30.6347761, 30.6347761]`, absolute pitch `1.2`, primitive period at most `20.7406834`, physical events at most `128`. Initial source speed is a different observable from mean drift/period. Domain derivation and the preserved old registration appear in `registration_validation.json`.

The effective source/P2 lower energy bound follows the prospective journal `Research_v3/next_round/domain_revisions.json`; original registration and earlier observations retain their former bounds. The ordinary analytic vertical PIP comparison remains restricted to E>1.

The independent initial-state audit `Research_v3/next_round/solver/domain_lower_energy_audit.json` admitted all331 baseline subunit source columns; its minimum-energy fresh BL1/BL2 return attempts hit tensile stance and establish no periodic gait.

| Research round | Executed tasks | Accepted source records | Method |
|---|---:|---:|---|
| A | 0 | 0 | direct conversion + fixed-energy correction and quantitative trace |
| B | 2 | 0 | adjacent/source-minimum neighbors + physical rephase/retraction + scaled correction |
| C | 0 | 0 | denser source neighbors + unrestricted physical chart + measured-stencil feasible predictor repair; separate BL2 hypothesis |

A row describes actual execution only when its count is positive. An unchanged retry or report refresh is not a new repair round. Per-column MAT evidence retains mapped source, explicit predictor modifications, primary solver failure and independent replay. `coverage_validation.json` distinguishes executed from untested source columns.

| Task | Execution/scientific state | Attempts | New point records | Evidence |
|---|---|---:|---:|---|
| `solver_validation` | accepted / solver_gates_passed | 1 | 0 | `Research_v3/next_round/tasks/validation/solver_validation/result.mat` |
| `PK_continuation_m1` | partial_checkpoint / continued_branch_attachment_unresolved | 4 | 4 | `Research_v3/next_round/tasks/validation/PK_continuation_m1/result.mat` |
| `PIP_candidate_1` | partial_checkpoint / unprocessed | 1 | 0 | `Research_v3/next_round/tasks/validation/PIP_candidate_1/result.mat` |

The exact unfinished MATLAB queue is `Research_v3/next_round/task_queue_validation.json`; the resumable task/phase MAT checkpoint is `checkpoint_validation.mat`. Point caps and task slices are checkpoints rather than branch endpoints.

Already executed work can be reproduced/resumed with MATLAB:

```matlab
addpath(fullfile(pwd,'SLIP_Quadruped_v3'));
report = RunResearchRound_v3('Profile','validation','Resume',true,'MinRepairRounds',3);
```
