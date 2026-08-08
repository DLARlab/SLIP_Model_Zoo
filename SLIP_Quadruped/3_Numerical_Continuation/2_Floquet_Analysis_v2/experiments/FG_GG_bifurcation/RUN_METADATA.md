# Run metadata

- Experiment: FG -> GG gathered-suspension galloping bifurcation
- Parent input: `data/parent_branch/BD1_20_2_FG.mat`
- Held-out daughter: GG
- Transition ID: `fg_to_gg`
- Dynamics core modified: no
- Event timing solver: existing production v2 solver
- Floquet coordinates: 12 reduced apex-section states; no event times
- Finite-difference base magnitude: `5e-7`
- Finite-difference factors: `[8 4 2 1]`
- Parent scan columns: `143:147`
- Nonlinear correction radii: `[1e-2 5e-3]`, both signs
- Consolidated reference refined `dx`: `5.91164917105`
- Expected exact nullity of `M-I`: 2
- Expected daughter label: GG
- Packaged artifact origin: one-transition projection of the verified
  combined six-transition reference run
- Export computation scope: saved record selected and paths rebound; Stage-A
  finite differences, critical refinement, and corrections not recomputed
- Independent recomputation command: `main_Test_FGGGBifurcation()`
- Independent wrapper test (2026-08-05, MATLAB R2025b): 4 passed, 0 failed,
  0 incomplete in 338.2579 s; parent and held-out stages accepted
- Independent rerun held-out alignment: GG `0.999791`

Package-local MATLAB version, timestamps, diagnostics, and acceptance records
are stored in the final MAT and logs. Generate `SHA256SUMS` only after the
package record is frozen.
