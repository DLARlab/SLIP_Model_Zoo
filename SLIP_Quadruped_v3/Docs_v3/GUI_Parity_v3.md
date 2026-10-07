# Quadruped GUI parity audit

The source inspected is `SLIP_Quadruped/SLIP_Quadruped_GUI.m` in the starting checkout, including its nested numerical, visualization, seed and continuation callbacks. Its left column contains Data Info, State/Hildebrand tabs, and Status. The right sidebar has Info, Visualization, Solve, Continuation (1D/Para/2D), and Oscillator Plot. The legacy code is a reference; no legacy callback or numerical function is called by v3.

This matrix was written before implementation. "Working legacy" describes connected callbacks in the inspected source, not a claim that every legacy numerical workflow was rerun.

| Feature and familiar position | Legacy callback/source | Legacy status | v3 callback/service and semantics |
|---|---|---|---|
| Folder, file, Plot, Plot All, Delete All; upper left | SelectFolder, GetMatFiles, PlotDatasetByName, PlotAllDatasets, DeleteAllDatasets | Connected | SelectFolder/LoadSelected/LoadAll/RemoveAll; canonical in-v3 inputs, multiple normalized datasets |
| Fixed/varying parameter filters; upper left | UpdateFixedParameterValues, SelectDatasetFromParameter | Connected | ApplyFilter/RefreshPlot; all ten schema parameters, per-solution filtering |
| State axes and dataset selection; State Plot | UpdateAxisData, BranchLineClicked, FigureWindowMoved | Connected | RefreshPlot/SelectNearest; schema state names, click selection, indexed inspection |
| Hildebrand Plot | Tab created at legacy line 331, no axes/callback | Empty placeholder | RefreshInspection/ComputePhaseDiagram_v3, event-derived contact intervals |
| Cursor and selected solution; Info | ResolveNearestCursorSelection, FormatCursorInfoText | Connected | SelectNearest/InspectSelection; mode, section/return identity, residual and detected events |
| Limits, aspect, view, export; Info | SetRoadmapLimits, ApplyManualAspectRatio, SaveCurrentPlot | Connected | ApplyView/ExportPlot; explicit numeric limits/aspect/view, confined PNG/PDF export |
| Animation and periodic orbit; Visualization/Animation | RefreshSelectedSolutionVisualization, RunVisualization, VisualizationSliderChanged | Connected | PrepareVisualization/Scrub/Play using SLIP_Animation_Quad_v3 and SLIP_PeriodicOrbit_Quad_v3 |
| Torso/leg trajectories and GRF; Visualization/Trajectories | UpdateSolutionVisualizationLayout, visualizationObjects | Connected | SLIP_Trajectories_Quad_v3, SLIP_GRF_Quad_v3 using the identical replayed orbit |
| Scrub, playback, stop, recording | RunVisualization, StopVisualization, OpenVisualizationSettings | Connected | trajectory-clock playback with synchronized speed controls; MP4/GIF export and PNG keyframe |
| Oscillator Plot | StartOscillatorPlayback, UpdateOscillatorFrame | Connected | Oscillator selected frame, play/pause/speed and GIF recording; angle/rate phase portraits in BL/BR/FL/FR schema order |
| Seed source/index, editors; Solve | ResolveSeedTabReference, SeedEditorTableChanged | Connected | SelectSeed/EditSeed; schema-derived 14 state and ten parameter rows, separate binary mode |
| Timing editor; Solve | timingSeedTable/GetSeedEditorValues | Editable prescribed-time representation | Read-only detected-event table; times never imposed on the state-triggered map |
| Noise, prediction, correction, plot/save; Solve | ApplySeedNoise, BuildPredictedSeedCandidate, SolvePredictedSeedCandidate, SaveSolvedSeedSolution | Connected | Perturb/Predict/Correct/PlotCandidate/Save; reproducible RNG, shared physical residual and RootSolver_v3 |
| Second seed at state radius; Continuation | FindContinuationSecondSeedAtStateRadius | Connected | SecondSeed; radius in scaled independent physical state, complete replay/admissibility acceptance |
| Fixed-parameter 1D; Continuation/1D | RunNumericalContinuation1D | Connected | StartFixed/stepRun; shared pseudoarclength continuation in the declared energy family, previous physical tangent carried between point chunks |
| Parameter variation; Continuation/Para | RunParameterVaryingContinuation | Connected | StartParameter/stepRun/NumericalContinuation1D_v3; requested grid, no changed event schedule |
| 2D; Continuation/2D | Run2DContinuationScan | Connected grid scan | StartScan/stepRun; two-parameter rectangular scan, explicitly not a certified solution-manifold continuation |
| Previews/progress/pause/stop/partial save | HandleGUIContinuationStatus, ToggleContinuationPause, RequestContinuationStop, SaveContinuationResult | Connected | point-boundary timer control, synchronized last accepted preview, checkpoint after every accepted/rejected point; Resume loads queue state |
| Independent Floquet/bifurcation diagnostics | Main GUI has no Floquet control; separate FloquetAnalysisGUI | Separate legacy tool | AnalyzeFloquet; independent shared FloquetAnalysis_v3, explicitly restricted option and regularity status |

