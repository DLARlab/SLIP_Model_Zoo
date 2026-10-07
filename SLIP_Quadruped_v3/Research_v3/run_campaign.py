#!/usr/bin/env python3
"""Bound MATLAB studies, checkpoint outcomes, and verify protected files."""
from pathlib import Path
import argparse, datetime, hashlib, json, os, subprocess, time

V3 = Path(__file__).resolve().parent.parent
ROOT = V3.parent
STAGES = ['inventory', 'compatibility', 'vertical', 'fixed_family', 'parent_only', 'pip_pk_local', 'floquet']
TERMINAL_BOUNDED_STOPS = {'budget_exhausted','budget_exhausted_during_refinement',
                         'unreliable_critical_refinement','unreliable_critical_derivative'}

def within(path):
    value = Path(path).resolve()
    if not value.is_relative_to(V3):
        raise ValueError(f'Path must resolve within v3: {value}')
    return value

def verify_protected():
    manifest = json.loads((V3/'Research_v3/baseline/protected_manifest.json').read_text())
    cleanup_file = V3/'Research_v3/Audits_v3/Working_Tree_Cleanup_v3.json'
    cleanup = json.loads(cleanup_file.read_text()) if cleanup_file.exists() else {}
    entries = {entry['path']:entry for entry in manifest['entries']}
    authorized = {}
    for change in cleanup.get('authorized_outside_v3_changes', []):
        rel = Path(change['path'])
        if (rel.is_absolute() or '..' in rel.parts or not rel.parts
                or rel.parts[0] in {'SLIP_Quadruped',V3.name,'.git'}
                or change['path'] not in entries
                or change['sha256_before'] != entries[change['path']].get('sha256')):
            raise ValueError(f'Invalid cleanup exception: {change["path"]}')
        authorized[change['path']] = change['sha256_after']
    differences = []
    expected = {e['path'] for e in manifest['entries']}
    actual = set()
    for path in ROOT.rglob('*'):
        rel = path.relative_to(ROOT)
        if '.git' in rel.parts or rel.parts[0] == V3.name:
            continue
        if path.is_file() or path.is_symlink():
            actual.add(str(rel))
    recorded_changes = []
    original_differences = []
    for entry in manifest['entries']:
        path = ROOT/entry['path']
        if 'symlink' in entry:
            same = path.is_symlink() and os.readlink(path) == entry['symlink']
        else:
            same = path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256']
        if not same:
            original_differences.append(entry['path'])
        if entry['path'] in authorized:
            after = authorized[entry['path']]
            accepted = (not path.exists() and not path.is_symlink()) if after is None else (
                path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == after)
            if accepted:
                recorded_changes.append(entry['path'])
            else:
                differences.append(entry['path'])
        elif not same:
            differences.append(entry['path'])
    permitted_missing = {name for name,value in authorized.items() if value is None}
    legacy = {name for name in expected if Path(name).parts[0] == 'SLIP_Quadruped'}
    legacy_actual = {name for name in actual if Path(name).parts[0] == 'SLIP_Quadruped'}
    valid = not differences and actual == expected-permitted_missing
    return {'checked_entries':len(expected),
            'unchanged':not original_differences and actual == expected,
            'verified_with_authorized_cleanup':valid,
            'authorized_cleanup_changes':recorded_changes,
            'legacy_reference_checked_entries':len(legacy),
            'legacy_reference_unchanged':not (legacy & set(original_differences)) and legacy_actual == legacy,
            'changed_or_missing':differences, 'added':sorted(actual-expected),
            'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}

def matlab_quote(value):
    return "'" + str(value).replace("'", "''") + "'"

def verify_fixtures():
    records=json.loads((V3/'Research_v3/baseline/source_fixture_manifest.json').read_text())['records']
    changed=[]
    for entry in records:
        file=within(V3/entry['fixture_path'])
        if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest()!=entry['sha256']:
            changed.append(entry['fixture_path'])
    return {'checked_entries':len(records),'unchanged':not changed,'changed_or_missing':changed}

def charged_seconds(ledger, config_name):
    """Conservatively charge summed process wall time, including retries.

    The append-only ledger is authoritative. Concurrent launchers must not
    overwrite one another's charge with a stale budget_state snapshot.
    """
    if not ledger.exists():
        return 0.0
    return sum(json.loads(line).get('elapsed_seconds', 0.0)
               for line in ledger.read_text().splitlines() if line.strip()
               and json.loads(line).get('config') == config_name)

def save_budget(path, ledger, config_name, last_stage):
    state={'elapsed_seconds':charged_seconds(ledger,config_name),
           'accounting':'sum of completed process wall seconds, including retries',
           'last_stage':last_stage}
    temporary=path.with_name(f'{path.name}.{os.getpid()}.tmp')
    temporary.write_text(json.dumps(state,indent=2)+'\n')
    temporary.replace(path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', choices=['validation','full'], default='validation')
    parser.add_argument('--stage', choices=['all',*STAGES], default='all')
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--verify-only', action='store_true')
    parser.add_argument('--matlab', default='/Applications/MATLAB_R2025b.app/bin/matlab')
    args = parser.parse_args()
    research = V3/'Research_v3'
    protection = verify_protected()
    fixture_verification=verify_fixtures()
    (research/'baseline/fixture_verification.json').write_text(json.dumps(fixture_verification,indent=2)+'\n')
    if not fixture_verification['unchanged']:
        raise SystemExit('Copied source fixtures differ from their provenance manifest.')
    (research/'baseline/protected_verification.json').write_text(json.dumps(protection,indent=2)+'\n')
    if not protection['verified_with_authorized_cleanup']:
        raise SystemExit('Protected content differs from initial manifest; see protected_verification.json')
    if args.verify_only:
        print(json.dumps(protection)); return
    config = within(research/'config'/f'{args.config}.json')
    cfg = json.loads(config.read_text())
    output = within(research/'runs'/args.config); output.mkdir(parents=True,exist_ok=True)
    ledger = research/'execution_ledger.jsonl'
    budget_file = output/'budget_state.json'
    env = os.environ.copy(); env['TMPDIR'] = str(V3/'t');env['MATLAB_PREFDIR']=str(research/'runtime/prefs')
    (V3/'t').mkdir(exist_ok=True)
    stages = STAGES if args.stage == 'all' else [args.stage]
    for stage in stages:
        artifact = output/f'{stage}.json'
        if args.resume and artifact.exists():
            status=json.loads(artifact.read_text()).get('status','')
            if status.startswith('completed') or status in TERMINAL_BOUNDED_STOPS:
                print(f'{stage}: retained {status} checkpoint; omit --resume for an explicit rerun')
                continue
        remaining = cfg['budgets']['total_wall_seconds']-charged_seconds(ledger,args.config)
        if remaining <= 0:
            print('Campaign wall budget exhausted; unresolved stages remain.');break
        per_stage = cfg['budgets']['continuation_wall_seconds'] if stage == 'fixed_family' else 900
        timeout = min(remaining,per_stage+60)
        command = (f"addpath({matlab_quote(research/'Drivers_v3')});"
                   f"RunResearchCampaign_v3({matlab_quote(stage)},{matlab_quote(config)},{matlab_quote(output)});")
        stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        log = within(research/'logs'/f'{args.config}-{stage}-{stamp}.log')
        entry={'stage':stage,'config':args.config,'command':command,'timeout_seconds':timeout,
               'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'configuration_sha256':hashlib.sha256(config.read_bytes()).hexdigest(),
               'log':str(log.relative_to(V3)),'source_fixture_verification':fixture_verification}
        stage_lock=output/f'.{stage}.running.json'
        try:
            with stage_lock.open('x') as handle:
                json.dump({'launcher_pid':os.getpid(),**entry},handle)
        except FileExistsError:
            raise SystemExit(f'Stage already reserved: {stage_lock}. Check its PID before removing a stale lock.')
        timer = time.monotonic()
        try:
            with log.open('w') as handle:
                process = subprocess.Popen([args.matlab,'-batch',command],cwd=V3,env=env,
                                           stdout=handle,stderr=subprocess.STDOUT,start_new_session=True)
                try:
                    entry['exit_code']=process.wait(timeout=timeout)
                    entry['status']='executed' if entry['exit_code']==0 else 'execution_failed'
                except subprocess.TimeoutExpired:
                    import signal
                    os.killpg(process.pid,signal.SIGTERM)
                    try:process.wait(timeout=10)
                    except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait()
                    entry['status']='wall_budget_stop';entry['exit_code']=process.returncode
        except OSError as error:
            entry['status']='resource_unavailable';entry['reason']=str(error)
        finally:
            stage_lock.unlink(missing_ok=True)
        entry['elapsed_seconds']=time.monotonic()-timer
        entry['protected_verification']=verify_protected()
        with ledger.open('a') as handle:handle.write(json.dumps(entry)+'\n')
        save_budget(budget_file,ledger,args.config,stage)
        print(f"{stage}: {entry['status']} in {entry['elapsed_seconds']:.1f}s",flush=True)
        if not entry['protected_verification']['unchanged']:
            raise SystemExit('Protected tree changed during campaign')
    (research/'baseline/protected_verification.json').write_text(json.dumps(verify_protected(),indent=2)+'\n')

if __name__ == '__main__':main()
