#!/usr/bin/env python3
"""Run P2 through the shared, v3-confined registered campaign."""
from pathlib import Path
import importlib.util

path=Path(__file__).resolve().parents[2]/'Research_v3/run_study.py'
spec=importlib.util.spec_from_file_location('shared_study_driver',path)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
if __name__=='__main__': module.main('P2')
