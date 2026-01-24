## Build & Run

Enter nix shell environment: `nix develop`
Run full analysis pipeline: `nix develop -c Rscript -e "targets::tar_make()"`
Run specific target: `nix develop -c Rscript -e "targets::tar_make(substitution_results)"`
Check pipeline status: `nix develop -c Rscript -e "targets::tar_progress()"`
Add new R package: Use nixos_nix MCP to find package, then add to flake.nix

## Validation

Run these after implementing to get immediate feedback:

- Pipeline validation: `Rscript -e "targets::tar_validate()"`
- Check convergence: `Rscript -e "tar_read(imputation_diagnostics)"`
- Memory usage: `Rscript -e "targets::tar_resources()"`
- Code style: `air format R/*.R`

## Operational Notes

### Memory Management
- Set crew workers to cores - 1: `parallel::detectCores() - 1`
- Enable garbage collection: `gc_before_wait = TRUE`

### Common Issues
- If targets cache corrupted: `tar_destroy()` then rebuild
- For debugging specific target: `tar_option_set(debug = "target_name")`
- Check crew worker logs in `.crew/` directory

### Codebase Patterns
- All analysis functions in `R/` directory
- Targets defined in `_targets.R` and `*_targets.R` files  
- Use `tar_source()` to load all R functions
- Compositional data stored as data.table with class "coda"

### Validation Targets
- `data_validated_raw`: Raw data with validation flags and Mahalanobis distance
- `data_clean`: Data filtered for valid records (positive components, sum constraints, plausible values)
- `data_final`: Clean data with calculated `wake_time` (4-part composition + wake)
