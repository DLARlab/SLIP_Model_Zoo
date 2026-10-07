# B2 continuation and its other apex

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


The two endpoints in the original 852-column B2 file were manual stops. The low end stopped after crossing both initial and mean zero velocity; the upper end stopped at a 300-second checkpoint. Neither was a demonstrated branch endpoint.

The delivered B2 file has **1,358 columns**: 360 new low-side points, all 852 original points unchanged, and 146 new upper-side points. Its sampled initial velocity spans approximately −20.1750 to +20.1733, passing folds in both directions. All new points pass native and two independent tighter-tolerance replays below 1e-8. The largest native residual across the complete file is 3.55e-9.

The new one-dimensional pseudo-arclength continuation allows signed velocity and negative ground reaction forces. It follows the observed exact reversible bounding symmetry in eight coordinates while retaining all 22 native periodic/contact equations for acceptance. The original high-speed seed was poorly conditioned in the unrestricted coordinates; the symmetry chart reduces the estimated condition number from about 2.36e8 to 2.01e4. No production model or existing continuation algorithm was edited for this work.

## Saved branch and figures

- `../B2_10_20_2_G.mat`: original columns preserved exactly, with validated continuation appended at both ends. `segmentInfo` maps every original column into the updated file; `previousMetadata` retains the old metadata with its original indexing.
- The canonical assembled branch is `../B2_10_20_2_G.mat`; its identity is recorded in `extension_summary.json`.
- `original_B2_852.mat`: byte-for-byte backup before this extension, SHA256 `92007b938dd1b6c8e39f5a37446364b6f23a49c6bd532c8b49f1be1c3153efb8`.
- `b2_extended_branch.png` / `.pdf`: every delivered B2 point in continuation order, including the high-speed fold and residual checks.
- `extended_path.png` / `.pdf`: the previously verified delayed-liftoff PIP → PK_B2_Parent → B2 route with the new B2 continuation. The earlier independent audit and its snapshots remain unchanged.
- `extension_summary.json`: final point counts, ranges, residuals, and hashes.

The file name ending in `_G` is retained for compatibility. It does not mean every saved initial configuration is a gathered suspension: some mathematical solutions have contact at their height maximum, and the branch may contain negative forces or negative travel speeds.

## What the other-apex connection establishes

Every original B2 orbit has one other downward apex, at half a period within the measured numerical accuracy. Shifting the state to that apex and shifting all touchdown/liftoff times by the same amount represents the same full periodic orbit.

For original column 441, both apices are in flight. The front-minus-hind foot span projected onto the torso is 0.424782 at the gathered apex and 1.627016 at the extended apex, compared with a hip span of 1. This directly verifies the two suspension configurations within one gait.

The signed-velocity continuation also overlaps the original family after the other-apex shift and horizontal reflection. For a corrected comparison near original column 200, the initial-state discrepancy is 1.61e-12, normalized event-time discrepancy is 4.51e-13, period discrepancy is 2.03e-13, and full-cycle trajectory discrepancy is 1.38e-11. Eight comparisons span the original branch and new upper continuation; the deepest comparison has larger full-cycle error (7.6e-8), explicitly retained in `apex_audit/overlap_batch.json`.

This is a verified phase/symmetry identification of a periodic family. It does not establish a new finite bifurcation point or global closure of the mathematical branch. The previously verified PIP/PK/B2 bifurcation points and their Floquet evidence remain in `../PIP_to_B2_Path_Audit/`.

Original column 12 (updated column 372) is itself invariant under the half-period shift followed by reflection: its mean velocity is 1.96e-16 and the full 14-state cycle discrepancy is 3.67e-12. See `apex_audit/stationary_fixed_point.json`. This establishes a stationary spatiotemporal symmetry without assigning a new bifurcation subtype.

- `../B2_10_20_2_E.mat`: the accepted other-apex representation. Its `sourceColumn` maps into the updated B2 file. All attempted candidates, acceptance masks, geometry, and phase errors are retained separately within the MAT file.
- `apex_audit/apex_equivalence.png` / `.pdf`: the two suspension configurations and cycle correspondence.
- `apex_audit/corrected_source_for_phase.mat`: explicit fixed-period corrections of 55 original source points whose raw other-apex replay exceeded 1e-8. The maximum correction norm is 1.24e-5; the original B2 columns themselves are unchanged. The companion retains raw and corrected sources so this numerical adjustment is visible.

The final companion contains **1,307 accepted columns**, including the phase images of all original 852 points. Its acceptance requires native periodic residual below 1e-8, full-cycle phase-matching state error below 1e-7, no contact-mode mismatch, and mean-speed difference below 1e-8. The largest accepted phase-matching error is 7.40e-8. All 1,358 attempted phase images remain in the source-aligned audit arrays; 51 points near the compressed upper end fail at least one acceptance gate. A phase-image failure does not erase its independently verified original-apex solution.

The companion's accepted source indices are 1:1306 plus the isolated point 1347. Treat the latter as a separately verified point, not a certified continuous bridge across excluded neighbors. Use `sourceColumn` to preserve this gap when plotting or choosing continuation seeds.

## Continuation limits and validation

The low search stopped after verified overlap with the existing family under phase/reflection. Its stored end is not a physical endpoint. The upper continuation passes a velocity fold and approaches very short stance legs. Near this region, angular dynamics and full-period shooting become sensitive; apex curvature and distinct contact-event spacing do not collapse at the earlier stop.

Every delivered native B2 column passes the full 22-equation residual threshold of 1e-8. The original column checks are reused from the frozen audit after exact matrix matching; every newly accepted continuation point receives an unchanged full-period native replay. Independent tighter-tolerance tail checks distinguish a converged delivered segment from exploratory candidates. See `endpoint_diagnostics/` and the final MAT metadata for the precise final stop and measured geometric margins. No exact collision endpoint or complete global component is claimed.

The last delivered upper point has initial velocity 4.7604556411, mean velocity 3.8364712117, period 1.3495272208, and minimum stance leg length 0.0033655806. Its tightest replay residual is 9.56e-9; the next candidate gives 1.007e-8 and is excluded. All new points, including the entire low extension, were checked at the native tolerances and at ODE tolerances 1e-13 and 3e-14. The delivered MAT includes these results and column mappings in `independentReplay`.

## Standing bounding family connected to BIP

The other requested deliverable is `../BS_10_20_2_BIP_Child.mat`, with its continuation, validation, figure, and limiting analysis in `../BS_10_20_2_BIP_Child_continuation/`. It is the standing family connected to the previously verified BIP drift bifurcation. The requested filename is retained; the local dynamical interpretation is a standing family from which traveling BIP branches emerge.

The file contains **213 verified orbits**, including the BIP critical orbit at column **24**. The largest native residual is 3.75e-9, and the largest of the two tighter replay residuals is 9.63e-9. Twenty additional native-passing tail candidates are retained in the audit but excluded from the deliverable because tighter replay fails the 1e-8 threshold.

Standing means zero cycle-mean horizontal velocity. Its stored section inherits the BIP connection's conditions of zero vertical velocity and zero body pitch, generally at a height minimum, so its instantaneous initial horizontal velocity need not vanish. One end approaches zero swing duration. The other has a documented shooting-accuracy limit; the data do not establish a globally complete component.
