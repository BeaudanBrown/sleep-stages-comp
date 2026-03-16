# Validation Patterns

Use these checks before trusting a new implementation.

## Estimand checks

- A zero-shift or identity intervention should produce a contrast near the null value implied by the estimand.
- LMTP risk ratios should be near 1 under no change.
- Additive contrasts should be near 0 under no change.

## Structural checks

- Branching targets must consume the mapped substitution value, not a fixed row or global object.
- Wide survival data should have monotone post-event outcomes if the package expects last-outcome-carried-forward semantics.
- Treatment-shift helpers should not mutate censoring or competing-event columns unless that is deliberate and documented.

## Sensitivity checks

- Report how many observations are actually intervened on.
- Compare support diagnostics across substitutions and durations.
- Use a simple simulated data-generating process with known null or directional effects before trusting real-data output.

