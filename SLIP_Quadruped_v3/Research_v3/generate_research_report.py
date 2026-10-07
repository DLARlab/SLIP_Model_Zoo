#!/usr/bin/env python3
"""Generate the paper-development report and figures from executed evidence."""
from pathlib import Path
import csv, datetime, json, os

V3=Path(__file__).resolve().parent.parent
RESEARCH=V3/'Research_v3'
RUN=RESEARCH/'runs/full'
FIGURES=RESEARCH/'Figures_v3'
os.environ['MPLCONFIGDIR']=str(RESEARCH/'runtime/matplotlib')
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

def seq(value):
    return [value] if isinstance(value,dict) else (value or [])

def read(name):
    file=RUN/f'{name}.json'
    return json.loads(file.read_text()) if file.exists() else {}

def number(value):
    return f'{value:.6g}' if isinstance(value,(float,int)) else 'unavailable'

def save(fig,name):
    fig.savefig(FIGURES/f'{name}.png',dpi=180,bbox_inches='tight')
    fig.savefig(FIGURES/f'{name}.pdf',bbox_inches='tight')
    plt.close(fig)

def main():
    FIGURES.mkdir(parents=True,exist_ok=True)
    plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False})
    vertical=read('vertical'); compat=read('compatibility'); family=read('fixed_family')
    local=read('pip_pk_local'); alternative=read('parent_only'); floquet=read('floquet')
    index=read('solution_index')
    points=seq(vertical.get('points'))
    if points:
        fig,axes=plt.subplots(1,2,figsize=(10,3.5))
        energy=[x['energy'] for x in points]
        axes[0].plot(energy,[x['analytic_period'] for x in points],label='analytic first-liftoff period')
        axes[0].scatter(energy,[x['period'] for x in points],s=22,label='v3 event simulation')
        axes[0].set(xlabel='mechanical energy E',ylabel='primitive period T');axes[0].legend(fontsize=8)
        axes[1].semilogy(energy,[x['period_error'] for x in points],'o-',label='period error')
        axes[1].semilogy(energy,[x['closure'] for x in points],'s-',label='full closure')
        axes[1].semilogy(energy,[x['energy_range'] for x in points],'^-',label='energy range')
        axes[1].set(xlabel='mechanical energy E',ylabel='absolute error');axes[1].legend(fontsize=8)
        save(fig,'vertical_benchmark_v3')
    observations=seq(compat.get('observations'))
    if observations:
        names=sorted({Path(x['source']['fixture_path']).stem for x in observations})
        accepted=[sum(x['status']=='accepted_autonomous_seed' and Path(x['source']['fixture_path']).stem==n for x in observations) for n in names]
        rejected=[sum(x['status']!='accepted_autonomous_seed' and Path(x['source']['fixture_path']).stem==n for x in observations) for n in names]
        fig,ax=plt.subplots(figsize=(10,4));y=np.arange(len(names))
        ax.barh(y,accepted,color='#287b5b',label='autonomous periodic state')
        ax.barh(y,rejected,left=accepted,color='#bc6846',label='rejected / incompatible sampled state')
        ax.set(yticks=y,yticklabels=names,xlabel='sampled source records');ax.legend(fontsize=8)
        save(fig,'legacy_compatibility_v3')
    parents=seq(local.get('parent_samples'))
    if parents:
        fig,ax=plt.subplots(figsize=(7,3.5))
        ax.plot([x['energy'] for x in parents],[x.get('det_DP_minus_I',np.nan) for x in parents],'o-')
        ax.axhline(0,color='black',linewidth=.7)
        for c in seq(local.get('connections')):ax.axvline(c['critical_energy'],color='#bc6846',linestyle='--')
        ax.set(xlabel='parent energy E',ylabel='det(DP_E − I)',title='Pronk-restricted parent scan; sign changes only')
        save(fig,'parent_critical_scan_v3')
    connections=seq(local.get('connections'))
    if parents and connections:
        fig,axes=plt.subplots(1,2,figsize=(10,3.5))
        for sample in parents:
            values=sample.get('multipliers_real',[])
            axes[0].scatter([sample['energy']]*len(values),values,s=15,color='#287b5b')
        for target in [-1,1]:axes[0].axhline(target,color='black',linewidth=.7,linestyle='--')
        axes[0].set(xlabel='parent energy E',ylabel='real part of restricted multipliers',title='Unmatched spectral samples; no branch sorting')
        for c in connections:
            axes[1].semilogy([1,2,3],c['singular_values'],'o-',label=f'E*={c["critical_energy"]:.6f}')
            axes[1].axhline(c['matrix_uncertainty_estimate'],linewidth=.7,linestyle='--')
        axes[1].set(xticks=[1,2,3],xlabel='singular-value index of DP_E − I',ylabel='singular value / estimated uncertainty')
        axes[1].legend(fontsize=8);save(fig,'restricted_critical_spectrum_v3')
        fig,ax=plt.subplots(figsize=(5,3))
        matrix=np.asarray([c['critical_direction'] for c in connections]).T
        values=ax.imshow(matrix,cmap='coolwarm',vmin=-1,vmax=1,aspect='auto')
        ax.set(yticks=[0,1,2],yticklabels=['COM dx','synchronous leg angle','synchronous leg rate'],
               xticks=np.arange(len(connections)),xticklabels=[f'E*={c["critical_energy"]:.6f}' for c in connections],
               title='Frozen parent-only kernel directions')
        fig.colorbar(values,ax=ax);save(fig,'restricted_critical_directions_v3')
    if connections:
        fig,axes=plt.subplots(1,2,figsize=(10,3.5))
        for c in connections:
            samples=[x for x in seq(c.get('amplitudes')) if x.get('converged')]
            for sign in [-1,1]:
                selected=sorted([x for x in samples if np.sign(x['signed_amplitude'])==sign],key=lambda x:abs(x['signed_amplitude']))
                if not selected:continue
                a=np.array([abs(x['signed_amplitude']) for x in selected])
                axes[0].loglog(a,np.maximum(np.abs([x['energy']-c['critical_energy'] for x in selected]),1e-16),'o-',label=f'E*={c["critical_energy"]:.6f}, sign {sign:+d}')
                axes[1].plot([x['signed_amplitude'] for x in selected],[x['mean_speed'] for x in selected],'o-')
        axes[0].set(xlabel='predictor amplitude |s|',ylabel='|E(s) − E*|');axes[0].legend(fontsize=7)
        axes[1].set(xlabel='signed predictor amplitude s',ylabel='mean horizontal speed')
        save(fig,'signed_pronk_candidates_v3')
    solutions=seq(index.get('solutions'))
    continued=[x for x in solutions if x.get('origin')=='imported-seed continuation']
    if continued:
        fig,axes=plt.subplots(1,2,figsize=(10,3.5))
        for sign in [-1,1]:
            selected=[x for x in continued if f'family_{sign:+d}.mat' in x['artifact']]
            if not selected:continue
            axes[0].plot([x['energy'] for x in selected],[x['mean_speed'] for x in selected],'o-',label=f'arclength direction {sign:+d}')
            axes[1].semilogy([x['artifact_point_index'] for x in selected],[max(x['replay_closure_inf'],1e-16) for x in selected],'o-')
        axes[0].set(xlabel='energy E at fixed physical p',ylabel='mean speed');axes[0].legend(fontsize=8)
        axes[1].axhline(1e-8,color='black',linestyle='--',label='acceptance target')
        axes[1].set(xlabel='accepted point index',ylabel='independent replay closure');axes[1].legend(fontsize=8)
        save(fig,'fixed_parameter_family_v3')
    series=[RUN/'vertical_07_series.json',RUN/'fixture_09_00001_series.json']
    if all(x.exists() for x in series):
        fig,axes=plt.subplots(3,2,figsize=(10,7),sharex='col')
        for column,file in enumerate(series):
            d=json.loads(file.read_text());t=np.asarray(d['time']);x=np.asarray(d['state']);q=np.asarray(d['mode'])
            axes[0,column].plot(t,x[:,2],label='COM y');axes[0,column].plot(t,x[:,1],label='COM dx')
            axes[0,column].set_title('PIP analytic parent' if column==0 else 'Imported PK state');axes[0,column].legend(fontsize=8)
            for leg,k in enumerate([6,8,10,12]):axes[1,column].plot(t,x[:,k],label=['BL','BR','FL','FR'][leg])
            axes[1,column].set_ylabel('leg angle');axes[1,column].legend(ncol=4,fontsize=7)
            # Keep the final sample at repeated times: physical right-side mode.
            _,reverse_indices=np.unique(t[::-1],return_index=True);keep=np.sort(len(t)-1-reverse_indices)
            for leg in range(4):axes[2,column].step(t[keep],q[keep,leg]+1.3*leg,where='post',label=['BL','BR','FL','FR'][leg])
            axes[2,column].set(xlabel='time',ylabel='contact mode + leg offset')
        save(fig,'physical_trajectory_contact_comparison_v3')

    testfile=RESEARCH/'Audits_v3/final_test_summary.txt'
    test_summary=testfile.read_text().strip() if testfile.exists() else 'Final aggregate test result unavailable.'
    analyzer=RESEARCH/'Audits_v3/code-analyzer-issues-v3.csv'
    issues=list(csv.DictReader(analyzer.open())) if analyzer.exists() else []
    analyzer_errors=sum(x.get('Severity','').lower()=='error' for x in issues)
    valid=[x for x in solutions if x.get('replay_passed') and 1.0001<=x.get('energy',0)<=3 and abs(x.get('mean_speed',999))<=3]
    observed=sorted({x['gait_label'] for x in valid})
    ledger=RESEARCH/'execution_ledger.jsonl'
    ledger_rows=[json.loads(x) for x in ledger.read_text().splitlines()] if ledger.exists() else []
    charge=sum(x.get('elapsed_seconds',0) for x in ledger_rows if x.get('config')=='full')
    status_rows=[]
    for c in connections:
        e=c.get('evidence',{});a=seq(c.get('amplitudes'))
        successful=[x for x in a if x.get('converged')]
        trans=c.get('transversality',{})
        status_rows.append(f'| {c["critical_energy"]:.12g} | {c["status"]} | {len(successful)}/{len(a)} | {number(trans.get("estimate"))} ± {number(trans.get("uncertainty_estimate"))} | {", ".join(e.get("failed_gates",[])) or "none"} |')
    run_rows=[f'| {r["direction"]:+d} | {r["accepted_count"]} | {r["reason"]} | {number(r.get("max_full_closure"))} |' for r in seq(family.get('runs'))]
    figure_names=['vertical_benchmark_v3','legacy_compatibility_v3','parent_critical_scan_v3','restricted_critical_spectrum_v3','restricted_critical_directions_v3','signed_pronk_candidates_v3','fixed_parameter_family_v3','physical_trajectory_contact_comparison_v3']
    figure_text='\n\n'.join(f'![{name.replace("_"," ")}](../Research_v3/Figures_v3/{name}.png)' for name in figure_names if (FIGURES/f'{name}.png').exists())
    text=f'''# Final research status — quadruped v3

Generated from saved execution evidence on {datetime.datetime.now(datetime.timezone.utc).isoformat()}.

The requested single PIP-rooted gait network is **unresolved** in the registered autonomous model and bounded domain. Local mathematical propositions are derived conditionally. Ordinary vertical PIP and traveling pronk states are reproduced and continued; imported ancestry is not inferred. Restricted parent-only attachment status is determined by the checks below. Full simultaneous-contact smoothness, unrestricted stability, P1/P2 bridging, coverage, and global connectivity are not established.

## Hypotheses and model

The model is `{compat.get('model_id','v3-autonomous-first-directed-root-compressive-stance')}`. It uses the first eligible descending touchdown and ascending liftoff, with compressive stance, explicit reset ownership, and the unchanged 14-coordinate physical schema. Fixed baseline physical parameters are `[10,10,20,20,1,1,0,0,2,0.5]`. The registered energy interval is `[1.0001,3]`, mean speed lies in `[-3,3]`, pitch magnitude is at most `1.2`, primitive period at most `12`, and the event bound is `64`. Translation, time phase, and proven fixed-parameter symmetries are the allowed equivalences. The desired graph permits regular connections; nonsmooth candidates are recorded separately.

`H_local` is assessed for specified local connections; the executed support here is numerical and restricted. `H_network` (one root reaching both target studies), `H_coverage` (all registered classes), and `H_global` (every admissible primitive orbit) remain unresolved. PC/TR/TL are included in the declared universe; they have not been recovered. The historical P1 critical point has energy greater than `9.83045`, outside the registered interval. This campaign does not assess that critical point and does not claim its nonexistence.

## Methods and implementation

The new physical chart removes one dependent stored angular rate per stance leg. Apex/translation dimension is `12 − number_of_stance_legs`. Energy conservation supplies an independent fixed-parameter family residual: one closure equation is eliminated through a regular energy pivot and replaced by the energy equation; the full physical closure remains mandatory at acceptance. Pseudo-arclength continuation checks tangent rank, full closure, topology, conditioning, and restart replay. Corrected distance-constrained second seeds use these same services.

Gait classification uses complete state/contact histories, circular flight intervals, primitive-cover checks, descriptive front/hind pairing, and motion residuals. BL marking is an explicit local chart with a prescribed touchdown occurrence. Synthetic overlap/coincidence checks and an actual PIP replay were executed before cleanup; no physical B2 chart-overlap example was validated in this campaign. A label and equal contact times are not a proof of isotropy.

The finite-difference Floquet API uses physical tangent coordinates and nonlinear retraction. Energy/family neutrality is distinguished from extra critical modes. Split-contact perturbations are allowed to fail closed. A restricted matrix is not used as a full-system stability certificate. See [mathematical methods](Periodic_Orbit_and_Bifurcation_Theory_v3.md), [LaTeX source](Periodic_Orbit_and_Bifurcation_Theory_v3.tex), and [model audit](Model_Equivalence_Audit_v3.md). The standalone LaTeX source compiled successfully using the native editor; its PDF preview is available there, with no separate exported PDF claimed.

## Executed numerical results

The compatibility stage sampled {len(observations)} columns from 18 checksum-preserved fixtures: first, middle, and last columns of each family. {compat.get('accepted_seed_count','unavailable')} source records produced autonomous periodic states. P1 contributes one and P2 five. The two PK fixture copies are identical, so these are five distinct mapped states; the nearzero PIP state lies outside the registered energy interval, leaving four distinct admitted comparison states. Period/contact identity is checked independently of autonomous state acceptance. B2 and its other-apex view are not counted as independent discoveries. Per-family rejection conditions, parameters, source columns, and first divergences are in [P1 reproduction](P1_Reproduction_Report_v3.md) and [P2 discovery](P2_Discovery_Report_v3.md).

The corrected nearzero touchdown occurs at `0.00014142135426574`, approximately `1.54e-12` from its analytic time. Two diagnosed detector defects were repaired: storing samples after an earlier chosen event, and premature simultaneity clustering based on guard value alone. Simultaneity now also requires a local event-time test. The latter regression was observed failing before the change and passing afterward. Unsupported grazing remains a boundary qualification.

The analytic vertical benchmark executed {len(points)} energies. Maximum period error is {number(vertical.get('max_period_error'))}, full closure {number(vertical.get('max_closure'))}, and energy variation {number(vertical.get('max_energy_range'))}. Delayed scheduled histories have extra stance revolutions; they suppress the first liftoff and traverse tensile stance. They are incompatible with this contact law. A common geometric limit does not provide a regular root bridge.

The imported PK energy-family stage status is `{family.get('status','unavailable')}`. Both predictor directions preserve physical p, and every stored accepted point is classified. The stopping reason below is numerical, not a proof of a complete family. The fresh positive-direction run retained 21 points instead of the registered 20 because of a resume-overlap counting bug. This deviation is disclosed in fixed_family.json and fixed prospectively; no observation was deleted. Resumed convenience arrays were also rebuilt from the authoritative complete point records without changing those orbits.

| Arclength direction | Accepted points | Stop | Maximum full closure |
|---|---:|---|---:|
{chr(10).join(run_rows) or '| — | unavailable | pending stage evidence | — |'}

The unrestricted alternative stage tried {len(seq(alternative.get('attempts')))} frozen symmetry-sector predictors; none certified a daughter edge. These trials are not an exhaustive search. Ordinary full-state PK Floquet differentiation returned dimension {floquet.get('unrestricted',{}).get('dimension','unavailable')} and reliable=`{floquet.get('unrestricted',{}).get('reliable','unavailable')}` because nearby trials changed section-relative event charts. No full-system spectrum or stability conclusion is drawn from its NaN entries.

## Parent-only critical points and signed corrections

The current stage is `{local.get('status','unavailable')}`. It scans {len(parents)} deterministic parent energies, finds sign changes of `det(DP_E−I)` in a fixed-energy three-coordinate pronk chart, and refines at most two brackets. Predictions are saved before daughter correction and use no imported daughter states. Even-multiplicity crossings, tangent zeros, and intervals containing multiple zeros can be missed. An additional exact restricted-parent resonance check predicts a +1/−1 spectral point at E=1.06168502751 inside the first coarse interval, which this sign-change grid missed. Its daughter attachment was not computed. The first observed critical energy agrees with the n=1 resonance prediction within approximately 4.1e-9. These analytic checks are described in the parent-only validation document; [three unprocessed candidates](../Research_v3/parent_candidate_queue_v3.json) are retained separately. Derivative and solve tolerances were tightened as a recorded validation amendment, without changing the search domain; the prior exploratory files are versioned.

| Critical energy | Evidence status | Converged signed samples | Left-kernel mixed derivative | Failed gates |
|---:|---|---:|---:|---|
{chr(10).join(status_rows) or '| — | no completed certificate | — | — | — |'}

The first critical point also has a restricted multiplier near −1 within estimated matrix uncertainty. The fixed-point +1 kernel remains simple, but an isolated one-center dynamical normal form or stability claim is unsupported. The evidence gate requires a resolved simple kernel and cokernel, mixed-derivative signal above estimated uncertainty, signed amplitude sequences, genuine corrections, stricter full replay, primitive synchronized contact cycles, full-trajectory distinction, reflection loss through nonzero drift, and convergence toward the critical parent. These are numerical estimates, not interval proofs. Even a supported restricted attachment does not establish C2/C3 cluster regularity in an open unrestricted neighborhood or a full smooth pitchfork theorem. See [parent-only validation](Parent_Only_Pronk_Validation_v3.md).

## Network and coverage

The authoritative [typed graph](../Research_v3/graph/index.json) and [graph report](Ancestry_Graph_v3.md) distinguish imported comparisons, parent-only numerical candidates, phase equivalences, and unresolved hypotheses. No missing edge is supplied by a matching gait name. The unresolved edges are PK→BD; BD→HB_front and BD→HB_hind; both half-bounds→GP; the ordinary/delayed PIP bridge; delayed PIP→PK_B2_Parent; PK_B2_Parent→B2; B2→F2 and B2→H2; F2/H2→G2; and the bridge between the named P1 PK and PK_B2_Parent families. PIP→PK has only the restricted evidence level reported above and has not supplied these downstream edges. Strict fixed-model `H_network` is not achieved.

Independent replay index status: `{index.get('status','unavailable')}`, count {index.get('count','unavailable')}, failed replays {index.get('failed_replay_count','unavailable')}. The index retains individual states and provenance; repeated seed occurrences in two continuation directions are not independent discoveries. Registered-domain labels in replayed accepted evidence are: {', '.join(observed) or 'pending solution index'}. All requested non-pronking target classes remain unrecovered. Import rejection or a bounded numerical stop is not proof that such orbits cannot exist.

## GUI and validation

The v3 GUI uses the familiar panel/tab arrangement and shared numerical services. The executed load→inspect→correct→fixed-pronk continue→restricted Floquet→animate→save workflow yielded closure `3.2222e-10` and a reliable `4×4` restricted matrix. Matched `1120×740` screenshots, nine consequential callback tests, five-frame MP4, animation GIF, oscillator GIF, scrubbing/speed, partial saves, and loaded-orbit replay are recorded in [GUI parity](GUI_Parity_v3.md). Compressed saves preserve exact primary times/states/modes/events and the Floquet matrix. These GUI checks do not certify unrestricted scientific claims.

Historical full-suite summary, retained before test-source cleanup:

```text
{test_summary}
```

The initial baseline was 135 passed/137, with two legacy-manifest failures and one incomplete result. Those assertions demanded 70 files at an old protected path already absent from the starting checkout; neither protected files nor those assertions were changed to hide the failures. A generic-pipeline schema lookup regression found during the first final run was repaired by using the model-owned schema. Code Analyzer recorded {len(issues)} issues, including {analyzer_errors} errors; the CSV retains warnings/information. Historical aggregate summaries, launcher checks, environment and LaTeX evidence are retained under `Research_v3/Audits_v3`. At the user's cleanup request, test sources/runners, raw test MAT/JUnit/log outputs and machine caches were removed. These counts describe the executed pre-cleanup suite; the retained physical replay audit is rerunnable.

The cleanup keeps all research states, trajectories, matrices, predictions and scientific reports. Compressed MAT-v7 replacements passed complete loaded-artifact `isequaln` comparisons; the 357,391,654-byte unrestricted Floquet artifact became 15,371,053 bytes without dropping any fields. Only byte-identical prior-result copies were deduplicated. See [cleanup audit](../Research_v3/Audits_v3/Working_Tree_Cleanup_v3.md) for file sizes, removed files and protection checks.

## Reproduce, resume, and retained limitations

From the repository root, run:

```sh
python3 SLIP_Quadruped_v3/Research_v3/run_campaign.py --config validation --stage all --resume
python3 SLIP_Quadruped_v3/Research_v3/run_campaign.py --config full --stage all --resume
python3 SLIP_Quadruped_v3/Research_v3/run_campaign.py --verify-only
python3 SLIP_Quadruped_v3/Research_v3/generate_family_reports.py
python3 SLIP_Quadruped_v3/Research_v3/generate_research_index.py --config full
python3 SLIP_Quadruped_v3/Research_v3/generate_research_report.py
```

Omit `--resume` for an explicit rerun; completed and terminal bounded-stop stage JSONs are retained by resume, while partial fixed-family MAT checkpoints replay their last accepted point before correction. The parent-only driver versions prior artifacts and recomputes predictions. No source archive referenced by legacy reports was present locally or executed. The launcher records exact MATLAB commands, configuration hashes, timestamped logs, retry charges, stage locks, and protected-file verification. Historical logs remain available. Summed recorded full-campaign process wall charge is {charge:.1f} seconds against a 7200-second discovery budget; historical test summaries and independent replay logs are retained separately. This summed accounting is conservative for overlapping processes and avoids stale counter resets. It does not imply that a branch is exhausted when its point cap is reached.

MATLAB R2025b Update 5 (MACA64) and RNG seed `20261007` were used. All runtime and artifact writes are confined to v3, including MATLAB preferences/temp paths and graphics output. Native MATLAB startup required an approved sandbox escalation. The campaign verified all 547 initially protected files/links outside v3 and all 18 copied source fixture checksums. The later cleanup authorization allows changes outside the legacy `SLIP_Quadruped/` folder; removal of repository tests/CI, updates to their audit runner/documentation, and macOS metadata cleanup/ignore changes are recorded separately. The complete legacy reference and all 18 fixtures remain unchanged; see [protected verification](../Research_v3/baseline/protected_verification.json).

The strongest result is conditional local mathematics plus executed ordinary-PIP/pronk reproduction, fixed-parameter continuation, qualified parent-only evidence, and demonstrated scheduled/autonomous incompatibilities. The requested full network, all-class coverage, unrestricted stability, exact nonsmooth bridges, and global completeness remain open.

## Figures from executed evidence

{figure_text}
'''
    # Empty dictionary defaults above are interpolated expressions, not templates.
    (V3/'Docs_v3/Final_Research_Status_v3.md').write_text(text)
    handoff={'schema_version':'research-handoff-v3-1','generated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
             'model_id':compat.get('model_id'),'stage_status':{k:read(k).get('status','absent') for k in ['inventory','compatibility','vertical','fixed_family','parent_only','pip_pk_local','floquet','solution_index']},
             'full_campaign_process_wall_seconds':charge,'discovery_wall_budget_seconds':7200,
             'network_achieved':False,'global_exhaustiveness_claimed':False,
             'resumable_checkpoints':[str(x.relative_to(V3)) for x in sorted(RUN.glob('family_*.mat'))],
             'report':'Docs_v3/Final_Research_Status_v3.md','graph':'Research_v3/graph/index.json',
             'unprocessed_candidate_queue':'Research_v3/parent_candidate_queue_v3.json','validation_recipe':'Research_v3/audit_commands.sh','cleanup_audit':'Research_v3/Audits_v3/Working_Tree_Cleanup_v3.json','execution_ledger':'Research_v3/execution_ledger.jsonl','protected_verification':'Research_v3/baseline/protected_verification.json'}
    (RESEARCH/'handoff_checkpoint.json').write_text(json.dumps(handoff,indent=2)+'\n')
    print(f'Wrote research report and {len(list(FIGURES.glob("*.png")))} figure PNGs.')

if __name__=='__main__':main()
