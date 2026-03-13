---
name: r-analysis-test-suites
description: Specialized guidance for designing testthat suites for R statistical analysis code, especially simulation-based validation, numerical invariants, edge cases, and regression tests for causal pipelines. Use when creating or reviewing tests for analysis functions, estimators, transformations, target pipelines, or scientific reporting code.
---

# R Analysis Test Suites

Design tests to catch scientific mistakes, not just syntax mistakes. Prefer small deterministic tests, simulation-backed oracle tests, and invariant checks over brittle snapshots of large objects.

## Core workflow

1. Identify the scientific contract of the code.
   Ask what must remain true if the implementation is correct.
2. Test the smallest layer that can express that contract.
   Pure transformations and helper functions come before models and pipelines.
3. Use the right test type.
   Invariants for transformations, oracle tests for simulated DGPs, regression tests for previously fixed bugs, and contract tests for pipeline outputs.
4. Make numerical assertions robust.
   Use tolerances, directionality, monotonicity, and null checks instead of exact floating-point equality where noise is expected.
5. Keep tests privacy-safe.
   Use simulated data only, synthetic fixtures, or aggregated summaries.

## Recommended test categories

- Transformation invariants.
  Example: substitutions preserve total allocated time and non-target parts remain unchanged.
- Support and edge cases.
  Example: infeasible substitutions leave rows unchanged and flag them correctly.
- Statistical oracle tests.
  Example: a simulated null effect yields a contrast near 0 or 1; a protective-N3 DGP yields the expected direction.
- Regression tests for known bugs.
  Example: mapped targets use the branch-specific substitution rather than the first row.
- Pipeline contract tests.
  Example: outputs contain expected columns, estimand labels, and branch counts.

## Review rules

- Avoid tests that depend on confidential data or exact model coefficients from real analyses.
- Avoid asserting full printed model objects.
- Prefer testing quantities with stable scientific meaning: signs, identities, dimensions, bounds, null behavior, and intervention counts.
- If a bug was fixed once, add a narrow regression test for that failure mode.

## References

- Read [references/testthat-patterns.md](references/testthat-patterns.md) for framework usage.
- Read [references/statistical-test-design.md](references/statistical-test-design.md) for analysis-specific patterns.

