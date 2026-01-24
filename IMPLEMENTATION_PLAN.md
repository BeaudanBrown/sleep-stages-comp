# Implementation Plan - Compositional Sleep Analysis

## Priority 1: Core Infrastructure

- [ ] Configure crew controller for parallel processing with optimal worker settings
- [ ] Set up targets workflow with proper memory management for large compositional datasets
- [ ] Implement robust ILR transformation functions with numerical stability checks
- [ ] Create compositional data validation pipeline with comprehensive QC checks

## Priority 2: Data Pipeline

- [ ] Refactor data loading functions to use consistent naming conventions
- [ ] Implement compositional-aware imputation for 250 iterations
- [ ] Add multivariate density threshold functions for plausible compositions
- [ ] Adjust composition to exclude wake time, include TST as covariate
- [ ] Create data quality report generation target

## Priority 3: Statistical Methods

- [ ] Implement isotemporal substitution function with proper g-computation
- [ ] Add multivariate normal fitting for compositional distributions
- [ ] Implement Rubin's rules for combining 250 imputations
- [ ] Create exhaustive grid search for optimal composition (no optimization needed)

## Priority 4: Analysis Targets

- [ ] Set up dynamic targets for substitution combinations (15, 30, 45, 60 mins)
- [ ] Create targets for dementia/MCI combined endpoint
- [ ] Create targets for MRI outcomes (brain_vol, hippo_vol, wmh_vol)
- [ ] Ensure all targets return data.table with input metadata

## Priority 5: Visualization

- [ ] Implement risk ratio plots with x-axis as minutes substituted
- [ ] Create cumulative risk curves for best/worst/typical compositions
- [ ] Add comparison plots for different outcomes
- [ ] Ensure all plots are publication-ready

## Priority 6: Output Generation

- [ ] Create publication-ready table formatting functions
- [ ] Implement Quarto report template with dynamic results
- [ ] Add figure export functions with consistent styling
- [ ] Create supplementary material generation targets

## Technical Debt & Issues

- [ ] Investigate numerical precision issues in extreme compositions
- [ ] Ensure nix environment has all required packages
- [ ] Check targets seed handling for reproducibility

## Future Enhancements

- [ ] Interactive Shiny app for exploring substitution effects
- [ ] Machine learning approaches for optimal composition finding
- [ ] Time-varying compositional models
- [ ] Joint modeling of multiple outcomes

## Notes

- Sleep composition is 4-part (n1, n2, n3, rem) with wake excluded
- Total sleep time (TST) included as covariate in all models
- All functions should handle edge cases (zero values, extreme compositions)
- Maintain reproducibility with explicit seed management
- Document statistical assumptions in code comments
- Use dynamic targets exclusively, returning data.table objects
- Run all R code within nix shell environment