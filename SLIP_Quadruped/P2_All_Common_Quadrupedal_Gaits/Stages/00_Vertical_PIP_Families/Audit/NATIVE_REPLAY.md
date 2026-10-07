# Frozen production replay of the analytic vertical families

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


Direct full-cycle replay without event-timing correction evaluated 36 samples;
34 passed both state and periodic residual norms below 1e-8.

- Delayed PIP: **16/18 passed**, maximum periodic residual 0.0126251468002.
- Ordinary PIP: **18/18 passed**, maximum periodic residual 1.108e-11.

| Family | Column | E | Native periodic residual | Native state return | Native mean velocity |
|---|---:|---:|---:|---:|---:|
| Delayed | 1487 | 19.9957256264 | 7.03539971338e-7 | 7.03539936718e-7 | −4.88664363083e-8 |
| Delayed | 1586 | 19.99999 | 0.0126251468002 | 0.0126251434590 | −0.000876871653266 |

The analytic family has exactly zero horizontal velocity throughout the entire
orbit. These delayed samples develop nonzero mean horizontal velocity during
the full angular production integration near zero leg length. The independent
Cartesian replay and exact forward segment composition remain below 1e-8;
their global maxima are 3.975e-12 and 1.930e-13, respectively.

The analytic near-collision samples remain in the family data, with native
replay failure explicitly recorded. No native correction was used to move
the analytic orbit or hide this drift. Passing selected samples does not imply
that every saved column was checked by the production model.

The full machine-readable records are in `native_sample_validation.mat` and
`native_sample_validation.json` and `native_sample_validation.mat` contain the retained validation records.
The original model source and existing branch files were not modified.
Reproduce using `validate_native_samples.m` and the frozen code in this audit.
