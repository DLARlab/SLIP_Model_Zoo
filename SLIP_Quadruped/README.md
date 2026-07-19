# SLIP Quadruped GUI

`SLIP_Quadruped_GUI` is the interactive interface for exploring periodic quadrupedal SLIP solutions, inspecting individual gaits, visualizing motion, refining seeds, and running numerical continuation.

## Requirements

- MATLAB with support for `uifigure` and UI components
- Optimization Toolbox (`fsolve`)
- A display session (the GUI is not intended for headless use)
- Optional: Parallel Computing Toolbox when **UseParallel** is enabled in the solver settings

The GUI adds the entire `SLIP_Quadruped` folder tree to the MATLAB path when it starts.

## Start the GUI

In MATLAB, change to the `SLIP_Quadruped` directory (or add that directory to the MATLAB path), then run:

```matlab
SLIP_Quadruped_GUI
```

Alternatively, open and run `SLIP_Quadruped/SLIP_Quadruped_GUI.m` from the MATLAB editor.

## Input data

The GUI lists `.mat` files in the current data folder. Each loadable file must contain a numeric variable named `results`:

```matlab
load('branch.mat', 'results')
```

Each column of `results` is one periodic solution. Rows are arranged as follows:

| Rows | Contents |
| --- | --- |
| 1-13 | States: `dx`, `y`, `dy`, `phi`, `dphi`, `alphaBL`, `dalphaBL`, `alphaFL`, `dalphaFL`, `alphaBR`, `dalphaBR`, `alphaFR`, `dalphaFR` |
| 14-22 | Event timing: `tBL_TD`, `tBL_LO`, `tFL_TD`, `tFL_LO`, `tBR_TD`, `tBR_LO`, `tFR_TD`, `tFR_LO`, `tAPEX` |
| 23-29 | Parameters: `k_leg`, `k_swing`, `J_pitch`, `l_leg`, `phi_neutral`, `l_b`, `k_r_leg` |

The supplied roadmap data under `P1_Breaking_Symmetries_Leads_to_Diverse_Qudrupedal_Gaits/1_Roadmap` can be selected as an example data folder.

## Quick-start workflow

1. Click **Select Folder** and choose a folder containing compatible `.mat` files.
2. Select a file and click **Plot**, or use **Plot All** to load every compatible branch in the folder.
3. Move the pointer over a branch point to preview its values. Click a point to lock it as the selected solution.
4. Use the **Info**, **Visualization**, **Solve**, **Continuation**, or **Oscillator Plot** tabs for the desired operation.
5. Watch the **Status** panel at the bottom for progress, output paths, and errors.

## Data and state plots

The **Data Info** area controls which branches are displayed:

- **Plot** adds the selected dataset and makes it active.
- **Plot All** adds all `.mat` datasets in the selected folder.
- **Delete All** clears the plot without deleting files from disk.
- **Fixed Parameter** and **Varying Parameter** filter/select branches using their parameter values.

In **State Plot**, choose the state used for each axis. The initial view is two-dimensional, but choosing a third coordinate and changing the view angles enables a 3-D view.

The **Info** tab provides:

- **Plotted Datasets**: select the active branch or remove one branch from the plot.
- **Solution Info**: hover information and the locked point selected by clicking a branch.
- **Axis > Limit**: enter axis limits; **Roadmap** applies the standard roadmap limits.
- **Axis > Ratio**: use automatic scaling or apply a manual X:Y:Z aspect ratio.
- **View**: select a preset view or enter view angles.
- **Save Plot**: export the current branch plot as PNG or vector PDF. The file is written to the selected data folder.

Deleting a plotted dataset only removes it from the GUI; it does not delete the source `.mat` file.

## Visualize a selected solution

First click a branch point, then open **Visualization**.

- Drag **Normalized stride** or enter a value from 0 to 1 to inspect a single instant.
- Click **Run** to play one stride and **Stop** to interrupt playback.
- **Animation** shows the quadruped and its periodic orbit.
- **Trajectories** shows torso, back-leg, front-leg, and ground-reaction-force plots.

Use the gear button to enable frame-by-frame trajectory updates or recording:

