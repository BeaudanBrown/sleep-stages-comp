# Build Phase: Compositional Sleep Stage Analysis Implementation

## Phase 0: Context Loading
0a. Study `specs/*` with up to 500 parallel Sonnet subagents to learn the compositional analysis specifications.
0b. Study @IMPLEMENTATION_PLAN.md to understand current priorities.
0c. Study existing `R/*` functions for compositional data analysis patterns.
0d. Use Context7 library documentation for targets, crew, compositions, and other R packages.
0e. All R code must be run within the nix environment: `nix develop -c Rscript`

## Phase 1: Implementation
1. Your task is to implement compositional analysis functionality per the specifications using parallel subagents. Follow @IMPLEMENTATION_PLAN.md and choose the most important item to address. 

**Before implementation:**
- Search the codebase using Sonnet subagents to confirm functionality doesn't exist
- Review existing patterns in `R/*` for consistency
- Check targets workflow for similar branching patterns
- Verify required R packages are in flake.nix, add using nixos_nix MCP if needed

**Implementation guidelines:**
- Use targets cross() and map() for generating substitution combinations
- Implement crew controllers for parallel execution
- Follow functional programming patterns (pure functions, no side effects)
- Use data.table for efficient data manipulation
- Leverage compositions package for ILR transformations

**Key patterns to follow:**
```r
# Use dynamic targets that return data.table with metadata
tar_target(
  substitution_results,
  {
    scenarios <- expand.grid(
      from = c("n1", "n2", "n3", "rem"),
      to = c("n1", "n2", "n3", "rem"),
      minutes = c(15, 30, 45, 60)
    ) %>% filter(from != to)
    
    # Return data.table with all inputs and results
    map_dfr(seq_len(nrow(scenarios)), function(i) {
      perform_substitution(
        data = data,
        from = scenarios$from[i],
        to = scenarios$to[i],
        minutes = scenarios$minutes[i]
      )
    })
  },
  pattern = map(data_imputed)
)
```

## Phase 2: Testing & Validation
2. After implementing functionality:
   - Run targets pipeline: `nix develop -c Rscript -e "targets::tar_make()"`
   - Validate plausibility thresholds for realistic substitutions
   - Ensure reproducibility with set seeds
   - Check Rubin's rules combination for 250 imputations

Ultrathink about edge cases:
   - Participants with extreme sleep compositions
   - Missing data patterns  
   - Numerical stability in ILR transformations (now 3 coordinates, not 4)
   - Convergence in imputation models (250 iterations)

## Phase 3: Documentation & Updates
3. When you discover issues or complete tasks:
   - Immediately update @IMPLEMENTATION_PLAN.md with findings
   - Document any deviations from specs with rationale
   - Add operational notes to @AGENTS.md for future runs
   - Update specs if implementation reveals better patterns

## Phase 4: Version Control
4. When functionality is complete and tested:
   - Stage all changes: `git add -A`
   - Commit with descriptive message: `git commit -m "feat: implement isotemporal substitution for [specific functionality]"`
   - Push to remote: `git push`
   - Create semantic version tag if milestone reached

## Important Implementation Notes

**99999.** Document the WHY in comments - explain compositional constraints and statistical assumptions

**999999.** Single source of truth - consolidate substitution logic in one place, not scattered

**9999999.** Create git tag when major analysis components complete (e.g., "v0.1.0-substitutions-complete")

**99999999.** Add diagnostic logging for:
   - Number of valid compositions after substitution
   - Convergence of statistical models
   - Memory usage in parallel computation

**999999999.** Keep @IMPLEMENTATION_PLAN.md current - future agents need accurate status

**9999999999.** Update @AGENTS.md with discovered commands:
   - How to run specific substitution analyses
   - Memory settings for crew workers
   - Troubleshooting targets cache issues

**99999999999.** Resolve any bugs immediately, even if unrelated to current task

**999999999999.** Implement completely - no placeholders in statistical functions

**9999999999999.** Clean @IMPLEMENTATION_PLAN.md periodically, archiving completed items

**99999999999999.** If specs conflict with compositional theory, use Opus 4.5 with 'ultrathink' to resolve

**999999999999999.** CRITICAL: Keep @AGENTS.md operational only - implementation details belong in code comments or specs

## Compositional Analysis Checklist
- [ ] ILR transformations work with 4-part sleep composition (excluding wake)
- [ ] Substitutions maintain realistic sleep patterns
- [ ] Multivariate density threshold prevents impossible compositions  
- [ ] Imputation respects compositional geometry
- [ ] Results include back-transformation to interpretable units
- [ ] Rubin's rules correctly combine 250 imputations
- [ ] Total sleep time included as covariate