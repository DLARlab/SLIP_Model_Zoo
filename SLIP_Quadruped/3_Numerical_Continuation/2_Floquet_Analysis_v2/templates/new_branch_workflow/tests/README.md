# Experiment tests

Add package-local MATLAB tests that verify, without consulting daughter data,
that stages 1--3 retain their stable candidate IDs, accepted numerical
diagnostics, and reproducible local seeds.  A separate validation test may load
held-out daughters and must identify itself as Stage 5.

At minimum, assert:

- every claimed crossing interval joins consecutive original branch columns;
- both endpoint Floquet maps and the refined orbit are accepted;
- the refined multiplier residual and finite-difference uncertainty meet the
  configured tolerances;
- every switched `+1` direction is classified as additional, not tangent;
- accepted corrected seeds pass the canonical periodic-orbit and map checks;
- repeated critical groups use the declared subspace/direction resolver;
- daughter-reference paths never appear in Stage 1--3 artifacts.
