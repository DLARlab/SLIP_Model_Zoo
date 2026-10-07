#!/usr/bin/env python3
"""Refresh confined graph, solution and study indexes from saved evidence only.

This is an indexer, not a solver or certificate authority. In particular, a
restricted attachment label never certifies an unrestricted network edge.
"""
from __future__ import annotations

import argparse
import collections
import datetime
import hashlib
import importlib.metadata
import json
import math
import os
from pathlib import Path

V3 = Path(__file__).resolve().parents[1]
RESEARCH = V3 / 'Research_v3'
P1 = 'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits'
P2 = 'P2_All_Common_Quadrupedal_Gaits'
EDGE_TYPES = [
    'validated_regular_symmetry_breaking_connection',
    'other_validated_local_bifurcation',
    'admissible_nonsmooth_itinerary_connection',
    'grazing_zero_duration_boundary_limit',
    'phase_proven_symmetry_equivalence',
    'multiple_cover_identification',
    'numerical_candidate_proximity_only',
]
STAGES = ['inventory', 'compatibility', 'vertical', 'fixed_family',
          'parent_only', 'pip_pk_local', 'floquet']
READ_SNAPSHOTS = {}


def confined(path):
    path = Path(path).resolve()
    if not path.is_relative_to(V3):
        raise ValueError(f'Output/reference must resolve inside v3: {path}')
    return path


