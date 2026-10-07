# B2: the other downward apex is a second description of the same cycle

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../../README.md) for current locations.


Every one of the original 852 B2 cycles has exactly one other downward apex.
Its phase is T/2, with maximum observed fractional deviation 1.32e-9. All original
stored sections are themselves downward apices; the initial vertical
accelerations range from −9.7713 to −0.6680. Each complete cycle also contains two
vertical minima.

The full-cycle phase map is

`X_other(0) = X_original(tau)`,
`E_other = mod(E_original - tau, T)`,
`T_other = T`, with `tau ≈ T/2`.

Horizontal position is reset to zero, as in the model's translational reduction.
For a replay time s, the corresponding original state is at
`mod(s + tau, T)`; horizontal displacement is compared with the original
trajectory continued by whole-cycle translations. The period is **not halved**.
This coordinate change supplies the other-apex branch representation directly.
It does not require two curves in the stored initial-state chart to intersect.

All eight labelled leg-event times are shifted together. Complete 13-state
trajectories were compared at 100 smooth points per cycle; mean velocity and
contact modes were checked separately. Every comparison had identical contact
modes. The maximum mean-speed difference over all 852 raw rephasings was 3.71e-11.
Raw trajectory differences reached 2.78e-7 in the most numerically sensitive
stored high-speed points; these limitations are retained, not hidden.

## Gathered and extended are assigned from the actual airborne geometry

The projected signed front-minus-hind foot-tip span is measured along the torso
axis, whose hip-to-hip length is 1. Each foot is constructed as

`foot = hip + rho * [sin(phi + alpha), -cos(phi + alpha)]`.

Swing legs have rest length 1; stance lengths follow the model's ground
constraint. A span below 1 describes a gathered leg configuration, and a span
above 1 describes an extended configuration. A suspension label is assigned
only when all four legs are out of contact. Left/right legs coincide in this
paired bounding family.

| Original source column | Original-apex support | Original foot span | Other-apex support | Other foot span |
|---|---|---:|---|---:|
| 1 | Four legs in contact | 1.026566 | Four legs in contact | 1.141075 |
| 441 | Flight: gathered | 0.424782 | Flight: extended | 1.627016 |
| 600 | Flight: gathered | −0.953622 | Flight: extended | 2.963698 |
| 852 | Flight: gathered | −0.994060 | Flight: extended | 2.972721 |

Negative signed spans mean the projected hind and front foot tips have crossed.
Column 1 has no suspension at either apex. Therefore the filename suffix `G`
cannot be applied as a physical suspension classification throughout the
extended mathematical branch.

For original column 441, the period is 1.704338562, mean speed 0.715085696, and
phase shift 0.852169280. Its two apex initial speeds are 0.727537322 and 0.747908482;
the pitch rates are +0.101514 and −0.111363. The full-cycle state discrepancy after
rephasing is 1.55e-9 and the mean-speed difference 1.19e-11. The second flight
interval is short because this sample is close to its onset.

`apex_equivalence.png` and `.pdf` show this specific original column, its two
leg configurations, the shifted full-cycle height replay, and unchanged
contact itinerary. Original column 441 is assembled column 801. Original and newly assembled
column indices must not be confused. `apex_geometry.csv` contains both configurations for every original
column.

## Endpoint and continuation overlap evidence

At original endpoint 1, initial u=−0.028931193 changes to−0.075074141 at the other
apex; pitch rate changes from−0.150032 to+0.151476. The rephased native residual
is 1.16e-12. At original endpoint 852, initial u=19.51601694 changes to 19.51658130,
and pitch rate changes from+0.06613494 to−0.07692563; the rephased residual
is 1.87e-11. Period and mean velocity are unchanged.

The new low continuation overlaps the horizontally reflected other-apex image
of the old branch and the new upper continuation. Horizontal reflection is

`u -> -u`, `phi -> -phi`, `dphi -> -dphi`,

with front/hind leg pairs exchanged, all leg angles and angular rates negated,
and their touchdown/liftoff pairs exchanged. Height, vertical velocity and
period are unchanged. This is a symmetry for the present equal front/hind
parameters.

Eight pairs were independently corrected near the candidate reference branch,
at the mapped initial speed, and compared through their complete cycles:

| Low checkpoint column | Nearby reference column |
|---:|---|
| 6 | Original 28 |
| 50 | Original 119 |
| 78 | Original 200 |
| 140 | Original 393 |
| 200 | Original 528 |
| 260 | Original 737 |
| 302 | Upper checkpoint 23 |
| 362 | Upper checkpoint 79 |

The resulting initial-state differences are 2.9e-13–1.3e-11, normalized-event
differences at most 8.6e-13, and period differences at most 9.0e-13. Full-cycle
trajectory discrepancies are at most 6.9e-10 except the deepest upper 79 case,
which reaches 7.6e-8 and is reported explicitly. `overlap_batch.mat` and `.json`
preserve the sampled input checkpoints, corrected representatives, phase maps,
and all diagnostics. This establishes overlap under phase and reflection;
it does not by itself establish closure of an entire mathematical component.

