% FLOQUET Public API for reduced-Poincare Floquet analysis.
%
% Numerical analysis
%   computeFDM              - Differentiate the reduced Poincare map.
%   analyzeBranch           - Analyze an ordered parent continuation branch.
%   detectBifurcations      - Detect persistent multiplier crossings.
%   refineCriticalOrbit     - Refine a bracketed critical periodic orbit.
%   predictBranchDirection  - Lift a reduced critical direction to [X;E].
%   correctBranchSwitch     - Correct a branch-switch predictor.
%   continueDaughterBranch  - Continue two corrected same-ray seeds.
%   validatePeriodicOrbit   - Validate timing, topology, section and closure.
%
% Inspection
%   inspectAnalysis         - Validate and summarize an existing result.
%
% Dataset I/O
%   floquet.io.loadDataset               - Validate/load a saved view.
%   floquet.io.exportDataset             - Export canonical analysis data.
%   floquet.io.trackDisplayMultipliers   - Visualization-only mode ordering.
%
% Workflow
%   floquet.workflow.create             - Create a parent-only workflow.
%   floquet.workflow.load               - Load configuration data safely.
%   floquet.workflow.migrate            - Explicitly convert an empty v1 config.
%   floquet.workflow.inspect            - Validate and inspect artifact state.
%   floquet.workflow.runStage           - Run one ready canonical stage.
%   floquet.workflow.confirmCandidates  - Confirm Stage-1 candidate IDs.
%   floquet.workflow.confirmRays        - Confirm Stage-3 continuation rays.
%
% GUI
%   floquet.gui.launch      - Open the Floquet analysis workbench.
