# P1 seeded reproduction and ancestry status

This report is generated from saved evidence by `Research_v3/generate_family_reports.py`; it runs no simulation or solver. The source `Research_v3/runs/full/compatibility.json` has status `completed`, finished UTC `07-Oct-2026 09:52:16`, and SHA-256 `b09c927a99795f32130ca1e7753f8517f45d3890f37f8814a24472355635cc92`.

The completed replay contains 27 sampled source columns: 1 autonomous-state replay acceptances and 1 of those within the baseline parameter/initial-energy bounds. Autonomous-state acceptance is not an ancestry edge, and it is not automatically reproduction of the same legacy hybrid cycle. A primitive identity, complete forward trajectory, period, modes, guard eligibility and all event occurrences must also agree.

## Fixed model, domain and qualification

The model is `v3-autonomous-first-directed-root-compressive-stance`, with schema state order `x,dx,y,dy,phi,dphi,alphaBL,dalphaBL,alphaBR,dalphaBR,alphaFL,dalphaFL,alphaFR,dalphaFR`, separate contacts `BL,BR,FL,FR`, and baseline p=`[10,10,20,20,1,1,0,0,2,0.5]`. TD/LO use the first eligible directed state root; accepted tensile stance and swing penetration are rejected. `v2-exact` maps the legacy inactive-osa swing law and the physical parameter vector, not the full scheduled hybrid execution.

The registered search bounds are E in `[1.0001,3]`, mean speed in `[-3,3]`, absolute pitch at most 1.2, primitive relative period at most 12 and at most 64 physical events. The energy column below is the independently evaluated finite-j mechanical energy of the mapped initial state; it does not itself certify mode admissibility, conservation, geometric bounds or the full orbit. Out-of-domain imported source comparisons remain useful model diagnostics and cannot complete the registered network.

The root component is the ordinary synchronous vertical PIP family. Source filenames and directory trees describe historical provenance; no inherited parent/daughter relation is a v3 ancestry certificate. Accepted states at distinct parameters, under distinct event laws, or at different primitive covers cannot be merged to create a fixed-model graph.

The protected P1 critical snapshot has initial dx=`4.43406193516227`. With positive height and nonnegative other mechanical-energy terms, E is strictly greater than `0.5*dx^2=9.83045262243`. This is above the preregistered E<=3 bound. The campaign therefore does not test that historical critical neighborhood. This exclusion is distinct from sampled-state model rejection and from a failed search; the domain was not expanded after observing it.

The P1/P2 `PK_20_2.mat` source copies have identical SHA-256 `45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401`; column 1 maps to the same state, mode, parameters and autonomous event log. Their two accepted provenance records are a duplicate comparison, not two orbit discoveries. This does not identify that family with the distinct `PK_B2_Parent` dataset.

## Sampled fixtures and first recorded failure

