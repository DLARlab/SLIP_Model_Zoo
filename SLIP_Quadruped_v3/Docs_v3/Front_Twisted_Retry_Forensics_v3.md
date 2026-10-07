# Executed front twisted-return retry forensics

The front retry remains unaccepted, with an unresolved numerical near-null direction. Its complete finite Jacobian improves the evidence over the original partial-Jacobian pilot, but does not supply an accepted daughter or a resolved rank certificate. These conclusions come from the saved report and algebra only; no new map, corrector, core or active-driver change was performed for this audit.

The bound report is `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Front_Twisted_Retry/n0_positive_front_twisted_common_C1_Broyden_retry/front_retry_report.mat`, SHA256 `d159adb777ae33b9931f33df54461687852d27b8650e50240f6320c785f4c84f`, modified 7 October 2026 at 15:57:48 UTC. The compact MAT/JSON audit is `P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Front_Twisted_Retry/Forensics/audit.mat/json`. It records the current validation_06 canonical gate, unchanged RootSolver SHA `ad3ab6c664b89fed8ef81c7944a1f2d9062756313f7e42f8119ae5ad1c9edf75`, correction-source hashes and the registered front method. Saved-report algebra is reproducible with `AuditFrontTwistedRetryForensics_v3`; its log is `front_retry_forensics.log`.

| Saved observation | Value |
| --- | ---: |
| Shared-service elapsed time | 468.85 s |
| Core objective calls / core residual map evaluations | 214 / 212 |
| Full Jacobian evaluations / accepted Newton steps | 2 / 1 |
| Invalid evaluations | 0 |
| Initial / final twisted residual | 1.60613365e-8 / 1.60613894e-8 |
| Actual full BL2 closure / fixed acceptance threshold | 5.49199832e-8 / 1e-8 |
| Measured first-order optimality | 2.96574257e-15 |
| Two smallest singular values | 1.41375449e-3, 4.42745952e-9 |
| Physical-coordinate Jacobian condition estimate | 3.21131e9 |

The primary stop is `First-order optimality tolerance satisfied.`, exitflag 3. Full-closure finalization fails separately because actual BL2 closure exceeds `1e-8`; independent replay was not reached. The wrapper marked a partial checkpoint near the end of its slice, but the retained primary cause is optimality stopping, not an invalid return or an unavailable derivative. All thirteen FD columns passed their registered reliability gates and the common-C1 event-order chart. These per-column statements do not establish resolution of the weakest singular value.

The physical-coordinate gradient norm is `1.43850420e-15`. RootSolver uses scaled coordinates: `norm((J.*stateScale')'*r,Inf)=2.96574257e-15`, exactly the recorded stopping value and below the default shared-service `1e-14` optimality threshold. The difference is coordinate scaling; it is not evidence of an inconsistent stopping calculation. The same scaling identity exactly reproduces both five-dimensional accuracy-repair stops.

The recorded maximum FD refinement error `1.725407e-6` is normalized by `max(1,norm(fineColumn))`. Converting each selected fine column and Root's state scale back to the reported physical-coordinate Jacobian gives an empirical matrix-difference Frobenius estimate `2.133578e-5`. This is a refinement estimate, not a rigorous bound, and is much larger than the measured smallest singular value. A finite matrix and reliable columns therefore cannot certify its weakest inverse direction or numerical full rank.

The weakest left singular component contains `0.999999993332` of the squared residual norm. The corresponding right vector aligns with the separately recorded n0 common-pronk critical direction by `0.9999999999999984`. Its principal physical components are common horizontal velocity and equal angle/rate motion of all four legs. This matches the already qualified extra pronk +1 kernel retained by the front-swap formulation; no simple-kernel theorem was assumed. The formal undamped linear step has norm `3.83660`, horizontal-velocity change `-1.31428` and common leg-rate changes near `-1.78300`, compared with the frozen front amplitude `0.001`. These large linear changes are not admissible local-branch evidence; they illustrate sensitivity to the unresolved small denominator.

The accepted scaled step was only `9.514609e-10`. Its squared norm `9.052794e-19` is below `eps=2.220446e-16`, so the existing RootSolver Broyden denominator guard discards the matrix even when compatibility metadata agrees. This explains the second complete FD after one accepted step. It is a distinct cause from the earlier raw-event-cluster compatibility rejection. Preserving verified common-C1 metadata does not remove this small-step guard or its derivative cost.

A warm finite-matrix retry with only smaller optimality and step thresholds could again require a complete thirteen-dimensional FD and does not address the extra center direction. It must not be advertised as a cheap accuracy-only fix. The current outcome is preserved as unresolved. No blind front revision03 was prepared. A further experiment would need a separately registered, dimension-consistent hypothesis addressing the coupled center/nullity structure, followed by the unchanged actual physical BL2, energy, stance and primitive acceptance gates. Common-C1 evidence still makes no unrestricted C2, ancestry, new-gait or global-network claim.
