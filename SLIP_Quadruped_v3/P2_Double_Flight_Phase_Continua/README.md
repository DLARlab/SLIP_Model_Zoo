# Double-flight phase continua

This folder provides saved primitive two-flight results and their independent scientific audits. The admitted standing results lie in the exact opposed-side-spread restriction at the baseline physical parameters. They have zero horizontal drift, actual two-flight labeled returns and `unclassified/ambiguous` gait status. They are not recovered B2, F2, H2 or G2 branches.

## Branch and cycle sample files

| Direct MATLAB file | Saved records | Meaning |
|---|---:|---|
| [Opposed_Spread_n0_Negative_Cycle_Samples.mat](Opposed_Spread_n0_Negative_Cycle_Samples.mat) | 5 | One exact predictor admission, one genuine nonlinear correction and three subsequent restricted branch samples. |
| [Opposed_Spread_n0_Positive_Cycle_Samples.mat](Opposed_Spread_n0_Positive_Cycle_Samples.mat) | 5 | One exact predictor admission, one genuine nonlinear correction and three subsequent restricted branch samples. |
| [Opposed_Spread_n0_n1_Theory_Cycle_Samples.mat](Opposed_Spread_n0_n1_Theory_Cycle_Samples.mat) | 4 | Saved exact-predictor replays at n0/n1 and both signs; two sampled cycle classes modulo time phase. |

Each MAT collection contains `branch` and `solutions`. Adjacent JSON files retain record kinds, amplitudes, flight counts, gait labels, closure values and source hashes. Exporting these collections performs no new shooting and creates no additional acceptance certificate.

At fixed resonance and nonzero magnitude `|A|`, the positive and negative states are two marked apex phases of the same primitive labeled BL2 cycle, separated by half a period without relabeling the legs. Predictor admission and correction at the same amplitude are also separate evidence operations rather than separate cycles. Consequently, the ten campaign records sample five n0 cycle classes modulo phase; the four theory records sample two classes, one at n0 and one at n1. These counts overlap at the common n0 sample and must not be added as distinct families. See the [phase-equivalence audit](Bifurcation_Audits/Opposed_Spread/Theory/opposed_spread_phase_equivalence.json) and [restricted construction](../Docs_v3/Restricted_PIP_Opposed_Spread_Period_Two_v3.md).

## Bifurcation and validation evidence

- [Opposed_Spread](Bifurcation_Audits/Opposed_Spread/): separate signed campaign checkpoints and accepted trials, analytic/actual-model [theory audits](Bifurcation_Audits/Opposed_Spread/Theory/), [shared-solver admission and correction](Bifurcation_Audits/Opposed_Spread/Solver_Audit/) and saved [figures](Bifurcation_Audits/Opposed_Spread/Figures/).
- [Measured_Flip_BL2](Bifurcation_Audits/Measured_Flip_BL2/): independently registered front/hind flip vectors, actual BL2 attempts and [deadline-cutoff derivative forensics](Bifurcation_Audits/Measured_Flip_BL2/Forensics/). The final n0 trial remained unaccepted; incomplete FD columns are not a mathematical nonexistence result.
- [Front_Twisted_Retry](Bifurcation_Audits/Front_Twisted_Retry/): the retained unconverged front-only pilot/retry and [near-null derivative forensics](Bifurcation_Audits/Front_Twisted_Retry/Forensics/). No accepted two-flight daughter or resolved weakest singular value follows from that attempt.
- [Source_Recovery](Bifurcation_Audits/Source_Recovery/): source catalogs, converted predictors, correction/replay outcomes and physical failure traces. Original P2 provenance does not by itself determine a recovered orbit's flight count.
- [Source_Critical_Fixtures](Bifurcation_Audits/Source_Critical_Fixtures/) and [Source_Plot_Fixtures](Bifurcation_Audits/Source_Plot_Fixtures/): preserved historical raw snapshots with provenance, not autonomous accepted branch collections. The finite archived inventory found no explicit F2/H2/G2 seeds; `saved_ge_phase` describes B2 gathered/extended apex views, not a G2 gait. [Archived seed availability](../Docs_v3/P2_Archived_Seed_Availability_v3.md).
- [Frozen_Source_Sectors](Bifurcation_Audits/Frozen_Source_Sectors/): frozen parent/sector evidence with its original acceptance or unfinished status.
- [Historical_Study](Bifurcation_Audits/Historical_Study/): preserved historical study indexes, configurations, source fixtures, converted seeds and validation provenance.

Original P2 sources that produced single-flight PK/PIP controls belong with the measured [single-flight results](../P1_Single_Flight_Phase_Continua/) or shared source ledgers, while retaining their original source IDs and study origin. The research runner, global configuration, task/checkpoint ledgers and qualified graph remain in [Research_v3](../Research_v3/).

The exact restricted standing construction and finite admitted samples establish no B2/F2/H2/G2 recovery, imported-PK ancestry of the standing family, unrestricted stability, or complete P1/P2 gait network.
