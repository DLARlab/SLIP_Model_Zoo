# Round C: fixed-selector physical-parameter homotopy

`RunNineHourRoundC_v3` freshly admits three retained lower-torsion roots, then changes the two torsional stiffnesses together toward the exact principal vector `[10;10;20;20;1;1;0;0;2;.5]`. It preserves the other eight parameters exactly. Acceptance at a stiffness of 20 alone cannot establish principal-parameter success; all ten entries must agree exactly and the shared nine gates must pass.

The explicit 2026-10-13 user convention determines the new experiment IDs. Historical `C1_FE_10_17.5_2.mat` is the fore-spread F route: its hind pair is synchronized, the physical chart is `hind-pair`, and the selector is `alpha_FL-alpha_FR`. Historical `C1_HG_10_17.5_2.mat` is the hind-spread H route: its fore pair is synchronized, the chart is `fore-pair`, and the selector is `alpha_BL-alpha_BR`. The B route uses `left-right` and `alpha_BL-alpha_FL`. Physical indices remain `[BL BR FL FR]`; changing H/F names does not exchange physical coordinates.

The actual independently admitted baseline return-policy configuration is extracted with `RecordedReturnPolicy_v3`. Every stage uses that policy object and its declared occurrence. A name cannot restore unspecified defaults. The initial baseline input still records its explicit named acquisition contract, and the subsequent policy comes from what its fresh admission actually used.

For d independent physical section coordinates, energy E is free and one signed physical angle selector gives d+1 equations and unknowns. The baseline selector stores its coordinate indices, zero reference, signed normal, target and zero energy coefficient. Later stages verify the coordinate layout and reuse this exact normal and target. They never silently change a selector when a chart or pivot changes. A target within the unchanged `1e-8` selector tolerance of zero is reported as unresolved acquisition capture, because it would allow immediate collapse to a symmetric parent.

Each preflight saves the literal predictor, full p10, symmetry, physical selector, actual policy configuration and family source SHA before constructing a chart. A failed preflight has its own typed input/outcome receipt and is never reported as a shared-service solver call. Resume checks those inputs and source identity before reusing an outcome. New `v2_...` IDs distinguish these trials from earlier full-chart or named-policy experiments. Existing complete and progress row fields remain compatible with the research graph and final validation.

Newton with the existing hybrid finite-difference Jacobian remains the initial method. Actual Round A diagnostics motivate preserving the synchronized pair for H/F: only the columns splitting that pair failed, while the complementary physical columns remained reliable. This is a restricted acquisition chart, not a full-space Floquet or bifurcation certificate.

If a new actual trial has a finite valid base but again fails at derivative construction, the existing shared RootSolver supports a separately recorded raw native finite-difference `fsolve` successor. For example, after inspecting `failedTrial`:

```matlab
assert(exist('fsolve','file')==2);
nativeDefaults=optimoptions('fsolve');
assert(strcmp(nativeDefaults.FiniteDifferenceType,'forward'));
settings=failedTrial.options;
settings.MaxWallSeconds=360;
settings.SolverOptions=struct('Algorithm','fsolve', ...
    'ProvideJacobianToFsolve',false,'FsolveAlgorithm','trust-region-dogleg', ...
    'MaxIterations',30,'MaxFunctionEvaluations',2500, ...
    'FunctionTolerance',1e-11,'ResidualAcceptanceTolerance',1e-10, ...
    'StepTolerance',1e-13);
retry=NineHourCorrectTrial_v3(root,registration, ...
    [failedTrial.id,'_rawFD_retry01'],failedTrial.seed,settings);
```

Record the observed obstruction and successor method in a separate receipt before this retry. The new ID is essential: a completed `NineHourCorrectTrial_v3` receipt is reused without executing changed options. Explicit `Algorithm='fsolve'` avoids `auto`, which would also invoke the Newton path. The native forward-difference type must be observed on the executing MATLAB installation before describing it as executed. The residual, p10, policy, fixed selector, replay settings and nine admission gates remain unchanged. Raw solver differences do not acquire hybrid derivative reliability or classical Floquet status; preserve `jacobianReliable=false` and the native iteration/exception evidence.

An invalid initial physical return or failed selector preflight needs a valid predictor or formulation repair. Changing the root algorithm cannot repair an invalid initial return. Every failed successor remains evidence; no finite search establishes global nonexistence or a parent/daughter attachment.
