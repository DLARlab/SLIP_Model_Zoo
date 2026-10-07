# Fresh full Floquet verification: delayed PIP → traveling PK

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


The fresh **12×12** production Floquet calculation confirms an additional +1 crossing of the delayed-liftoff stationary vertical family at height approximately **1.045694946314**. Removing the true vertical-family tangent leaves the crossing multiplier below. The signed traveling-PK daughter secants converge to its critical kernel.

These matrices describe the **complete labeled delayed-contact cycle**, including the intervening flight apex. They are **not first-apex return matrices**. The critical cycle period is **2.440936446440**; the input metadata's ordinary PIP period is **1.447477619861**, a difference of **0.993458826580** in prescribed stance duration.

| Stationary vertical orbit | Height | Full contact-cycle period | Additional multiplier after removing the parent tangent |
|---|---:|---:|---:|
| Below critical | 1.045594946314 | 2.439753387887 | 0.997099009717 |
| Critical | 1.045694946314 | 2.440936446440 | 1.000000067649 |
| Above critical | 1.045794946314 | 2.442119744207 | 1.002981728296 |

The approximately 6.8e-8 discrepancy from the separately computed common-motion 3×3 values is consistent with the finite-difference precision indicated by this full calculation. The critical value is interpreted as +1 at numerical precision; its displayed extra digits do not establish an exact nonzero offset.

## Code and return-cycle identity

Each run starts from MATLAB's default path and explicitly adds only the frozen production framework, solution-management, and Floquet package directories under `../../code/SLIP_Quadruped`. Ten resolved production function paths and their SHA-256 hashes are recorded before and after execution, then independently checked again at export. The dynamics function handle is also verified to point into the frozen snapshot. No live original core file is used or modified.

`floquet.computeFDM` receives **22 state/timing entries and a separate 7-parameter vector**, never the 29-row storage container. All base event times and periods returned by the production timing solver match the stored inputs exactly. All three cycles pass apex orientation, complete-stride coverage, periodicity, event topology, and timing-repeatability checks. Perturbed periods remain close to their own selected base cycles; exact ranges are retained in `summary.json`. There is no observed switch to the shorter ordinary-PIP cycle.

The reduced section coordinates are `[dx, y, phi, dphi, alphaBL, dalphaBL, alphaFL, dalphaFL, alphaBR, dalphaBR, alphaFR, dalphaFR]`. Along the stationary vertical family only `y` changes on this section, so its normalized tangent is exactly the height-coordinate vector. This is independently checked against the neighboring input orbits. Event-time variation belongs to the internally solved return map, not to the section coordinates.

## Perturbation checks and selection

Both four-level runs passed the unchanged production policy: clustered simultaneous-event topology, all 96 perturbed maps per orbit, derivative refinement, forward/backward consistency, and timing-repeatability validation. No tolerance or rejection rule was relaxed, and neither run had a rejected orbit.

| Variant | Absolute perturbation factors before state scaling | Maximum finest matrix-refinement change across the three orbits |
|---|---|---:|
| Fine | 4e-6, 2e-6, 1e-6, 5e-7 | 1.50728e-6 |
| Coarse, selected | 3.2e-5, 1.6e-5, 8e-6, 4e-6 | 1.78297e-7 |

Selection uses only the smaller maximum operator-norm difference between the two finest central-difference matrices. Proximity of an eigenvalue to +1 is not used. The smaller-step run shows a larger integration/timing roundoff contribution. These refinement changes are diagnostic uncertainty indicators, not rigorous eigenvalue error bounds. Both complete runs are preserved in separate `fine/` and `coarse/` directories.

At criticality the two smallest singular values of `M-I` are **3.96e-11 and 2.52e-8**, followed by **0.409606**. The second-smallest singular values at the two neighboring orbits are **0.00108240** and **0.00110911**. The exact vertical parent tangent has residual below 1.28e-10 across the three selected matrices. Thus the extra near-null direction is distinct from the parent-family tangent and is separated from the remaining directions by a large singular-value gap.

## Daughter direction check

All eight signed PK daughter inputs were reintegrated with the frozen native dynamics. Their signed pairs define secants independent of the Floquet eigenvectors. After removing the parent tangent, each secant is compared with the entire two-dimensional critical SVD subspace projected off that tangent. No arbitrary eigenvector from a repeated +1 cluster is selected.

| Daughter speed magnitude | `||(M-I)v||` | Distance to parent-removed critical kernel |
|---:|---:|---:|
| 0.01 | 1.96e-5 | 9.08e-6 |
| 0.005 | 4.95e-6 | 2.27e-6 |
| 0.002 | 8.40e-7 | 3.65e-7 |
| 0.001 | 2.60e-7 | 9.51e-8 |

The convergence supports the traveling branch's attachment to this delayed-PIP orbit. Full spectra, including all other modes, are retained; this local crossing check does not claim stability of the complete branch or establish global branch coverage.

