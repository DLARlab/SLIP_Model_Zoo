# Reference data

`viewer_datasets/` contains nine precomputed datasets used by the analysis
viewer and GUI regression tests. Every file validates as the supported
schema-1.0 `FloquetData` layout and records the production
`reduced-poincare-fdm-v2` evaluator. The reduced Poincare matrices, internally
solved event times, accepted masks, and eigendata are reusable, so the clean
directory rename does not require rerunning those computations. The catalog
is stored as compressed MATLAB v7 files; all nine files were round-trip
checked for exact `isequaln` equality during the storage migration.

These files are convenient derived visualization data, not canonical
scientific artifacts. In particular, their saved screening annotations
predate the canonical analysis/export split and do not establish a persistent
bifurcation. The five-stage workflow never uses this catalog to detect,
refine, predict, correct, continue, or validate a bifurcation.

For a new branch, create a workflow with `floquet.workflow.create` and keep its
authoritative outputs under that workflow's numbered `artifacts/` tree. The
GUI can load the canonical Stage-1 analysis directly. Export an optional
viewer dataset only when repeated browsing or interchange justifies the
additional derived file.
