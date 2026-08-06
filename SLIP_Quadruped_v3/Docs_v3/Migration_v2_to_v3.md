# Migrating quadruped v1/v2 data to v3

Legacy files remain supported by legacy code. Migration is needed only when
old data are passed into the independent v3 framework. Do not load an old
vector directly into v3: state, mode, event, and parameter adapters make the
semantic conversion explicit.

## Full state

Old order:

```text
[x,dx,y,dy,phi,dphi,
 alphaBL,dalphaBL,alphaFL,dalphaFL,
 alphaBR,dalphaBR,alphaFR,dalphaFR]
```

New order:

```text
[x,dx,y,dy,phi,dphi,
 alphaBL,dalphaBL,alphaBR,dalphaBR,
 alphaFL,dalphaFL,alphaFR,dalphaFR]
```

The forward permutation is

```matlab
newX = oldX([1,2,3,4,5,6,7,8,11,12,9,10,13,14]);
```

Use the adapter so rows, columns, and reverse conversion are handled:

```matlab
newX = LegacyStateAdapter_v3.toV3State(oldX);
oldX = LegacyStateAdapter_v3.fromV3State(newX);
```

## Thirteen root coordinates

Because the translation coordinate `x` is excluded, the forward permutation
is

```matlab
newU = oldU([1,2,3,4,5,6,7,10,11,8,9,12,13]);
```

Use:

```matlab
newU = LegacyStateAdapter_v3.toV3Unknown(oldU);
oldU = LegacyStateAdapter_v3.fromV3Unknown(newU);
```

## Contact mode

The old mode order is `[BL,FL,BR,FR]`; the new order is
`[BL,BR,FL,FR]`:

```matlab
newQ = LegacyModeAdapter_v3.toV3(oldQ);   % oldQ([1,3,2,4])
oldQ = LegacyModeAdapter_v3.fromV3(newQ);
```

## Contact events

Events are mapped through their names. Numeric IDs are not retained blindly.

| Event name | Old ID | New ID |
|---|---:|---:|
| `BL_TD` | 1 | 1 |
| `BL_LO` | 2 | 2 |
| `BR_TD` | 5 | 3 |
| `BR_LO` | 6 | 4 |
| `FL_TD` | 3 | 5 |
| `FL_LO` | 4 | 6 |
| `FR_TD` | 7 | 7 |
| `FR_LO` | 8 | 8 |

```matlab
newEventIds = LegacyEventAdapter_v3.toV3(oldEventIds);
oldEventIds = LegacyEventAdapter_v3.fromV3(newEventIds);
```

Event-name inputs are also accepted.

## Parameters

The old parameter vector is

```text
p_old = [k,ks,J,l,osa,lb,kr]
```

Conversion to the ten v3 parameters uses

\[
k_{l,b}=\frac{2k\,kr}{1+kr},\qquad
k_{l,f}=\frac{2k}{1+kr},
\]

\[
k_{s,b}=k_{s,f}=ks,\qquad
l_{l,b}=l_{l,f}=l,
\]

\[
j_{pitch}=J,\qquad l_{com}=lb.
\]

This preserves

\[
\frac{k_{l,b}}{k_{l,f}}=kr,
\qquad k_{l,b}+k_{l,f}=2k.
\]

The old production dynamics parsed `osa` but did not use it. Therefore the
conversion requires one of two explicit policies:

- `semantic-rsla`: set `rsla_b=rsla_f=osa`; this activates the documented
  meaning of the old parameter.
- `v2-exact`: set `rsla_b=rsla_f=0`; this reproduces the old production
  swing equation and reports nonzero `osa` as discarded.

```matlab
[pSemantic, semanticReport] = ...
    LegacyParameterAdapter_v3.toV3(pOld, 'semantic-rsla');

[pExact, exactReport] = ...
    LegacyParameterAdapter_v3.toV3(pOld, 'v2-exact');
```

The returned report always states the policy and whether a nonzero `osa`
was activated or discarded.

## Loading an old branch point

```matlab
data = load('old_branch.mat');
oldPoint = data.results(:, column);

oldU = oldPoint(1:13);
oldP = oldPoint(23:29);
schema = QuadrupedSchema_v3.shared();
oldQ = false(schema.Leg.Count,1); % use a stored section mode when present

u = LegacyStateAdapter_v3.toV3Unknown(oldU);
q = LegacyModeAdapter_v3.toV3(oldQ);
[p, conversion] = ...
    LegacyParameterAdapter_v3.toV3(oldP, 'v2-exact');

schemaMetadata = schema.metadata();
```

`v2-exact` is normally the appropriate initial replay policy. Switching to
`semantic-rsla` changes the mathematical model whenever old `osa` is nonzero,
so the converted point should then be corrected with the v3 root solver.

Every newly saved v3 branch must include the metadata returned by
`QuadrupedSchema_v3.metadata()`.
