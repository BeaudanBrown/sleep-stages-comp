# Reusable Scripts Directory

This directory contains reusable R scripts for common development and debugging tasks. These scripts are designed to be run via the nixr.sh wrapper.

## Purpose

The goal of this directory is to:
- Avoid repeating common diagnostic commands in the context window
- Provide a library of tested, reusable scripts for new agents
- Document common debugging and development workflows
- Keep the main repository clean of transient debugging code

**Note:** This directory is gitignored. Scripts here are for local development only.

---

## Available Scripts

### Data Inspection

| Script | Purpose | Usage |
|--------|---------|-------|
| `inspect_sim_data.R` | Load and inspect simulated data structure | `./nixr.sh -f scripts/inspect_sim_data.R` |
| `check_ilrs.R` | Verify ILR coordinates are computed correctly | `./nixr.sh -f scripts/check_ilrs.R` |
| `validate_composition.R` | Check composition variables for NAs/invalid values | `./nixr.sh -f scripts/validate_composition.R` |

### Pipeline Debugging

| Script | Purpose | Usage |
|--------|---------|-------|
| `test_make_cuts.R` | Test the make_cuts() function with current data | `./nixr.sh -f scripts/test_make_cuts.R` |
| `test_surv_expand.R` | Test survival data expansion | `./nixr.sh -f scripts/test_surv_expand.R` |
| `test_model_fit.R` | Test model fitting on simulated data | `./nixr.sh -f scripts/test_model_fit.R` |

### Target Management

| Script | Purpose | Usage |
|--------|---------|-------|
| `clean_simulation.R` | Invalidate and restart simulation targets | `./nixr.sh -f scripts/clean_simulation.R` |
| `check_targets_status.R` | Show outdated and errored targets | `./nixr.sh -f scripts/check_targets_status.R` |

---

## Creating New Scripts

When creating a new script:

1. **Name it descriptively**: `verb_noun.R` (e.g., `inspect_sim_data.R`)
2. **Add header documentation**: Purpose, inputs, outputs, usage example
3. **Use the nixr.sh wrapper**: Scripts should assume packages are pre-loaded
4. **Update this README**: Add the script to the appropriate table
5. **Test it**: Run via `./nixr.sh -f scripts/your_script.R`

### Script Template

```r
#!/usr/bin/env Rscript
# Script: scripts/your_script_name.R
# Purpose: Brief description of what this script does
# Usage: ./nixr.sh -f scripts/your_script_name.R
# Author: Created by [agent name] on [date]

# Script code here
# Packages (targets, data.table, etc.) are already loaded by nixr.sh

print("Script executed successfully")
```

---

## Quick Commands Reference

```bash
# Run a script
./nixr.sh -f scripts/script_name.R

# Run with verbose output
./nixr.sh -f scripts/script_name.R 2>&1 | tail -50

# Interactive R session with everything loaded
./nixr.sh -i

# Check which targets need rebuilding
./nixr.sh "targets::tar_outdated()"

# Run specific targets
./nixr.sh "targets::tar_make(names = starts_with('sim_'))"

# Visualize target graph
./nixr.sh "targets::tar_visnetwork()"
```

---

## Last Updated

- 2026-01-30: Created scripts directory and README
