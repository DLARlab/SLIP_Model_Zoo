# Archived P2 seed availability

The MATLAB inventory inspected all 58 MAT files currently present under the protected `SLIP_Quadruped/P2_All_Common_Quadrupedal_Gaits` tree, including nested plot, route, phase and bifurcation snapshots. It found zero explicit F2/H2/G2 or FE/HE/GE text/field labels. This is a finite archive finding, not a nonexistence claim about those physical families. [Complete file/variable/hash inventory](../P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/Catalogs/P2_extra_seed_catalog.json), [raw source catalog](../P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Recovery/Catalogs/P2_extra_seed_catalog.mat), [MATLAB inventory implementation](../Research_v3/next_round/theory/InventoryP2PlotSeeds_v3.m).

The complete `full_branch_data.mat` snapshot was copied byte for byte into v3 and SHA256-verified (`bd5fb4919fc9e11f42f41267c5440fdf3ae4fb3a7e70f2c17e58d4c703df09d2`). It contains these arrays:

| Variable | Columns | Historical source meaning |
|---|---:|---|
| `delayed` | 1586 | Delayed PIP |
| `pk` | 259 | PK parent of the archived B2 hypothesis |
| `b2` | 852 | B2 |
| `bip` | 904 | BIP |
| `ordinary` | 228 | Ordinary PIP |
| `supplied` | 891 | Supplied PK |
| `spread` | 648 | Spread PIP |
| `criticalOrbits` | 2 | Saved critical representatives |

All eight arrays carry legacy parameters `[10,20,2,1,0,0.5,1]`, mapped by the explicit `v2-exact` policy to `[10,10,20,20,1,1,0,0,2,0.5]`. Their initially paired angle/rate gaps are retained in the catalog; initial coordinates alone do not establish a complete gait, primitive flight count or branch ancestry. [Whole byte-exact plot snapshot](../P2_Double_Flight_Phase_Continua/Bifurcation_Audits/Source_Plot_Fixtures/010_full_branch_data.mat), [parameter adapter](../1_Dynamic_Frameworks/Adapters_v3/LegacyParameterAdapter_v3.m).

The filename `saved_ge_phase.mat` describes the **gathered/extended apex views of B2**. Its `rightResults` and `gaugedResults` each contain 1358 columns of that source family; the filename supplies no G2 gallop seed. The protected P2 README describes G/E as representations of the same periodic family and explicitly excludes a new bifurcation inferred from rephasing. [Protected P2 source README](../../SLIP_Quadruped/P2_All_Common_Quadrupedal_Gaits/README.md), [protected phase-representation discussion](../../SLIP_Quadruped/P2_All_Common_Quadrupedal_Gaits/Audit/Phase_Representation/MATH_RESEARCH.md).

The inventory preserves 1463 raw29-array occurrences, including repeated single-column and nested copies. This count is provenance, not distinct orbits, new sampling coverage, accepted v3 solutions or recovered families. Twenty-one additional useful whole snapshots reside in the new fixture area; existing exact fixtures are reused after hash checks. Raw29 data preserve `[legacy unknown13; scheduled event times8; period1; legacy parameters7]`. All autonomous conversion, correction, physical admission and actual gait/flight checks remain required. The shared full checkpoint and source inventory were not changed by this audit.
