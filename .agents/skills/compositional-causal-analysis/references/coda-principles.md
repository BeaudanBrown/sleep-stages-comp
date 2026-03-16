# CoDA Principles

## Purpose

Use this reference when reviewing or editing compositional analysis code. It is intentionally short and geared toward implementation checks, not pedagogy.

## High-value rules

- A composition is relative information on parts, not a vector in ordinary Euclidean space.
- Changing the part set changes the geometry. If wake is excluded, that is a different exposure than a 5-part composition.
- ILR coordinates are basis-dependent. Reordering parts or changing the SBP without updating the basis invalidates interpretation.
- Reallocation effects are generally asymmetric and baseline-dependent. “+15 min N3, -15 min REM” is a policy contrast, not a generic linear slope.
- Total sleep time must be handled explicitly. If TST is outside the composition and added as a covariate, keep that separation consistent in code and interpretation.
- Zero handling must be explicit. `acomp()` and log-ratio transforms assume strictly positive parts or a declared strategy for zeros.
- Density or support filters change the estimand. If implausible shifts are reverted to observed values, the target policy is conditional and partially applied.

## Implementation checks

- Confirm `comp_vars` matches the scientific exposure definition.
- Confirm the SBP rows correspond to the documented balances and component order.
- Recompute ILRs after every applied substitution.
- Keep component bounds and Mahalanobis thresholds documented near the intervention code.
- Report how many observations were actually shifted when interventions are feasibility-bounded.

## Sources

- `compositions` package documentation: https://search.r-project.org/CRAN/refmans/compositions/html/compositions.html
- Greenacre, *Compositional Data Analysis in Practice*: https://github.com/michaelgreenacre/CODAinPractice
- Dumuid et al. on compositional isotemporal substitution: https://pubmed.ncbi.nlm.nih.gov/29157152/

