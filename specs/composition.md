# Composition Specification

## Overview

Sleep stage times are **compositional data** - they represent parts of a constrained overnight window and are therefore dependent on one another. Standard regression on raw times violates the assumption of unconstrained predictors. We use **Isometric Log-Ratio (ILR)** transformation to map compositions to unconstrained real space.

---

## Composition Components

### Exposure composition (SHHS-2)

**5-part composition** using SHHS-2 stage and post-onset wake times, in the fixed component order:

`(N1, N2, N3, WASO, REM)`.

| Component | Variable | Description |
|-----------|----------|-------------|
| N1 | `n1_s2` | Light sleep stage 1 |
| N2 | `n2_s2` | Light sleep stage 2 |
| N3 | `n3_s2` | Slow wave sleep (deep) |
| WASO | `waso_s2` | Wake after sleep onset |
| REM | `rem_s2` | Rapid eye movement |

### Not included in the composition

- **Wake before sleep onset** is not part of the composition.
- **Sleep duration** is still adjusted for separately in the outcome models via `slp_time_s2`.

---

## Sequential Binary Partition (SBP)

The current code uses the 5-part SBP stored in `R/constants.R`. While the broader pipeline is being tightened, this code-defined basis is the source of truth for the ILR coordinates.

### SBP Matrix

```r
# Component order is fixed: (N1, N2, N3, WASO, REM)
#        N1  N2  N3  WASO REM
sbp <- matrix(c(
  -1, -1,  1,  1,  0,
  -1,  0,  0,  1,  1,
   0, -1,  1,  0,  1,
   0,  0, -1,  1,  1
), ncol = 5, byrow = TRUE)
```

### ILR Coordinate Interpretation

| Coordinate | Interpretation | Higher value means... |
|------------|----------------|----------------------|
| R1 | `{N3, WASO}` relative to `{N1, N2}` | More time in N3 and/or WASO relative to N1 and N2 |
| R2 | `{WASO, REM}` relative to `N1` | More time in WASO and/or REM relative to N1 |
| R3 | `{N3, REM}` relative to `N2` | More time in N3 and/or REM relative to N2 |
| R4 | `{WASO, REM}` relative to `N3` | More time in WASO and/or REM relative to N3 |

These labels are shorthand for the current plus/minus sets in the SBP matrix. If the basis changes, update this file and downstream interpretation together.

---

## ILR Transformation

Using the `{compositions}` package:

```r
library(compositions)

# Exposure composition variables (SHHS-2), fixed order
comp_vars <- c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")

# Build ILR basis from SBP
v <- gsi.buildilrBase(t(sbp))

# Transform
comp <- acomp(dt[, ..comp_vars])
ilr_coords <- ilr(comp, V = v)  # Returns 4 columns: R1, R2, R3, R4
```

### Zero handling

If any component is exactly zero, log-ratios are undefined. We use **multiplicative replacement** via `compositions::acomp()`.

Notes:
- Zero values should be rare for stage minutes; if unexpectedly common, revisit PSG derivation.
- The same replacement rule must be used consistently for observed and counterfactual compositions.

---

## Sleep Duration Adjustment

The ILR coordinates encode relative allocation across the 5-part composition, not absolute duration. The primary models therefore adjust for `slp_time_s2` separately.

For the ideal-composition analysis, the remaining design choice is which duration "whole" to hold fixed under the 5-part composition: `slp_time_s2` or a derived sleep-period-time quantity that includes `waso_s2`.

---

## SHHS-1 adjustment (prior sleep)

SHHS-1 sleep times are included as **raw minutes** (not ILR transformed) to adjust for prior sleep patterns:

- `n1`, `n2`, `n3`, `rem` (SHHS-1 stage times)
- `s1_incomplete` indicator (1 if `slp_time` is NA)

**Rationale:** SHHS-1 variables are confounders, not exposure. Raw times with RCS splines provide flexible adjustment.

---

## Code location

- **SBP matrix and composition variables:** `R/constants.R`
- **ILR transformation function:** `R/composition_utils.R` → `make_ilrs()`
- **Composition limits:** `R/composition_utils.R` → `make_comp_limits()`

---

## Updating the SBP

If the SBP needs to change:

1. Update `sbp` matrix in `R/constants.R`
2. Update `comp_vars` if components change
3. Rebuild the ILR basis: `v <- gsi.buildilrBase(t(sbp))`
4. Document the new interpretation in this file
5. Re-run pipeline: `tar_make()`

**Note:** Different SBPs are rotations of the same space; model fit is unchanged, only interpretation differs.
