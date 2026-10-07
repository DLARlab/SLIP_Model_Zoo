# Executed MATLAB round: completion and remaining-work audit

This native MATLAB snapshot was exported before temporary runtime-cache removal. The [post-cleanup repository audit](Next_Round_Post_Cleanup_v3.md) verifies the final path/hash and file-size checks after that removal. Numerical checkpoints, source epochs and research outcomes are unchanged.

Saved status: `total_budget_exhausted`. Requested network achieved: `0`; global completeness claimed: `0`.

Starting commit `f53c39cca530d9782d00ba8699acb1d55484f7d8`; MATLAB `25.2.0.3177638 (R2025b) Update 5`, `MACA64`. All required solver gates passed: `1`.

Charged numerical task wall time: 10804.966923 / 10800 seconds; remaining 0.000000 seconds. Counted evaluations: 4990 / 300000. Total registered budget exhausted: `1`. Separate focused audit costs and interruption uncertainty are recorded in their saved audits and the execution ledger. Startup, report waits and postprocessing are not numerical task time.

Protection passes against 544 pre-existing outside-v3 files: no changed, missing or added outside-v3 files. Working files exceeding 100000000 bytes: 0. Largest scanned working file: `SLIP_Quadruped_v3/Research_v3/next_round/tasks/validation/PK_continuation_m1/branch.mat`, 18015528 bytes. `.git` object storage is excluded from this working-file scan.

## Actual research rounds

| Round | Distinct executed tasks | Actual attempts |
|---|---:|---:|
| A | 19 | 19 |
| B | 30 | 39 |
| C | 17 | 23 |

## Executed continuation coverage

Historical points copied into a new trace remain historical. The new-point column counts newly accepted appended records; neither row counts nor matching gait labels establish distinct families or attachment. Batch caps remain resumable checkpoints.

| Task | Records | New records | Energy interval | Mean-speed interval | State |
|---|---:|---:|---|---|---|
| `PK_continuation_m1` | 23 | 3 | [1.11711423282, 1.12280832524] | [-0.00721727742476, 0.108395252455] | `partial_checkpoint` |
| `PK_continuation_p1` | 22 | 1 | [1.11713894281, 1.12406150333] | [-0.119726882319, -0.00721727742476] | `partial_checkpoint` |
| `restricted_daughter_1_m1` | 2 | 1 | [1.55518548644, 1.55518605729] | [-0.00648547374057, 0.00657629252937] | `partial_checkpoint` |
| `restricted_daughter_1_p1` | 2 | 1 | [1.55518548644, 1.55534910658] | [-0.019547468136, -0.00648547374057] | `partial_checkpoint` |
| `restricted_daughter_2_m1` | 2 | 1 | [1.69596813992, 1.69596864643] | [-0.00595472572197, 0.00604126271993] | `partial_checkpoint` |
| `restricted_daughter_2_p1` | 2 | 1 | [1.69596813992, 1.69610806736] | [-0.0179508493868, -0.00595472572197] | `partial_checkpoint` |

## PIP candidate phases

| Task | Critical energy | Accepted signed records | Attachment gate | Phase |
|---|---:|---:|---|---|
| `PIP_candidate_1` | 1.06168502750681 | 10 | `candidate_only` | `continue_daughters` |
| `PIP_candidate_2` | 2.54212568767021 | 1 | `not_yet_evaluated` | `correct_daughters` |
| `PIP_candidate_3` | 2.74257570892904 | 1 | `not_yet_evaluated` | `correct_daughters` |
| `PIP_PK_low_energy_neighborhood` | 1.11711370229721 | 10 | `candidate_only` | `continue_daughters` |

## Separately registered attachment accuracy repairs

The original PIP records and their failed gates remain unchanged. A physically accepted repair replaces one record only in a copied ten-record sequence; an unsuccessful physical repair retains the original sequence. Campaign promotion additionally requires domain acceptance. Neither case counts a new branch amplitude.

