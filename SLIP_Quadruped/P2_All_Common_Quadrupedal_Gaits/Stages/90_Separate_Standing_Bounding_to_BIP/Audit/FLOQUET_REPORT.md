# Independent full-state Floquet check of the standing-BIP origin

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


All three full12 Floquet calculations passed the frozen production gates.
The nontrivial multiplier, after removing the independently corrected standing
parent tangent, lies below +1 before the candidate and above +1 after it.
The critical value is consistent with +1 at the observed numerical resolution.

| Orbit | Full period | Extra quotient multiplier | Finest multiplier change | Full-matrix refinement norm |
|---|---:|---:|---:|---:|
| standing_below | 2.982128115452 | 0.996933347072 | 3.45e-06 | 0.00021 |
| critical | 2.982228115452 | 0.999997153287 | 3.41e-06 | 0.000209 |
| standing_above | 2.982328115452 | 1.003084193015 | 3.38e-06 | 0.000208 |

## Section and orbit identity

The input BIP files start at a height minimum with positive vertical
acceleration, which is not eligible for the production downward-apex map.
Each complete state and event schedule was shifted to its first genuine
downward apex, near T/4. A standing-symmetry corrector using the unchanged
full periodic residual adjusted those phase-shifted states by at most
`9.103e-11`. The corrected critical
apex has vertical acceleration `-0.0143866208`,
and its periodic residual is `9.058e-13`.

The full period and labeled contact cycle were preserved and independently
checked against the timing solver's base orbit. The next downward apex after
half a cycle is the reflected state, not a fixed point of this full-cycle map.
The input-to-base maximum event-time change is at most
`0`.

## Numerical resolution

The critical extra multiplier is `0.999997153287`. Its distance
from +1, `2.847e-06`, is smaller than the observed final
refinement change `3.412e-06`. Across the four relative
perturbation levels 4e−6, 2e−6, 1e−6, and 5e−7, the critical estimates are
`[1.00000325239514, 1.0000011016386763, 1.0000005652959778, 0.999997153287177]`.
Every level keeps the two neighboring multipliers on opposite sides of +1;
their offsets are approximately 0.003, substantially larger than their
observed multiplier refinement changes of approximately 3.4e−6.

This is an **empirical numerical resolution statement**, not an interval proof
that an eigenvalue is exactly +1. The critical matrix is nonnormal; the
quotient eigenvalue condition number is approximately
`119.8`.
The raw matrix refinement norm is `0.000209`.
Multiplying that norm by the condition number gives a pessimistic generic
bound, so that matrix norm alone is not used to certify the crossing. The
step-by-step multiplier behavior, independently corrected parent/daughter
families, and native branch-rank checks are assessed together.

The critical singular values of M−I end with
`[0.03822740552903802, 1.4534379313693402e-07, 1.2904038737258273e-08]`; after parent removal they end with
`[0.038227405520869735, 2.3781574847126462e-08]`. Parent-tangent residuals are below
the matrix refinement scale. These SVD values are retained with that scale;
they are not presented as exact nullities from a noise-free matrix.

All 96 perturbed maps per orbit passed, as did the default topology,
event-timing repeatability, derivative-convergence, and forward/backward
checks. The largest finest forward/backward mismatch is
`0.00106096`,
below the existing 0.005 threshold. No gate was weakened.

## Daughter alignment

The already-corrected daughters at mean speeds ±1e−3, ±2e−4, and ±5e−5 were independently shifted to the same downward apex and directly replayed. After removing the corrected standing-parent tangent, their distances to the entire two-dimensional critical SVD subspace are 0.002576, 0.0001036, 6.274e-06. The corresponding norms of (M−I) times the transverse direction are 0.005417, 0.0002178, 1.348e-05. These are finite-difference numerical alignment checks, not exact equalities. No additional Floquet matrices were computed for this comparison.

