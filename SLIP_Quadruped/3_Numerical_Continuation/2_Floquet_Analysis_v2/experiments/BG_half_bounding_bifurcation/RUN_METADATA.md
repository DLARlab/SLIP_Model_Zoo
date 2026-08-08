# Run metadata

- Experiment: BG half-bounding bifurcations
- Parent input: `data/parent_branch/BD1_20_2_BG.mat`
- Held-out daughters: HG and FG
- Transition IDs: `bg_to_hg`, `bg_to_fg`
- Dynamics core modified: no
- Event timing solver: existing production v2 solver
- Floquet coordinates: 12 reduced apex-section states; no event times
- Finite-difference base magnitude: `5e-7`
- Finite-difference factors: `[8 4 2 1]`
- Parent scan columns: `37:41` and `64:68`
- Nonlinear correction radii: `[1e-2 5e-3]`, both signs
- Consolidated reference refined `dx`: `4.50616189521`, `5.64566295496`
- Expected exact nullity of `M-I`: 2 at each crossing
- Expected daughter labels: HG, FG
- Packaged artifact origin: two-transition projection of the verified
  combined six-transition reference run
- Export computation scope: saved records selected and paths rebound; Stage-A
  finite differences, critical refinement, and corrections not recomputed
- Independent recomputation command: `main_Test_BGHalfBoundingBifurcation()`
- Independent wrapper test (2026-08-05, MATLAB R2025b): 4 passed, 0 failed,
  0 incomplete in 654.4491 s; both parent and held-out stages accepted
- Independent rerun held-out alignments: HG `0.999918`, FG `0.999063`

Package-local MATLAB version, timestamps, diagnostics, and acceptance records
are stored in the final MAT and captured logs. `SHA256SUMS` is generated only
after source, data, outputs, and logs are frozen.
