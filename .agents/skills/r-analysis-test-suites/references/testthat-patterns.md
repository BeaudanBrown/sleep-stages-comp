# testthat Patterns

## Modern framework basics

- Use `testthat` edition 3 conventions.
- Organize tests around one behavior per file or tightly related behaviors.
- Use helpers and fixtures to keep repeated synthetic data setup out of assertions.
- Use `expect_equal(..., tolerance = ...)` for numerical results that should be close.
- Use snapshot tests sparingly for stable textual outputs, not for noisy model summaries.
- Use local state helpers such as `withr` patterns when tests need temporary options, files, or environment changes.

## Good fits for this repo

- `expect_named()` or column checks for target outputs.
- `expect_true()` and `expect_false()` for feasibility flags and monotonicity.
- `expect_equal()` for closure, totals, and identity transformations.
- `expect_gt()` and `expect_lt()` for directional effects under simple simulated DGPs.
- `expect_error()` for invalid component definitions or malformed substitution requests.

## Existing online skill

MCP Market already has a strong general testing skill:

- R Package Testing with testthat: https://mcpmarket.com/tools/skills/r-package-testing-1

It is useful for general `testthat` structure and mocking patterns, but it is not specific to statistical estimands or causal validation.

## Sources

- `testthat` home page: https://testthat.r-lib.org/
- `R Packages` testing chapter: https://r-pkgs.org/testing-basics.html
- MCP Market, R Package Testing with testthat: https://mcpmarket.com/tools/skills/r-package-testing-1

