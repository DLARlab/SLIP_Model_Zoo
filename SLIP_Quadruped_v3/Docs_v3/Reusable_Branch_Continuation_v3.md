# Reusable periodic-branch continuation

The reusable workflow is `ContinuePeriodicBranch_v3`. It extracts the native
state predictor/corrector used by the PK search; it does not introduce another
continuation algorithm. The old `RunC1Continuation_v3` name is a compatibility
adapter for callers supplying an explicit current-process absolute `Budget`.
Empty or retired campaign budgets fail with `C1Continuation:LegacyBudgetRetired`.
New code should use the public function and its local wall limit.

## Starting and resuming

Start with two admitted native solutions joined by an explicitly stored
physical continuation edge. Their order chooses the initial direction.
Imported nearby points and numerical meeting relations do not establish that
edge. Inputs use indexed native schema2 or Essential schema4 branch files;
the published `Research_v3/C1/Results/Partial_Components` folder supplies
schema4 files. `WorkingCore29` files use the separate result-viewing reader
`LoadC1WorkingSolutionCore29_v3` and are not direct inputs to this function.

```matlab
addpath(fullfile(pwd,'SLIP_Quadruped_v3'));
V3AddPaths_v3();

sourceFile = '/absolute/path/to/native_branch.mat';
outputFile = '/absolute/path/to/new_branch.mat';
options = struct('Symmetry','pronk','AllowedClasses',{{'PK'}}, ...
    'MaxAccepted',20,'MaxWallSeconds',600,'TrialSeconds',120);
run = ContinuePeriodicBranch_v3(outputFile,sourceFile,[14 13],options);
```

Use real indices from your source file. Repeating the same call resumes from
the last committed pair and its compatible controller state. The call has a
bounded local runtime; it does not adopt an expired research campaign's clock.
A time or point limit is a pause in the search, not a physical endpoint.

For the PK flight supplement used in the completed search, explicitly add
the C1 checks and select the post-return adapter:

```matlab
addpath(fullfile(V3Root_v3(),'Research_v3','C1'));
options.PointCheck = @PKFlightPointCheck_v3;
options.AdapterSources = {'RecordedOrbitReplayProfile_v3', ...
    'CheckC1PKOrbitFlights_v3','CheckC1PKFlightInterval_v3', ...
    'AllFlightClearanceBounds_v3'};
```

This checks both fresh initializers and new candidates. It operates after
the native result is saved, and never governs finite-difference trial maps.
The generic default retains the shared nine gates; it does not certify
continuous PK flight clearance. The supplement remains conditional on its
recorded arithmetic cushions.

On a new segment, saved historical gates alone are insufficient. Intake
evaluates both literal seeds under the current model through the shared PSS.
Its new coupled problem selects `E = energy(raw_state,q,p)` and allows at most
one Newton iteration; any change to the raw state, modes or parameters
refuses intake. Fresh period and stride are checked separately against the
saved values. This does not recreate historical energy coordinates or
requalify the old edge. A refused source is not evidence of a physical
endpoint or absence of a branch.

## Mathematical scope

The predictor uses the scaled secant of the last two admitted states. The
corrector solves the coupled state and free-energy system, including the
state arclength equation. Energy remains a solved coordinate. Corrections use
`root-newton`; optimization is not part of this workflow.

The shared `PeriodicSolutionSolver_v3` retains its original nine acceptance
gates. A corrected point earns a physical edge only after admission, matching
policy/section/parameters/modes, and directed predictor-capture checks. A
small residual or proximity to another branch is insufficient.

The initial supported scope is the existing quadruped apex charts with the
complete recorded BL1 return policy and certain one-flight classifications.
Choose the appropriate existing symmetry chart for another C1 gait. In
half-bounding, **H means hind-leg spread with synchronized fore legs; F means
fore-leg spread with synchronized hind legs**. Mixed-contact checks must use
their own valid numerical domain. The synchronous PK whole-flight checker is
not a generic derivative-domain test.

| Physical family | Existing chart | `AllowedClasses` |
|---|---|---|
| Exact centered synchronous PK | `pronk` | `{'PK'}` |
| Bounding | `left-right` | `{'B'}` |
| Hind spread, fore synchronized | `fore-pair` | `{'H'}` |
| Fore spread, hind synchronized | `hind-pair` | `{'F'}` |
| Galloping / unrestricted C1 chart | `none` | `{'G'}` |

The chart must represent the literal source states. These choices do not
project a source into symmetry or establish a bifurcation. BG/BE and the other
posture suffixes are downstream labels; the allowed-family filter uses the
physical family shown above.

The user-specified height criterion concerns the marked COM apex:
`apex_height < 0.5 * resting_leg_length`. Equality continues; the minimum
height along a trajectory is not substituted for apex height. The default
uses equal fore/hind resting leg lengths. For a model with unequal lengths,
set `MinimumApexHeightRatio=0` to disable this particular criterion and use
an explicitly defined `StopCheck` for that model.

## Persistence and compact results

One branch MAT file contains indexed solutions and physical edges. One small
checkpoint contains the current pair, adaptive radius, derivative/controller
state and any unfinished transaction. A prepared solver call with an unknown
outcome is held for reconciliation rather than silently repeated. Returned
native results are preserved before optional checks or branch publication.

Compact storage preserves literal initial state, modes, parameters, period,
stride, complete policy/section, and saved admission and event evidence. It
discards dense trajectories and repeated diagnostic runtime objects only
after qualification. Loading historical decisions does not perform a fresh
admission. Replaying a compact solution requires a new, explicitly configured
integration.

Retire consumed stages and temporary verification output after each closed
run. Keep current branch files, the active checkpoint, reusable methods and
the concise outcome. Do not accumulate a new full archive or source snapshot
for every invocation. Historical audit paths for retired payloads are
provenance locators; their hashes do not imply that those payloads still exist.

## Finalizing a closed branch

Keep the branch and checkpoint together while the frontier is active. After
the last writer has stopped, the reusable storage exporter can make a smaller
trajectory-free final file without running Root, a map, or classification:

```matlab
d = dir(outputFile);
source = struct('file',outputFile,'sha256',RoundSHA256_v3(outputFile), ...
    'bytes',d.bytes);
settings = struct('MaximumBytes',32*1024^2,'MaxWallSeconds',600, ...
    'SaveMarginSeconds',60,'ReadbackIndices',[1 2]);
receipt = CondenseBranchFile_v3(source,finalFile,settings);
```

Use existing indices and a fresh `finalFile` in an existing folder. The returned
receipt verifies literal cores, stored scientific projections, physical edges
and independent selected readbacks. Unknown graph or method formats refuse
conversion. Keep the receipt with the final result. Remove the retired active
file, checkpoint, test outputs and routine logs only after verification and
source-hash checks. Do not replace an active output in place: its checkpoint
refers to that exact output. A later search can start a new segment from an
admitted physical pair in the final file, using fresh intake.
