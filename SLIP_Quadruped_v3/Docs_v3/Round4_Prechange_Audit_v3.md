# Round 4 pre-change audit

This historical audit retains the repository baseline, MATLAB environment,
and pre-existing protected-manifest failure. General test sources, runners,
generated payloads, and count-only summaries were removed during cleanup.
Retained numerical audits and provenance are in `Research_v3/Audits_v3`;
the current numerical results are described in `Final_Research_Status_v3.md`.

Baseline captured on 2026-08-11 before Round 4 implementation changes.

## Repository baseline

- Requested reference commit: `a683f7f385a8d185517b63754aeb1d628c651d33`.
- Actual `HEAD`: `a683f7f385a8d185517b63754aeb1d628c651d33`.
- `git status --short`: clean.
- `git diff --check`: clean.
- No v1/v2 file was modified as part of this baseline capture.

`git log --oneline -5`:

```text
a683f7f SLIP_Quadruped_v3
4eccd18 Delete FloquetAnalysisGUI.m
623f489 Create FloquetAnalysisGUI.m
576d8fa Floquet Analysis v2
057bf3e Floquet Analysis v2
```

## MATLAB and platform

- MATLAB: `25.2.0.3177638 (R2025b) Update 5`.
- Release: `2025b`.
- Computer/architecture: `MACA64` / `maca64`.
- Platform: `Darwin 25.5.0`, kernel
  `Darwin Kernel Version 25.5.0: Tue Jun 9 22:28:34 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T6050 arm64`.
- License reported by MATLAB: Student License.

Installed products reported by `ver` (47):

| Product | Version |
|---|---:|
| Aerospace Toolbox | 25.2 |
| Antenna Toolbox | 25.2 |
| Bioinformatics Toolbox | 25.2 |
| Communications Toolbox | 25.2 |
| Computer Vision Toolbox | 25.2 |
| Control System Toolbox | 25.2 |
| Curve Fitting Toolbox | 25.2 |
| DSP HDL Toolbox | 25.2 |
| DSP System Toolbox | 25.2 |
| Deep Learning Toolbox | 25.2 |
| Econometrics Toolbox | 25.2 |
| Embedded Coder | 25.2 |
| Financial Toolbox | 25.2 |
| Fixed-Point Designer | 25.2 |
| Fuzzy Logic Toolbox | 25.2 |
| Global Optimization Toolbox | 25.2 |
| HDL Coder | 25.2 |
| Image Acquisition Toolbox | 25.2 |
| Image Processing Toolbox | 25.2 |
| Industrial Communication Toolbox | 25.2 |
| Instrument Control Toolbox | 25.2 |
| MATLAB | 25.2 |
| MATLAB Coder | 25.2 |
| MATLAB Compiler | 25.2 |
| MATLAB Compiler SDK | 25.2 |
| MATLAB Report Generator | 25.2 |
| Mapping Toolbox | 25.2 |
| Optimization Toolbox | 25.2 |
| Parallel Computing Toolbox | 25.2 |
| Partial Differential Equation Toolbox | 25.2 |
| Phased Array System Toolbox | 25.2 |
| RF PCB Toolbox | 25.2 |
| RF Toolbox | 25.2 |
| ROS Toolbox | 25.2 |
| Radar Toolbox | 25.2 |
| Reinforcement Learning Toolbox | 25.2 |
| Signal Processing Toolbox | 25.2 |
| Simscape | 25.2 |
| Simscape Electrical | 25.2 |
| Simscape Fluids | 25.2 |
| Simscape Multibody | 25.2 |
| Simulink | 25.2 |
| Simulink Coder | 25.2 |
| Simulink Control Design | 25.2 |
| Statistics and Machine Learning Toolbox | 25.2 |
| Symbolic Math Toolbox | 25.2 |
| Wavelet Toolbox | 25.2 |

## Pre-existing protected-manifest failure

The recorded preservation check reported a failure in:

```text
TestHybridFramework_v3/everyRestoredLegacyFileRemainsPresent
```

Its static manifest expects 70 files under:

```text
SLIP_Quadruped/3_Numerical_Continuation/2_FloquetAnalysis/
```

At baseline that directory was absent, so all 70 manifest entries were
reported missing. The failure is a repository-content/preservation failure,
not evidence of a numerical failure in the v3 dynamics, root solver,
continuation, Floquet analysis, or graphics. The recorded reference-commit
baseline therefore failed its preservation check.

No physical-admissibility tolerance, event rule, or preservation requirement
was weakened to change this outcome.
