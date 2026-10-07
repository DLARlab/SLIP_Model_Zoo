# Round 1 numerical and performance baseline

Historical environment note: the MATLAB availability and blocked results
below describe the original Round 1 host and commit. During the 2026-10-07
cleanup, characterization test sources were removed. The retained
`tools/runRound1Audit.m` still runs numerical and performance audits and
explicitly records the absent characterization suite.

## Outcome

No MATLAB executable is installed on the audit host:

```text
$ command -v matlab
matlab: not found
$ command -v octave
octave: not found
```

Consequently no ODE runtime, residual norm, `fsolve` iteration count,
finite-difference singular value, MATLAB profiler result, or graphics result
is reported. This is an environment blocker, not a failed model run. The
reproducible bounded harness is
`tools/runRound1Audit.m`.

Run the retained numerical audit from the repository root in a MATLAB
environment with the required products. This current recipe excludes the
removed characterization suite:

```matlab
addpath('tools');
report = runRound1Audit();
```

Command-line equivalent:

```sh
matlab -batch "addpath('tools'); report=runRound1Audit();"
```

Generated output is confined to ignored
`artifacts/round1-audit/`. The harness fixes the RNG with
`rng(314159,'twister')`, restores the original path/current directory/default
figure visibility, and hashes the research artifacts before and after.

## Audit host

| Item | Observed value |
|---|---|
| Commit | `2c106101383ecee1b2a9d695efe09fbd72d5718a` |
| Branch | `main` |
| OS | macOS 26.5.2, build `25F84`, Darwin arm64 |
| MATLAB release | Blocked: executable absent |
| MATLAB toolboxes | Blocked: executable absent |
| Display | No `DISPLAY`, `WAYLAND_DISPLAY`, or `MIR_SOCKET` advertised; GUI capability cannot be tested without MATLAB |
| Static RNG use | GUI has ambient `rand`/`randn`; audit harness uses seed 314159 |

The exact initial status was:

```text
## main...origin/main
?? SLIP_Model_Zoo_Round1_Audit_Prompt.md
```

The prompt is a pre-existing untracked user file and was not changed.

## Reference cases

The harness uses `PK_20_2.mat`, column 1 for residual, full-stride, root,
graphics, and Jacobian work, and columns 1–2 for the capped continuation
attempt. Two additional static audit selections are recorded for later
cross-gait checks:

| File and column | Reason | Limitation |
|---|---|---|
| `PK_20_2.mat`, column 1 | Roadmap seed, 891-column branch, finite 29-row data, nominal parameters | Periodicity and gait label not runtime-verified |
| `BD1_20_2_GE.mat`, column 100 | Interior point of a distinct 200-column roadmap branch | Filename is not treated as proof of gait class |
| `BD1_20_2_HG.mat`, column 269 | Interior point of a distinct 538-column roadmap branch | Filename is not treated as proof of gait class |

All use `[k,ks,J,l,osa,lb,kr]=[10,20,2,1,0,0.5,1]`, away from the explicit
`J=0`, `l=0`, `kr=-1`, and hip-endpoint boundaries. All values are finite.
However, no stored column in any of the nine branch files has `TD>LO` for any
leg. A wrapped-stance reference case therefore does not exist in repository
data. The requested two confirmed gait classes and one confirmed valid
periodic root remain runtime checks, rather than assumptions derived from
filenames.

## Bounded executions prepared

| Baseline | Harness behavior | Fixed bounds/options | Round 1 result |
|---|---|---|---|
| Residual-only | `Quadrupedal_ZeroFun_v2(z,p,'skipSolve')`, one output | Production ODE chooses `RelTol=AbsTol=1e-12` for stored `dx<15` | Blocked: MATLAB absent |
| Full stride | Six-output call to the same residual | Same production ODE settings; reports `numel(T)` | Blocked |
| Root correction | Deterministic `1e-7*max(1,abs(z))*sin(index)` perturbation, `fsolve` | Levenberg–Marquardt; `MaxIter=8`, `MaxFunEvals=100`, `TolFun=TolX=1e-10` | Blocked: MATLAB/Optimization Toolbox unavailable |
| Short 1-D continuation | `PK` columns 1–2, radius `0.01` | One iteration per direction, solver `MaxIter=2`, `MaxFunEvals=50`; plotting, pauses, prompts, and temp save disabled | Blocked |
| Gait, one solution | `Gait_Identification(z)` | Single call | Blocked |
| Gait, branch | `Gait_Identification(results(1:22,:))` | Single call | Blocked: also requires `downsample` resolution |
| Headless graphics | Invisible `SLIP_PeriodicOrbit_Quad` construct/update/export | One figure, PNG under artifact directory | Blocked |
| MAT catalog | Load `results` from each roadmap MAT file and count bytes/columns | Nine files | MATLAB timing blocked; static volume measured below |
| Residual profile | Profile one residual-only evaluation and save `profile('info')` plus HTML | Exactly one call | Blocked |
| Jacobian | Central differences at relative steps `1e-4`, `1e-5`, `1e-6` | Absolute step `h_j=h_rel*max(1,abs(z_j))`; absolute rank floor `1e-10` plus MATLAB epsilon threshold; row/column-normalized spectra | Blocked |

