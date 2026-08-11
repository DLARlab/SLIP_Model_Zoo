# Artifact and provenance schema

This document defines the storage contract for a new Floquet-v2 workflow.
The configuration schema is `floquet-workflow-config-v2`; its artifact layout
is `numbered-artifacts-v1`.

## Canonical output tree

```text
<workflow-output>/
  workflow_config.mat
  artifacts/
    01_discovery/
      floquet_analysis.mat
      candidate_inventory.csv
      rejected_points.csv
      rejected_intervals.csv
    02_refinement/
      refined_candidates.mat
      refinement_summary.csv
    03_seed_search/
      daughter_seed_search.mat
      daughter_seed_attempts.csv
    04_daughter_branches/
      inventory.mat
      inventory.csv
      <candidate>/<ray>/branch.mat
    05_validation/
      validation_report.mat
      validation_summary.csv
  checkpoints/
    floquet_scan_checkpoint.mat
    daughter_continuation_checkpoint.mat
  views/
  logs/
```

`views/` and `logs/` are optional. Numerical stages do not read publication
plots, GUI caches, or text logs as scientific inputs.

## Configuration contract

`workflow_config.mat` contains the scalar variable `config` and normally a
creation/migration metadata struct. Core fields include:

| Field | Meaning |
| --- | --- |
| `SchemaVersion` | Exactly `floquet-workflow-config-v2`. |
| `ArtifactLayoutVersion` | Exactly `numbered-artifacts-v1`. |
| `ExperimentRoot` | Root that owns the numbered artifact tree. |
| `FloquetRoot` | Optional bootstrap location of this implementation. |
| `ParentBranchFile` | Canonical parent MAT path. |
| `ExpectedParentSHA256` | Frozen digest of the complete parent input. |
| `AnalysisOptions` | Full-parent FDM, tracking, detector, and checkpoint options. |
| `Selection` | Explicit Stage-1 candidate confirmation. |
| `Refinement` | Critical-orbit and repeated-group configuration. |
| `BranchSwitch` | Direction resolver, amplitudes, signs, predictor, and corrector configuration. |
| `Continuation` | Explicit Stage-3 ray plan, options, and checkpoint policy. |
| `Validation` | Stage-5-only references and independent validator. |
| `Directories`, `Files` | Canonical v2 paths derived from `ExperimentRoot`. |

`floquet.workflow.create` fingerprints the parent before saving this config.
`floquet.workflow.load` accepts only a scalar config struct or a MAT file
containing scalar `config`; it does not execute a selected MATLAB script.
`workflow_config.mat` is configuration and provenance only. It is never a
numerical result and it must not contain copies of stage reports.

Candidate and ray confirmation APIs return updated in-memory configs. They do
not silently rewrite an input MAT file. This avoids an implicit mutation of an
audited workflow snapshot.

## Stage authority and variables

| Stage | MAT file | Canonical variable | Purpose |
| ---: | --- | --- | --- |
| 1 | `floquet_analysis.mat` | `analysis` | Reduced-map FDMs, accepted/rejected masks, topology intervals, tracked spectra, candidates, options, and provenance. |
| 2 | `refined_candidates.mat` | `refinementReport` | Corrected critical orbits, refined spectra/subspaces, readiness, failures, and Stage-1 handoff. |
| 3 | `daughter_seed_search.mat` | `seedReport` | Resolved directions, complete predictors, nonlinear corrections, multi-amplitude ray evidence, and Stage-2 handoff. |
| 4 | `inventory.mat` | `daughterReport` | Confirmed ray plan, compact continuation records, per-ray output identities, and Stage-3 handoff. |
| 5 | `validation_report.mat` | `validationReport` | Generic continuation validation, optional held-out results, and Stage-4 handoff. |

These five MAT files are the sole numerical authorities in a new generic
workflow. The exact `config.Files` contract also names their derived CSV
views, the Stage-4 ray directory, and the Stage-4 checkpoint; it has no field
for a combined experiment-result MAT. A combined report, GUI cache, or
publication bundle may be written beneath `views/`, but no later stage may
read it and it cannot enter the SHA-linked authority chain.

The main Stage-1 analysis has version `floquet-branch-analysis-v2` and
provenance schema `floquet-provenance-v2`. Full scientific authority requires:

- the canonical reduced-Poincare algorithm;
- the canonical production evaluator identity;
- parent-only inputs;
- exact ordered full-parent coverage; and
- a compatible implementation manifest.

A subset scan or explicitly injected evaluator may produce useful diagnostics,
but its provenance prevents it from entering the standardized scientific
artifact chain as production discovery.

## Upstream lineage

Every downstream MAT artifact names and hashes its immediate source:

- Stage 2 records the canonical Stage-1 file and SHA-256;
- Stage 3 records the canonical Stage-2 file and SHA-256;
- Stage 4 records the canonical Stage-3 file and SHA-256; and
- Stage 5 records the canonical Stage-4 file and SHA-256.

The chain validator reconstructs the complete ancestry, including the parent
branch digest. Replacing or editing an upstream file makes the downstream
artifact stale. `floquet.workflow.inspect` reports that state as invalid
instead of loading the downstream report as current evidence.

Callback and held-out-reference implementations are also fingerprinted where
they affect a scientific claim. Stage 5 verifies reference independence from
the parent, upstream artifacts, and generated daughter files.

## CSV audit views

CSV files are flat, derived views intended for inspection, plotting, and
manual review. Later stages never read them as numerical authority.

The standard tables are:

- `candidate_inventory.csv`: persistent crossing candidates and their stable
  IDs;
