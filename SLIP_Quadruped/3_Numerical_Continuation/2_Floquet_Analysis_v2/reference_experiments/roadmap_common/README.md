# Shared targeted-roadmap reference engine

This directory contains experiment-specific reusable code shared by four
retrospective reference packages:

- `BG_half_bounding_bifurcation`: BG -> HG and BG -> FG;
- `BE_half_bounding_bifurcation`: BE -> FE and BE -> HE;
- `FG_GG_bifurcation`: FG -> GG;
- `GE_HE_bifurcation`: HE -> GE.

It is not a fifth experiment, a public Floquet API, or a generic
`floquet.workflow.Session` implementation. New branch-wide workflows should
use `+floquet/+workflow`, not call this directory as a template.

## Ownership and information barrier

Every shared entry point requires an explicit experiment definition.
Each package owns one small `*ReferenceExperiment.m` declaration containing
its schema, ID, code, root, and nonempty transition list.
`RunRoadmapReferenceExperiment` validates that declaration and dispatches
`run`, `replay`, or `refresh`. `RoadmapRobustnessPaths(experimentRoot)` anchors
shared code here while routing all package-owned inputs and outputs beneath
that root. There is no fallback to a combined branch library.

```text
<reference-package>/
├── data/
│   ├── parent_branch/
│   └── held_out_daughter_branches/
├── artifacts/
│   ├── 01_discovery/
│   ├── 02_refinement/
│   ├── 03_seed_search/
│   ├── 04_daughter_branches/
│   └── 05_validation/
├── checkpoints/
├── views/
└── logs/                    optional local transcripts, never frozen
```

For each transition, Stage A opens its declared parent only. Its designated
daughter is opened in Stage B after the parent prediction and correction
records are frozen. A branch file may still be the declared parent of a
different transition; that role is explicit in the case table.

## What the engine writes

`main_Test_RoadmapBifurcationRobustness` writes the authoritative specialized
report under `artifacts/05_validation/`, a completed parent-only report under
`artifacts/03_seed_search/`, and standardized reference projections in all
five numbered stages. `WriteRoadmapStageArtifacts` also writes
`reference_experiment_config.mat` with:

- schema `floquet-reference-experiment-config-v2`;
- layout `numbered-artifacts-v1`;
- experiment type `targeted-retrospective-reference`;
- workflow compatibility `not-resumable-by-floquet.workflow.Session`.

Stages 1--4 deliberately use `floquet-reference-*-v2` schemas. Stage 5 uses
the compact `floquet-reference-validation-index-v3` schema: it records
validation conclusions and hashes the authoritative specialized result and
upstream projections without embedding those payloads again. Similar
filenames do not make these files interchangeable with generic workflow artifacts.
Reference projections are stored as compressed MATLAB v7 files; the complete
specialized result remains the authority.
Interrupted parent-only recovery belongs under `checkpoints/`; completed
reference evidence belongs under `artifacts/`.

## Driver

The public reference-package operation is:

```matlab
result = RunRoadmapReferenceExperiment(definition,action,options);
```

where `action` is `run`, `replay`, or `refresh`. Internally:

- `main_Test_RoadmapBifurcationRobustness` performs the targeted numerical
  calculation and held-out validation;
- `main_HandValidate_RoadmapBifurcations` independently replays a saved
  result; and
- `main_Refresh_RoadmapReferenceArtifacts` refreshes derived validation and
  PNG/CSV/Markdown outputs without claiming to rerun Stage A.

Use the package-local definition, which pins the experiment root and allowed
transition IDs. Run and replay disable logging by default; an explicit
`LogFile` creates a local diagnostic transcript that is never package
authority. MATLAB FIG files are not frozen; portable plots are PNG.

The centralized tests are under `../../tests/production/`;
`test_roadmap_bifurcation_robustness.m` covers the shared engine. Set
`SLIP_RUN_LONG_ROADMAP_TESTS=1` for the gated production recomputation.

## Scientific scope

The engine evaluates predeclared historical windows on folded parent branches.
It is useful reference evidence for finite-difference convergence, critical
refinement, symmetry-mode selection, signed correction persistence, and
held-out alignment. It does not claim blind whole-branch discovery, generic
checkpoint resumption, or global daughter continuation.
