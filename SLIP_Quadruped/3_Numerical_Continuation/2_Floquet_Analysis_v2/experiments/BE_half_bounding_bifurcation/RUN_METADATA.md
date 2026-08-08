# Run metadata

- Experiment: BE half-bounding bifurcations
- Parent input: `data/parent_branch/BD1_20_2_BE.mat`
- Held-out daughters: FE and HE
- Transition IDs: `be_to_fe`, `be_to_he`
- Dynamics core modified: no
- Event timing solver: existing production v2 solver
- Floquet coordinates: 12 reduced apex-section states; no event times
- Finite-difference base magnitude: `5e-7`
- Finite-difference factors: `[8 4 2 1]`
- Parent scan columns: `25:29` and `57:61`
- Nonlinear correction radii: `[1e-2 5e-3]`, both signs
- Consolidated reference refined `dx`: `4.83363821441`, `6.04807025559`
- Expected exact nullity of `M-I`: 2 at each crossing
- Expected daughter labels: FE, HE
- Packaged artifact origin: two-transition projection of the verified
  combined six-transition reference run
- Export computation scope: saved records selected and paths rebound; Stage-A
  finite differences, critical refinement, and corrections not recomputed
- Independent recomputation command: `main_Test_BEHalfBoundingBifurcation()`
- Independent wrapper test (2026-08-05, MATLAB R2025b): 4 passed, 0 failed,
  0 incomplete in 697.5607 s; both parent and held-out stages accepted
- Independent rerun held-out alignments: FE `1.000000`, HE `0.999257`

Package-local MATLAB version, timestamps, diagnostics, and acceptance records
are stored in the final MAT and captured logs. Generate `SHA256SUMS` only after
all package artifacts are frozen.