## Implementation and evidence

`SLIP_Quadruped_GUI_v3` constructs the familiar hierarchy. `GUI_v3/QuadrupedGUIController_v3` owns callback state, canonical input/output validation, selection, replay, shared-service dispatch and point-boundary scheduling. Correction and continuation use `EnergyFamilyResidual_v3`, `RootSolver_v3`, `FixedParameterContinuation_v3`, and `NumericalContinuation1D_v3`; the GUI contains no integrator, root algorithm or continuation engine. The conservative family coordinate is energy, appended to solver parameters only; the physical model retains exactly ten parameters. Parameter scans declare fixed family energy and create a physical chart for each parameter vector.

All accepted GUI solutions undergo a fresh forward replay and a normalized physical-state closure check at `1e-8`, with translation removed, discrete mode closure and admissibility retained. The user can request full, left/right, or pronk restrictions explicitly. The last two are labeled restricted; they do not stand for unrestricted transverse stability or branch attachment. Grounded chart lifting comes from the shared physical-manifold/Floquet services, rather than perturbing redundant stance rates. Unsupported contact-cluster derivatives remain unresolved in the shared analysis result.

The return-policy control preserves a stored chart by default. Explicit event-cycle and BL-marked choices are available. A BL-marked solution preserves its declared BL-touchdown count, never substitutes apex return multiplicity for that count, and rejects a missing occurrence identity. Detected event times remain read-only diagnostics.

Saves use `CompactResearchBranch_v3` to preserve primary trajectories, events and derivative matrices while replacing duplicate finite-difference traces and runtime callback contexts with explicit summaries. Compressed MAT v7 retains the detailed diagnostic structures without the large HDF5 overhead of v7.3 for many small fields. Pause and stop take effect between bounded point solves. Accepted and rejected points, queue position, solver settings, initial energy, seed provenance and terminal reason are checkpointed. Fixed-family continuation carries its previous physical tangent across GUI point chunks. Resumption repeats a pending point after interruption; it does not claim to restore solver internals. The 2D preview distinguishes accepted points from rejected points. Shared graphics use event-preserving samples; repeated-stride playback accumulates horizontal drift while retaining classification of the original primitive cycle.

### Actual MATLAB verification

MATLAB R2025b Update 5 ran the seven original callback tests successfully. The two added return-chart tests passed separately; the save/resume and final UI tests passed again after recording controls and compact saves were added. The nine tests covered confinement, schema ordering and edits, deterministic perturbation, independent replay/correction, a radius-constrained second seed, parameter-run pause/checkpoint/resume/save, return-chart identity, actual fixed-parameter continuation, an explicitly pronk-restricted Floquet calculation, and hidden UI creation/animation/scrubbing/export. Test sources, temporary check scripts and generated test logs were removed during the 2026-10-07 cleanup. `Research_v3/Audits_v3/final_summary.json` retains the authoritative aggregate count. Workflow, recording and serialization evidence remain in `GUI_v3/Outputs_v3/`.

