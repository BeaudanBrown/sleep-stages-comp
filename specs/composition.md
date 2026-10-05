# Composition Specification

## Overview

Sleep stage times are **compositional data** - they represent parts of a constrained overnight window and are therefore dependent on one another. Standard regression on raw times violates the assumption of unconstrained predictors. We use **Isometric Log-Ratio (ILR)** transformation to map compositions to unconstrained real space.

---

## Composition Components

### Exposure composition (SHHS-2)

**Four-part composition** using SHHS-2 sleep stages, in the fixed component order:

`(N1, N2, N3, REM)`.

| Component | Variable | Description |
|-----------|----------|-------------|
| N1 | `n1_s2` | Light sleep stage 1 |
| N2 | `n2_s2` | Light sleep stage 2 |
| N3 | `n3_s2` | Slow wave sleep (deep) |
| REM | `rem_s2` | Rapid eye movement |

### Not included in the composition

- **WASO** is a separate SHHS-2 spline covariate, held at each participant's observed value under interventions.
- **Sleep duration** is still adjusted for separately in the outcome models via `slp_time_s2`.

---

## Sequential Binary Partition (SBP)

The code uses the four-part SBP in `R/composition_utils.R`.

### SBP Matrix

```r
# Component order is fixed: (N1, N2, N3, REM)
#        N1  N2  N3  REM
sbp <- matrix(c(
  -1, -1,  1,  1,
   1, -1,  0,  0,
   0,  0,  1, -1
), ncol = 4, byrow = TRUE)
```

### ILR Coordinate Interpretation

| Coordinate | Interpretation | Higher value means... |
|------------|----------------|----------------------|
| R1 | `{N3, REM}` relative to `{N1, N2}` | More N3/REM relative to N1/N2 |
| R2 | `N1` relative to `N2` | More N1 relative to N2 |
| R3 | `N3` relative to `REM` | More N3 relative to REM |

These labels are shorthand for the current plus/minus sets in the SBP matrix. If the basis changes, update this file and downstream interpretation together.

---

## ILR Transformation

Using the `{compositions}` package:

```r
library(compositions)

# Exposure composition variables (SHHS-2), fixed order
comp_vars <- c("n1_s2", "n2_s2", "n3_s2", "rem_s2")

# Build ILR basis from SBP
v <- gsi.buildilrBase(t(sbp))

# Transform
comp <- acomp(dt[, ..comp_vars])
ilr_coords <- ilr(comp, V = v)  # Returns 3 columns: R1, R2, R3
```

### Zero handling

If any component is exactly zero, log-ratios are undefined. We use **multiplicative replacement** via `compositions::acomp()`.

Notes:
- Zero values should be rare for stage minutes; if unexpectedly common, revisit PSG derivation.
- The same replacement rule must be used consistently for observed and counterfactual compositions.

---

## Sleep Duration Adjustment

The ILR coordinates encode relative allocation across the four sleep stages, so the primary models adjust for `slp_time_s2` separately. Stage-to-stage substitutions preserve observed TST and WASO. Fixed synthetic compositions can have different TST values; prediction sets TST to the assigned four-stage sum while leaving WASO observed. Support uses stage composition and TST, without screening on WASO.

---

## SHHS-1 adjustment (prior sleep)

SHHS-1 sleep stages are transformed to three ILRs using the same basis to adjust for prior sleep patterns:

- `R1_s1`, `R2_s1`, `R3_s1` (SHHS-1 stage composition)
- `s1_incomplete` indicator (1 if `slp_time` is NA)

SHHS-1 WASO remains available for descriptive reporting but is not a model covariate.

---

## Code location

- **SBP matrix:** `R/composition_utils.R`; **composition variables:** `constant_targets.R`
- **ILR transformation function:** `R/composition_utils.R` → `make_ilrs()`

---

## Updating the SBP

If the SBP needs to change:

1. Update `sbp` matrix in `R/composition_utils.R`
2. Update `comp_vars` if components change
3. Rebuild the ILR basis: `v <- gsi.buildilrBase(t(sbp))`
4. Document the new interpretation in this file
5. Rebuild affected pipeline targets

**Note:** Different SBPs are rotations of the same space; model fit is unchanged, only interpretation differs.
