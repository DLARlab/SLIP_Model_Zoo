# Hybrid event continuation regressions

Run from the `SLIP_Model_Zoo` repository root in native MATLAB:

```matlab
v3 = fullfile(pwd, 'SLIP_Quadruped_v3');
addpath(v3);
V3AddPaths_v3(v3);
addpath(fullfile(v3, 'Tests_v3'));

HybridEventRestartRegression_v3();
HybridEventLifecycleRegression_v3();
HybridEventRestartConfigurationRegression_v3();
HybridEventAuxiliaryAnchorRegression_v3();
```

The four commands assert 53 cases: 29 restart cases, seven simulator/Poincare lifecycle cases, eleven detector configuration variants, and six earliest-root cases. Each configuration variant checks all four context preparation/restoration paths. `HybridEventStopFixture_v3` supplies the necessary identity-distinct handle objects for the wrapped stop condition test.

The regressions exercise real simulator/detector/PoincareMap interfaces and the native independent-leg reset policy. They cover close distinct touchdown/liftoff roots, full simultaneous batches, consumed/new/re-enabled channels, descriptor reordering, section-phase and rejected-candidate continuation, reset geometry diagnostics, stop identity isolation, and exact earliest-root ownership.

Two narrow nonmonotone reentry fixtures explicitly use `MaxStep=1e-7` to resolve their interior excursions. The retained coarse-step failures are not reclassified as a history fix. Explicitly labelled native `ode45` adapters change terminal flags to report genuine future roots; one also reverses the raw time/state/index row order. Every adapter root is checked against the unchanged callback values and directions. These adapters exercise solver-return ordering, not default native solver behavior.

This suite does not establish periodicity, gait ancestry, branch completion, or fresh nine-gate admission for stored quadruped orbits. Those require their separate numerical evidence. All-trajectory-row diagnostic metrics also differ from the PSS physical audit, which excludes virtual intermediate batch rows.

## Continuation context contract

Event callbacks are pure. Arming changes are committed after an ODE solve returns. A physical/section batch is anchored only by a physical or stop root at the actual earliest solver time. Auxiliary interior-entry roots cannot anchor physical batches. Only machine-coincident auxiliary roots acquire ownership at that accepted instant; physical simultaneity tests retain their configured value, time and transversality rules.

Independent fresh calls retain their original initialization and zero-surface protection. Continuation history is explicit. A simulator caller that continues through a stopping-section boundary may use the optional third output and final context input:

```matlab
[part1, result1, context] = simulator.simulate( ...
    system, x0, q0, p, [t0, tf], struct('StopCondition', stop1));
assert(result1.success && result1.stop_occurred && ...
    result1.final_time < tf && ~isempty(context));
[part2, result2] = simulator.simulate( ...
    system, result1.final_state, result1.final_mode, p, ...
    [result1.final_time, tf], struct('StopCondition', stop2), context);
```

The explicit handoff retains physical guard ownership at the identical system, parameter, time, state and mode. It initializes the newly supplied stop namespace independently. `PoincareMap_v3` performs this handoff locally through all three section phases and rejected return candidates, and starts with fresh context on each new `evaluate` call.

Direct detector users receive the opaque context as the third `integrate` output. After an actual model-owned reset, call `prepareRestart` with the actual processed guard/stop IDs, then pass the ready context as the optional final `integrate` input. `prepareContinuousRestart` is reserved for a proven no-reset continuation with the exact accepted state/mode. Processing any physical guard, including a numerically identity reset, requires the strict reset path.

For unaffected channels across physical resets, stable IDs alone do not prove identical guard geometry. A descriptor can declare its complete state dependencies in `metadata.restart_arming`:

```matlab
descriptor.metadata.restart_arming = struct( ...
    'schema', 'state-parameter-guard-geometry-v1', ...
    'definition', 'my-stable-guard-definition-v1', ...
    'state_dependencies', [3, 5, 7], ...
    'mode_independent', true);
```

The declaration is a model contract: the state dependency set must be complete, and changing its surface requires changing its definition. The complete parameter vector is bound separately. Native quadruped guards declare their position dependencies; the built-in apex section declares `dy` only while its exact built-in value function remains installed. An overridden value function conservatively depends on the full state.

The detector diagnoses an ambiguous persistent armed channel near or across a reset-affected surface rather than inventing a crossing. Consumed guards and newly activated opposite guards remain protected until the required interior excursion. A pure section stop with no processed physical guard can carry physical history without a reset-geometry declaration.

Contexts bind the exact normalized eleven-field `EventDetector.Options` structure. A changed detector configuration is rejected. Per-call nested `ODEOptions` remain explicit separate integration inputs and are recorded in segment diagnostics. Do not describe different effective integration profiles as identical merely because they share a context policy.

Contexts contain live collaborators and must remain local, ephemeral values. Never place them in ordinary reports, trajectories, branch MAT files, checkpoints, or a global/object cache. Public restart diagnostics contain only plain IDs, flags and reasons.
