# Compact branch storage

Large working files are allowed when necessary to finish a branch search. A
storage-size target must not reject an otherwise admitted root or stop
continuation. After search, condense retained results and measure their size
against the original corresponding whole v2 branch file; the five-times target
is separate from the diagnostic comparison with an equal-point-count v2 subset.

The current continuation authority uses the full schema2 representation
described below. The additive schema4 essential export has an explicit smaller
retention contract: exact scientific values and typed connectivity are retained,
while dense trajectories and runtime diagnostic tapes require fresh replay or
remain only in the raw working store. It does not reproduce a complete runtime
object or establish a new admission. Both BE0092 and the full 465-record PK snapshot passed native export
projection qualification. Public cold-runtime qualification remains unattempted. See [the storage report](Storage_Reduction_20261030.md)
for the actual qualification boundary. Keep the raw store and current frontier
journal as resume authority while the search is unfinished.

After each closed run, retain its concise actual outcome, current continuation
authority and essential numerical evidence. Remove consumed stages, caches,
test fixtures and duplicate diagnostics after their last consumer finishes.
Do not make a new exhaustive archive or full-journal return copy for every run.
Keep the core method sources and enough configuration to repeat the method;
retired private execution wrappers need not remain byte-for-byte rerunnable.

`BranchSolutionFile_v3` stores one or more ordered components in one compressed v7 MAT
file. Each append adds `solution_000001`, `report_000001`, and so on. A small
`branch_index` contains cell arrays of point and edge rows. Reports and metadata
contain plain numeric, logical, character, string, struct or cell data; the caller
may compact a report before passing it to storage.

The index storage version is `BranchSolutionFile_v3:2`. Each variable must fit
the v7 limit of 2 GB. The file can contain multiple independently loaded solution
and report variables; storage does not use HDF5 or slice individual variables.
Version 1 experimental v7.3 stores are refused rather than appended or converted.

```matlab
BranchSolutionFile_v3.initialize(file, struct('campaign', 'C1'));
point = struct('component_identity', 'PK_upper_tail', 'classification', 'PK', ...
    'nativeE', E, 'signedmeanU', signedU, 'provenance', struct('source', sourceRef));
[branchIndex, pointIndex] = BranchSolutionFile_v3.append(file, orbit, report, point);
branchIndex = BranchSolutionFile_v3.index(file);
[orbit, report, pointMetadata] = BranchSolutionFile_v3.loadSolution(file, pointIndex);
```

`initialize` returns the new index and refuses an existing destination. `append`
returns the complete updated index and the global point index. `index` reads only
the index and variable directory. `loadSolution` loads only the selected solution;
it also loads that point's report when a second output is requested. Its third
output is the original point metadata.

Every point requires `component_identity`, `classification`, `nativeE`,
`signedmeanU`, and scalar-struct `provenance`. Energy and signed mean speed are
supplied by the caller; `NaN` records an unknown value. Optional `order` must
increase within the component. Without it, storage uses the previous component
order plus one. Append order is bookkeeping and does not establish a branch edge.

To record an edge, supply both `edge_enabled=true` and `edge_from`, the global
index of an earlier point in the same component. Other appends add no edge.
Component identity, classification and provenance are recorded as supplied;
storage performs no scientific classification, admission or computation.

An appended solution must be one native `HybridOrbit_v3`. Nested native objects
may be `HybridOrbit_v3` or `Trajectory_v3`. Their complete public properties are
saved without modification and compared recursively after readback, including
class, shape, struct fields, cell contents, sparse/real storage and values. Object
IDs do not replace this comparison. Foreign objects, function handles and cyclic
or excessively nested values are refused rather than silently stripped.

One writer owns a file. Append copies the current file to a unique stage in the
same directory, saves the new point and index, and verifies readback before an
atomic rename replaces the live file. Failure removes the stage and leaves the
live file unchanged before commit. A filesystem that cannot perform the atomic
move is refused. There is no persistent file per point. This full-file copy trades
write cost for a simple transaction boundary; it is intended for serialized
campaign checkpoints rather than concurrent writers.


As of 31 October 2026, additive BE0092 (2 occurrences, 27,420 bytes) and
merged PK (465 occurrences, 1,740,487 bytes) snapshots passed native whole-store
index and two independent thin-load projection checks. The PK five-times
original-v2 target remains false. Working raw files remain admitted continuation
authority. The GUI/range/recent utility sources were installed and read back;
their combined native cold-runtime qualification was unattempted. A compact
record does not provide dense trajectories or raw-resume runtime objects.
See Storage_Reduction_20261030.md for the independently qualified current FS
state and preserved original failed exporter/publisher outcomes.
