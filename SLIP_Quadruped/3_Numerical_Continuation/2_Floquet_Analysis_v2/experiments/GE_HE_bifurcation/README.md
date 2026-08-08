# GE/HE bifurcation experiment (HE parent -> GE daughter)

The folder name `GE_HE_bifurcation` follows the requested label. The actual
and scientifically recorded direction is **HE parent -> GE daughter**:
hind-spread half-bounding with extended suspension (`HE`) loses its remaining
front left/right symmetry and attaches to galloping with extended suspension
(`GE`). The refined reference point is `dx = 6.13622289546`.

Stage A receives only the packaged HE parent. GE is loaded only in Stage B,
after the parent Floquet direction and signed nonlinear corrections are
frozen.

## Packaged-reference provenance

The supplied result artifacts are a frozen one-transition projection of the
verified combined six-transition roadmap run. Exporting selected the HE->GE
record and rebound saved branch paths and experiment provenance locally; it
did not recompute Stage-A finite differences, critical refinement, or branch
corrections. `main_Test_GEHEBifurcation` performs an independent package-local
dynamics recomputation and replaces the projected reference outputs.

## Layout

```text
GE_HE_bifurcation/
├── README.md, MANIFEST.md, RUN_METADATA.md, SHA256SUMS
├── GEHEExperimentPaths.m
├── main_Test_GEHEBifurcation.m
├── main_HandValidate_GEHEBifurcation.m
├── main_Refresh_GEHEReferenceArtifacts.m
├── data/parent_branch/BD1_20_2_HE.mat
├── data/held_out_daughter_branches/BD1_20_2_GE.mat
├── tests/
├── results/{intermediate,final}/
└── logs/
```

## Reproduce and audit

```matlab
experimentRoot = fullfile('SLIP_Quadruped','3_Numerical_Continuation', ...
    '2_Floquet_Analysis_v2','experiments','GE_HE_bifurcation');
addpath(experimentRoot);

report = main_Test_GEHEBifurcation();
assert(report.summary.accepted);
assert(strcmp(report.transitions.ID,'he_to_ge'));

replay = main_HandValidate_GEHEBifurcation();
assert(replay.accepted);
```

Use `main_Refresh_GEHEReferenceArtifacts()` only for derived validation and
presentation refreshes from a frozen parent computation.

```matlab
results = run(testsuite(fullfile(experimentRoot,'tests'), ...
    'IncludeSubfolders',true));
assert(~any([results.Failed]));
```

Set `SLIP_RUN_LONG_GEHE_PACKAGE_TESTS=1` for a temporary production rerun.
Verify the package with `shasum -a 256 -c SHA256SUMS`.

The package-local final MAT is authoritative. This is a targeted historical-window test,
not a blind global search. Shared numerical and dynamics functions are not
duplicated, and hybrid nonsmoothness remains a rejection condition.
