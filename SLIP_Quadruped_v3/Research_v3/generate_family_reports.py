#!/usr/bin/env python3
"""Refresh prose evidence reports from saved campaign JSON; runs no experiments."""
from __future__ import annotations
import collections
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / 'Research_v3' / 'runs' / 'full'
DOCS = ROOT / 'Docs_v3'


def number(value):
    return 'unavailable' if value is None else f'{value:.9g}'


def energy(row):
    x, p, q = row.get('initial_state', []), row.get('physical_parameter', []), row.get('initial_mode', [])
    if len(x) != 14 or len(p) != 10 or len(q) != 4:
        return None
    result = .5 * (x[1] ** 2 + x[3] ** 2 + p[8] * x[5] ** 2) + x[2]
    for leg in range(4):
        if not q[leg]:
            continue
        offset = -p[9] if leg < 2 else 1-p[9]
        angle = x[4] + x[6 + 2*leg]
        denominator = math.cos(angle)
        if abs(denominator) < 1e-12:
            return None
        length = (x[2] + offset * math.sin(x[4])) / denominator
        rest, stiffness = (p[4], p[0]) if leg < 2 else (p[5], p[1])
        result += .5 * stiffness * (rest-length) ** 2
    return result


def event_compatibility(row):
    """Compare prescribed-cycle timing, ignoring ordering inside TD/LO ties."""
    actual, scheduled = row.get('events', []), row.get('scheduled_events', [])
    actual_t, source_t = row.get('detected_period'), row.get('legacy_period')
    if not actual or not actual_t or not source_t:
        return 'not assessed: no complete autonomous log'
    if abs(actual_t-source_t) > 1e-6:
        return f'period differs by {actual_t-source_t:+.6g}'
    if len(actual) != len(scheduled):
        return f'event multiplicity differs ({len(actual)} vs {len(scheduled)})'
    for kind in sorted({e['type'] for e in scheduled} | {e['type'] for e in actual}):
        a = [e['time'] % actual_t for e in actual if e['type'] == kind]
        b = [e['time'] % source_t for e in scheduled if e['type'] == kind]
        if len(a) != len(b):
            return f'{kind} occurrence count differs'
        for time in a:
            distances = [abs((time-peer + actual_t/2) % actual_t-actual_t/2) for peer in b]
            index = min(range(len(distances)), key=distances.__getitem__)
            if distances[index] > 1e-6:
                return f'{kind} time differs by {distances[index]:.6g}'
            b.pop(index)
    return 'timing/multiplicity matches within 1e-6 (trajectory equivalence unproved)'


def clean(value):
    return str(value).replace('|', '/').replace('\n', ' ')


def items(value):
    """Normalize MATLAB singleton and empty struct-array JSON encodings."""
    if isinstance(value, dict):
        return [value] if value else []
    return value or []


def accepted(row):
    return row['status'] == 'accepted_autonomous_seed'


def in_domain(row, cfg):
    value = energy(row)
    if value is None:
        return False
    low, high = cfg['domain']['energy']
    parameter = row.get('physical_parameter', [])
    baseline = cfg['baseline_v3_parameters']
    return low <= value <= high and len(parameter) == len(baseline) and all(
        abs(a-b) <= 1e-12 for a, b in zip(parameter, baseline))