| Source fixture | Columns | Saved statuses | Initial energies | First recorded failure or unresolved qualification |
|---|---|---|---|---|
| `BD1_20_2_BE.mat` | 1, 222, 443 | rejected: 3 | 10.8061344, 90.4029803, 152.008488 | ContinuousDynamics_v3:PhysicallyInadmissible: Quadruped section-return is physically inadmissible: swing_foot_penetration:BL, contact_complementarity_loss:BL, swing_foot_penetration:BR, contact_complementarity_loss:BR, swing_foot_penetration:FL, contact_complementarity_loss:FL, swing_foot_penetration:FR, contact_complementarity_loss:FR. |
| `BD1_20_2_BG.mat` | 1, 238, 474 | rejected: 3 | 10.8061344, 81.4697066, 151.616698 | ContinuousDynamics_v3:PhysicallyInadmissible: Quadruped section-return is physically inadmissible: swing_foot_penetration:BL, contact_complementarity_loss:BL, swing_foot_penetration:BR, contact_complementarity_loss:BR, swing_foot_penetration:FL, contact_complementarity_loss:FL, swing_foot_penetration:FR, contact_complementarity_loss:FR. |
| `BD1_20_2_FE.mat` | 1, 115, 228 | rejected: 3 | 10.7855534, 8.6095972, 12.6195988 | ContinuousDynamics_v3:PhysicallyInadmissible: Quadruped section-return is physically inadmissible: swing_foot_penetration:BL, contact_complementarity_loss:BL, swing_foot_penetration:BR, contact_complementarity_loss:BR, swing_foot_penetration:FL, contact_complementarity_loss:FL, swing_foot_penetration:FR, contact_complementarity_loss:FR. |
| `BD1_20_2_FG.mat` | 1, 107, 212 | rejected: 3 | 10.7703467, 17.9477922, 16.8291332 | ContinuousDynamics_v3:PhysicallyInadmissible: Quadruped section-return is physically inadmissible: swing_foot_penetration:BL, contact_complementarity_loss:BL, swing_foot_penetration:BR, contact_complementarity_loss:BR, swing_foot_penetration:FL, contact_complementarity_loss:FL, swing_foot_penetration:FR, contact_complementarity_loss:FR. |
| `BD1_20_2_GE.mat` | 1, 101, 200 | rejected: 3 | 13.1206882, 16.4260848, 19.719307 | ContinuousDynamics_v3:TensileStance: Stance compression is below the admissibility tolerance for leg(s) BL. |
| `BD1_20_2_GG.mat` | 1, 139, 277 | rejected: 3 | 18.3636695, 17.152848, 13.1206882 | ContinuousDynamics_v3:PhysicallyInadmissible: Quadruped section-return is physically inadmissible: swing_foot_penetration:FL, contact_complementarity_loss:FL. |
| `BD1_20_2_HE.mat` | 1, 91, 180 | rejected: 3 | 10.7784711, 16.6366956, 19.1798215 | ContinuousDynamics_v3:PhysicallyInadmissible: Quadruped section-return is physically inadmissible: swing_foot_penetration:BL, contact_complementarity_loss:BL, swing_foot_penetration:BR, contact_complementarity_loss:BR, swing_foot_penetration:FL, contact_complementarity_loss:FL, swing_foot_penetration:FR, contact_complementarity_loss:FR. |
| `BD1_20_2_HG.mat` | 1, 270, 538 | rejected: 3 | 11.0910246, 5.83571576, 10.7784711 | ContinuousDynamics_v3:TensileStance: Stance compression is below the admissibility tolerance for leg(s) FL, FR. |
| `PK_20_2.mat` | 1, 446, 891 | accepted_autonomous_seed: 1, rejected: 2 | 1.11713894, 96.2638783, 20.5273827 | ContinuousDynamics_v3:PhysicallyInadmissible: Quadruped section-return is physically inadmissible: swing_foot_penetration:BL, contact_complementarity_loss:BL, swing_foot_penetration:BR, contact_complementarity_loss:BR, swing_foot_penetration:FL, contact_complementarity_loss:FL, swing_foot_penetration:FR, contact_complementarity_loss:FR. |

A tensile-state or penetration failure is a specific violation of the selected mode domain. An invalid initial section can indicate a different apex/chart rather than nonexistence of an orbit. A missing return within bounds or a solver stop leaves that search unresolved. The table is a bounded column sample, not an exhaustive rejection of every source orbit.

## Autonomous replay versus original cycle

| Source / column | Replay label / primitive diagnostic | Saved residual | Legacy / autonomous period | Contact-history comparison |
|---|---|---|---|---|
| `PK_20_2.mat` / 1 | PK / primitive_within_checked_bound | 2.95206304e-10 | 1.56452021 / 1.56452021 | timing/multiplicity matches within 1e-6 (trajectory equivalence unproved) |

The contact comparison ignores mere ordering differences inside simultaneous TD/LO ties and compares all event occurrences on the time circle at the specified periods. A timing/multiplicity match is a diagnostic, not proof of equal flows, resets, GRF or complete hybrid trajectories. The machine-readable first-divergence field compares simultaneous contact clusters rather than tie ordering. If the initial state already violates the physical domain, that is the first failure; later schedule differences are secondary.

## Reproduction and parent-only discovery

P1 requested edges are ordinary PIP -> P1 PK -> BD -> HB_front/HB_hind -> GP, including BE/BG/FE/FG/HE/HG/GE/GG subclasses. The imported-source replay comparisons supply no daughter attachment or parent-only certificate. A separate restricted parent-only ordinary-PIP-to-traveling-pronking experiment is summarized below; the subsequent PK -> BD -> half-bound -> GP edges remain unresolved here. Both spread orientations must be analyzed in their independent physical directions; a paired parent chart cannot discover them.

## Separate restricted parent-only checkpoint

The saved `P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/Historical/pip_pk_local.json` status is `budget_exhausted`, origin `parent-only`, and restriction `pronk invariant subspace; no split-contact derivative claimed`. The artifact reports held-out daughter use as `False`. These records are separate from imported-seed replay. A stored restricted attachment status does not establish unrestricted contact-cluster smoothness, a theorem-backed pitchfork or ancestry of the imported PK/B2-parent datasets.