The actual load → inspect → correct → continue → Floquet → animate → save workflow is recorded in `GUI_Workflow_Evidence_v3.mat` and is rerunnable with `run_gui_workflow_v3`. Its seed is an analytic vertical PIP at physical parameters `[10,10,20,20,1,1,0,0,2,0.5]`, apex height `1.2`, and flight mode. Observed normalized closure norms were `3.1585e-10` for inspection/correction and `3.2222e-10` at the accepted new continuation point. The computed `4×4` pronk-invariant Floquet block was reported reliable. This proves a functioning GUI workflow on that restricted family; it establishes no daughter connection or unrestricted PIP stability.

The recorded serialization audit separately verified exact preservation of raw primary states, times, modes, event histories, event batches and the Floquet matrix, then replayed the loaded orbit successfully at `3.2222e-10`. The accepted solution shrank from 406,940,533 bytes in v7.3 to 9,158,296 bytes in compressed v7; its partial checkpoint shrank from 11,242,238 to 336,291 bytes. The v7 write/read took 2.08/1.14 seconds in the measured run; controller compaction plus save took 3.57 seconds. `GUI_v3/Outputs_v3/GUI_Serialization_Evidence_v3.mat` retains these observations; the temporary serialization scripts and logs were removed. These timings concern the saved demonstration and do not predict arbitrary campaign sizes.

Matched native screenshots have **1120×740 pixels**, verified using `imfinfo`, with a legacy construction-only baseline and the v3 validated orbit:

| View | Legacy reference | v3 |
|---|---|---|
| Info | [Legacy Info](../GUI_v3/Outputs_v3/GUI_Legacy_Info_1120x740.png) | [v3 Info](../GUI_v3/Outputs_v3/GUI_v3_Info_1120x740.png) |
| Visualization | [Legacy Visualization](../GUI_v3/Outputs_v3/GUI_Legacy_Visualization_1120x740.png) | [v3 Visualization](../GUI_v3/Outputs_v3/GUI_v3_Visualization_1120x740.png) |
| Solve | [Legacy Solve](../GUI_v3/Outputs_v3/GUI_Legacy_Solve_1120x740.png) | [v3 Solve](../GUI_v3/Outputs_v3/GUI_v3_Solve_1120x740.png) |
| Continuation | [Legacy Continuation](../GUI_v3/Outputs_v3/GUI_Legacy_Continuation_1120x740.png) | [v3 Continuation](../GUI_v3/Outputs_v3/GUI_v3_Continuation_1120x740.png) |

The screenshots were visually inspected for panel positions, tab hierarchy, editable schema data and graphics. They verify layout parity, not orbit equivalence with the legacy numerical model. `capture_gui_parity_v3` regenerates v3 screenshots from the saved accepted workflow solution. The protected legacy was only read and launched for native UI screenshots; all exports and MATLAB preferences/logs stayed within v3.

### Precise remaining parity qualifications

- Animation MP4, animation GIF, oscillator GIF and playback-speed callbacks were executed in MATLAB using five-frame smoke exports. `VideoReader` decoded five MP4 frames; `imfinfo` read five frames in each GIF. `GUI_Recording_Evidence_v3.mat` records these results. This is a bounded codec/recording check, not a long-recording endurance test.
- GIF recording retains exact detected event frames and uses their time differences for delays. MP4 recording uses uniformly spaced samples with one-sided reset interpolation; endpoint timing is quantized at the chosen frame rate. Both preserve schema/mode ownership and repeated-stride translation. Playback uses trajectory time and an explicit speed multiplier rather than advancing one frame per timer tick.
- Native mouse hover/click callbacks are connected, while the automated workflow used indexed selection. Physical pointer interaction was not driven in the regression test.
- The main panels and tab positions are retained; subpanel sizing and numerical-setting controls are adapted to the independent v3 model rather than matching every legacy widget pixel for pixel. The new Hildebrand tab completes the old empty placeholder.
- Finite-budget successful GUI continuation does not establish a complete branch. Root failures, chart boundaries and derivative irregularity remain explicit rejected/terminal diagnostics. The scan is a parameter grid, not a certified two-dimensional solution manifold.

Run from MATLAB with only the v3 root on the initial project path:

```matlab
addpath('/absolute/path/to/SLIP_Quadruped_v3');
SLIP_Quadruped_GUI_v3();
% Reproduce the actual validated workflow:
addpath('/absolute/path/to/SLIP_Quadruped_v3/GUI_v3');
run_gui_workflow_v3();
```
