# Floquet-v2 experiment packages

Experiment packages use the same reproducibility layout:

```text
<experiment>/
  README.md
  data/
  results/final/
  results/intermediate/
  logs/
  tests/
```

Shared return-map, refinement, prediction, correction, and utility functions
remain one level above `experiments/`; they are not copied into a package.
Each package resolves those shared paths through one experiment-local path
helper and keeps all configuration in one registry or main entry point.

The `data/` substructure may differ when the scientific roles require it. A
single-parent experiment can separate parent and held-out daughters directly.
A multi-stage experiment in which one branch is a daughter in one case and a
parent in another stores each MAT file once in a branch library; its registry
declares the role per transition. This avoids duplicate inputs and ambiguous
hash provenance.

Current packages:

- `pronking_multigait_bifurcation`: one pronking parent and six held-out gait
  rays at a multiple +1 point.
- `roadmap_bifurcation_robustness`: four parent experiments and six targeted
  secondary pair-symmetry-breaking +1 transitions in one consolidated run.
- `BG_half_bounding_bifurcation`: independent BG-parent reproduction of
  BG -> HG and BG -> FG.
- `BE_half_bounding_bifurcation`: independent BE-parent reproduction of
  BE -> FE and BE -> HE.
- `FG_GG_bifurcation`: independent FG-parent reproduction of FG -> GG.
- `GE_HE_bifurcation`: independent HE-parent reproduction of HE -> GE. The
  folder keeps the requested pair label; the numerical direction is never
  reversed.

The four single-parent packages own separate copies of only the branches
needed for their test. Their supplied MAT/CSV/figure artifacts are frozen,
path-local projections of the validated consolidated reference, with Stage B
rerun against each local held-out daughter. Each package's `main_Test_*`
entry point is the reproduction authority: it freshly recomputes Stage A
from the local parent, then performs held-out validation. The package README
contains the exact MATLAB commands, long-test environment variable, and
hand-replay command.

Reference results from the independent production reruns are:

| package | transition | refined `dx` | held-out direction alignment |
|---|---|---:|---:|
| `BG_half_bounding_bifurcation` | BG -> HG | 4.50616189521 | 0.999918 |
|  | BG -> FG | 5.64566295496 | 0.999063 |
| `BE_half_bounding_bifurcation` | BE -> FE | 4.83363821441 | 1.000000 |
|  | BE -> HE | 6.04807025559 | 0.999257 |
| `FG_GG_bifurcation` | FG -> GG | 5.91164917105 | 0.999791 |
| `GE_HE_bifurcation` | HE -> GE | 6.13622289546 | 0.999819 |
