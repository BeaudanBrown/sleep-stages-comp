---
name: lmtp-gcomp-survival
description: Specialized guidance for longitudinal modified treatment policies, targeted learning, parametric g-computation, pooled logistic survival models, and competing-risk estimands in R. Use when implementing, debugging, or reviewing LMTP/TMLE or g-computation survival analyses, especially when distinguishing intervention means, risks, hazards, and contrast-based risk ratios.
---

# LMTP G-Computation Survival

Start by pinning down the estimand. Only then inspect code paths, outcome encoding, and plots.

## Core workflow

1. State the target contrast in plain language.
   Example: risk ratio under a substitution policy versus no intervention.
2. Identify which object each function returns.
   `lmtp_tmle()` returns an intervention-specific mean outcome. Comparative quantities require `lmtp_contrast()`.
3. Separate hazards, cumulative risk, and competing-risk summaries.
   Do not treat pooled-logistic hazards, intervention means, and risk ratios as interchangeable.
4. Validate intervention semantics.
   Check whether the code implements `shift`, `shifted`, or a bounded policy that leaves some observations unchanged.
5. Validate survival encoding.
   Outcome, censoring, competing-event, and person-time conventions must match the package and estimand.

## Review rules

- For LMTP relative risks, require a no-intervention reference fit and an explicit contrast:
  `psi_null <- lmtp_tmle(..., shift = NULL)`
  `psi_sub <- lmtp_tmle(...)`
  `rr <- lmtp_contrast(psi_sub, ref = psi_null, type = "rr")`
- If plots say “risk ratio,” verify they are built from contrast outputs, not `tidy(lmtp_fit)` alone.
- For pooled logistic g-computation, check that hazards are converted into cumulative risk with the intended competing-risk logic.
- Treat positivity and support as first-class concerns. If the intervention is only feasible for some participants, report that policy definition and the intervention count.
- Prefer simulated data or aggregated diagnostics when checking outputs.

## Repo-specific expectations

- Read [references/lmtp-gformula-checks.md](references/lmtp-gformula-checks.md) when editing estimands or survival encoding.
- Read [references/validation-patterns.md](references/validation-patterns.md) when planning diagnostics or tests.