- `rejected_points.csv`: rejected FDM evaluations and reasons;
- `rejected_intervals.csv`: gaps, topology changes, and other unusable
  adjacency intervals;
- `refinement_summary.csv`: one row per confirmed critical candidate;
- `daughter_seed_attempts.csv`: signed, multi-amplitude predictor/corrector
  attempts;
- `inventory.csv`: one row per selected continuation ray; and
- `validation_summary.csv`: generic and held-out validation summary.

If a CSV and its MAT source disagree, the MAT artifact governs and the CSV
must be regenerated.

## Per-ray branch files

Stage 4 saves each selected ray beneath a sanitized candidate/ray path:

```text
artifacts/04_daughter_branches/<candidate>/<ray>/branch.mat
```

Each file contains the continued `results` matrix and its `info` structure.
The inventory stores compact quality and provenance rather than duplicating
large branch matrices by default. The exact file digest is recorded in the
ray record.

An accepted ray file means the configured continuation and numerical checks
passed. Physical gait identity and uniqueness remain Stage-5 claims.

## Checkpoints

Checkpoints are restart state, not completed scientific artifacts.

The Stage-1 checkpoint uses schema `floquet-branch-checkpoint-v2` and stores
per-point raw computation state. Resume checks source and numeric branch
digests, branch selection, reduced dimension, evaluator identity, resolved
FDM options, MATLAB/implementation fingerprints, and schema. Tracking and
detection are rerun after scanning completes.

The Stage-4 checkpoint binds the exact Stage-3 artifact digest, ordered ray
selection, continuation options, and completed per-ray files. Resume occurs
only at controlled ray boundaries.

V1 checkpoints are deliberately nonresumable. Their implementation identity
and path ownership are not interchangeable with clean-root v2.

## Derived visualization data

The canonical Stage-1 MAT file is sufficient for the GUI. A separate
`FloquetData` cache is optional:

```matlab
[FloquetData,outputFile] = floquet.io.exportDataset(analysis,options);
```

This projection may contain branch indices, continuation coordinates, section
states, solved event times, Floquet matrices, tracked eigenpairs, distance
indicators, rejection masks, and candidate annotations. It must not rerun FDM
or redetect bifurcations.

The former one-step diagnostic generator has been retired because it repeated
scientific work already owned by `floquet.analyzeBranch`. New viewer data must
follow `analyzeBranch -> exportDataset -> loadDataset`; the export step never
recomputes matrices, tracking, or candidates.

`floquet.io.trackDisplayMultipliers` remains a narrowly scoped GUI/export
utility. It supplies deterministic plot ordering, phase alignment, and
conjugate-pair color metadata only. It never calls the bifurcation detector,
never replaces `analysis.tracks`, and can neither create candidates nor grant
scientific authority. The authoritative tracks and detector report copied
into a schema-1.1 view always come from `floquet.analyzeBranch`.

The nine files under `reference_data/viewer_datasets` are frozen,
schema-validated 1.0 viewer datasets computed with the production
reduced-Poincare evaluator. Their stored matrices, event-time solutions,
accepted masks, and eigendata remain readable without a rerun, but schema 1.0
is a read-only compatibility boundary: no current writer emits it, the loader
always normalizes it to non-authoritative diagnostic status, and it is not a
substitute for a canonical v2 analysis. Canonical detection, refinement,
prediction, correction, continuation, and validation read the numbered
workflow artifacts.

## Reference-experiment artifacts

Directories under `reference_experiments` use the numbered stage organization
so that evidence is easy to locate and compare. They remain specialized,
targeted retrospective packages. Their configuration is stored as
`reference_experiment_config.mat` and declares the workflow-compatibility
boundary.

These packages may contain local scan windows, symmetry-adapted direction
resolvers, historical daughter data, and experiment-specific validators. They
are not generic `floquet-workflow-config-v2` chains, are not automatically
resumable through `floquet.workflow.runStage`, and must not be presented as
blind discovery from an unlabeled parent.

Their Stage-5 `validation_report.mat` uses schema
`floquet-reference-validation-index-v3`. It is intentionally a compact index:
it retains acceptance decisions, validation metrics, claim boundaries, and
SHA-256 identities for the authoritative specialized result and the four
upstream stage projections. It does not embed a second copy of discovery,
refinement, seed-search, or daughter-ray payloads. This reference-only rule
does not change the canonical generic Stage-5 contract described above.

Reference projections below the MATLAB v7 size limit are saved as compressed
v7 MAT files. Canonical generic workflow artifacts continue to use the atomic
writer and may use v7.3 when their size or access requirements justify it.

## Immutability and overwrite

Canonical artifacts are immutable by default. A preflight check prevents a
stage from overwriting its parent input, an upstream artifact, a configured
reference, or a generated daughter file. When overwrite is explicitly
enabled, the caller is responsible for treating all downstream artifacts as
stale and regenerating the chain.

MAT files are installed through the workflow's atomic artifact writer. Logs
and plots do not authorize a numerical result; reproducibility rests on the
canonical inputs, options, evaluator identities, hashes, and MATLAB artifacts.

## Legacy read policy

A missing workflow schema is treated as legacy v1. V1 paths remain exactly as
stored and are never silently rebased into the numbered tree.

- A nonempty v1 chain is read-only historical evidence.
- Any v1 checkpoint makes the workflow nonresumable in v2.
- An empty v1 configuration may be explicitly converted with
  `floquet.workflow.migrate`.
- A nonempty v1 chain must be preserved; recomputation starts in a new v2
  output root.

This fail-closed policy prevents a current workflow from attaching v2
authority to artifacts generated by a different implementation contract.
