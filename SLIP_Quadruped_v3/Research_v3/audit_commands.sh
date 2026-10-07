#!/bin/sh
# Replay retained physical solutions and regenerate evidence indexes/reports.
set -eu
TASK_RESEARCH_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TASK_V3_ROOT=$(dirname -- "$TASK_RESEARCH_ROOT")
TASK_MATLAB_BIN=${TASK_MATLAB_BIN:-/Applications/MATLAB_R2025b.app/bin/matlab}
cd "$TASK_V3_ROOT"
mkdir -p t Research_v3/runtime/prefs Research_v3/logs
export TMPDIR="$TASK_V3_ROOT/t"
export MATLAB_PREFDIR="$TASK_RESEARCH_ROOT/runtime/prefs"
"$TASK_MATLAB_BIN" -batch "addpath('Research_v3/Drivers_v3'); r=ExportResearchEvidence_v3(); assert(r.failed_replay_count==0);" \
    -logfile "$TASK_RESEARCH_ROOT/logs/reproduced-independent-replay.log"
python3 Research_v3/run_campaign.py --verify-only
python3 Research_v3/generate_research_index.py --config full
python3 Research_v3/generate_family_reports.py
python3 Research_v3/generate_research_report.py
