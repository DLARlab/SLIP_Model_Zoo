# Imported PK and the low-energy PIP daughter: executed local bridge

The MATLAB campaign completed four small constrained continuation increments from an imported PK orbit to the independently corrected negative-amplitude daughter of the low-energy PIP spectral candidate. Fresh closure and endpoint comparison support a local numerical connection between these two PK records. This result does not establish a rigorous branch identity, a complete global network, or the separate shrinking-amplitude attachment of the daughter to PIP.

The prospective [registration](../Research_v3/next_round/low_energy_PK_bridge_registration.json) froze the source, target, parameters, amplitudes, locality bounds, comparisons and cumulative 480-second budget before any maps. The source is point2 of the preserved historical negative PK branch; its symmetry projection changes the physical state only by roundoff, `3.60e-16`. The target is the frozen independently corrected daughter with signed parent-kernel observable `-.01`, near parent energy `1.1171137022972106`. No horizontal reflection or time-phase shift is used in the comparison.

The amplitude grid was `[-.010445179772861062, -.010333884829645796, -.010222589886430530, -.010111294943215266, -.01]`. The first grid point is a separate fresh source admission; only the next four count as new continuation points. Each point uses the five-dimensional synchronized-pronk amplitude corrector, free energy, exact baseline parameters `[10,10,20,20,1,1,0,0,2,.5]`, the autonomous contact law and tighter independent BL1 replay. Every admitted point has the actual PK classifier, one positive-duration flight and one touchdown/liftoff per leg. Reliable current-source Jacobians were reused with the explicit root-solver reuse flag.

The bridge completed in `344.54047245833334` seconds, with 143 residual and 134 map evaluations. Its [result](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Imported_PK_Bridge/imported_PK_to_low_PIP_daughter_negative_0p01/bridge_result.json) records four accepted increments, one fresh source admission and `local_numerical_connection_supported=true`. All predictors, primary corrections and independent replays remain in the task's MAT artifacts.

| Endpoint comparison against the independently corrected target | Measured gap |
|---|---:|
| Marked apex physical state | `6.0620e-12` |
| Energy | `6.0580e-12` |
| Period | `2.2625e-11` |
| Horizontal drift | `1.0798e-12` |
| Contact phases | `3.5325e-12` |
| One-sided contact states | `1.2527e-11` |
| Saved smooth histories, 2001 samples | `5.4051e-9` |

The contact counts and modes agree. The saved smooth-history comparison uses one-sided linear interpolation in smooth spans; it is a finite-resolution diagnostic, not a certified trajectory error bound. The actual closed returns provide the separate closure checks. Full comparison data are in [endpoint_trajectory_comparison.mat](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Imported_PK_Bridge/imported_PK_to_low_PIP_daughter_negative_0p01/endpoint_trajectory_comparison.mat).

A pre-execution shape review found that the orbit's `stride_displacement` is a 14-dimensional state difference. The prospective [method revision](../Research_v3/next_round/low_energy_PK_bridge_method_revision_001.json) fixed scalar speed/drift to component1 and added explicit pitch/eight-contact domain checks. It retained the frozen source/target, amplitude grid, physical model, acceptance thresholds and budget. No maps were executed during that repair.

The first positive `+.0003` daughter accuracy repairs failed their tightened reduced-residual target because first-order optimality stopped the primary solves. Those measured failures and the original `candidate_only` sequences remain intact. Separately registered revision02 set optimality tolerance `1e-18` and step tolerance `1e-13`, retaining the reduced residual target, function tolerance, physical model and full acceptance gates. Both revision02 corrections passed every unchanged shrinking-daughter attachment gate. They replace only `+.0003` in copied evidence and count no new amplitudes. [Executed accuracy audit](PIP_Attachment_Accuracy_Repair_v3.md).

The final zero-map [composition audit](../Research_v3/next_round/restricted_imported_PK_composition_audit.json) compared the unchanged negative `-.01` orbit in the accepted low-energy accuracy sequence with the frozen bridge target. Their saved apex state, energy, period, drift, contact phases/modes, one-sided states and 2001-point smooth histories are identical. Thus the independently evaluated restricted attachment and four-increment bridge support a composed **conditional numerical PIP-to-imported-PK connection** in the exact-baseline synchronized-pronk subspace.

The connection is explicitly anchored at critical energy `1.1171137022972106`, source task `PIP_PK_low_energy_neighborhood` and accuracy task `PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02`. It does not identify this low-energy parent orbit with the older critical parents at energies about `1.555` and `1.695`. The [typed graph](../Research_v3/next_round/graph/index_full.json) records the qualified connection. Rigorous identity, unrestricted bifurcation/stability and the requested full P1/P2 network remain unestablished.

The final MATLAB master status is `total_budget_exhausted`: charged task wall `10804.966922625003` seconds against the prospective `10800`-second account. The final map/correction operation completed between budget checks, giving `4.966922625003` seconds of recorded overshoot. Counter and status preservation were verified by a final export-only invocation. The 4990 recorded function evaluations are a lower bound because in-flight counts at a previous interruption are unknown; documented conservative interruption charges also remain in the wall account. Focused solver/theory/workflow audit wall is recorded separately.