- **GIF** and **Video (.mp4)** record playback in the selected data folder.
- **Animation keyframes (.pdf)** creates a `Keyframes` subfolder.
- Recording temporarily locks the direct time controls until playback ends or is stopped.

## Oscillator plot

The **Oscillator Plot** tab displays touchdown and liftoff phase relationships for all four legs of the active branch.

- Use **Current Index** to select a solution in the branch.
- Adjust **Playing Speed**, then click **Play** to step through the branch.
- **Pause** stops playback.
- The gear button optionally records playback to a GIF in the selected data folder.

Changing the oscillator index also changes the selected solution used by the other GUI tabs.

## Refine or create a solution

The **Solve** tab uses a selected branch solution as a seed for `fsolve`.

1. Select a branch and choose the seed source:
   - **Cursor** uses the point clicked in the state plot.
   - **Index input** uses a manually entered branch column.
2. Edit values in the state, timing, or parameter tables if needed.
3. Optionally configure the algorithm, tolerances, iteration limits, scaling, and parallel evaluation.
4. Optionally add state and/or parameter noise. **Percent** scales noise relative to each value; **Absolute** uses the entered magnitude directly. Click **Apply Noise** to create a new randomized prediction.
5. Click **Plot Predicted** to inspect the guess.
6. Click **Solve For Solution** and check the reported residual and gait type.
7. Use **Plot Solved** to compare the corrected solution, or **Save Solved Solution** to save it.

Saved solutions contain `results` plus a `solvedSolutionInfo` structure describing the source seed, solver settings, residual, exit flag, and identified gait.

## Numerical continuation

All continuation modes begin with the same seed-pair workflow:

1. Open **Continuation** and select **1D**, **Para**, or **2D**.
2. Choose the first-seed source. Available sources include a clicked cursor point, branch index, branch percentage, and a solution produced in the **Solve** tab.
3. Set the state-space **Radius**.
4. Click **Solve Second Seed**. Continuation will not start until this second seed is valid for the current source and radius.
5. Optionally click **Plot Sol Pair** to inspect the two seeds.

### 1D

Enter a solution filename and click **Run**. The continuation follows the branch in both directions while updating the preview. The final `.mat` file is saved in the selected data folder; temporary progress uses `solution_temp.mat`.

### Para

Select a parameter, enter a positive target value and output filename, then click **Run**. This mode varies the selected model parameter from its current value toward the target and stores the resulting branch in the selected data folder.

### 2D

Select a parameter and enter one or more positive target values separated by spaces, commas, semicolons, or line breaks. Click **Run** to generate parameter-indexed continuation branches. The default list is based on 0.8, 0.9, 1.0, 1.1, and 1.2 times the loaded parameter value.

The 2-D scan resumes compatible existing output when possible and reports completed, skipped, failed, and blocked targets in **Status**.

For every continuation mode:

- **Pause** pauses after the currently active numerical step; click again to resume.
- **Stop** requests a controlled stop and preserves completed final output where applicable.
- Do not close MATLAB while a continuation result is being written.

## Output locations

Unless a save dialog explicitly asks for another location, GUI outputs are written relative to the folder selected in **Data Info**:

| Output | Location |
| --- | --- |
| Saved state plot | Selected data folder |
| Visualization GIF/MP4 | Selected data folder |
| Animation keyframes | `Keyframes/` under the selected data folder |
| Oscillator GIF | Selected data folder |
| 1-D and parameter continuation results | Selected data folder |
| 2-D scan branches and reports | Scan output folder created under the selected data folder |

## Troubleshooting

- **A file does not plot:** confirm it contains a numeric variable named `results` with one solution per column and all 29 rows described above.
- **Visualization is disabled:** click a valid point on a plotted branch first.
- **Continuation will not run:** solve a fresh second seed after changing the first-seed source or radius.
- **The solver returns an invalid solution:** reduce the applied noise, restore the original seed values, or try a closer branch point. Check the residual shown in the **Solve** panel.
- **Controls are clipped:** enlarge the GUI window and use the scroll bars inside the sidebar panels.
