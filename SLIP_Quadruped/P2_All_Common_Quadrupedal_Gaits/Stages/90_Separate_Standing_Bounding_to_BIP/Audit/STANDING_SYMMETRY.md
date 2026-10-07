# Standing BIP symmetry and the distinction between zero drift and bifurcation

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


**Zero mean velocity alone does not imply a bifurcation.** A periodic gait can
cross zero net displacement regularly. It does not thereby become vertical
PIP or synchronized PK: this BIP retains front/hind alternating contact.

This bounded audit reads the saved trajectories and native Jacobians in
`mean_zero.mat` and `drift_daughters.mat`. It performs local interpolation and
linear algebra only. Source hashes and all numerical arrays are retained in
`standing_symmetry.json`; `check_standing_symmetry.py` reproduces this report.

## Actual half-period reflection symmetry

Let R reflect horizontal position and pitch, exchange front/hind legs, and
negate each leg's angle and angular rate. Vertical height and velocity remain
unchanged. Both inspected zero-drift orbits satisfy
`Y(t+T/2)=R Y(t)` to saved-trajectory precision, after choosing the reflection
center at the initial x=0 position. The comparison at T/2 is away from contact
events, so it does not interpolate across a reset.

| Quantity | Original corrected zero-drift point | New daughter-limit candidate |
|---|---:|---:|
| T | 2.982208850266364 | 2.982228115451653 |
| Reduced 13-state reflection error | 1.086e-12 | 1.085e-12 |
| x(T/2) | 6.3e-14 | 6.025e-14 |
| TD half-period lag error | -2.858e-13 | -2.189e-13 |
| LO half-period lag error | -2.858e-13 | -2.189e-13 |
| Interpolation-window variation | 7.31e-14 | 7.318e-14 |
| Distance from half time to nearest contact event | 0.368034 | 0.368028 |

Model equivariance and matching contact schedules extend the symmetry from
the matched state to the entire orbit. This half-period reflection symmetry
forces zero displacement over the full cycle. It is substantially stronger
evidence than observing zero average velocity alone.

## Why the original point supports a standing family, not a bifurcation claim

The original point has one near-zero native22 singular value
`3.8192e-11`; the next is
`7.9187e-06`, above the finest Jacobian
refinement norm `5.8168e-08`. Its unit
solution tangent has `dT/ds=0.395968936`.
As the difference step is halved, the derivative of
`TD_h−TD_f−T/2` converges toward zero (from approximately −1.07e−4 to −1.68e−6);
the corresponding LO constraint behaves the same way.

**Conditional argument:** if the observed rank21 corresponds to a regular
one-dimensional local solution branch and the phase chart is smooth, the
nonzero period derivative makes T a local branch coordinate. Reflection
preserves T and fixes the base orbit modulo its half-period phase shift.
Local uniqueness at each T then forces it to fix the nearby branch pointwise.
These nearby orbits are standing, with zero net displacement. This does not
declare the original zero-drift point a pitchfork.

## The nearby daughter-limit candidate is different

The new candidate differs in period by
`1.92651852884e-05`. At the finest native
Jacobian scale its two smallest singular values are
`1.1749e-11` and
`1.5937e-09`, with the next
`0.038538429` and refinement norm
`5.8177e-08`. The regular-uniqueness argument
above is **not** applied at this two-direction candidate.

Paired drifting solutions with signed mean speeds ±1e−3, ±2e−4, and ±5e−5
approach this candidate, while their pair averages converge more rapidly.
The detailed distances and period offsets are in the JSON. This supports the
nearby standing-parent / drifting-daughter interpretation, together with the
separate local standing-family audit. A native periodic-residual Jacobian
alone is not a Floquet certificate; the independent full12 calculation is
recorded in `../bip_floquet/`.

## Section convention

Both original stored dy=0 sections have **positive** vertical acceleration
(approximately 0.192894). They are height
minima, not downward-curvature apices. A Floquet implementation requiring a
downward apex must phase-shift the full state and event schedule, preserve
the full contact period, and pass its existing checks. Its gates must not be
weakened to admit the original minimum section.