Original column 12 (assembled column 372), the stored mean-zero orbit, is
invariant under the half-cycle phase shift followed by reflection. Its period is
2.340136996208, mean speed 1.96e-16, and initial speed 0.0234719411. The phase
fraction is 0.500000000000225. Independent comparison of the full 14-state
trajectory at 200 points gives discrepancy 3.67e-12; initial-state discrepancy
is 8.75e-13, normalized-event discrepancy 3.43e-12, and period difference zero.
`stationary_fixed_point.mat` and `.json` retain this certificate. This establishes
a spatiotemporal symmetry at mean zero without a normal-form bifurcation claim.

No separately named extended-suspension B2 source MAT was found in the workspace.
Related P1 `BD1_20_2_BG.mat` and `BD1_20_2_BE.mat` files were inspected and retained
as distinct comparisons; nearest initial-state resemblance alone is not used
to call them the same orbit. The phase image of the actual B2 input provides
the requested second apex representation without inventing a new dataset.

## Numerical correction and companion schema

Raw rephasing gives maximum native residual 1.45e-8. Original columns 785–839
(55 points) fail 1e-8. Only these source cycles were corrected in the exact
reversible eight-variable subspace at their fixed original periods. The
phased orbits were not freely corrected. Raw source arrays, corrected source
arrays, correction masks, norms and full reports are preserved in
`corrected_source_for_phase.mat`.

The maximum source correction norm is 1.24e-5 at original 839, dominated by
leg-rate changes around 6e-6; initial-speed change there is 3.31e-9 and period
change is zero. After these explicit source corrections, all 852 other-apex
cycles pass native residual 1e-8, with maximum 9.97e-9. `B2_other_apex.mat` retains
the raw phase image and its acceptance flags; the corrected batch is stored
separately and is used by the final companion builder.

All current runtime paths resolve to the frozen production copies in
`PIP_to_B2_Path_Audit/code/SLIP_Quadruped`. The dense-output helper changes only
the function name/output interface and retains the ode45 solution structures.
Equations, resets, event timing and integration tolerances are unchanged.
Active and frozen dynamics, both leg kinematic functions, and event regulation
were also verified byte-identical. `dense_runtime_provenance.json` records hashes.

Use `rephase_other_apex(solution29)` for one source cycle. It returns every
interior downward-apex candidate and full native/trajectory/geometry diagnostics.
Use

`build_other_apex_companion(inputFile, outputFile)`

for an assembled `results29xN` MAT. Exact matches identify the original 852
columns and reuse their explicit source corrections. An optional third argument
can provide the 852 assembled source indices explicitly.

In the final companion, standard `results` contains only accepted candidates;
`sourceColumn` maps each column to the assembled input. `allRephasedResults`,
`allApexCandidates`, `allCandidateDiagnostics`, and the source-aligned `all*`
arrays retain every attempt, including failures and multiple-apex cases.
Raw/corrected source arrays, correction norms, phase times, geometry and native
acceptance are all retained. This preserves reviewable evidence without placing
NaN or rejected cycles in the standard branch-results array.


## Final assembled companion and explicit acceptance

The assembled source contains 1358 cycles: 360 new low-side cycles, the original
852 at columns 361–1212, and 146 new upper-side cycles. Every source cycle yielded
exactly one other downward apex. `P2/B2_10_20_2_E.mat` stores 1307 accepted
other-apex representatives in its standard `results` array, with `sourceColumn`
mapping to the assembled source. All original 852 cycles are retained.

Each accepted representative satisfies all four numerical gates:

- Native full periodic residual below 1e-8.
- Maximum state difference below 1e-7 over 100 smooth full-cycle phase comparisons.
- No contact-mode mismatches at the comparison points.
- Absolute mean-velocity difference below 1e-8.

The maxima over accepted representatives are 9.9657e-9 for native residual,
7.3963e-8 for phase-trajectory difference, and 3.7058e-11 for absolute mean-speed
difference. Contact-mode mismatch count is zero for every attempted cycle.
These are sampled numerical checks over the full cycle, rather than a uniform
analytic error bound.

Accepted source indices are 1–1306 and 1347. Excluded source indices 1307–1346 and
1348–1358 all fail the trajectory gate; 1352, 1356 and 1358 also fail the native
residual gate. Native residual alone would accept 1355 points, although the
maximum attempted trajectory difference reaches 1.6279e-5. The isolated accepted
index 1347 does not certify continuity through its excluded neighbors. All 1358
attempts, acceptance masks, error measurements and source corrections remain in
the companion's source-aligned `all*` arrays. No rejected candidate appears in
standard `results`.

The only explicit source corrections remain original 785–839, now assembled
1145–1199; all source periods are fixed. Final source values were checked exactly
against the completed assembled input before refreshing its SHA-256 metadata.
`final_companion_validation.json` records the final hashes, acceptance gates and
counts; `final_companion_per_source.csv` lists every attempt. These diagnostics
describe a phase representation of the accepted cycles, not an additional
physical branch or evidence that continuation terminates at the numerical
acceptance boundary.
