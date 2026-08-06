# Quadruped v3 state, parameter, leg, mode, and event conventions

`QuadrupedSchema_v3` is the executable source of truth for every table in
this document. Production v3 code must query that schema rather than copy
numeric indices.

Schema versions:

- overall: `quadruped-v3.1`
- state: `quadruped-state-v3.1`
- parameter: `quadruped-parameter-v3.1`

## Continuous state

The state has 14 components. `alpha` is measured relative to the torso.

| Index | Name | Meaning |
|---:|---|---|
| 1 | `x` | horizontal COM position |
| 2 | `dx` | horizontal COM velocity |
| 3 | `y` | vertical COM position |
| 4 | `dy` | vertical COM velocity |
| 5 | `phi` | torso pitch angle |
| 6 | `dphi` | torso pitch rate |
| 7 | `alphaBL` | back-left leg angle relative to torso |
| 8 | `dalphaBL` | back-left relative angular rate |
| 9 | `alphaBR` | back-right leg angle relative to torso |
| 10 | `dalphaBR` | back-right relative angular rate |
| 11 | `alphaFL` | front-left leg angle relative to torso |
| 12 | `dalphaFL` | front-left relative angular rate |
| 13 | `alphaFR` | front-right leg angle relative to torso |
| 14 | `dalphaFR` | front-right relative angular rate |

The translation gauge is `x(1)=0`. The 13 root coordinates are
`u=x(2:14)`. The apex phase coordinate is `dy=x(4)`. Independent periodic
and section-tangent coordinates are `[2,3,5:14]`.

## Parameters

The v3 model has exactly ten parameters.

| Index | Name | Meaning | Valid range |
|---:|---|---|---|
| 1 | `k_l_b` | back-leg axial stiffness | positive |
| 2 | `k_l_f` | front-leg axial stiffness | positive |
| 3 | `k_s_b` | back-leg torsional stiffness coefficient | nonnegative |
| 4 | `k_s_f` | front-leg torsional stiffness coefficient | nonnegative |
| 5 | `l_l_b` | back-leg uncompressed length | positive |
| 6 | `l_l_f` | front-leg uncompressed length | positive |
| 7 | `rsla_b` | back-leg rest swing-leg angle | finite |
| 8 | `rsla_f` | front-leg rest swing-leg angle | finite |
| 9 | `j_pitch` | torso pitching inertia | positive or `Inf` |
| 10 | `l_com` | COM distance from back hip on unit torso | strictly between 0 and 1 |

The old `kr` and `osa` names are not v3 production parameters. They are
handled only by explicit legacy conversion.

Expanding family parameters always produces `[BL;BR;FL;FR]` vectors:

```text
k_l  = [k_l_b; k_l_b; k_l_f; k_l_f]
k_s  = [k_s_b; k_s_b; k_s_f; k_s_f]
l_0  = [l_l_b; l_l_b; l_l_f; l_l_f]
rsla = [rsla_b; rsla_b; rsla_f; rsla_f]
s    = [-l_com; -l_com; 1-l_com; 1-l_com]
```

## Leg and mode order

The only v3 leg order is:

```text
[BL, BR, FL, FR]
```

The contact mode is

```text
q = [qBL; qBR; qFL; qFR]
```

with zero for swing and one for stance. All 16 binary contact modes are
mathematically available; a gait label is not part of the mode.

## Contact-event catalog

| ID | Name | Leg | Type | Direction of guard crossing |
|---:|---|---|---|---:|
| 1 | `BL_TD` | BL | touchdown | -1 |
| 2 | `BL_LO` | BL | liftoff | +1 |
| 3 | `BR_TD` | BR | touchdown | -1 |
| 4 | `BR_LO` | BR | liftoff | +1 |
| 5 | `FL_TD` | FL | touchdown | -1 |
| 6 | `FL_LO` | FL | liftoff | +1 |
| 7 | `FR_TD` | FR | touchdown | -1 |
| 8 | `FR_LO` | FR | liftoff | +1 |

Numeric IDs are an internal representation. External conversion and
diagnostics should use the event names and leg metadata.

## Serializable metadata

`QuadrupedSchema_v3.metadata()` returns the fields that every new saved v3
branch must carry:

- `state_names`
- `parameter_names`
- `leg_order`
- `event_order`
- `state_schema_version`
- `parameter_schema_version`
- `schema_version`

