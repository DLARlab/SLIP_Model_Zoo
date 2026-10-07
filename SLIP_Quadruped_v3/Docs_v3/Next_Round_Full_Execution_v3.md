# Executed MATLAB research round (full)

Starting commit `f53c39cca530d9782d00ba8699acb1d55484f7d8`; MATLAB `25.2.0.3177638 (R2025b) Update 5` on `MACA64`. Registration `07-Oct-2026 11:40:17` was saved before numerical experiments. Historical files in `Research_v3/runs/full` remain unchanged.

Current outcome: `total_budget_exhausted`. Charged numerical task wall time 10804.967 s of 10800 s; 4990 function evaluations, 58 new point records and 14 accepted source records. Records can represent duplicate orbit states; these totals are not counts of distinct gait families.

The campaign account includes a conservative182-second external-interruption charge with measured interval86–182 seconds because the exact stop timestamp was not captured; uncertainty is preserved in `Research_v3/next_round/queue_schema_repair.json`. Focused solver/theory/workflow audit wall times outside this master account are reported separately in their artifacts.

A second source-handoff interruption was charged conservatively46seconds, with measured interval15–46seconds and no captured exact stop timestamp. Its per-column artifacts survived; the old source process did not finalize its phase checkpoint. The uncertainty is preserved in `Research_v3/next_round/interruption_P1_source_07_B.json`.

The negative PK interruption was stopped at the observed UTC second 14:58:48 and charged 337 seconds. Its saved accepted points were reconciled; 138 known completed evaluations are retained as a lower bound and in-flight evaluation counts are unknown. Consequently the campaign evaluation total is a recorded lower bound, not an exact global count. See `Research_v3/next_round/continuation_interruption_reconciliation.json`.

Fresh next-round PIP signed-daughter evidence contains 22 accepted records, counted directly from executed amplitude artifacts independently of older task counters. Full-space bifurcation/stability and branch attachment retain their separate gates.

Standing opposed-spread campaign evidence contains 10 independently admitted restricted records. Exact predictor admission, meaningful nonlinear correction and subsequent signed-amplitude branch samples remain distinct; the actual classifier may remain unclassified. These records establish no requested B2/F2/H2/G2 connection or full-space stability.

These standing records are numerically consistent with 5 sampled orbit classes modulo time phase. At fixed resonance and|A|, ±A are marked half-period phases of the same labeled orbit; signed records do not count as distinct gait families. The saved counterpart audit is `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Opposed_Spread/Theory/opposed_spread_phase_equivalence.json`.

The requested connected P1/P2 network is not established. This finite search makes no global completeness or nonexistence claim. The two historical restricted PIP–PK attachments are preserved with their invariant-pronk qualification, separately from imported PK ancestry and full-system stability.

A new qualified local numerical PK bridge is supported: four small constrained increments from an imported PK record reach the independently corrected low-energy negative PIP daughter, with state/energy/period/drift/contact and trajectory endpoint agreement. This is separate from rigorous ancestry and the shrinking-amplitude PIP attachment gate. Evidence: `Docs_v3/Imported_PK_Low_Energy_Local_Bridge_v3.md`.

The separate low-energy accuracy repair passes the unchanged signed shrinking-sequence attachment gates. Its negative daughter agrees with the frozen bridge target in a zero-map saved-trajectory comparison, supporting a composed conditional numerical PIP-to-imported-PK connection at critical E=1.1171137022972106 in the exact-baseline synchronized-pronk subspace. The anchor is `PIP_PK_low_energy_neighborhood`, with accuracy task `PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02`; this does not identify the older critical parent orbits at E1.555/1.695. Full-space bifurcation/stability, rigorous ancestry and the global P1/P2 network remain unestablished. Evidence: `Research_v3/next_round/restricted_imported_PK_composition_audit.json`.

Prospective domain: E `[0.780615248, 250.669125]`, mean speed `[-30.6347761, 30.6347761]`, absolute pitch `1.2`, primitive period at most `20.7406834`, physical events at most `128`. Initial source speed is a different observable from mean drift/period. Domain derivation and the preserved old registration appear in `registration_full.json`.

The effective source/P2 lower energy bound follows the prospective journal `Research_v3/next_round/domain_revisions.json`; original registration and earlier observations retain their former bounds. The ordinary analytic vertical PIP comparison remains restricted to E>1.

The independent initial-state audit `Research_v3/next_round/solver/domain_lower_energy_audit.json` admitted all331 baseline subunit source columns; its minimum-energy fresh BL1/BL2 return attempts hit tensile stance and establish no periodic gait.

