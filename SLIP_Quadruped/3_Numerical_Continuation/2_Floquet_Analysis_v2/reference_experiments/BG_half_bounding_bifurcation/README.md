# BG half-bounding reference experiment

This targeted retrospective package reproduces two symmetry-breaking
attachments of bounding with gathered suspension (`BG`):

| transition | broken pair | held-out daughter | refined `dx` |
| --- | --- | --- | ---: |
| BG -> HG | hind left/right | hind-spread half-bound | 4.50616110936 |
| BG -> FG | front left/right | front-spread half-bound | 5.64566295496 |

Stage A opens only `data/parent_branch/BD1_20_2_BG.mat`, using parent
windows `37:41` and `64:68`. Stage B opens HG and FG only after the parent
Floquet direction, timing lift, and signed nonlinear corrections have been
frozen. This is reference evidence for known local windows, not blind
branch-wide discovery.

## Numerical contract

- Reduced apex-section dimension: 12 state coordinates; event times are
  solved by the existing production solver but are not Floquet states.
- Central-FDM base magnitude: `5e-7`; factors: `[8 4 2 1]`.
- Correction radii: `[1e-2 5e-3]`, evaluated in both signs.
- Expected numerical nullity of `M-I`: 2 at each crossing (parent tangent
  plus one additional symmetry-breaking direction).
- Dynamics core modified: no.

## Package contents and authority

`BGHalfBoundingReferenceExperiment.m` is the only package-local executable
definition. It declares the package identity, root, and transition IDs.
`../roadmap_common/RunRoadmapReferenceExperiment.m` owns run, replay, and
refresh routing; the remaining numerical implementation is shared in
`../roadmap_common/` and reusable production code is in `../../+floquet/`.

Inputs are:

- `data/parent_branch/BD1_20_2_BG.mat` — sole Stage-A parent;
- `data/held_out_daughter_branches/BD1_20_2_HG.mat` — Stage-B validation;
- `data/held_out_daughter_branches/BD1_20_2_FG.mat` — Stage-B validation.

Artifacts are organized as:

```text
artifacts/
  01_discovery/          floquet_analysis.mat and audit CSV
  02_refinement/         refined_candidates.mat and audit CSV
  03_seed_search/        parent predictions, corrections, and audit CSV
  04_daughter_branches/  corrected-ray inventory and audit CSV
  05_validation/         authority, compact index, CSV, Markdown, PNG
checkpoints/              interrupted-run recovery only
views/                    optional derived user views
logs/                     optional local transcripts, never frozen
```

The retrospective exception is
`artifacts/05_validation/roadmap_bifurcation_robustness_results.mat`, the
authoritative specialized result. The adjacent `validation_report.mat` is a
compact `floquet-reference-validation-index-v3` record that hashes the
authority and upstream projections; it is not another complete report.
These projections are not resumable generic `floquet.workflow.Session`
artifacts. The generated `reference_experiment_config.mat` declares this
boundary explicitly.

## Run, replay, and refresh

From the repository root:

```matlab
floquetRoot = fullfile('SLIP_Quadruped','3_Numerical_Continuation', ...
    '2_Floquet_Analysis_v2');
referenceRoot = fullfile(floquetRoot,'reference_experiments');
experimentRoot = fullfile(referenceRoot,'BG_half_bounding_bifurcation');
commonRoot = fullfile(referenceRoot,'roadmap_common');
addpath(floquetRoot,commonRoot,experimentRoot);

definition = BGHalfBoundingReferenceExperiment();
report = RunRoadmapReferenceExperiment(definition,'run');
assert(report.summary.accepted);
assert(isequal({report.transitions.ID},{'bg_to_hg','bg_to_fg'}));

replay = RunRoadmapReferenceExperiment(definition,'replay');
assert(replay.accepted);

% Derived outputs only; does not rerun Stage A.
refreshed = RunRoadmapReferenceExperiment(definition,'refresh');
```

Run and replay logging is disabled by default. Supply an explicit `LogFile`
option only when a local transcript is useful; logs and MATLAB FIG files are
not package evidence. Portable plots are PNG.

The centralized regression is
`../../tests/production/test_roadmap_bifurcation_robustness.m`. Set
`SLIP_RUN_LONG_ROADMAP_TESTS=1` before MATLAB startup to include its gated
production subset recomputation.

## Frozen provenance and integrity

The historical independent run on 2026-08-05 used MATLAB R2025b and reported
4 passed, 0 failed, 0 incomplete in 654.4491 s, with held-out alignments HG
`0.999918` and FG `0.999063`. Generated MAT files carry the provenance of any
later refresh or recomputation.

`SHA256SUMS` fingerprints package-owned source, inputs, numerical artifacts, CSV,
Markdown, PNG, configuration, and this README. It excludes optional logs,
MATLAB FIG files, and itself. Regenerate it only after intentionally freezing
a complete package record.

Grazing, changed event topology, simultaneous impacts, folded-coordinate
ambiguity outside the declared windows, and global daughter continuation are
outside this package's claim.
