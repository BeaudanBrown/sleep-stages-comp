# Statistical Test Design

## What to test

- Algebraic invariants:
  totals preserved, dimensions correct, names aligned, order-sensitive mappings respected.
- Estimand invariants:
  null intervention gives null contrast, identity transforms are unchanged, reference-vs-intervention comparisons use the right baseline.
- DGP recovery:
  simple simulated scenarios recover direction and approximate magnitude.
- Bug regressions:
  every substantive historical bug gets a focused test.

## Patterns for this repository

- `make_ilrs()`:
  test column count, naming, and deterministic recomputation after a known substitution.
- `apply_substitution()`:
  test preserved totals, correct changed parts, and correct `substituted` flags under feasible and infeasible cases.
- LMTP helpers:
  test that the no-intervention reference path is present and that a 0-minute shift gives a contrast near the null.
- Targets definitions:
  test target shape with `tar_manifest()`-level expectations where possible rather than expensive end-to-end runs.

## What not to do

- Do not use confidential rows as fixtures.
- Do not pin tests to unstable random outputs without setting seeds or using broad tolerances.
- Do not assert scientific claims from a single noisy fit when a simpler deterministic contract can be tested directly.

