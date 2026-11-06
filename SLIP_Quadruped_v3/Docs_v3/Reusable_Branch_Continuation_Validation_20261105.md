# Reusable continuation validation — 5 November 2026

The public `ContinuePeriodicBranch_v3` implementation passed a bounded native
MATLAB test. This validates the exercised numerical and persistence paths;
it is not a branch search or a proof of branch completeness.

## Method preserved

The canonical engine extracts the existing native state-PAL correction.
Its normalized chord uses state coordinates; energy remains a coupled solved
coordinate with zero weight in the PAL normal. It uses `root-newton`, the
existing energy-family residual and all nine original PSS acceptance gates.
No optimizer, source snapping, or replacement of derived event/trajectory
outputs by solved coordinates was introduced. The research
`RunC1Continuation_v3` entry point is a compatibility adapter; its exact old
source is preserved once under `Docs_v3/Compatibility`.

The supported public scope is the existing native apex charts, a complete
recorded BL1 return policy, and certain one-flight classifications. PK
continuous-flight eligibility is an explicitly selected post-return
`PKFlightPointCheck_v3`, not a condition imposed on intermediate Root/FD
trials or on other gaits.

## Executed checks

The actual fixture was the owned physical edge 1→2 in
`PK15h_20261104_HistoricalMRefresh01_Row06_CurrentCarrier.mat`. Both literal
states roundtripped the public pronk chart exactly. Historical saved gates
were prerequisites; both source states were freshly validated by the new
fixed-state PSS intake before use. Their original source file was unchanged.

The test used a fresh 1,200-second local budget and at most one correction
service per call. It performed two intake services and exactly two
continuation correction services, producing two new all-nine PK points and
two directed physical edges. Both new points passed the optional continuous
PK flight checker. They were stored compactly after qualification.

| Check | Observed result |
|---|---|
| Callback throws after the first known native result | Result retained; no point appended |
| Callback changes its cloned trajectory termination | Mutation refused; original retained NativeID and termination unchanged |
| Callback throws during recovery | Result remains recoverable; zero new correction calls |
| Recover the known result normally | One point committed with zero repeated correction calls |
| Remove only the test-owned source hardlink, then resume | Owned branch/checkpoint resumed; original source remained intact |
| Restore the directed pair and adaptive controller | Exact saved pair/radius/derivative index restored |
| Change a numerical method option | Refused before a new solve; checkpoint unchanged |
| Inject an unknown prepared transaction in a separate test checkpoint | HOLD; zero new correction calls |
| Public left-right chart on an actual retained point | Lossless pack/lift; no left-right Root claim |
| Existing final WorkingCore29 reader | Historical compact solution remained readable |

The requested radii were `0.001` and `0.0018803015465431968`; the saved next
radius was `0.0035355339059327377`. The second call ended at its one-attempt
cap after committing its point. This is a bounded test disposition, not an
endpoint declaration.

## Runtime and storage

MATLAB process 55041, tool session 18823, exited with code 0. The complete
process took **291.73 seconds** wall time; the instrumented test body took
286.125 seconds and remained within its 1,200-second budget. Peak resident
set size reported by `/usr/bin/time -l` was 1,847,427,072 bytes. These totals
include two fresh intakes, deliberate callback failures, checkpoint recovery,
five normal/recovery invocations, two refusal/HOLD calls and reader checks; they are not per-point
Root timings or a comparison with v2.

The final four-record branch was **75,155 bytes** and its active session
checkpoint **34,384 bytes**. The qualified compact records had no dense
trajectory. Full returned native custody existed before optional checks and
was released only after the corresponding outcome was committed. Ordinary
failure history is bounded and explicitly omits dense diagnostic tapes.

The subsequent saved-data extraction in
`Research_v3/C1/Audits/ReusableContinuation_Timing01.json` retained these
measurements:

| Operation | Measured seconds |
|---|---:|
| Fixed-state source intake 1, including its PSS service | 38.936 |
| Fixed-state source intake 2, including its PSS service | 46.850 |
| First new point: original PSS service | 85.594 |
| Second new point: original PSS service | 85.956 |
| Second attempt before its final checkpoint | 89.134 |
| Second point: explicit returned-result custody checkpoint | 0.574 |
| Second point: whole-flight checker itself | 0.021 |
| Second point: branch publication and two installed readbacks | 0.072 |

Both intake services entered the Root solver and returned at zero iterations
with the literal source state, mode and parameters unchanged. The second
correction reported two Root iterations. The two new points' saved full
closure errors were approximately `4.77e-14` and `8.21e-15`.

The approximately 86-second PSS measurements include the strict native
correction/admission service, not an isolated Newton-iteration benchmark.
**The sub-five-second target was not achieved in this fixture.** No matching
v2 run was measured, so there is no speed-parity or speedup claim. The verified
improvements here concern reusable invocation, persistence, recovery and
compact storage. The whole-flight and publication timings do not explain the
entire remaining overhead. Callback transport and initial/final checkpoint
costs were not separately measured. The first correction's wrapper-call timer
was overwritten during recovery; its original saved PSS elapsed time remains
available and is the value reported above.

## Evidence and limits

The native result is `Research_v3/C1/Audits/ReusableContinuation_Validation01.mat`
; routine logs and test fixtures are retired after the final verification. The independent review checked
their returned references, unchanged method/source headers, absence of owned
pending stages and leases, and process absence. The public engine source
tested was SHA256
`99c8dae2f5f7915599c535dba4e3c105234fff2b2fb60ec59a424758673a869b`.

This run did not perform another branch search, a fresh left-right correction,
a v2 benchmark, an arbitrary-gait validation, or a simulated process crash
inside the append/readback interval. The latter transaction ordering was
source-reviewed; the executed fault checks exercised returned-result custody,
callback isolation, unknown-intent HOLD and committed-controller resume.

## Final storage verification and test cleanup

The final saved-data check also passed after the historical sources were
retired and the 43 partial files were moved to `Results/Partial_Components`.
It loaded first/middle/last records from both current PK cores and independently
loaded selected relocated partial and unmatched records. Literal state,
parameter, mode, NativeID and retained scientific projections were unchanged.
The retired-budget compatibility cases refused before any model call.

The actual four-record continuation test branch condensed from 75,155 to
38,359 bytes in 11.332 seconds, preserving its **two** earned physical edges.
Its imported initializer records did not acquire another edge. All four
literal cores, saved admission gates and IDs were checked. This storage-only
check performed zero Root calls, maps, replays or classifications. Its body
took 309.903 seconds, within its 900-second cap; the process exited with code 0.

`Research_v3/C1/Audits/ReusableContinuation_FinalStorageSmoke_20261105.mat`
is the concise plain result. Disposable branch files, their checkpoints and
the condensed test output were removed after PASS; the audit retains their
tested literal cores and outcomes. Temporary scripts and routine logs are
retired during final cleanup. Paths to those old test payloads identify
historical evidence and are not current datasets.