| Critical energy | Saved evidence status | Signed amplitude samples | Maximum saved complete-state closure |
|---|---|---|---|
| 1.55516525 | `numerically_supported_restricted_attachment` | 10 | 8.7374552e-12 |
| 1.69595084 | `numerically_supported_restricted_attachment` | 10 | 1.76699511e-11 |

This is a snapshot of the saved local experiment. Tighter replay, full-trajectory distinctions, amplitude convergence, released physical directions and continuation/attachment assessment must be read from its final certificates and the overall research status. No P1/P2 network completion follows from this table.

## Additional boundary qualification

Ordinary `PIP_10_20_2.mat` column 1 has initial E approximately `1.00000001`, below the registered lower bound. The current saved first BL TD is `0.000141421354`, compared with the exact flight benchmark `0.000141421356`. The previous detector clustered a nonzero-height guard prematurely at the artificial leave-section stop (`t=1e-7`). The regression was reproduced red, then fixed by requiring both surface-value tolerance and root-time proximity when the normal velocity is nonzero, with the original direction/tolerance settings retained. The final contract tests place all four TD events at the physical root within 1e-9 and preserve ordinary simultaneous contacts. The out-of-domain energy qualification remains. Small endpoint closure alone does not certify near-grazing event-time accuracy; grazing continuation and ordinary smoothness still require separate treatment.

PC/TR/TL remain in the declared target universe and are not certified reached here. The conditional local propositions in `Periodic_Orbit_and_Bifurcation_Theory_v3.md` do not imply H_network, H_coverage or H_global.

## Supporting runs and reproducibility

The saved exact vertical stage status is `completed`; maximum saved period error is 1.00561248e-09, closure is 1.88878868e-09, and energy range is 2.30013963e-09. These are vertical-model benchmark observations, not off-synchrony branch connections.

The fixed-parameter family stage snapshot status is `completed`. Its final counts/terminal reasons and accepted physical points must be read from the completed checkpoint; a running or budget-ended stage cannot establish branch completeness.

The protected-source manifest is `Research_v3/baseline/source_fixture_manifest.json`. Each observation records its immutable in-v3 fixture path, original path, checksum, source HEAD, variable, column, model parameter policy and mapped state/mode/parameter. Converted seeds preserve source provenance separately from v3 result identity. The local P2 original-run archive was absent in the recorded inventory; no native scheduled campaign execution is claimed.

This report records the preserved previous campaign. The next round runs and resumes entirely in MATLAB through `RunResearchRound_v3('Profile','full','Resume',true,'MinRepairRounds',3)` after adding `SLIP_Quadruped_v3` to the MATLAB path. The distinct `RunP1ResearchRound_v3` driver corrects source/critical neighborhoods, preserves failed candidates and releases physical symmetry directions in later repair rounds. Read `Next_Round_Full_Execution_v3.md`, `MATLAB_Research_Runner_v3.md` and `Research_v3/next_round/task_queue_full.json` for actual new execution, coverage and unfinished tasks. The previous source JSON, MAT checkpoints, logs and ledger remain authoritative for the historical numbers above; the public next-round workflow does not require their Python generators. Model-gate failures remain distinct from physical-boundary results and search-budget limits.

The generic parent-only stage status is `completed_bounded_search`: No branch edge is certified by this search. Its attempt diagnostics are separate from the restricted local pronking study. The corrected compatibility replay uses effective top-level integration RelTol=1e-09, AbsTol=1e-10; earlier ODEOptions-only runs were superseded.

## Imported PK continuation segments

These segments hold the ten physical parameters fixed and vary conserved energy within the pronk restriction. Their imported seed supplies no ordinary-PIP ancestry. Accepted-point counts include stored restart/seed endpoints; they are not counts of distinct gait classes or proof of complete branches.

| Direction | Status | Stored accepted points | Maximum complete-state closure | Stop reason |
|---|---|---|---|---|
| -1 | `completed_bounded_branch` | 20 | 3.38852946e-10 | maximum point count reached |
| 1 | `completed_bounded_branch` | 21 | 2.96106695e-10 | maximum point count reached |

See the typed graph and `Branches_v3/index.json` for shared checkpoints. Maximum point count is a numerical budget stop, not a demonstrated physical endpoint.