The harness catches and records each operation separately so a graphics or
dependency failure does not erase numerical results. It saves solver options,
warnings/errors in the diary, output point counts, report structures, hashes,
and any generated files. It does not run the unbounded default continuation
loop.

## Static data/I/O baseline

The nine level-5 MAT files occupy 491,686 bytes on disk and contain 3,443
columns. The dense `29 x 3443` double payload alone is 798,776 uncompressed
bytes, excluding MATLAB container overhead. Individual counts are in
[`data-schema-round1.md`](data-schema-round1.md).

The GUI repeatedly loads the complete `results` variable for cataloging and
plotting (`SLIP_Quadruped_GUI.m:2520-2531,2625-2635,3819,3860,3979`).
The 2-D continuation loader uses `matfile` only for v7.3 files and otherwise
loads full level-5 files
(`NumericalContinuation2D_Quadruped_v2.m:1419-1486`). At current repository
size this is small, but the pattern scales with branch size.

## Static performance observations

These are hypotheses about cost until measured; they are classified `PH`.

| ID | Candidate cost | Source evidence | Measurement to collect |
|---|---|---|---|
| PH-01 | A one-output residual still accumulates full `T/Y/Y_EVENT` and computes all GRFs | `Quadrupedal_ZeroFun_v2.m:123-125,249-263` | Compare residual-only and six-output wall time, ODE count, allocations |
| PH-02 | Numerical Jacobians repeat the complete hybrid integration many times | `fsolve` calls at `SolveQuadrupedalZE.m:42`, continuation corrector at `NumericalContinuation1D_Quadruped_v2.m:983-986`; no supplied Jacobian | Profile ODE calls/function evaluations per correction |
| PH-03 | Contact, geometry, and force work is independently repeated | ODE at `Quadrupedal_ZeroFun_v2.m:385-465`, GRF at lines 600–679, graphics at `ComputeJoint_LegLA.m:1-166` | Call tree and per-function self time |
| PH-04 | Dynamic trajectory growth reallocates | `T=[];Y=[]` then concatenation at `Quadrupedal_ZeroFun_v2.m:123-125,249-251` | Allocation profiler and output size |
| PH-05 | Gait classification builds a fixed `1e-4` timeline | `Gait_Identification.m:174-199` | Time/memory versus stride period and branch width |
| PH-06 | Historical revisit checks can grow quadratically with accepted points | `NumericalContinuation1D_Quadruped_v2.m:1309-1364` | Continuation time per accepted point versus history length |
| PH-07 | GUI catalog operations repeatedly load full MAT payloads | `SLIP_Quadruped_GUI.m:2520-2531,3819,3860,3979` | Cold/warm load time and bytes for synthetic large branches |
| PH-08 | Checkpoints and current-directory logging introduce I/O | `NumericalContinuation1D_Quadruped_v2.m:561-600,1476-1493` | Files/bytes and time by checkpoint |
| PH-09 | Graphics constructors redraw complete geometry | `SLIP_Animation_Quad.m`, `SLIP_Trajectories_Quad.m`, `SLIP_GRF_Quad.m` | Invisible constructor/update wall time and graphics object count |
| PH-10 | GUI status callbacks may dominate fast continuation steps | Callback/status paths throughout the 1-D/2-D continuation and GUI | Profile with callbacks enabled/disabled using identical seeds |

No optimization is proposed on the strength of these hypotheses alone.

## Solver/residual dimensions to interpret future timings

The ordinary finite-inertia root has 22 unknowns and 22 residuals. Infinite
inertia adds one residual; one optional pair constraint adds two. The 1-D
corrector appends one pseudo-arclength equation, and 2-D radius correction
appends one radius equation. These overdetermined variants can be accepted by
Levenberg–Marquardt, but timing or convergence alone will not establish a
correct continuation formulation. The Jacobian report must accompany the
future baseline.

## Required result record after MATLAB execution

After running the command above, copy the generated measurements into this
table without replacing blocked cells with estimates:

| Operation | Time | Function evals | Iterations | Residual norm | ODE/output points | Warnings/errors | Files/side effects |
|---|---:|---:|---:|---:|---:|---|---|
| Residual-only | Pending | N/A | N/A | Pending | Pending | Pending | Audit artifacts only |
| Full stride | Pending | N/A | N/A | Pending | Pending | Pending | Audit artifacts only |
| Root correction | Pending | Pending | Pending | Pending | Pending | Pending | Audit artifacts only |
| Capped continuation | Pending | Pending | Pending | Pending | Pending | Pending | Audit artifacts only |
| Gait single/branch | Pending | N/A | N/A | N/A | N/A | Pending | None expected |
| Headless graphics | Pending | N/A | N/A | N/A | N/A | Pending | One PNG |
| MAT catalog | Pending | N/A | N/A | N/A | N/A | Pending | None |
