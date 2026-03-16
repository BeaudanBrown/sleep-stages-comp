# Repo Checklist

Use this checklist before finalizing changes in this repository.

## Exposure definition

- Four-part SHHS-2 sleep-stage composition only: N1, N2, N3, REM.
- Wake is not part of the exposure composition.
- SHHS-1 sleep variables are adjustment covariates, not exposure ILRs.

## Intervention semantics

- Substitution policies act on the raw parts.
- Derived ILRs are recomputed after substitution.
- If a shift is infeasible or fails a plausibility screen, leave that observation unchanged and state that estimand explicitly.

## Common failure modes

- Mixing SHHS-1 and SHHS-2 sleep columns inside the same composition.
- Forgetting to update `ilr_names` after changing the composition basis.
- Treating intervention-specific means as comparative effects.
- Describing a bounded policy as if everyone were shifted.

