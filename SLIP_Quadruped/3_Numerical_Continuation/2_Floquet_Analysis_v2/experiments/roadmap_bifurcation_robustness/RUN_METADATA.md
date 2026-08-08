# Reference-run metadata

- Repository: `SLIP_Model_Zoo`
- Experiment version: `roadmap-bifurcation-robustness-v1`
- Dynamics core modified: **no**
- Event timing solver: existing production v2 solver
- Floquet dimension: 12 reduced apex-section states
- Event-time Floquet coordinates: **none**
- Parent experiments: BG, BE, FG, HE
- Targeted transitions: BG->HG, BG->FG, BE->FE, BE->HE, FG->GG, HE->GE
- Window provenance: retrospective calibration from the saved roadmap
- Isolation boundary: each numerical transition analysis receives only its
  parent array; its specified daughter is passed only to held-out validation
- Shared-file caveat: FG and HE are daughters in early transitions and parents
  in later transitions, so isolation is per transition rather than global file
  access across the entire six-case MATLAB process
- Reference-run status: 6/6 parent predictions and 6/6 held-out validations
  accepted
- Refined coordinates: 4.50616189521, 5.64566295496, 4.83363821441,
  6.04807025559, 5.91164917105, 6.13622289546
- Finite-difference convergence: maximum `1.889e-7`
- Forward/backward derivative mismatch: maximum `2.429e-4`
- Event timing residual: maximum `3.431e-11`
- Held-out Floquet/daughter alignment: minimum `0.999063`
- Independent hand replay: 6/6 accepted; maximum corrected canonical
  residual `1.217e-13`
- Roadmap MATLAB test suite: 13 passed, 0 failed, 0 incomplete (`352.5 s` in
  the packaged final log; independently repeated at `366.6 s`)
- Pronking cross-regression: 21 passed, 0 failed, 0 incomplete (`9.87 s`)
- Package integrity audit: report, frozen parent file, six per-case MAT files,
  both summary CSVs, and all six hand-replay rows loaded and agreed

The exact MATLAB version, timestamps, numerical options, refined coordinates,
convergence diagnostics, predictor/corrector records, and held-out metrics are
stored in `results/final/roadmap_bifurcation_robustness_results.mat`.
