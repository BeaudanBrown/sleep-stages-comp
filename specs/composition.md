# Composition Specification

## Overview

Sleep stage times are **compositional data** - they represent parts of a whole (total sleep time) and are constrained to sum to a constant. Standard regression on raw times violates the assumption of unconstrained predictors. We use **Isometric Log-Ratio (ILR)** transformation to map compositions to unconstrained real space.

---

## Composition Components

### Exposure composition (SHHS-2)

**4-part composition** using SHHS-2 sleep stages, in the fixed component order:

`(N1, N2, N3, REM)`.

| Component | Variable | Description |
|-----------|----------|-------------|
| N1 | `n1_s2` | Light sleep stage 1 |
| N2 | `n2_s2` | Light sleep stage 2 |
| N3 | `n3_s2` | Slow wave sleep (deep) |
| REM | `rem_s2` | Rapid eye movement |

### Not included in the composition

- **Wake** (including WASO) is *not* part of the composition.
- **Total sleep time (TST)** is included as a *separate covariate*.

---

## Sequential Binary Partition (SBP)

The SBP defines how components are hierarchically grouped for ILR transformation.

We use a **"restorative vs light sleep"** partition consistent with the component order `(N1, N2, N3, REM)`:

```
Level 1: {N3, REM} vs {N1, N2}    → R1
Level 2: N3 vs REM                → R2
Level 3: N1 vs N2                 → R3
```

### SBP Matrix

```r
# Component order is fixed: (N1, N2, N3, REM)
#        N1  N2  N3  REM
sbp <- matrix(c(
  -1, -1,  1,  1,   # R1: restorative vs light
   0,  0,  1, -1,   # R2: N3 vs REM
   1, -1,  0,  0    # R3: N1 vs N2
), ncol = 4, byrow = TRUE)
```

### ILR Coordinate Interpretation

| Coordinate | Interpretation | Higher value means... |
|------------|----------------|----------------------|
| R1 | log-ratio of restorative to light sleep | More time in N3+REM relative to N1+N2 |
| R2 | log-ratio of N3 to REM | More N3 relative to REM |
| R3 | log-ratio of N1 to N2 | More N1 relative to N2 |

### Rationale for This SBP

1. **Substantively meaningful:** Groups sleep by function (restorative vs transitional/light)
2. **Aligned with research questions:** SWS (N3) and REM have distinct proposed mechanisms for brain health
3. **Interpretable contrasts:** Each ILR has a clear interpretation

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

## Total Sleep Time (TST) adjustment

Since wake is excluded from the composition, we adjust for **total sleep time** as a separate covariate.

```r
total_sleep_time_s2 <- n1_s2 + n2_s2 + n3_s2 + rem_s2
```

This ensures the model accounts for absolute sleep duration, not just relative composition.

---

## SHHS-1 adjustment (prior sleep)

SHHS-1 sleep times are included as **raw minutes** (not ILR transformed) to adjust for prior sleep patterns:

- `n1`, `n2`, `n3`, `rem` (SHHS-1 stage times)
- `slp_time` (SHHS-1 total sleep time, may be missing due to battery failure)
- `s1_incomplete` indicator (1 if `slp_time` is NA)

**Rationale:** SHHS-1 variables are confounders, not exposure. Raw times with RCS splines provide flexible adjustment.

---

## Code location

- **SBP matrix and composition variables:** `R/constants.R`
- **ILR transformation function:** `R/utils.R` → `make_ilrs()`
- **Composition limits:** `R/utils.R` → `make_comp_limits()`

---

## Updating the SBP

If the SBP needs to change:

1. Update `sbp` matrix in `R/constants.R`
2. Update `comp_vars` if components change
3. Rebuild the ILR basis: `v <- gsi.buildilrBase(t(sbp))`
4. Document the new interpretation in this file
5. Re-run pipeline: `tar_make()`

**Note:** Different SBPs are rotations of the same space; model fit is unchanged, only interpretation differs.
