# PK parent profile

- Constructor: `PKParentWorkflowConfig()`
- Frozen parent: `PK_20_2.mat`
- Role: parent-only full-branch discovery profile

Add this folder and the Floquet-v2 root to the MATLAB path, construct `config`
once, and follow the shared staged command sequence in [`../README.md`](../README.md).
The repeated-space resolver and gait-specific corrector are deliberately unset:
the generic workflow must record an unresolved repeated `+1` group instead of
selecting an arbitrary eigensolver basis vector. The historical specialized
pronking validation remains in
[`../../../reference_experiments/PK_multigait_bifurcation/`](../../../reference_experiments/PK_multigait_bifurcation/).