| Repair task | Source task | Original gate | Copied sequence gate | Physical/domain acceptance | Execution state |
|---|---|---|---|---|---|
| `PIP_candidate_1_attachment_accuracy_repair_plus_0.0003` | `PIP_candidate_1` | `candidate_only` | `candidate_only` | `0` / `0` | `unresolved_obstruction` |
| `PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003` | `PIP_PK_low_energy_neighborhood` | `candidate_only` | `candidate_only` | `0` / `0` | `unresolved_obstruction` |
| `PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02` | `PIP_candidate_1` | `candidate_only` | `numerically_supported_restricted_attachment` | `1` / `1` | `accepted` |
| `PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02` | `PIP_PK_low_energy_neighborhood` | `candidate_only` | `numerically_supported_restricted_attachment` | `1` / `1` | `accepted` |

## Imported-PK bridge experiment

| Task | New increments | Endpoint/local connection supported | State |
|---|---:|---|---|
| `imported_PK_to_low_PIP_daughter_negative_0p01` | 4 | `1` | `accepted` |

## Exact unfinished MATLAB queue

227 tasks remain unfinished. This is incomplete research, not a nonexistence result. Dependencies, repair revisions, counters, failure records and seed provenance are in `Research_v3/next_round/task_queue_full.json` and the native `checkpoint_full.mat`. The table below contains every unfinished task at this snapshot.