| Research round | Executed tasks | Accepted source records | Method |
|---|---:|---:|---|
| A | 19 | 7 | direct conversion + fixed-energy correction and quantitative trace |
| B | 30 | 6 | adjacent/source-minimum neighbors + physical rephase/retraction + scaled correction |
| C | 17 | 1 | denser source neighbors + unrestricted physical chart + measured-stencil feasible predictor repair; separate BL2 hypothesis |

A row describes actual execution only when its count is positive. An unchanged retry or report refresh is not a new repair round. Per-column MAT evidence retains mapped source, explicit predictor modifications, primary solver failure and independent replay. `coverage_full.json` distinguishes executed from untested source columns.

| Task | Execution/scientific state | Attempts | New point records | Evidence |
|---|---|---:|---:|---|
| `solver_validation` | accepted / solver_gates_passed | 2 | 0 | `Research_v3/next_round/tasks/full/solver_validation/result.mat` |
| `PIP_candidate_1` | partial_checkpoint / restricted_spectral_candidate_with_executed_daughter_attempts | 4 | 12 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/PIP_candidate_1/result.mat` |
| `PIP_candidate_2` | partial_checkpoint / independently_closed_restricted_daughter_records | 3 | 1 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/PIP_candidate_2/result.mat` |
| `PIP_candidate_3` | partial_checkpoint / independently_closed_restricted_daughter_records | 2 | 1 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/PIP_candidate_3/result.mat` |
| `PK_continuation_m1` | partial_checkpoint / continued_branch_attachment_unresolved | 2 | 3 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Continuation/PK_continuation_m1/result.mat` |
| `PK_continuation_p1` | partial_checkpoint / continued_branch_attachment_unresolved | 1 | 1 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Continuation/PK_continuation_p1/result.mat` |
| `restricted_daughter_1_m1` | partial_checkpoint / continued_branch_attachment_unresolved | 1 | 1 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Continuation/restricted_daughter_1_m1/result.mat` |
| `restricted_daughter_1_p1` | partial_checkpoint / continued_branch_attachment_unresolved | 1 | 1 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Continuation/restricted_daughter_1_p1/result.mat` |
| `restricted_daughter_2_m1` | partial_checkpoint / continued_branch_attachment_unresolved | 1 | 1 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Continuation/restricted_daughter_2_m1/result.mat` |
| `restricted_daughter_2_p1` | partial_checkpoint / continued_branch_attachment_unresolved | 1 | 1 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Continuation/restricted_daughter_2_p1/result.mat` |
| `P1_source_01_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_01_A/result.mat` |
| `P1_source_02_A` | pending / not_executed | 0 | 0 | `` |
| `P1_source_03_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_03_A/result.mat` |
| `P1_source_04_A` | pending / not_executed | 0 | 0 | `` |
| `P1_source_05_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_05_A/result.mat` |
| `P1_source_06_A` | pending / not_executed | 0 | 0 | `` |
| `P1_source_07_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_07_A/result.mat` |
| `P1_source_08_A` | pending / not_executed | 0 | 0 | `` |
| `P1_source_09_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_10_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_10_A/result.mat` |
| `P2_source_11_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_11_A/result.mat` |
| `P2_source_12_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_12_A/result.mat` |
| `P2_source_13_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_13_A/result.mat` |
| `P2_source_14_A` | partial_checkpoint / source_orbits_recovered_ancestry_unresolved | 1 | 5 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_14_A/result.mat` |
| `P2_source_15_A` | partial_checkpoint / source_recovery_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_15_A/result.mat` |
| `P2_source_16_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_16_A/result.mat` |
| `P2_source_17_A` | partial_checkpoint / source_orbits_recovered_ancestry_unresolved | 1 | 2 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_17_A/result.mat` |
| `P2_source_18_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_18_A/result.mat` |
| `P1_source_01_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_01_B/result.mat` |
| `P1_source_02_B` | pending / not_executed | 0 | 0 | `` |
| `P1_source_03_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_03_B/result.mat` |
| `P1_source_04_B` | pending / not_executed | 0 | 0 | `` |
| `P1_source_05_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_05_B/result.mat` |
| `P1_source_06_B` | pending / not_executed | 0 | 0 | `` |
| `P1_source_07_B` | external_interruption / not_executed | 1 | 0 | `` |
| `P1_source_08_B` | pending / not_executed | 0 | 0 | `` |
| `P1_source_09_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_10_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_11_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_12_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_13_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_15_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_16_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B` | partial_checkpoint / source_recovery_unresolved | 1 | 6 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_17_B/result.mat` |
| `P2_source_18_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_18_B/result.mat` |
| `P1_source_01_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_02_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_03_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_04_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_05_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_06_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_07_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_08_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_09_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_10_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_11_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_12_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_13_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_15_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_16_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_C` | partial_checkpoint / source_orbits_recovered_ancestry_unresolved | 3 | 1 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_17_C/result.mat` |
| `P2_source_18_C` | partial_checkpoint / source_recovery_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_18_C/result.mat` |
| `P1_source_19_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_19_A/result.mat` |
| `P1_source_20_A` | pending / not_executed | 0 | 0 | `` |
| `P1_source_21_A` | pending / not_executed | 0 | 0 | `` |
| `P1_source_22_A` | pending / not_executed | 0 | 0 | `` |
| `P1_source_23_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_23_A/result.mat` |
| `P1_source_24_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_24_A/result.mat` |
| `P1_source_25_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_25_A/result.mat` |
| `P2_source_26_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_26_A/result.mat` |
| `P2_source_27_A` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_27_A/result.mat` |
| `P2_source_28_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_29_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_30_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_31_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_32_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_33_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_34_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_35_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_36_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_37_A` | pending / not_executed | 0 | 0 | `` |
| `P2_source_38_A` | pending / not_executed | 0 | 0 | `` |
| `P1_source_19_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_19_B/result.mat` |
| `P1_source_20_B` | pending / not_executed | 0 | 0 | `` |
| `P1_source_21_B` | pending / not_executed | 0 | 0 | `` |
| `P1_source_22_B` | pending / not_executed | 0 | 0 | `` |
| `P1_source_23_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_23_B/result.mat` |
| `P1_source_24_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_24_B/result.mat` |
| `P1_source_25_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_25_B/result.mat` |
| `P2_source_26_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_26_B/result.mat` |
| `P2_source_27_B` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_27_B/result.mat` |
| `P2_source_28_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_29_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_30_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_31_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_32_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_33_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_34_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_35_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_36_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_37_B` | pending / not_executed | 0 | 0 | `` |
| `P2_source_38_B` | pending / not_executed | 0 | 0 | `` |
| `P1_source_19_C` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_19_C/result.mat` |
| `P1_source_20_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_21_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_22_C` | pending / not_executed | 0 | 0 | `` |
| `P1_source_23_C` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_23_C/result.mat` |
| `P1_source_24_C` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_24_C/result.mat` |
| `P1_source_25_C` | retryable_failure / selected_source_neighborhood_unresolved | 3 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_25_C/result.mat` |
| `P2_source_26_C` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_26_C/result.mat` |
| `P2_source_27_C` | retryable_failure / selected_source_neighborhood_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_27_C/result.mat` |
| `P2_source_28_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_29_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_30_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_31_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_32_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_33_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_34_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_35_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_36_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_37_C` | pending / not_executed | 0 | 0 | `` |
| `P2_source_38_C` | pending / not_executed | 0 | 0 | `` |
| `PIP_PK_low_energy_neighborhood` | partial_checkpoint / restricted_spectral_candidate_with_executed_daughter_attempts | 3 | 12 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/PIP_PK_low_energy_neighborhood/result.mat` |
| `P2_source_10_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_11_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_12_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_13_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_15_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_16_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_18_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_26_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_27_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_28_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_29_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_30_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_31_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_32_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_33_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_34_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_35_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_36_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_37_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_38_C_BL2_hypothesis` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_A_column_1_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_A_column_1_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_A_column_2_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_A_column_2_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `PIP_measured_flip_BL2_front_hind` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_1_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_1_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_2_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_2_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_3_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_3_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_4_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_4_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_5_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_5_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_6_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_column_6_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `PIP_n0_measured_flip_BL2_front_hind` | partial_checkpoint / period_two_sector_hypothesis_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Measured_Flip_BL2/PIP_n0_measured_flip_BL2_front_hind/result.mat` |
| `P1_source_01_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_02_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_03_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_04_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_05_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_06_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_07_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_08_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_09_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_10_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_11_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_12_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_13_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_15_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_16_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_B_predictor_trace` | accepted / repaired_predictor_flow_diagnosis_executed | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_17_B_predictor_trace/result.mat` |
| `P2_source_18_B_predictor_trace` | accepted / repaired_predictor_flow_diagnosis_executed | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_18_B_predictor_trace/result.mat` |
| `P1_source_19_B_predictor_trace` | accepted / repaired_predictor_flow_diagnosis_executed | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_19_B_predictor_trace/result.mat` |
| `P1_source_20_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_21_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_22_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P1_source_23_B_predictor_trace` | accepted / repaired_predictor_flow_diagnosis_executed | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_23_B_predictor_trace/result.mat` |
| `P1_source_24_B_predictor_trace` | accepted / repaired_predictor_flow_diagnosis_executed | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_24_B_predictor_trace/result.mat` |
| `P1_source_25_B_predictor_trace` | accepted / repaired_predictor_flow_diagnosis_executed | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P1_source_25_B_predictor_trace/result.mat` |
| `P2_source_26_B_predictor_trace` | accepted / repaired_predictor_flow_diagnosis_executed | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_26_B_predictor_trace/result.mat` |
| `P2_source_27_B_predictor_trace` | accepted / repaired_predictor_flow_diagnosis_executed | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/P2_source_27_B_predictor_trace/result.mat` |
| `P2_source_28_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_29_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_30_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_31_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_32_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_33_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_34_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_35_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_36_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_37_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `P2_source_38_B_predictor_trace` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_1_daughter_1_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_1_daughter_1_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_C_column_1_revision_1_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_17_C_column_1_revision_1_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_1_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_1_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_2_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_2_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_15_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_15_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_28_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_28_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_42_revision_0_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `P2_source_14_A_column_42_revision_0_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `PIP_PK_low_energy_neighborhood_daughter_5_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `PIP_PK_low_energy_neighborhood_daughter_5_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `PIP_PK_low_energy_neighborhood_daughter_6_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `PIP_PK_low_energy_neighborhood_daughter_6_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_1_daughter_5_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_1_daughter_5_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_1_daughter_9_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_1_daughter_9_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `opposed_spread_n0_negative_A1e-3_campaign` | partial_checkpoint / restricted_period_two_corrected_branch_checkpoint_attachment_unresolved | 2 | 3 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Opposed_Spread/opposed_spread_n0_negative_A1e-3_campaign/result.mat` |
| `opposed_spread_n0_positive_A1e-3_campaign` | partial_checkpoint / restricted_period_two_corrected_branch_checkpoint_attachment_unresolved | 2 | 3 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Opposed_Spread/opposed_spread_n0_positive_A1e-3_campaign/result.mat` |
| `PIP_candidate_1_daughter_10_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_1_daughter_10_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `PIP_PK_low_energy_neighborhood_daughter_10_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `PIP_PK_low_energy_neighborhood_daughter_10_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `n0_positive_front_twisted_common_C1_Broyden_retry` | partial_checkpoint / front_twisted_candidate_unresolved | 1 | 0 | `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Front_Twisted_Retry/n0_positive_front_twisted_common_C1_Broyden_retry/result.mat` |
| `imported_PK_to_low_PIP_daughter_negative_0p01` | accepted / local_numerical_PK_connection_and_endpoint_identity_supported | 1 | 4 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Imported_PK_Bridge/imported_PK_to_low_PIP_daughter_negative_0p01/result.mat` |
| `PIP_candidate_1_attachment_accuracy_repair_plus_0.0003` | unresolved_obstruction / accuracy_repair_not_yet_supporting_attachment | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/PIP_candidate_1_attachment_accuracy_repair_plus_0.0003/result.mat` |
| `PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003` | unresolved_obstruction / accuracy_repair_not_yet_supporting_attachment | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003/result.mat` |
| `PIP_candidate_2_daughter_1_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_2_daughter_1_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_3_daughter_1_continuation_m1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_3_daughter_1_continuation_p1` | pending / not_executed | 0 | 0 | `` |
| `PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02` | accepted / numerically_supported_restricted_attachment | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02/result.mat` |
| `PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02` | accepted / numerically_supported_restricted_attachment | 1 | 0 | `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02/result.mat` |

The exact unfinished MATLAB queue is `Research_v3/next_round/task_queue_full.json`; the resumable task/phase MAT checkpoint is `checkpoint_full.mat`. Point caps and task slices are checkpoints rather than branch endpoints.

Already executed work can be reproduced/resumed with MATLAB:

```matlab
addpath(fullfile(pwd,'SLIP_Quadruped_v3'));
report = RunResearchRound_v3('Profile','full','Resume',true,'MinRepairRounds',3);
```