def refresh():
    source = RUN / 'compatibility.json'
    report = json.loads(source.read_text())
    cfg = report['config']
    vertical_file = RUN / 'vertical.json'
    vertical = json.loads(vertical_file.read_text()) if vertical_file.exists() else {}
    fixed_file = RUN / 'fixed_family.json'
    fixed = json.loads(fixed_file.read_text()) if fixed_file.exists() else {}
    parent_file = RUN / 'parent_only.json'
    parent = json.loads(parent_file.read_text()) if parent_file.exists() else {}
    local_file = RUN / 'pip_pk_local.json'
    local = json.loads(local_file.read_text()) if local_file.exists() else {}
    observations = items(report.get('observations'))
    old = any(row['status'] == 'accepted_uncorrected_seed' for row in observations)
    nearzero = next((r for r in observations if r['source']['fixture_path'].endswith('/PIP_10_20_2.mat') and r['column'] == 1), None)
    nearzero_td = next((e.get('time') for e in nearzero.get('events', []) if e['type'] == 'BL_TD'), None) if nearzero else None
    nearzero_expected = math.sqrt(2*(nearzero['initial_state'][2]-1)) if nearzero and nearzero.get('initial_state') else None
    premature_record = nearzero_td is not None and nearzero_expected is not None and abs(nearzero_td-nearzero_expected) > 1e-9
    provisional = old or premature_record or report.get('status') != 'completed'
    fingerprint = hashlib.sha256(source.read_bytes()).hexdigest()
    for study, name in [('P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits', 'P1_Reproduction_Report_v3.md'),
                        ('P2_All_Common_Quadrupedal_Gaits', 'P2_Discovery_Report_v3.md')]:
        p1 = study.startswith('P1_')
        rows = [row for row in observations if row['source']['study'] == study]
        valid = [r for r in rows if accepted(r)]
        bounded = [r for r in valid if in_domain(r, cfg)]
        groups = collections.defaultdict(list)
        for row in rows:
            groups[Path(row['source']['fixture_path']).name].append(row)
        title = 'P1 seeded reproduction and ancestry status' if p1 else 'P2 seeded compatibility and discovery status'
        text = [f'# {title}', '',
                'This report is generated from saved evidence by `Research_v3/generate_family_reports.py`; it runs no simulation or solver. '
                f'The source `Research_v3/runs/full/compatibility.json` has status `{report.get("status")}`, '
                f'finished UTC `{report.get("finished_utc", "not yet recorded")}`, and SHA-256 `{fingerprint}`.', '']
        if provisional:
            text += ['**Provisional checkpoint.** The available compatibility file predates a required event-detector correction or is incomplete. '
                     'Old `accepted_uncorrected_seed` records are superseded observations, not accepted primitive orbits. '
                     'Final acceptance, event-count and first-divergence conclusions require the scheduled corrected-code replay. '
                     'The table below records what was attempted and its saved first failure; it does not promote stale acceptance.', '']
        else:
            text += [f'The completed replay contains {len(rows)} sampled source columns: {len(valid)} autonomous-state replay acceptances and '
                     f'{len(bounded)} of those within the baseline parameter/initial-energy bounds. '
                     'Autonomous-state acceptance is not an ancestry edge, and it is not automatically reproduction of the same legacy hybrid cycle. '
                     'A primitive identity, complete forward trajectory, period, modes, guard eligibility and all event occurrences must also agree.', '']
        text += ['## Fixed model, domain and qualification', '',
                 'The model is `v3-autonomous-first-directed-root-compressive-stance`, with schema state order '
                 '`x,dx,y,dy,phi,dphi,alphaBL,dalphaBL,alphaBR,dalphaBR,alphaFL,dalphaFL,alphaFR,dalphaFR`, '
                 'separate contacts `BL,BR,FL,FR`, and baseline p=`[10,10,20,20,1,1,0,0,2,0.5]`. '
                 'TD/LO use the first eligible directed state root; accepted tensile stance and swing penetration are rejected. '
                 '`v2-exact` maps the legacy inactive-osa swing law and the physical parameter vector, not the full scheduled hybrid execution.', '',
                 'The registered search bounds are E in `[1.0001,3]`, mean speed in `[-3,3]`, absolute pitch at most 1.2, '
                 'primitive relative period at most 12 and at most 64 physical events. '
                 'The energy column below is the independently evaluated finite-j mechanical energy of the mapped initial state; '
                 'it does not itself certify mode admissibility, conservation, geometric bounds or the full orbit. '
                 'Out-of-domain imported source comparisons remain useful model diagnostics and cannot complete the registered network.', '',
                 'The root component is the ordinary synchronous vertical PIP family. '
                 'Source filenames and directory trees describe historical provenance; no inherited parent/daughter relation is a v3 ancestry certificate. '
                 'Accepted states at distinct parameters, under distinct event laws, or at different primitive covers cannot be merged to create a fixed-model graph.', '']
        if p1:
            text += ['The protected P1 critical snapshot has initial dx=`4.43406193516227`. '
                     'With positive height and nonnegative other mechanical-energy terms, E is strictly greater than '
                     f'`0.5*dx^2={.5*4.43406193516227**2:.12g}`. '
                     'This is above the preregistered E<=3 bound. The campaign therefore does not test that historical critical neighborhood. '
                     'This exclusion is distinct from sampled-state model rejection and from a failed search; the domain was not expanded after observing it.', '']
        else:
            text += ['The proposed route `PIP -> B2 -> F2/H2 -> G2` remains a hypothesis. '
                     'The protected evidence instead records a delayed-PIP -> PK_B2_Parent -> B2 route, with ordinary-PIP/delayed-PIP and PK-family bridges unresolved. '
                     'B2 G/E are reported alternate apex representations of the same cycles, not distinct discoveries; '
                     'their equivalence under the chosen autonomous model still requires corrected full-state rephasing and replay.', '',
                     'The delayed analytic fixture column 1 has y=`1+1e-10`, all-stance contact, and zero rates. '
                     'Its energy is approximately 1.0000000001, below 1.0001. '
                     'The earlier map output had an approximately -0.9934489 time reversal and a spurious near-initial contact; '
                     'it is invalid evidence despite a small endpoint residual. '
                     'The corrected detector rejects that raw root using the existing directed/transverse predicate. '
                     'See `Near_Grazing_Event_Diagnosis_v3.md` and the before/after MAT artifacts. '
                     'This boundary record must not become an accepted delayed-PIP seed or a primitive two-flight orbit.', '',
                     'At positive flight amplitude, the analytic delayed vertical history suppresses the first eligible ascending LO root '
                     'and subsequently enters tensile stance. It is incompatible with this contact law. '
                     'The geometric grazing limit and its multiple covers do not establish a regular bridge. '
                     'This specific obstruction does not exclude every possible nonvertical ordinary-PIP-to-B2 route.', '']
        text += ['The P1/P2 `PK_20_2.mat` source copies have identical SHA-256 '
                 '`45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401`; '
                 'column 1 maps to the same state, mode, parameters and autonomous event log. '
                 'Their two accepted provenance records are a duplicate comparison, not two orbit discoveries. '
                 'This does not identify that family with the distinct `PK_B2_Parent` dataset.', '']
        text += ['## Sampled fixtures and first recorded failure', '',
                 '| Source fixture | Columns | Saved statuses | Initial energies | First recorded failure or unresolved qualification |',
                 '|---|---|---|---|---|']
        for fixture, values in groups.items():
            first = next((r for r in values if r.get('reason')), None)
            reason = first['reason'] if first else 'No saved failure; full hybrid-cycle equivalence and ancestry remain separate checks.'
            statuses = ', '.join(f'{k}: {v}' for k, v in collections.Counter(r['status'] for r in values).items())
            if old:
                statuses = statuses.replace('accepted_uncorrected_seed', 'superseded old acceptance')
            text.append(f'| `{fixture}` | {", ".join(str(r["column"]) for r in values)} | {clean(statuses)} | '
                        f'{", ".join(number(energy(r)) for r in values)} | {clean(reason)} |')
        text += ['', 'A tensile-state or penetration failure is a specific violation of the selected mode domain. '
                 'An invalid initial section can indicate a different apex/chart rather than nonexistence of an orbit. '
                 'A missing return within bounds or a solver stop leaves that search unresolved. '
                 'The table is a bounded column sample, not an exhaustive rejection of every source orbit.', '',
                 '## Autonomous replay versus original cycle', '',
                 '| Source / column | Replay label / primitive diagnostic | Saved residual | Legacy / autonomous period | Contact-history comparison |',
                 '|---|---|---|---|---|']
        for r in valid if not provisional else []:
            c = r.get('classification', {})
            primitive = c.get('primitive', {})
            diagnosis = f'{c.get("label", "unclassified")} / {primitive.get("status", "unassessed")}'
            text.append(f'| `{Path(r["source"]["fixture_path"]).name}` / {r["column"]} | {clean(diagnosis)} | '
                        f'{number(r.get("residual_norm"))} | {number(r.get("legacy_period"))} / {number(r.get("detected_period"))} | '
                        f'{clean(event_compatibility(r))} |')
        if not valid or provisional:
            text.append('| No final acceptance listed | Final replay pending or no admitted source sample | — | — | No equivalence claim |')
        text += ['', 'The contact comparison ignores mere ordering differences inside simultaneous TD/LO ties and compares all event occurrences '
                 'on the time circle at the specified periods. A timing/multiplicity match is a diagnostic, not proof of equal flows, resets, '
                 'GRF or complete hybrid trajectories. The machine-readable first-divergence field compares simultaneous contact clusters '
                 'rather than tie ordering. If the initial state already violates the physical domain, that is the first failure; '
                 'later schedule differences are secondary.', '',
                 '## Reproduction and parent-only discovery', '']
        if p1:
            text += ['P1 requested edges are ordinary PIP -> P1 PK -> BD -> HB_front/HB_hind -> GP, '
                     'including BE/BG/FE/FG/HE/HG/GE/GG subclasses. '
                     'The imported-source replay comparisons supply no daughter attachment or parent-only certificate. '
                     'A separate restricted parent-only ordinary-PIP-to-traveling-pronking experiment is summarized below; '
                     'the subsequent PK -> BD -> half-bound -> GP edges remain unresolved here. '
                     'Both spread orientations must be analyzed in their independent physical directions; a paired parent chart cannot discover them.', '']
        else:
            text += ['F2 means front-spread half-bounding and H2 means hind-spread half-bounding. '
                     'The legacy suffix 2 is a timing heuristic; physical flight count is independently measured over the numerically identified '
                     'primitive cycle. A component may pass through zero-, one- and two-flight segments, and a double cover of a one-flight '
                     'orbit is not a new double-flight gait. Borderline, unclassified and primitive-unknown records remain explicit diagnostics.', '',
                     'Imported B2, PK_B2_Parent or daughter states are seeded comparison inputs, not parent-only discoveries. '
                     'No B2 -> F2, B2 -> H2, F2/H2 -> G2 or root/PK-family bridge is certified by these replay observations. '
                     'Without an admitted B2 parent and validated unrestricted derivative, proceeding with a claimed smooth daughter certificate would '
                     'bypass the model gate. The graph may retain blocked/unresolved candidate edges, not invented branches.', '']
        if local:
            text += ['## Separate restricted parent-only checkpoint', '',
                     f'The saved `Research_v3/runs/full/pip_pk_local.json` status is `{local.get("status")}`, '
                     f'origin `{local.get("origin")}`, and restriction `{local.get("restriction")}`. '
                     f'The artifact reports held-out daughter use as `{local.get("held_out_daughters_used")}`. '
                     'These records are separate from imported-seed replay. A stored restricted attachment status does not establish '
                     'unrestricted contact-cluster smoothness, a theorem-backed pitchfork or ancestry of the imported PK/B2-parent datasets.', '',
                     '| Critical energy | Saved evidence status | Signed amplitude samples | Maximum saved complete-state closure |',
                     '|---|---|---|---|']
            for connection in items(local.get('connections')):
                amplitudes = items(connection.get('amplitudes'))
                closures = [a.get('full_closure') for a in amplitudes if a.get('full_closure') is not None]
                text.append(f'| {number(connection.get("critical_energy"))} | `{connection.get("status")}` | '
                            f'{len(amplitudes)} | {number(max(closures) if closures else None)} |')
            text += ['', 'This is a snapshot of the saved local experiment. Tighter replay, full-trajectory distinctions, '
                     'amplitude convergence, released physical directions and continuation/attachment assessment must be read '
                     'from its final certificates and the overall research status. No P1/P2 network completion follows from this table.', '']
        text += ['## Additional boundary qualification', '',
                 'Ordinary `PIP_10_20_2.mat` column 1 has initial E approximately `1.00000001`, below the registered lower bound. '
                 f'The current saved first BL TD is `{number(nearzero_td)}`, compared with the exact flight benchmark '
                 f'`{number(nearzero_expected)}`. '
                 'The previous detector clustered a nonzero-height guard prematurely at the artificial leave-section stop (`t=1e-7`). '
                 'The regression was reproduced red, then fixed by requiring both surface-value tolerance and root-time proximity '
                 'when the normal velocity is nonzero, with the original direction/tolerance settings retained. '
                 'The final contract tests place all four TD events at the physical root within 1e-9 and preserve ordinary simultaneous contacts. '
                 'The out-of-domain energy qualification remains. Small endpoint closure alone does not certify near-grazing event-time '
                 'accuracy; grazing continuation and ordinary smoothness still require separate treatment.', '']
        text += ['PC/TR/TL remain in the declared target universe and are not certified reached here. '
                 'The conditional local propositions in `Periodic_Orbit_and_Bifurcation_Theory_v3.md` do not imply H_network, H_coverage or H_global.', '',
                 '## Supporting runs and reproducibility', '',
                 f'The saved exact vertical stage status is `{vertical.get("status", "not available")}`; '
                 f'maximum saved period error is {number(vertical.get("max_period_error"))}, '
                 f'closure is {number(vertical.get("max_closure"))}, and energy range is {number(vertical.get("max_energy_range"))}. '
                 'These are vertical-model benchmark observations, not off-synchrony branch connections.', '',
                 f'The fixed-parameter family stage snapshot status is `{fixed.get("status", "not available")}`. '
                 'Its final counts/terminal reasons and accepted physical points must be read from the completed checkpoint; '
                 'a running or budget-ended stage cannot establish branch completeness.', '',
                 'The protected-source manifest is `Research_v3/baseline/source_fixture_manifest.json`. '
                 'Each observation records its immutable in-v3 fixture path, original path, checksum, source HEAD, variable, column, '
                 'model parameter policy and mapped state/mode/parameter. Converted seeds preserve source provenance separately from v3 result identity. '
                 'The local P2 original-run archive was absent in the recorded inventory; no native scheduled campaign execution is claimed.', '',
                 'Run/resume through `python3 SLIP_Quadruped_v3/Research_v3/run_campaign.py --config full --stage compatibility` '
                 'from the repository root (using the driver\'s registered MATLAB environment). '
                 'After a completed corrected-code replay, refresh this report with '
                 '`python3 SLIP_Quadruped_v3/Research_v3/generate_family_reports.py`. '
                 'The source JSON, MAT checkpoints, logs and execution ledger are authoritative for what actually ran. '
                 'Model-gate failures are distinct from physical-boundary results and search-budget limits.', '',
                 f'The generic parent-only stage status is `{parent.get("status", "not available")}`: '
                 f'{parent.get("connection_status", "No completed certificate available.")} '
                 'Its attempt diagnostics are separate from the restricted local pronking study. '
                 f'The corrected compatibility replay uses effective top-level integration RelTol={cfg["integration"]["relative_tolerance"]:g}, '
                 f'AbsTol={cfg["integration"]["absolute_tolerance"]:g}; earlier ODEOptions-only runs were superseded.', '']
        if fixed.get('runs'):
            text += ['## Imported PK continuation segments', '',
                     'These segments hold the ten physical parameters fixed and vary conserved energy within the pronk restriction. '
                     'Their imported seed supplies no ordinary-PIP ancestry. Accepted-point counts include stored restart/seed endpoints; '
                     'they are not counts of distinct gait classes or proof of complete branches.', '',
                     '| Direction | Status | Stored accepted points | Maximum complete-state closure | Stop reason |',
                     '|---|---|---|---|---|']
            for segment in items(fixed.get('runs')):
                text.append(f'| {segment.get("direction")} | `{segment.get("status")}` | {segment.get("accepted_count")} | '
                            f'{number(segment.get("max_full_closure"))} | {clean(segment.get("reason"))} |')
            text += ['', 'See the typed graph and `Branches_v3/index.json` for shared checkpoints. '
                     'Maximum point count is a numerical budget stop, not a demonstrated physical endpoint.\n']
        (DOCS / name).write_text('\n'.join(text))
    print(f'Refreshed P1/P2 reports from compatibility status={report.get("status")}, provisional={provisional}.')


if __name__ == '__main__':
    refresh()
