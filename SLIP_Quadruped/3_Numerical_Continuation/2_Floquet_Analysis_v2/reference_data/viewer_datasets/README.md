# Floquet viewer datasets

This directory is an optional central browsing cache for
`FloquetAnalysisGUI`. It is not the authority for an experiment and it is
not necessary to create a second GUI-specific MAT file for every branch.

`floquet.analyzeBranch` is the sole production discovery authority. The
canonical experiment-local artifact contains the reduced matrices, point and
interval validity, canonical multiplier tracks, persistent detector results,
and numerical provenance. Refinement and branch switching must read that
artifact, never a file in this directory.

For a standardized bifurcation experiment, persist one canonical full-branch
analysis under that workflow's `artifacts/01_discovery/` directory. The GUI
can read that result directly through `floquet.io.loadDataset`, or use a lossless
derived view created by `floquet.io.exportDataset`. This exporter does
not recompute matrices or rerun detection. Its output path must differ from
the canonical source. Reuse a central cache only after verifying the parent
content, resolved finite-difference options, tracker/detector configuration,
and algorithm/schema version.

The former one-step diagnostic dataset generator has been retired. New data
must be computed once by `floquet.analyzeBranch`, then optionally projected by
`floquet.io.exportDataset` and validated by `floquet.io.loadDataset`. This
removes the second branch-analysis implementation and keeps scientific
authority in the canonical Stage-1 artifact.

The nine current `*_floquet.mat` files were generated before the canonical
analysis/export split. They validate as schema-1.0 datasets, record the
production `reduced-poincare-fdm-v2` evaluator, and retain reduced Poincare
matrices, internally solved event times, accepted masks, and eigendata. Those
numerical fields remain reusable; moving the files into this neutrally named
catalog does not require a rerun. Their saved
`bifurcation_indicator` and candidate-count tables are screening annotations,
not verified bifurcations: those annotations came from a separate adjacent-
bracket path and lack all of the persistence, interval-topology, and `+1`
branch-tangent tests in `floquet.detectBifurcations`.

Schema 1.0 is retained only as a read boundary for these frozen files. No
current API writes it. The loader forces every schema-1.0 cache to
`scientific_authority=false`, even if historical metadata claimed otherwise.
All newly exported views use schema `1.1-analysis-view`.

The saved `source_file` values are historical provenance strings from the
pre-migration experiment layout. The loader does not dereference them; all
state, event-time, matrix, and eigendata required by the viewer are embedded
in each MAT file. Current branch copies live under the independent
`reference_experiments/*/data/` packages, so the catalog is not rewritten
merely to rebase those descriptive strings. The same numerical structures
have been losslessly resaved as compressed MATLAB v7 files: the catalog is
now approximately 27 MiB instead of 196 MiB. Equality was checked with
`isequaln` before each original file was replaced.

`SHA256SUMS` records the byte-level digest of every checked-in viewer
dataset. From this directory, run
`shasum -a 256 -c SHA256SUMS` after moving the catalog or before relying on
it for regression inspection.

`tests/gui/test_viewer_dataset_catalog.m` loads every catalog entry through
`floquet.io.loadDataset`, verifies its stored point/acceptance counts, and
confirms that schema-1.0 datasets remain explicitly diagnostic. Update that
contract test whenever a checked-in dataset is intentionally added, removed,
or regenerated.

Do not use a small `distance_plus_one`, `distance_minus_one`, or
`unit_circle_distance` value as proof of a bifurcation. Re-run or upgrade the
analysis through the canonical internal multiplier tracker plus
`floquet.detectBifurcations` before refinement or branch switching.

For a new branch:

1. run the complete parent-only `floquet.analyzeBranch` workflow and save its
   canonical artifact under the experiment;
2. inspect and freeze candidates from that artifact;
3. optionally open it directly in the GUI;
4. create a central derived cache only when repeated browsing, portability,
   or distribution justifies the additional file.
