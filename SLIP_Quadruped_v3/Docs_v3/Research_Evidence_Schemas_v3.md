# Research evidence schemas and refresh

The schemas use JSON Schema draft 2020-12. They distinguish recorded observations from accepted scientific claims. `null` means the summary does not contain a measurement; it does not mean zero or a passed check. The coordinate/version authority remains `1_Dynamic_Frameworks/Schema_v3/QuadrupedSchema_v3.m`, with `quadruped-state-v3.1`, `quadruped-parameter-v3.1`, fourteen physical coordinates, four separate contact modes and ten physical parameters.

- `Research_v3/schemas/ancestry_graph.schema.json` describes model/parameter identities, typed nodes and edges, origin, isotropy assessment, regularity, evidence references and connectivity counts. `type` records the actual evidence category and `intended_type` records the hypothesis. An unresolved edge is a numerical candidate and cannot count as validated connectivity.
- `Research_v3/schemas/solutions.schema.json` describes the compact comparison/benchmark index. It includes provenance, complete initial state/mode when available, section, primitive-period diagnostic, drift/speed, event word/log, cluster/flight diagnostics, gait, symmetry residuals, physical margins, settings, raw-residual slots, derivative references, neighbors and parent certificates. Fields not exported into the source JSON remain explicit unknowns with authoritative MAT references.
- `Research_v3/schemas/replayed_solution_index.schema.json` describes `runs/full/solution_index.json`, produced by `ExportResearchEvidence_v3`. It retains complete initial coordinates/modes, physical parameters, physical/section charts, event and cluster logs, classification, measured margins and raw complete-state replay closure, settings, origin and artifact neighbors. Full primary trajectories and detailed derivative data remain in the referenced MAT artifacts. Its `parent_edge_certificate` is a graph reference; that reference grants no certificate by itself.

`Research_v3/generate_research_index.py` reads saved JSON and writes confined indexes. It runs no integration, correction or discovery. It reads the current restricted attachment status from `pip_pk_local.json` every time; it never converts the earlier exploratory support label into an unrestricted network certificate. MATLAB singleton struct arrays and empty arrays are normalized explicitly. File references used for production artifacts must resolve within v3.

Run from the repository root:

```sh
python3 SLIP_Quadruped_v3/Research_v3/generate_research_index.py --config full
python3 SLIP_Quadruped_v3/Research_v3/generate_family_reports.py
```

The indexer uses Python 3 and `jsonschema` for schema validation. The installed validator version and the actual validated counts/source checksums are written to `Research_v3/graph/validation.json`. `--validate-only` validates a newly constructed snapshot without changing outputs. The semantic checks additionally enforce unique IDs, valid edge/node/solution references, fixed model identity, absence of provisional connectivity claims and confined artifact paths. Schema success validates serialization and the explicit claim policy; it does not establish mathematical regularity or physical correctness.

`Research_v3/graph/index.json` is the authoritative typed graph. `ancestry_graph.json` is an identical small compatibility copy. Per-edge directories contain compact evidence records and references, not copied trajectories. P1/P2 study indexes retain imported-seed continuation and parent-only work as separate origins. An imported replay, a restricted attachment and a nonsmooth boundary cannot be interchanged to fill a missing regular edge.

Refresh both indexers after final replay/continuation/local stages. Their source fingerprints and stage statuses identify the snapshot used; a running stage remains incomplete. The final strongest scientific claim must be made from the completed certificates, not from an index filename or a descriptive gait label.
