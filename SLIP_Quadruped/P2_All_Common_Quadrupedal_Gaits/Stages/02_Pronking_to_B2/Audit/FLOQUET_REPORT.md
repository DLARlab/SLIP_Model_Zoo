# Independent PK → B2 Floquet audit

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


Fresh differentiation of the full 12-dimensional reduced apex-state, full-cycle
return map confirms a transverse multiplier crossing +1 at the saved critical
parent, u = 0.593430750523358. The structural unit
multiplier along the pronking family was removed using a separately corrected
local family tangent at each of the three parent points.

| Point | Initial velocity | Extra quotient multiplier | Parent tangent kernel residual | Finest FD relative change |
|---|---:|---:|---:|---:|
| below | 0.591430750523 | 0.994094465072 | 9.344e-09 | 1.420e-09 |
| critical | 0.593430750523 | 1.000000004761 | 3.037e-08 | 1.973e-09 |
| above | 0.595430750523 | 1.005899450160 | 3.220e-08 | 1.493e-09 |

The secant slope across the bracket is 2.95124627.
All 288/288 perturbed timing-solved maps passed. The calculation used
clustered event topology with scaled central perturbations 5e-7 × [8, 4, 2, 1]
and the frozen solver's default strict acceptance thresholds; no rejection
threshold was relaxed. Full raw map values, timing/topology diagnostics, all four
derivative matrices, spectra and eigenvectors are in `pk_to_b2_floquet.mat`.
The maximum forward/backward relative mismatch was
1.194e-05, below the configured 5e-3 threshold.

Parent solutions were freshly corrected within exact pronking symmetry, giving
full periodic residuals at most 3.796e-13.
Central parent tangents using ±1e-5 and ±5e-6 differed by at most
8.845e-10 in normalized direction.
Changing between these tangents changed the selected quotient multiplier by at
most 1.998e-15.

At the critical point, the two smallest singular values of M − I are
2.573e-09 and 1.324e-09, while the next is
7.022e-01. After removing the parent tangent from the
domain, the smallest singular value is
2.021e-09 and the next is
7.022e-01. This resolves a second
critical direction beyond the family tangent. The finest matrix refinement
change has absolute 2-norm 7.499e-08; the center
multiplier's 4.761e-09 deviation from 1 is within this numerical scale.

Signed daughter pairs at decreasing pitch-rate amplitudes were independently
replayed, with maximum full periodic residual 3.694e-13.
For each pair, the signed state secant was projected perpendicular to the
parent-family tangent and normalized. Its residual and distance to the
smallest transverse singular direction converge as follows:

| Pitch-rate amplitude | ‖(M − I)d‖₂ | Distance to transverse critical direction |
|---:|---:|---:|
| 0.005 | 5.779e-05 | 7.887e-06 |
| 0.001 | 2.260e-06 | 3.137e-07 |
| 0.0002 | 9.898e-08 | 1.299e-08 |
| 5e-05 | 1.894e-08 | 5.348e-09 |

The projected directions preserve left/right pair equality, zero initial pitch
angle, opposite front/hind initial leg angles and equal front/hind initial leg
rates to the stored numerical precision. The normalized secants also contain
changes in speed, height and common leg rate; they are not assumed to be a pure
pitch-coordinate direction. Their family-tangent component is removed before
the kernel comparison. The smallest-amplitude direction has normalized pitch
rate component 0.532433309.

All three parent orbits already have two other multipliers outside the unit
circle (at the center approximately −2.164715 and −8.919277). Thus this +1
crossing is not an onset of overall linear stability. Four near-zero full-map
multipliers are retained in `multipliers.csv`, including their finite-difference
noise; none are silently discarded. The center's two individual eigenvectors
near +1 are not given unique structural/critical labels because the repeated
eigenspace basis is not unique. The quotient supplies the critical mode's role.

These data support the local PK → B2 branch connection. A normal form and its
coefficients were not computed, so a formal subtype such as a pitchfork, and
supercritical/subcritical classification, remain unverified.

