# C1 results and reusable continuation

The current PK result contains two known numerical components: the long family
(621 stored occurrences) and short family (524). Their typed graph contains
1,042 physical continuation edges, 96 exact-record relations and 13 finite
numerical meeting relations. These relations have different meanings; file
order and numerical proximity are not additional physical edges.

The [final PK report](Audits/PK15h_20261104_Final_Report.md) records the finite
scope, P1 comparisons, studied boundaries and remaining mathematical limits.
The result is not a proof of global PK uniqueness or exhaustion. Other C1
gaits and their complete bifurcation network remain unresolved.

## Current working components

The [current component folder](Compact_Exports_20261030/PK15h_20261104_FinalCurrentWorkingCoreSet01)
contains one MAT file per connected component, with individual solutions
available through the public reader. The combined files are about 2.35 MB.
The matrix layout is 29-by-N: initial state14, stride14 and period.

```matlab
% v3 is the absolute SLIP_Quadruped_v3 directory.
addpath(v3); V3AddPaths_v3(v3);
c1 = fullfile(v3,'Research_v3','C1');
folder = fullfile(c1,'Compact_Exports_20261030', ...
    'PK15h_20261104_FinalCurrentWorkingCoreSet01');
file = fullfile(folder,'C1_PK_Component_0001_WorkingCore29.mat');
sha = 'f76a21ac424bab9d60bdda484c5ac217dcc4769ba7c3659acf33df5f785728db';
[orbit,report,point,view] = LoadC1WorkingSolutionCore29_v3(file,1,sha);
```

Component 2 is `C1_PK_Component_0002_WorkingCore29.mat`, SHA256
`2d26534db60084774e4e1f72086d3a895cef0a53aeb015f6ef3e383e99f00a1f`.
Loading reconstructs a trajectory-free native seed and historical decisions;
it performs no new admission. Draw branch lines from physical edges only.
The two files retain the necessary working-size exception; the original
five-times-v2 publication size target remains unmet.

## Historical partial components

[Results/Partial_Components](Results/Partial_Components) contains 43 compact
MAT files, totaling 4.44 MB. Its [catalog](Results/Partial_Components/catalog.json)
maps every file to the original source and the verified storage receipt.
`Isolated_Records.mat` is a separate unconnected record catalog. These files
retain partial historical results; their names do not establish completed
branches or bifurcations.

```matlab
file = fullfile(c1,'Results','Partial_Components','C1_BE_Component_0002.mat');
[orbit,report,metadata] = EssentialBranchSolutionFile_v3.loadSolution(file,1);
```

The retained role sidecar distinguishes explicit wrapper/nonedge markers from
saved native-report acceptance. Forty-two historical stored role labels differ
from those markers; the sidecar preserves the distinction without changing
admission or graph flags. Use physical edges for branch lines and treat
controls and isolated records separately.

## Searching another branch

Use [ContinuePeriodicBranch_v3](../../3_Numerical_Continuation/2_Continuation_Algorithms/ContinuePeriodicBranch_v3.m)
and the [short continuation guide](../../Docs_v3/Reusable_Branch_Continuation_v3.md).
The reusable function owns adaptive prediction, coupled state/free-energy root
correction, original all-nine admission, physical capture, persistence and
resume. Select an appropriate supported chart and admitted directed pair;
a branch filename or a P1 template does not supply that evidence.

H means hind-leg spread with synchronized fore legs. F means fore-leg spread
with synchronized hind legs. Root correction uses root-newton only. The
marked-apex stop is strictly below half the resting leg length.

## Retention

The November 5 cleanup retires obsolete recovery archives, private execution
scripts, repeated checkpoints and dense historical diagnostics after retaining
current solutions and essential numerical projections. Historical paths inside
old reports can identify retired payloads. Their hashes are provenance, not a
promise that every original run can be replayed byte-for-byte.

[The final cleanup ledger](Audits/V3_Final_Cleanup_Ledger_20261105.json)
records the storage and private-workflow retirements, including exact removed
paths and hashes. No legacy v2 file or Git object is part
of this cleanup. Retained compact partial branches require fresh replay for
trajectory-dependent work and fresh admission for new continuation points.

The six large PK/P1/PIP study and old custody files are replaced by
[essential study evidence](Audits/PK_Essential_Study_Evidence_20261105.mat)
(10.3 MB). It preserves selected raw solutions, admission facts, full flight
proofs, comparisons, final root matrices and unresolved custody flags. It
cannot resume the retired historical checkpoints. See the
[study retirement entry in the cleanup ledger](Audits/V3_Final_Cleanup_Ledger_20261105.json) for
the exact replacements and discarded diagnostic histories.

The large historical audit catalog uses checksum-verified byte parts under
`Audits/V3_Historical_Essential_Audit_Facts_20261105.mat.parts/` for GitHub
storage. See the [restore instructions](../../Docs_v3/Storage_Cleanup_20261105.md#github-storage-and-restoration)
before inspecting that catalog. Current PK cores and partial branches remain
ordinary MAT files and load directly. The restored oversized catalog is ignored
by Git; its tracked parts preserve the exact original bytes.