| Task | Kind | Execution state | Scientific status | Current phase | Attempts |
|---|---|---|---|---|---:|
| `PIP_candidate_1` | `PIP_candidate` | `partial_checkpoint` | `restricted_spectral_candidate_with_executed_daughter_attempts` | `continue_daughters` | 4 |
| `PIP_candidate_2` | `PIP_candidate` | `partial_checkpoint` | `independently_closed_restricted_daughter_records` | `correct_daughters` | 3 |
| `PIP_candidate_3` | `PIP_candidate` | `partial_checkpoint` | `independently_closed_restricted_daughter_records` | `correct_daughters` | 2 |
| `PK_continuation_m1` | `continuation` | `partial_checkpoint` | `continued_branch_attachment_unresolved` | `` | 2 |
| `PK_continuation_p1` | `continuation` | `partial_checkpoint` | `continued_branch_attachment_unresolved` | `` | 1 |
| `restricted_daughter_1_m1` | `continuation` | `partial_checkpoint` | `continued_branch_attachment_unresolved` | `` | 1 |
| `restricted_daughter_1_p1` | `continuation` | `partial_checkpoint` | `continued_branch_attachment_unresolved` | `` | 1 |
| `restricted_daughter_2_m1` | `continuation` | `partial_checkpoint` | `continued_branch_attachment_unresolved` | `` | 1 |
| `restricted_daughter_2_p1` | `continuation` | `partial_checkpoint` | `continued_branch_attachment_unresolved` | `` | 1 |
| `P1_source_01_A` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_02_A` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_03_A` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_04_A` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_05_A` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_06_A` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_07_A` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_08_A` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_09_A` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_10_A` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_11_A` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_12_A` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_13_A` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_14_A` | `P2_source` | `partial_checkpoint` | `source_orbits_recovered_ancestry_unresolved` | `correct` | 1 |
| `P2_source_15_A` | `P2_source` | `partial_checkpoint` | `source_recovery_unresolved` | `` | 1 |
| `P2_source_16_A` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_17_A` | `P2_source` | `partial_checkpoint` | `source_orbits_recovered_ancestry_unresolved` | `correct` | 1 |
| `P2_source_18_A` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_01_B` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_02_B` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_03_B` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_04_B` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_05_B` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_06_B` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_07_B` | `P1_source` | `external_interruption` | `not_executed` | `` | 1 |
| `P1_source_08_B` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_09_B` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_10_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_11_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_12_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_13_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_15_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_16_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B` | `P2_source` | `partial_checkpoint` | `source_recovery_unresolved` | `` | 1 |
| `P2_source_18_B` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_01_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_02_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_03_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_04_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_05_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_06_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_07_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_08_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_09_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_10_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_11_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_12_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_13_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_15_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_16_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_C` | `P2_source` | `partial_checkpoint` | `source_orbits_recovered_ancestry_unresolved` | `correct` | 3 |
| `P2_source_18_C` | `P2_source` | `partial_checkpoint` | `source_recovery_unresolved` | `` | 1 |
| `P1_source_19_A` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_20_A` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_21_A` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_22_A` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_23_A` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_24_A` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_25_A` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_26_A` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_27_A` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_28_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_29_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_30_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_31_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_32_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_33_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_34_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_35_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_36_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_37_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_38_A` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_19_B` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_20_B` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_21_B` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_22_B` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_23_B` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_24_B` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_25_B` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_26_B` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_27_B` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_28_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_29_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_30_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_31_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_32_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_33_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_34_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_35_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_36_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_37_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_38_B` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_19_C` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_20_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_21_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_22_C` | `P1_source` | `pending` | `not_executed` | `` | 0 |
| `P1_source_23_C` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_24_C` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P1_source_25_C` | `P1_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 3 |
| `P2_source_26_C` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_27_C` | `P2_source` | `retryable_failure` | `selected_source_neighborhood_unresolved` | `executed_signed_sector_trials` | 1 |
| `P2_source_28_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_29_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_30_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_31_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_32_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_33_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_34_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_35_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_36_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_37_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_38_C` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `PIP_PK_low_energy_neighborhood` | `PIP_candidate` | `partial_checkpoint` | `restricted_spectral_candidate_with_executed_daughter_attempts` | `continue_daughters` | 3 |
| `P2_source_10_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_11_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_12_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_13_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_15_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_16_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_18_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_26_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_27_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_28_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_29_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_30_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_31_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_32_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_33_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_34_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_35_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_36_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_37_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_38_C_BL2_hypothesis` | `P2_source` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_A_column_1_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_A_column_1_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_A_column_2_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_A_column_2_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_measured_flip_BL2_front_hind` | `period_two_sector` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_1_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_1_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_2_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_2_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_3_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_3_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_4_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_4_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_5_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_5_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_6_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_B_column_6_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_n0_measured_flip_BL2_front_hind` | `period_two_sector` | `partial_checkpoint` | `period_two_sector_hypothesis_unresolved` | `correct` | 1 |
| `P1_source_01_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_02_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_03_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_04_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_05_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_06_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_07_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_08_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_09_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_10_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_11_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_12_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_13_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_15_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_16_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_20_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_21_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P1_source_22_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_28_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_29_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_30_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_31_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_32_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_33_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_34_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_35_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_36_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_37_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `P2_source_38_B_predictor_trace` | `source_predictor_audit` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_1_daughter_1_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_1_daughter_1_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_C_column_1_revision_1_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_17_C_column_1_revision_1_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_1_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_1_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_2_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_2_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_15_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_15_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_28_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_28_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_42_revision_0_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `P2_source_14_A_column_42_revision_0_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_PK_low_energy_neighborhood_daughter_5_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_PK_low_energy_neighborhood_daughter_5_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_PK_low_energy_neighborhood_daughter_6_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_PK_low_energy_neighborhood_daughter_6_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_1_daughter_5_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_1_daughter_5_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_1_daughter_9_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_1_daughter_9_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `opposed_spread_n0_negative_A1e-3_campaign` | `period_two_sector` | `partial_checkpoint` | `restricted_period_two_corrected_branch_checkpoint_attachment_unresolved` | `` | 2 |
| `opposed_spread_n0_positive_A1e-3_campaign` | `period_two_sector` | `partial_checkpoint` | `restricted_period_two_corrected_branch_checkpoint_attachment_unresolved` | `` | 2 |
| `PIP_candidate_1_daughter_10_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_1_daughter_10_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_PK_low_energy_neighborhood_daughter_10_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_PK_low_energy_neighborhood_daughter_10_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `n0_positive_front_twisted_common_C1_Broyden_retry` | `period_two_sector` | `partial_checkpoint` | `front_twisted_candidate_unresolved` | `` | 1 |
| `PIP_candidate_2_daughter_1_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_2_daughter_1_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_3_daughter_1_continuation_m1` | `continuation` | `pending` | `not_executed` | `` | 0 |
| `PIP_candidate_3_daughter_1_continuation_p1` | `continuation` | `pending` | `not_executed` | `` | 0 |
