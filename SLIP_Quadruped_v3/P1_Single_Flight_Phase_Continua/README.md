# Single-flight phase continua

This folder provides direct MATLAB branch files for saved single-flight PIP/PK results. The files collect accepted records from existing numerical work; organizing or exporting them adds no simulations, closure checks, or bifurcation certificates. Counts include admitted seeds where stated and do not count distinct gait families.

## Branch files

| Direct MATLAB file | Saved records | Meaning |
|---|---:|---|
| [Historical_PK_Continuation_m1.mat](Historical_PK_Continuation_m1.mat) | 20 | Preserved historical negative-direction PK continuation. |
| [Historical_PK_Continuation_p1.mat](Historical_PK_Continuation_p1.mat) | 21 | Preserved historical positive-direction PK continuation. |
| [PK_continuation_m1.mat](PK_continuation_m1.mat) | 23 | The 20 historical records plus three accepted continuation increments. |
| [PK_continuation_p1.mat](PK_continuation_p1.mat) | 22 | The 21 historical records plus one accepted continuation increment. |
| [restricted_daughter_1_m1.mat](restricted_daughter_1_m1.mat), [restricted_daughter_1_p1.mat](restricted_daughter_1_p1.mat) | 2 each | One admitted daughter seed and one continuation increment in each direction. |
| [restricted_daughter_2_m1.mat](restricted_daughter_2_m1.mat), [restricted_daughter_2_p1.mat](restricted_daughter_2_p1.mat) | 2 each | One admitted daughter seed and one continuation increment in each direction. |
| [PIP_n0_PK_Local_Continuation.mat](PIP_n0_PK_Local_Continuation.mat) | 3 | One admitted seed and two local continuation increments. |
| [PIP_Low_Energy_PK_Local_Continuation.mat](PIP_Low_Energy_PK_Local_Continuation.mat) | 3 | One admitted seed and two local continuation increments. |
| [Restricted_Daughter_1_Signed_Samples.mat](Restricted_Daughter_1_Signed_Samples.mat) | 10 | Historical restricted signed daughter samples. |
| [Restricted_Daughter_2_Signed_Samples.mat](Restricted_Daughter_2_Signed_Samples.mat) | 10 | Historical restricted signed daughter samples. |
| [PIP_n0_PK_Signed_Samples.mat](PIP_n0_PK_Signed_Samples.mat) | 10 | Original accepted signed daughter samples near the n0 parent. |
| [PIP_Low_Energy_PK_Signed_Samples.mat](PIP_Low_Energy_PK_Signed_Samples.mat) | 10 | Original accepted signed daughter samples near the low-energy parent. |
| [PIP_candidate_2_PK_Signed_Samples.mat](PIP_candidate_2_PK_Signed_Samples.mat) | 1 | One accepted signed daughter sample; no completed shrinking two-sign attachment sequence. |
| [PIP_candidate_3_PK_Signed_Samples.mat](PIP_candidate_3_PK_Signed_Samples.mat) | 1 | One accepted signed daughter sample; no completed shrinking two-sign attachment sequence. |
| [Imported_PK_Low_Energy_Local_Bridge.mat](Imported_PK_Low_Energy_Local_Bridge.mat) | 5 | One fresh source admission and four accepted local bridge increments. |

Every listed MAT file contains `branch`. Exported sample collections also contain `solutions`; their adjacent JSON files record source paths, hashes, amplitudes, gait classifications and record kinds. Signed sample collections retain the original accepted records. The later `+.0003` accuracy corrections are separate audit artifacts and do not replace the originals in these collections.

## Bifurcation and validation evidence

Numerical acceptance, ancestry and derivative scope are documented independently of the branch collections:

- [Continuation](Bifurcation_Audits/Continuation/): direction-specific checkpoints, corrector failures, closure/classification records and restart evidence.
- [PIP_to_PK](Bifurcation_Audits/PIP_to_PK/): critical-parent searches, signed daughter attempts, original failures, historical evidence and the separate [accuracy repair revision02](Bifurcation_Audits/PIP_to_PK/Accuracy_Repair_02/).
- [Imported_PK_Bridge](Bifurcation_Audits/Imported_PK_Bridge/): frozen source/target, admitted bridge points and the [endpoint trajectory comparison](Bifurcation_Audits/Imported_PK_Bridge/imported_PK_to_low_PIP_daughter_negative_0p01/endpoint_trajectory_comparison.mat).
- [Full_Floquet](Bifurcation_Audits/Full_Floquet/): saved physical spectra and directional/service audits; the reported derivative and invariant-subspace scopes remain essential.
- [Source_Recovery](Bifurcation_Audits/Source_Recovery/): converted source columns, actual replay/correction attempts and preserved partial physical failures.
- [Frozen_Source_Sectors](Bifurcation_Audits/Frozen_Source_Sectors/): frozen parent and sector-attempt evidence, including unfinished attempts.
- [Historical_Study](Bifurcation_Audits/Historical_Study/): preserved study indexes, configurations, source fixtures, converted seeds and validation provenance.

The accepted low-energy attachment and four-increment bridge support a conditional numerical connection to imported PK within the exact-baseline synchronized-pronk restriction. Its parent anchor is `E=1.1171137022972106`; it does not identify that parent with the older critical parents near `1.555` and `1.695`. See the [bridge explanation](../Docs_v3/Imported_PK_Low_Energy_Local_Bridge_v3.md) and [saved composition audit](../Research_v3/next_round/restricted_imported_PK_composition_audit.json).

An original P2 source may yield a single-flight PK/PIP control. Placement follows the measured orbit itinerary while source IDs and original study provenance remain in the P1 evidence or shared source ledgers. Copied raw fixtures are historical inputs, not accepted branches. Research control, global configuration, task/checkpoint ledgers and the qualified connectivity graph remain under [Research_v3](../Research_v3/).

These finite samples and local restricted connections do not establish unrestricted stability, rigorous global connectivity, or completeness of the requested P1/P2 gait network.
