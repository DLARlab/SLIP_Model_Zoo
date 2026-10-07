# Native BIP connection audit

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


**The saved drifting BIP branch connects to a newly identified standing bounding parent family.** The origin is near saved columns 233–234, where mean forward speed changes sign. It is distinct from the original initial-speed-zero seed and from the other previously saved P2 families.

The critical standing orbit has initial velocity `-0.0206915832077`, height `0.969089784386`, pitch rate `0.130759126579`, and full period `2.98222811545`. Its mean speed is `-4.16e-15` and full native periodic residual infinity norm is `3.6e-13`. The stored section is a vertical minimum; it is not an apex section.

## Evidence for the connection

1. Six separately corrected drifting orbits at mean velocities ±0.001, ±0.0002 and ±0.00005 converge to the same standing orbit. The two even-in-speed extrapolations differ by only `6.43e-11` across all 22 state/event coordinates.
2. The critical full22 periodic-residual Jacobian has two unresolved zero singular values (`1.17e-11`, `1.59e-9`), followed by `0.0385384`. The last four-step derivative refinement difference is `5.82e-8`. Standing-parent neighbors at period offsets ±0.0001 have only one continuation null direction; their second singular values are about `4.10e-5`.
3. After independently identifying the standing-parent tangent, the extra signed rank diagnostic crosses `-4.10387e-5 → -1.56308e-9 → +4.11800e-5`. This scalar is a Jacobian rank diagnostic, not a Floquet multiplier.
4. Independently corrected standing-parent and drifting-daughter tangents lie in the critical two-dimensional kernel (projection errors `1.14e-9` and `4.57e-8`). They are independent: absolute cosine `0.114647`; the daughter component transverse to the parent has norm `0.993406`.
5. Re-correcting the ±0.001 drifting daughters to the measured mean speeds of saved columns 233 and 234 reproduces their complete 22 coordinates within `2.97e-10` and `4.17e-11`. Thus the local daughter is linked numerically to the saved branch, beyond visual proximity or a shared velocity.

The independently computed full-state Floquet audit is stored separately under `../bip_floquet/`.

## Full stored branch and other candidates

All 904 points pass a fresh frozen-model replay. Maximum residual infinity norm: `7.62e-10`; maximum Euclidean norm: `9.88e-10`. Mean speed spans `[-0.551646584, +0.551646483]`; minimum body height is `0.044156655`, and tensile GRF reaches `-9.637332`.

The original initial-velocity-zero seed (column 228) actually has mean speed `+0.0193809247` and pitch rate `0.129687503`. It is a regular point of the drifting branch. The two corrected pitch-rate-zero points retain opposite front/hind leg angles of magnitude `0.3334282` and `0.2898959`; their full Jacobians have only the continuation null direction.

| Point | Smallest singular value | Next singular value | FD refinement difference | Interpretation |
|---|---:|---:|---:|---|
| saved_1 | 2.46e-07 | 0.103674 | 0.000178 | One continuation null direction |
| saved_217 | 7.69e-11 | 0.0241706 | 8.7e-08 | One continuation null direction |
| saved_228 | 2e-10 | 0.00941613 | 6.53e-08 | One continuation null direction |
| saved_904 | 0.00119 | 0.0374938 | 489 | Inconclusive |
| pitch_zero_134_135 | 3.56e-10 | 0.0488233 | 1.75e-07 | One continuation null direction |
| pitch_zero_345_346 | 2.08e-10 | 0.107929 | 3.1e-08 | One continuation null direction |

A mean-speed-zero solve without preserving the drifting daughter can land on a nearby regular standing orbit (`T=2.98220885027`). Its extra singular value is `7.92e-6`; it is not the bifurcation. Fixed nonzero mean-speed daughters resolved this branch-selection issue.

The largest apparent left/right trajectory discrepancy (`1.63e-5`, column 777) occurs during front-leg touchdown resets separated by `2.72e-10` time units. Outside a `1e-8` window around events, that orbit agrees left/right to `1.54e-12`. Both raw and event-context diagnostics are retained.

