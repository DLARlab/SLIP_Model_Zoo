# Run metadata

- Experiment: pronking multi-gait Floquet-v2 bifurcation
- Primary input: `data/pronking_branch/PK_20_2.mat`
- Held-out inputs: `data/held_out_daughter_branches/BD1_20_2_{BE,BG,FE,FG,HE,HG}.mat`
- MATLAB: R2025b Update 5, Student License
- Repository commit at packaging: `f2e6859454afdba372decd40daf3a9cd61bb741c`
- Dynamics core modified: no
- Reduced Poincare dimension: 12
- Critical continuation coordinate: initial horizontal speed `dx = X(1)`
- Finite-difference base magnitude: `5e-7`
- Finite-difference factors: `[8 4 2 1]`
- Critical sample columns: `194:198`
- Nonlinear correction radii: `[1e-2 5e-3]`
- Search seed provenance: deterministic symmetry grid, no daughter data
- Final status: verified
- Corrected bifurcation coordinate: `4.43406193516227`
- Persistent class counts `[B F H]`: `[2 2 2]`
- Packaged regression run: 2026-08-05 10:06 EDT
- Packaged regression result: 21 passed, 0 failed, 0 incomplete
- Packaged full experiment: 2026-08-05 10:07--10:13 EDT
- Independent replay: 2026-08-05 10:14 EDT
- Independent replay result: 12/12 corrected orbits accepted

The current repository commit does not include the newly created untracked
Floquet-v2 source. `MANIFEST.md` records the packaged source/input inventory;
the final packaging run log records the exact executed code state and output.

## Commands

```matlab
report = main_Test_PronkingMultiGaitBifurcation();
audit = main_HandValidate_PronkingBifurcation();
```

Captured transcripts:

- `logs/pronking_tests.log`
- `logs/pronking_full_experiment.log`
- `logs/pronking_hand_validation.log`

`SHA256SUMS` fingerprints the packaged source, inputs, outputs, and logs.
