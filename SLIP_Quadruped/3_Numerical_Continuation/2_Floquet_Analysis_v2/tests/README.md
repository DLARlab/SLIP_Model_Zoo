# Floquet-v2 tests

The tests are executable contracts, not one-time development files. Keep them
with the scientific source even after a feature appears stable: they protect
the reduced-section dimension, event-time exclusion, topology rejection,
canonical evaluator identity, artifact hashes, workflow review gates, and GUI
loading behavior.

## Routine suite

From the repository root:

```matlab
floquetRoot = fullfile(pwd,'SLIP_Quadruped', ...
    '3_Numerical_Continuation','2_Floquet_Analysis_v2');
suite = testsuite(floquetRoot,'IncludeSubfolders',true);
results = run(suite);
assert(all(~[results.Failed]));
```

Routine tests use synthetic data or frozen evidence where possible. Tests
that require hundreds of hybrid strides are discovered but assumption-filtered
unless their documented environment variable is enabled.

## Layout

- `unit/`: public namespace, dataset-I/O parity, and small numerical-contract
  tests;
- `workflow/`: five-stage API, information-barrier, artifact-chain, and
  confirmation-gate tests;
- `gui/`: viewer and canonical analysis-view projection tests;
- `integration/`: multi-component branch-analysis contracts;
- `production/`: opt-in numerical recomputation and frozen-reference tests;
- `fixtures/`: small synthetic fixture documentation and future shared data.

Reference experiments keep scripts, data, SHA ledgers, and expected reports
together under `reference_experiments/`; their executable tests are centralized
under `production/` so one suite layout owns all test discovery.

## Opt-in production gates

The exact variables are documented in the root README. They include the long
Floquet/event-solver recomputations, pronking branch switching, and targeted
Roadmap reference recomputation. Enable only the gate needed for the claim
being revalidated, then restore or clear it after the run.

Removing tests is not a meaningful cleanup: MATLAB source tests occupy little
space compared with branch MAT files and GUI caches, and they do not run at
application startup. A separately packaged runtime release may exclude
`tests/`, but the research/source repository should retain it.
