# Pronking multi-gait Floquet-v2 validation

Generated: `20260810T121901`  
MATLAB: `25.2.0.3177638 (R2025b) Update 5`

## Outcome

Floquet-v2 identified the three gait classes and the nonlinear search recovered six persistent oriented rays.

- Status: `verified`
- Refined critical dx: `4.43406193516227`
- Final dx bracket: `[4.43406193516227, 4.43406370981359]`
- Critical multiplier uncertainty: `1.411e-10`
- Canonical residual infinity norm: `3.997e-14`
- Numerical nullity of M-I: `4`
- Additional critical dimension: `3`

## Symmetry sectors

Full near-+1 ranks `[++, +-, -+, --]`: `[2 1 1 0]`  
Additional ranks `[bounding, front, hind, mixed]`: `[1 1 1 0]`  
Commutator Frobenius norms `[hind, front]`: `[4.62313e-08 1.48841e-07]`  
Commutator tolerance: `3.878e-07`

## Held-out daughter comparison

| Code | Expected | Predicted | dx near | Alignment | Angle (deg) | Hind pair | Front pair |
|---|---|---|---:|---:|---:|---:|---:|
| BE | B | B | 4.4316649 | 0.99999430 | 0.1934 | 4.822e-12 | 7.495e-11 |
| BG | B | B | 4.4316649 | 0.99993204 | 0.6680 | 4.822e-12 | 7.495e-11 |
| FE | F | F | 4.42699421 | 0.99991721 | 0.7373 | 8.017e-11 | 1.442e-03 |
| FG | F | F | 4.44314512 | 0.99986096 | 0.9555 | 4.238e-12 | 1.985e-03 |
| HE | H | H | 4.42537684 | 0.99999597 | 0.1628 | 1.165e-03 | 9.948e-12 |
| HG | H | H | 4.42537684 | 0.99994987 | 0.5737 | 1.165e-03 | 9.948e-12 |

Principal cosines: `[0.99999647 0.99998678 0.99978528]`  
Principal angles (degrees): `[0.152301 0.294592 1.18736]`

## Nonlinear six-arm correction

- Search status: `verified`
- Corrector: `symmetry-amplitude`
- Seed provenance: `deterministic-symmetry-grid`
- Attempts: `12`
- Accepted non-parent corrections: `12`
- Persistent oriented clusters: `6`
- Persistent class counts `[B F H]`: `[2 2 2]`
- Blind six-arm verification: `1`

| Cluster | Class | Persistent | Radii | Direction [b f h] | max canonical | max return |
|---:|---|---:|---|---|---:|---:|
| 1 | B | 1 | `[0.005 0.01]` | `[1 9.58791e-10 -2.01974e-09]` | 6.961e-14 | 1.488e-14 |
| 2 | B | 1 | `[0.005 0.01]` | `[-1 2.49675e-10 7.80257e-10]` | 1.893e-13 | 1.908e-14 |
| 3 | F | 1 | `[0.005 0.01]` | `[-0.842372 -0.538896 -4.2893e-09]` | 1.847e-13 | 4.313e-14 |
| 4 | H | 1 | `[0.005 0.01]` | `[-0.845312 -8.44178e-10 -0.534273]` | 6.661e-14 | 1.555e-14 |
| 5 | F | 1 | `[0.005 0.01]` | `[-0.842372 0.538896 -4.28676e-09]` | 9.903e-14 | 1.514e-14 |
| 6 | H | 1 | `[0.005 0.01]` | `[-0.845312 -8.44648e-10 0.534273]` | 7.094e-14 | 1.062e-14 |

## Interpretation and limitation

The reduced FDM predicts a three-dimensional additional +1 critical space. The saved daughter branches were not used to construct that space or the nonlinear seeds; their outgoing secants are a held-out validation set. The nonlinear claim additionally requires independently closed periodic orbits, production-solver event-time agreement, the expected gait isotropy, and persistence over two radii. The MAT file records every accepted and rejected correction attempt.
