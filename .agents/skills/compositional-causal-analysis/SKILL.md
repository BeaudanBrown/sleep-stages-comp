---
name: compositional-causal-analysis
description: Specialized guidance for compositional data analysis in causal or epidemiologic workflows, especially ILR/SBP-based sleep-stage reallocations, isotemporal substitution, and density- or feasibility-bounded interventions. Use when implementing, reviewing, or interpreting compositional exposure code, transformations, estimands, or plots in this repository or similar R analyses.
---

# Compositional Causal Analysis

Work from the simplex outward. Treat the composition definition, transformation, and intervention semantics as the first-order objects. Treat regression code as downstream implementation.

## Core workflow

1. Confirm the composition actually matches the scientific estimand.
   In this repo, that means a 4-part SHHS-2 composition, not a generic set of sleep columns.
2. Check compositional invariants before editing code.
   Parts must be non-negative, the relevant total must be handled deliberately, and any ILR/SBP basis must stay aligned with the declared component order.
3. Translate raw-minute interventions into compositional terms.
   A reallocation is a policy on the parts, followed by recomputation of derived ILRs. Do not reason as if a coefficient on a raw-minute term were the substitution effect.
4. Verify feasibility and support.
   If the policy is bounded by observed limits or density, state clearly that the estimand is “intervene when feasible/plausible, otherwise leave unchanged.”
5. Only then review model fitting, plotting, and reporting.

## Review rules

- Check that any code changing component names, order, or totals also updates the SBP/ILR basis and downstream coordinate names.
- Check that substitutions are applied on the parts first and ILRs are recomputed afterward.
- Check that “more in A, less in B” effects are not described as symmetric unless the analysis explicitly supports that interpretation.
- Check that density screens, percentile bounds, and zero handling are described as support restrictions, not innocuous preprocessing.
- Prefer simulated data for validation and examples. Do not print confidential row-level values.

## Repo-specific expectations

- Use the written specs as the source of truth when code and implementation drift.
- If a change touches compositional definitions, read [references/repo-checklist.md](references/repo-checklist.md).
- If you need a method refresher, read [references/coda-principles.md](references/coda-principles.md).