def write(path, value):
    path = confined(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    content = value if isinstance(value, str) else json.dumps(value, indent=2, allow_nan=False) + '\n'
    temporary = path.with_name(f'{path.name}.{os.getpid()}.index.tmp')
    temporary.write_text(content)
    temporary.replace(path)


def read(path):
    path = confined(path)
    if not path.exists(): return {}
    content=path.read_bytes()
    value=json.loads(content)
    READ_SNAPSHOTS[path]={'sha256':hashlib.sha256(content).hexdigest(), 'status':value.get('status','not_available'),
                          'finished_utc':value.get('finished_utc')}
    return value


def items(value):
    """MATLAB encodes singleton struct arrays as objects, empties as []."""
    if isinstance(value, dict):
        return [value] if value else []
    return value or []


def artifact(path, kind):
    path = confined(path)
    return {'path': str(path.relative_to(V3)), 'kind': kind, 'exists': path.is_file()}


def source_snapshot(path, value):
    # Fingerprint the exact bytes parsed, even if a running stage checkpoints
    # again between read and index generation.
    parsed=READ_SNAPSHOTS.get(path)
    return {'path': str(path.relative_to(V3)), 'exists':parsed is not None,
            **(parsed or {'sha256':None,'status':'not_available','finished_utc':None})}


def model(cfg):
    return {'id': cfg['model_id'], 'physical_parameter': cfg['baseline_v3_parameters'],
            'parameter_policy': cfg['legacy_parameter_policy'],
            'state_schema_version': 'quadruped-state-v3.1',
            'parameter_schema_version': 'quadruped-parameter-v3.1'}


def initial_energy(x, q, p):
    if len(x) != 14 or len(q) != 4 or len(p) != 10:
        return None
    result = .5 * (x[1]**2 + x[3]**2 + p[8]*x[5]**2) + x[2]
    for leg in range(4):
        if q[leg]:
            offset = -p[9] if leg < 2 else 1-p[9]
            denominator = math.cos(x[4] + x[6+2*leg])
            if abs(denominator) < 1e-12:
                return None
            length = (x[2] + offset*math.sin(x[4])) / denominator
            rest, stiffness = (p[4], p[0]) if leg < 2 else (p[5], p[1])
            result += .5 * stiffness * (rest-length)**2
    return result


def base_solution(identifier, cfg, origin, study, x, q, p, classification):
    primitive = classification.get('primitive', {})
    period = primitive.get('primitive_period')
    drift = primitive.get('primitive_drift')
    E = initial_energy(x, q, p)
    bound = cfg['domain']['energy']
    baseline_match = len(p) == 10 and all(abs(a-b) <= 1e-12 for a, b in zip(p, cfg['baseline_v3_parameters']))
    return {
        'id': identifier, 'status': 'summary_only', 'origin': origin, 'study': study,
        'model': {**model(cfg), 'physical_parameter': p or cfg['baseline_v3_parameters']},
        'source_provenance': [], 'initial_state': x if len(x) == 14 else None,
        'initial_mode': [bool(v) for v in q] if len(q) == 4 else None,
        'initial_energy': E,
        'initial_energy_parameter_bounds_admitted': E is not None and baseline_match and bound[0] <= E <= bound[1],
        'domain_qualification': 'Initial energy/parameter bounds only; complete geometry, margins and guard ownership remain separate.',
        'section_chart': {'status': 'artifact_reference_required',
                          'return_policy': 'EventCycleReturnPolicy_v3',
                          'section': 'downward apex', 'local_chart': None},
        'period': {'recorded': primitive.get('recorded_period'), 'primitive': period,
                   'cover_count': primitive.get('cover_count'),
                   'diagnostic_status': primitive.get('status', 'unknown'),
                   'checked_cover_bound': primitive.get('checked_cover_bound'),
                   'global_primitivity_proved': primitive.get('global_primitivity_proved', False)},
        'drift': drift, 'mean_speed': drift/period if period and drift is not None else None,
        'event_log': [], 'event_word': [],
        'cluster_data': {'status': 'artifact_reference_required',
                         'classification_clusters': classification.get('event_clusters'),
                         'ownership_batches': None},
        'flight': {'count': classification.get('flight_count'),
                   'definition': 'Positive all-flight intervals on the numerically identified primitive time circle.',
                   'status': 'measured' if classification.get('flight_count') is not None else 'unknown',
                   'intervals': classification.get('flight_intervals_on_circle'),
                   'sensitivity': classification.get('flight_count_sensitivity')},
        'gait': {'label': classification.get('label', 'unclassified'),
                 'status': classification.get('status', 'unassessed'),
                 'descriptive_only': True, 'isotropy_proved': classification.get('isotropy_proved', False)},
        'symmetry_residuals': {key: classification.get(key) for key in
                              ['contact_sync_errors', 'motion_sync_errors',
                               'left_right_half_phase_contact_errors', 'left_right_half_phase_motion_errors']},
        'physical_margins': {'status': 'artifact_reference_required', 'minimum_physical_margin': None,
                             'minimum_guard_transversality': None, 'guard_residuals': None},
        'solver_settings': {'integration': cfg['integration'], 'closure_target': 1e-8,
                            'residual_scaling': 'See saved details and registered driver; index does not recompute scaling.'},
        'residual': {'reported_norm': None, 'raw_components': None,
                     'complete_state_closure': None, 'status': 'not_extracted'},
        'derivative_diagnostics': {'status': 'not_assessed_for_this_summary', 'artifact_refs': []},
        'branch_neighbors': [], 'parent_edge_certificates': [], 'artifacts': [],
        'missing_evidence': ['JSON is a summary, not a complete acceptance certificate.',
                             'Raw residual components, physical margins, one-sided guard/reset ownership and complete traces are in MAT artifacts.'],
    }


def solution_registry(cfg, reports, run, snapshots):
    records = []
    manifest = read(RESEARCH/'baseline/source_fixture_manifest.json').get('records', [])
    fixture_ids = {r['fixture_path']: i for i, r in enumerate(manifest, 1)}
    for index, row in enumerate(items(reports['compatibility'].get('observations')), 1):
        c = row.get('classification', {})
        s = base_solution(f'imported-{index:03d}', cfg, 'imported_seed', row['source']['study'],
                          row.get('initial_state', []), row.get('initial_mode', []), row.get('physical_parameter', []), c)
        s['status'] = row['status']
        s['source_provenance'] = [{**row['source'], 'variable': row.get('variable'), 'column': row['column'],
                                   'role': 'immutable source comparison; no inherited ancestry'}]
        s['period']['recorded'] = row.get('detected_period')
        s['event_log'] = row.get('events', [])
        s['event_word'] = [e['type'] for e in s['event_log']]
        s['residual']['reported_norm'] = row.get('residual_norm')
        s['residual']['status'] = 'saved_driver_norm' if row.get('residual_norm') is not None else 'unavailable'
        s['failure_reason'] = row.get('reason', '')
        s['legacy_comparison'] = {'period': row.get('legacy_period'),
                                  'scheduled_events_diagnostic_only': row.get('scheduled_events', []),
                                  'first_divergence': row.get('first_divergence', {})}
        if s['status'] == 'accepted_autonomous_seed':
            k = fixture_ids[row['source']['fixture_path']]
            s['artifacts'].append(artifact(run/f'fixture_{k:02d}_{row["column"]:05d}.mat', 'full replay orbit and details'))
        records.append(s)
    for index, point in enumerate(items(reports['vertical'].get('points')), 1):
        x = [0.0]*14
        x[2] = point['energy']
        s = base_solution(f'root-vertical-{index:02d}', cfg, 'parent_only_root', 'shared', x, [False]*4,
                          cfg['baseline_v3_parameters'], point.get('classification', {}))
        s['status'] = 'numerical_vertical_benchmark'
        s['source_provenance'] = [{'role': 'Analytic root construction independently specified in vertical driver.',
                                   'source_path': 'Research_v3/Drivers_v3/RunResearchCampaign_v3.m', 'point': index}]
        s['residual'].update(reported_norm=point.get('closure'), status='saved_driver_norm')
        s['artifacts'] = [artifact(run/f'vertical_{index:02d}.mat', 'full root orbit and benchmark')]
        s['benchmark'] = {k: point.get(k) for k in ['energy', 'analytic_period', 'period_error', 'energy_range']}
        records.append(s)
    return {'schema_version': 'research-solutions-v3-1', 'model': model(cfg),
            'source_snapshots': snapshots, 'records': records,
            'authoritative_replay_index': artifact(run/'solution_index.json', 'independent tighter replay with complete indexed orbit evidence'),
            'evidence_policy': 'A saved autonomous seed acceptance is not a branch-edge certificate. Unknown evidence is explicit null; complete MAT artifacts remain authoritative.'}


def build_graph(cfg, reports, solutions, snapshots, run_name):
    nodes, edges = [], []
    m = model(cfg)
    def node(identifier, label, origin='hypothesis', status='unresolved', restricted=False, solution_ids=None, notes=''):
        nodes.append({'id': identifier, 'label': label, 'origin': origin, 'status': status,
                      'model': m, 'restricted': restricted, 'solution_ids': solution_ids or [], 'notes': notes})
    def edge(identifier, a, b, reason, scope='required_network', intended=EDGE_TYPES[0], source_status='unresolved', refs=None):
        edges.append({'id': identifier, 'source': a, 'target': b,
                      'type': EDGE_TYPES[-1], 'intended_type': intended,
                      'status': 'unresolved', 'source_status': source_status,
                      'scope': scope, 'counts_toward_regular_network': False,
                      'counts_toward_nonsmooth_connectivity': False,
                      'actual_isotropy_change': {'status': 'unassessed', 'parent': None, 'daughter': None},
                      'regularity': {'classical_full_derivative_validated': False,
                                     'restriction': 'No full admissible smoothness certificate.'},
                      'reason': reason, 'artifact_refs': refs or
                      [f'Research_v3/runs/{run_name}/compatibility.json',
                       f'Research_v3/runs/{run_name}/parent_only.json',
                       f'Research_v3/runs/{run_name}/floquet.json'],
                      'evidence_directory': f'Research_v3/graph/edges/{identifier}'})
    root_ids = [s['id'] for s in solutions['records'] if s['origin'] == 'parent_only_root']
    node('root-PIP', 'ordinary vertical PIP root', 'parent_only', 'numerical_root_benchmarks', True, root_ids,
         'Synchrony is an invariant restriction, not a full contact-cluster derivative certificate.')
    for identifier, label in [('P1-PK','P1 traveling-pronking family'), ('P1-BD','P1 bounding'),
                              ('P1-HB-front','P1 front-spread half-bound'), ('P1-HB-hind','P1 hind-spread half-bound'),
                              ('P1-GP','P1 galloping'), ('P2-B2','P2 B2 component'),
                              ('P2-F2','P2 front-spread two-flight target'), ('P2-H2','P2 hind-spread two-flight target'),
                              ('P2-G2','P2 two-flight galloping target'), ('delayed-PIP','delayed vertical PIP historical family'),
                              ('PK-B2-parent','distinct historical PK_B2_Parent family'),
                              ('PC','PC target'), ('TR','TR target'), ('TL','TL target')]:
        node(identifier, label, notes='Target/history name only; does not prescribe dynamics, isotropy or measured flight count.')
    desired = [('PIP-to-P1-PK','root-PIP','P1-PK'), ('P1-PK-to-BD','P1-PK','P1-BD'),
               ('P1-BD-to-HB-front','P1-BD','P1-HB-front'), ('P1-BD-to-HB-hind','P1-BD','P1-HB-hind'),
               ('P1-HB-front-to-GP','P1-HB-front','P1-GP'), ('P1-HB-hind-to-GP','P1-HB-hind','P1-GP'),
               ('PIP-to-B2','root-PIP','P2-B2'), ('B2-to-F2','P2-B2','P2-F2'),
               ('B2-to-H2','P2-B2','P2-H2'), ('F2-to-G2','P2-F2','P2-G2'), ('H2-to-G2','P2-H2','P2-G2')]
    for identifier, a, b in desired:
        edge(identifier, a, b, 'Requested hypothesis edge; no admissible fixed-model attachment certificate in these saved results.')
    for suffix in ['BE','BG','FE','FG','HE','HG','GE','GG']:
        identifier = f'P1-subclass-{suffix}'
        node(identifier, f'P1 historical {suffix} subclass', notes='Local physical subspace and attachment unresolved; source label is not an isotropy proof.')
        edge(f'P1-BD-to-{suffix}', 'P1-BD', identifier,
             'Actual repository subclass retained. Its source sample fails the selected model/domain; local attachment and destination class require new evidence.',
             scope='subclass_hypothesis', intended=EDGE_TYPES[-1])
    edge('ordinary-to-delayed-PIP','root-PIP','delayed-PIP',
         'Positive-amplitude analytic delayed history suppresses first eligible LO and reaches tensile stance. Grazing geometry does not establish an admissible regular bridge.',
         scope='boundary_bridge', intended=EDGE_TYPES[3], source_status='specific_vertical_history_incompatible')
    edge('delayed-PIP-to-PK-B2','delayed-PIP','PK-B2-parent',
         'Historical route; sampled delayed and PK_B2_Parent states are rejected under this v3 contact law.', scope='historical_route')
    edge('PK-B2-to-B2','PK-B2-parent','P2-B2','Historical route not regenerated as an admissible v3 connection.',scope='historical_route')
    edge('P1-PK-to-PK-B2','P1-PK','PK-B2-parent','Matching PK labels do not establish the same connected component.',scope='required_bridge')
    node('B2-apex-G','B2 historical G apex view', notes='Source-reported alternate apex; sampled fixtures rejected in v3.')
    node('B2-apex-E','B2 historical E apex view', notes='Source-reported alternate apex; sampled fixtures rejected in v3.')
    edge('B2-G-E-phase','B2-apex-G','B2-apex-E','Historical phase equivalence remains to be replayed on an admitted v3 full orbit.',scope='equivalence',intended=EDGE_TYPES[4])
    node('grazing-cover-limit','zero-flight grazing / possible cover limit','boundary_hypothesis',notes='Excluded below registered energy lower bound; limiting trace does not identify a primitive period.')
    edge('ordinary-grazing-limit','root-PIP','grazing-cover-limit','No boundary continuation certificate in the registered positive-amplitude domain.',scope='boundary_bridge',intended=EDGE_TYPES[3])
    edge('delayed-cover-limit','delayed-PIP','grazing-cover-limit','A limiting multiple-cover interpretation requires full state/mode history; invalid nearzero delayed replay is excluded.',scope='boundary_bridge',intended=EDGE_TYPES[5])
    # Imported rows cannot become parent-only descendants just because they close.
    groups = collections.defaultdict(list)
    for s in solutions['records']:
        if s['origin'] == 'imported_seed':
            groups[(s['source_provenance'][0]['sha256'], s['source_provenance'][0]['column'])].append(s)
    duplicate_annotations = []
    for group in groups.values():
        if not any(s['status'] == 'accepted_autonomous_seed' for s in group):
            continue
        first = group[0]
        identifier = 'source-' + first['id']
        node(identifier, first['gait']['label'] + ' imported replay', 'imported_seed', 'autonomous_seed_replay', False,
             [s['id'] for s in group], 'Imported evidence is disconnected from ancestry until a separate attachment is validated.')
        if len(group) > 1:
            duplicate_annotations.append({'node_id': identifier, 'solution_ids': [s['id'] for s in group],
                                          'source_sha256': first['source_provenance'][0]['sha256'],
                                          'reason': 'Identical fixture bytes and sampled column; duplicate PK provenance, not two discoveries or PK_B2_Parent equivalence.'})
    fixed=reports['fixed_family']
    for segment in items(fixed.get('runs')):
        direction=segment['direction']
        node(f'imported-PK-continuation-{direction:+d}',f'imported PK continuation direction {direction:+d}',
             'imported_seed',segment.get('status','unresolved'),True,
             notes='Same fixed physical parameters; continued from imported PK, with no PIP-root attachment. Numerical stop is not a physical branch endpoint.')
        nodes[-1]['artifact_refs']=[f'Research_v3/runs/{run_name}/family_{direction:+d}.mat']
        nodes[-1]['branch_summary']={key:segment.get(key) for key in
                                     ['direction','accepted_count','max_full_closure','energy','reason']}
    local = reports['pip_pk_local']
    connections = items(local.get('connections'))
    # Always show the ongoing restricted experiment even before its first result.
    for index, connection in enumerate(connections or [{}], 1):
        identifier = f'parent-only-PK-{index}'
        node(identifier, f'restricted traveling-pronk candidate {index}', 'parent_only',
             connection.get('status', local.get('status', 'not_available')), True,
             notes='Current experiment status is displayed verbatim. Final local assessment is pending; no inherited imported-PK identity.')
        edge(f'restricted-PIP-PK-{index}','root-PIP',identifier,
             'Restricted synchrony experiment only. Source support, if reported, does not certify the unrestricted requested network or identify either imported PK family.',
             scope='restricted_local_experiment', source_status=connection.get('status', local.get('status', 'not_available')),
             refs=['Research_v3/runs/'+run_name+'/pip_pk_local.json'])
        e = edges[-1]
        e['regularity']['restriction'] = local.get('restriction','pronk invariant subspace; split-contact derivative unproved')
        e['local_evidence_summary'] = {'critical_energy': connection.get('critical_energy'),
                                       'signed_amplitude_count': len(items(connection.get('amplitudes'))),
                                       'validation_version': local.get('validation_settings', {}).get('validation_version'),
                                       'stage_status': local.get('status','not_available')}
    return {'schema_version':'research-ancestry-graph-v3-1', 'model':m, 'domain':cfg['domain'],
            'source_snapshots':snapshots, 'nodes':nodes, 'edges':edges,
            'duplicate_annotations':duplicate_annotations,
            'hypotheses': {'H_local':'Local connections must be certified at their stated level.',
                           'H_network':'Required routes descend from one ordinary PIP root at fixed model/physical parameters.',
                           'H_coverage':'All registered target classes must be reached, including PC/TR/TL.',
                           'H_global':'Not assessed; no exhaustive/global theorem claimed.'},
            'connectivity_policy': {'regular_edge_types':EDGE_TYPES[:2],
                                    'additional_nonsmooth_edge_types':[EDGE_TYPES[2]],
                                    'boundary_equivalence_cover_edges_alone_do_not_establish_ancestry':True},
            'counts': {'verified_regular_edges':0, 'verified_nonsmooth_edges':0,
                       'unresolved_edges':len(edges),
                       'imported_replay_nodes':sum(n['status']=='autonomous_seed_replay' for n in nodes),
                       'imported_continuation_segments':sum(n['id'].startswith('imported-PK-continuation-') for n in nodes)},
            'conclusion':'Network and coverage unresolved. Restricted candidate statuses are dynamic observations, not final unrestricted certificates.'}


def validate(graph, solutions, replayed=None):
    from jsonschema import Draft202012Validator
    validations=[]
    validators={}
    documents=[('ancestry_graph', graph), ('solutions', solutions)]
    if replayed: documents.append(('replayed_solution_index',replayed))
    for name, data in documents:
        schema=read(RESEARCH/'schemas'/f'{name}.schema.json')
        Draft202012Validator.check_schema(schema)
        errors=list(Draft202012Validator(schema).iter_errors(data))
        if errors:
            raise ValueError('\n'.join(f'{name} {list(e.path)}: {e.message}' for e in errors))
        validators[name]=Draft202012Validator(schema)
        validations.append({'document':name, 'schema_valid':True})
    invalid_edge={**graph['edges'][0],'counts_toward_regular_network':True}
    if not list(validators['ancestry_graph'].iter_errors({**graph,'edges':[invalid_edge]})):
        raise ValueError('Schema failed the unresolved-edge negative control.')
    if solutions['records']:
        invalid_record={**solutions['records'][0],'initial_state':[0]*13}
        if not list(validators['solutions'].iter_errors({**solutions,'records':[invalid_record]})):
            raise ValueError('Schema failed the malformed-state negative control.')
    node_ids={n['id'] for n in graph['nodes']}
    solution_ids={s['id'] for s in solutions['records']}
    semantic = {
        'unique node/solution IDs':len(node_ids)==len(graph['nodes']) and len(solution_ids)==len(solutions['records']),
        'unique edge IDs':len({e['id'] for e in graph['edges']})==len(graph['edges']),
        'edge endpoints':all(e['source'] in node_ids and e['target'] in node_ids for e in graph['edges']),
        'solution references':all(set(n['solution_ids']) <= solution_ids for n in graph['nodes']),
        'no provisional connectivity':not any(e['counts_toward_regular_network'] or e['counts_toward_nonsmooth_connectivity'] for e in graph['edges']),
        'fixed model identity':all(n['model']==graph['model'] for n in graph['nodes']),
    }
    failures=[name for name,passed in semantic.items() if not passed]
    if failures: raise ValueError(f'Graph semantic validation failed: {failures}')
    for n in graph['nodes']:
        for reference in n.get('artifact_refs',[]): confined(V3/reference)
    for e in graph['edges']:
        confined(V3/e['evidence_directory'])
        for reference in e['artifact_refs']: confined(V3/reference)
    for s in solutions['records']:
        for a in s['artifacts']: confined(V3/a['path'])
    if replayed:
        rows=items(replayed.get('solutions'))
        if len({r['id'] for r in rows}) != len(rows):
            raise ValueError('Independent replay index contains duplicate record IDs.')
        for r in rows:
            for key in ['artifact','derivative_diagnostics_artifact','parent_edge_certificate']:
                confined(V3/r[key])
            if r['model_id'] != graph['model']['id'] or r['physical_parameter'] != graph['model']['physical_parameter']:
                raise ValueError('Independent replay index has a different fixed-model/parameter identity.')
        if replayed.get('status')=='completed_validation':
            if replayed.get('count') != len(rows) or replayed.get('failed_replay_count') != sum(not r['replay_passed'] for r in rows):
                raise ValueError('Independent replay counts disagree with the recorded rows.')
    return {'schema_version':'research-index-validation-v3-1', 'validator':'jsonschema',
            'validator_version':importlib.metadata.version('jsonschema'), 'checks':validations,
            'semantic_checks': ['unique IDs','edge endpoints','solution references','fixed model identity',
                                'no provisional edge counted as verified','artifact paths confined inside v3'],
            'negative_controls':['unresolved edge counted as regular rejected', '13-coordinate state rejected'],
            'solution_count':len(solution_ids), 'node_count':len(node_ids), 'edge_count':len(graph['edges'])}


def study_indexes(cfg, reports, graph, solutions, run):
    for study in [P1,P2]:
        short='P1' if study==P1 else 'P2'
        members=[s for s in solutions['records'] if s['study']==study]
        stage_refs=[artifact(run/f'{stage}.json',stage) for stage in STAGES]
        local_refs=[artifact(path,'restricted parent-only checkpoint') for path in sorted(run.glob('pronk_*.mat'))]
        local_refs += [artifact(path,'generic parent-only prediction/attempt') for path in sorted(run.glob('parent_*.mat'))]
        branch_refs=[artifact(path,'imported PK continuation; no root ancestry') for path in sorted(run.glob('family_*.mat'))]
        index={'schema_version':'study-reference-index-v3-1','study':study,
               'model':model(cfg),'solution_ids':[s['id'] for s in members],
               'accepted_seed_ids':[s['id'] for s in members if s['status']=='accepted_autonomous_seed'],
               'graph':'Research_v3/graph/index.json', 'solutions':'Research_v3/graph/solutions.json',
               'independent_replay_index':artifact(run/'solution_index.json','complete independent replay index'),
               'stage_refs':stage_refs, 'branch_refs':branch_refs,'parent_only_refs':local_refs,
               'policy':'References only. Imported fixed-family checkpoints and parent-only checkpoints are distinct origins; no artifacts copied.'}
        for folder, refs in [('Branches_v3', branch_refs+local_refs),('Checkpoints_v3',stage_refs),
                             ('Validation_v3',[artifact(RESEARCH/'graph/validation.json','schema validation')])]:
            write(V3/study/folder/'index.json',{**index,'artifact_refs':refs})
        figures=[artifact(path,'shared research figure') for path in sorted((RESEARCH/'Figures_v3').glob('*')) if path.is_file()]
        write(V3/study/'Figures_v3/index.json',{**index,'artifact_refs':figures,
              'status':'Shared export references; no additional plot run claimed by this index.'})
        report_name='P1_Reproduction_Report_v3.md' if short=='P1' else 'P2_Discovery_Report_v3.md'
        write(V3/study/'Reports_v3/index.md',f'# {short} study evidence\n\n'
              f'- [Current {short} report](../../Docs_v3/{report_name})\n'
              '- [Typed ancestry graph](../../Docs_v3/Ancestry_Graph_v3.md)\n'
              '- [Solution/graph schemas](../../Docs_v3/Research_Evidence_Schemas_v3.md)\n'
              '- [Branch/checkpoint references](../Branches_v3/index.json)\n\n'
              'From this driver directory, run `python3 run_study.py --stage refresh` to rebuild the saved-evidence indexes. '
              'The shared JSON/MAT outputs remain authoritative; this folder contains no copied branch traces.\n')
        config={'schema_version':'study-config-reference-v3-1','study':study,
                'registered_config':'Research_v3/config/full.json','validation_config':'Research_v3/config/validation.json',
                'model_id':cfg['model_id'],'allowed_stages':STAGES+['refresh'],
                'output_policy':'Shared launcher confines every output to v3. Compatibility runs both studies to avoid duplicate campaign execution.',
                'domain_policy':'Registered shared bounds and physical parameters; no study override.'}
        write(V3/study/'Config_v3/config.json',config)
        write(V3/study/'Configurations_v3/index.json',config)


def graph_report(graph, reports):
    local=reports['pip_pk_local']
    lines=['# Typed ancestry graph', '',
           'Generated from saved JSON by `Research_v3/generate_research_index.py`. This graph records hypotheses and evidence; '
           'it does not run experiments or grant numerical certification.', '',
           f'The current restricted PIP→PK stage status is `{local.get("status","not_available")}`. '
           'Each candidate displays its current source status. Earlier exploratory reports are not promoted to final certificates.', '',
           'The ordinary PIP root is supported by independent vertical benchmarks. Imported autonomous replay nodes are separate '
           'from parent-only nodes. Identical P1/P2 PK source bytes are annotated as duplicate provenance. '
           'The P1 PK family and PK_B2_Parent remain separate until an attachment or full-orbit equivalence is demonstrated.', '',
           '```mermaid','flowchart LR',
           '  PIP[ordinary PIP root] -. unresolved .-> PK[P1 PK]',
           '  PK -. unresolved .-> BD[P1 BD]',
           '  BD -. unresolved .-> HF[HB front]', '  BD -. unresolved .-> HH[HB hind]',
           '  HF -. unresolved .-> GP[P1 GP]', '  HH -. unresolved .-> GP',
           '  PIP -. unresolved .-> B2[P2 B2]', '  B2 -. unresolved .-> F2[front spread F2]',
           '  B2 -. unresolved .-> H2[hind spread H2]', '  F2 -. unresolved .-> G2[P2 G2]',
           '  H2 -. unresolved .-> G2', '  PIP -. restricted candidates .-> RPK[parent only traveling pronk]',
           '  IPK[imported PK replay duplicate provenance]', '  PC[PC unreached]', '  TR[TR unreached]', '  TL[TL unreached]',
           '```','',
           'Solid certified ancestry edges are currently absent. Dotted edges are unresolved, and names do not impose contact history '
           'or verified flight count. BE/BG/FE/FG/HE/HG/GE/GG, historical delayed bridges and B2 G/E phase equivalence are retained '
              'in the machine graph as separate unresolved records.', '',
           'Regular connectivity accepts validated regular symmetry-breaking or other validated local bifurcation edges. '
           'A separately assessed nonsmooth connectivity statement may additionally use admissible itinerary connections. '
           'Grazing limits, phase equivalences, multiple covers and numerical proximity alone do not establish ancestry. '
           'No graph edge presently counts toward either connectivity claim.', '',
           '| Edge | Actual evidence type | Intended type | Current source status | Scope |',
           '|---|---|---|---|---|']
    for e in graph['edges']:
        lines.append(f'| `{e["id"]}` | `{e["type"]}` | `{e["intended_type"]}` | `{e["source_status"]}` | `{e["scope"]}` |')
    lines += ['', 'Each edge has a small evidence directory under `Research_v3/graph/edges/`; the JSON points to shared campaign artifacts '
              'instead of duplicating trajectories. `Research_v3/graph/index.json`, `solutions.json`, and `validation.json` '
              'contain the graph, indexed solution summaries, and actual schema/semantic validation results.', '',
              'The complete independent replay evidence is `Research_v3/runs/full/solution_index.json` when present. '
              'Its dedicated schema is validated by the same refresh command. A parent-edge graph reference is not itself a parent-edge certificate.', '',
              'Refresh after final numerical stages with `python3 SLIP_Quadruped_v3/Research_v3/generate_research_index.py --config full` '
              'and `python3 SLIP_Quadruped_v3/Research_v3/generate_family_reports.py`. '
              'The graph status remains unresolved until a separate final assessment supplies the required certificates.\n']
    return '\n'.join(lines)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',choices=['validation','full'],default='full')
    parser.add_argument('--validate-only',action='store_true')
    args=parser.parse_args()
    run=confined(RESEARCH/'runs'/args.config)
    cfg=read(RESEARCH/'config'/f'{args.config}.json')
    reports={stage:read(run/f'{stage}.json') for stage in STAGES}
    snapshots=[source_snapshot(run/f'{stage}.json',reports[stage]) for stage in STAGES]
    replayed=read(run/'solution_index.json')
    snapshots.append(source_snapshot(run/'solution_index.json',replayed))
    solutions=solution_registry(cfg,reports,run,snapshots)
    graph=build_graph(cfg,reports,solutions,snapshots,args.config)
    validation=validate(graph,solutions,replayed)
    validation['source_snapshots']=snapshots
    validation['generated_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
    if not args.validate_only:
        write(RESEARCH/'graph/solutions.json',solutions)
        write(RESEARCH/'graph/index.json',graph)
        write(RESEARCH/'graph/ancestry_graph.json',graph)
        write(RESEARCH/'graph/validation.json',validation)
        for edge in graph['edges']:
            directory=V3/edge['evidence_directory']
            write(directory/'evidence.json',{**edge,'source_snapshots':snapshots})
            write(directory/'README.md',f'# {edge["id"]}\n\nStatus: `{edge["status"]}`; saved source status: `{edge["source_status"]}`.\n\n'
                  f'{edge["reason"]}\n\nSee `evidence.json` for typed evidence, shared references and source fingerprints. '
                  'This directory contains no invented branch or copied trajectory.\n')
        study_indexes(cfg,reports,graph,solutions,run)
        write(V3/'Docs_v3/Ancestry_Graph_v3.md',graph_report(graph,reports))
    print(f'Validated {validation["solution_count"]} solution summaries, {validation["node_count"]} nodes and {validation["edge_count"]} unresolved edges; local stage={reports["pip_pk_local"].get("status","not_available")}.')


if __name__=='__main__': main()
