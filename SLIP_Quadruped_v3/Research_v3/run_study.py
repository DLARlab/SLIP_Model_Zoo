#!/usr/bin/env python3
"""Study wrapper for the shared confined campaign and saved-evidence refresh."""
from __future__ import annotations
import argparse
from pathlib import Path
import subprocess
import sys

V3 = Path(__file__).resolve().parents[1]
STUDIES = {
    'P1': 'P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits',
    'P2': 'P2_All_Common_Quadrupedal_Gaits',
}
STAGES = ['inventory','compatibility','vertical','fixed_family','parent_only','pip_pk_local','floquet']


def main(study=None):
    parser=argparse.ArgumentParser(description=__doc__)
    if study is None: parser.add_argument('--study',choices=list(STUDIES),required=True)
    parser.add_argument('--stage',choices=['all',*STAGES,'refresh'],default='refresh')
    parser.add_argument('--config',choices=['validation','full'],default='full')
    parser.add_argument('--resume',action='store_true')
    parser.add_argument('--verify-only',action='store_true')
    parser.add_argument('--matlab',default='/Applications/MATLAB_R2025b.app/bin/matlab')
    args=parser.parse_args()
    selected=study or args.study
    if selected not in STUDIES: raise ValueError('Unknown study')
    research=V3/'Research_v3'
    if args.stage!='refresh' or args.verify_only:
        command=[sys.executable,str(research/'run_campaign.py'),'--config',args.config,
                 '--stage','all' if args.stage=='refresh' else args.stage,'--matlab',args.matlab]
        if args.resume: command.append('--resume')
        if args.verify_only: command.append('--verify-only')
        print(f'{selected}: using shared registered campaign; compatibility includes both studies.',flush=True)
        subprocess.run(command,cwd=V3,check=True)
        if args.verify_only: return
    subprocess.run([sys.executable,str(research/'generate_research_index.py'),'--config',args.config],cwd=V3,check=True)
    # The historical family comparison reports are explicitly full-campaign reports.
    if args.config=='full' and (research/'runs/full/compatibility.json').exists():
        subprocess.run([sys.executable,str(research/'generate_family_reports.py')],cwd=V3,check=True)


if __name__=='__main__': main()
