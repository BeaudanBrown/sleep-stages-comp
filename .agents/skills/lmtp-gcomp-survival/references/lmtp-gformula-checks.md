# LMTP and G-Formula Checks

## LMTP

- `lmtp_tmle()` and `lmtp_sdr()` estimate the mean outcome under one intervention.
- `lmtp_contrast()` compares one or more LMTP fits to a reference fit or constant and can return additive effects, relative risks, or odds ratios.
- The package supports survival outcomes with competing risks, but only if the wide data encoding matches package expectations.
- LMTP is attractive here because modified treatment policies can relax some practical positivity problems that make static deterministic interventions poorly supported.

## G-computation

- Pooled logistic models approximate discrete-time hazards, not final risk.
- Final risk requires iterating hazards over time and combining event and competing-event processes correctly.
- When comparing intervention and baseline risks, keep the intervention definition identical across all time points and participants unless the policy explicitly depends on feasibility or prior history.

## Failure modes to check

- Intervention mean plotted as a risk ratio.
- Reference fit omitted or computed under the wrong intervention.
- Survival outcome nodes not carried forward according to package expectations after the event.
- Censoring indicators altered by the treatment-shift code.
- Hard-coded substitution branch used inside a mapped target.

## Sources

- `lmtp` repository: https://github.com/nt-williams/lmtp
- `lmtp` manual: https://nt-williams.r-universe.dev/lmtp/doc/manual.html
- `gfoRmula` repository: https://github.com/CausalInference/gfoRmula
- `lmtp` package summary: https://www.cran-e.com/package/lmtp

