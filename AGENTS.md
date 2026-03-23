# AGENTS.md - Sleep Stage Composition Analysis

## Project Overview

This project investigates **hypothetical interventions on sleep stage composition** and their effects on dementia risk and brain health outcomes. Using compositional data analysis (CoDA), we estimate causal effects of reallocating time between sleep stages (N1, N2, N3/SWS, REM) via g-computation.

### Research Questions
1. **Isotemporal substitutions:** What is the effect of increasing time in one sleep stage at the expense of another (e.g., +15 min N3, -15 min REM)?
2. **Ideal composition:** What sleep stage distribution is associated with best outcomes?

### Data Sources
- **SHHS (Sleep Heart Health Study):** PSG data from SHHS-1 (baseline) and SHHS-2 (follow-up)
- **Framingham Offspring Study (FOS):** Dementia outcomes, MRI, covariates
- **Framingham Omni cohort:** Included, with cohort indicator variable

### Key Methodological Approach
- **Exposure:** SHHS-2 sleep composition (ILR-transformed)
- **Adjustment:** SHHS-1 sleep times (raw), total sleep time, confounders
- **Models:** Pooled logistic regression (dementia), linear regression (MRI)
- **Causal inference:** G-computation with density-bounded interventions
- **Inference:** Bootstrap confidence intervals

---

## Repository Structure

```
stages_compositional/
├── _targets.R           # Main pipeline orchestration
├── data_targets.R       # Data loading and preparation targets
├── analysis_targets.R   # Analysis targets (models, substitutions)
├── simulation_targets.R # Simulated data targets (for dev/validation)
├── IMPLEMENTATION_PLAN.md  # Detailed implementation roadmap
├── nixr.sh              # Nix wrapper for running R commands
├── R/                   # R functions and utilities
│   ├── constants.R      # Shared composition constants and labels
│   ├── composition_utils.R  # ILR creation and composition bounds
│   ├── substitution_utils.R # Substitution grids and bounded shifts
│   ├── survival_utils.R     # Survival expansion, formulas, model fitting
│   ├── lmtp_utils.R         # LMTP/TMLE support functions
│   ├── bootstrap_utils.R    # Bootstrap resampling helpers
│   ├── plot_utils.R         # Plot construction and file writing
│   ├── imputation.R         # MICE helpers and imputation workflow
│   ├── make_dataset_from_raw_files.R  # Raw data loading functions
│   ├── prepare_dataset.R              # Data cleaning and outcome derivation
│   ├── simulate_data.R       # Simulated data generation functions
│   ├── validate_simulation.R # Validation of simulation results
│   └── ...                   # Additional focused helper modules
├── scripts/             # Reusable development scripts (gitignored)
│   ├── README.md        # Documentation for available scripts
│   └── *.R              # Individual scripts for debugging/inspection
├── specs/               # Detailed specifications for each analysis component
│   ├── data.md          # Variables, cleaning, exclusions
│   ├── composition.md   # ILR transformation, SBP choice
│   ├── models.md        # Model specifications, formulas
│   ├── outcomes.md      # Outcome definitions and timing
│   ├── analysis.md      # Isotemporal substitution and ideal composition methods
│   └── simulation.md    # Simulated data specification
├── Analysis_plan/       # LaTeX analysis plan (DO NOT MODIFY)
└── .env                 # Environment variables for data paths (not in git)
```

---

## Technology Stack

| Component | Tool |
|-----------|------|
| Pipeline | `{targets}` with `{tarchetypes}` |
| Data manipulation | `{data.table}` |
| Compositional analysis | `{compositions}` |
| Imputation | `{mice}` |
| Regression | `{Hmisc}` (rcs), base R glm/lm |
| Storage format | `{qs}` (fast serialization) |

---

## Development Environment (Nix)

This project uses **Nix** for reproducible development environments. All R packages and dependencies are managed through `flake.nix`.

### Running R Commands

Use the **`nixr.sh`** wrapper script to run R commands through the nix environment:

```bash
# Run R commands directly
./nixr.sh "library(targets); tar_make()"

# Run a script file
./nixr.sh -f my_script.R

# Load targets and check status
./nixr.sh "targets::tar_visnetwork()"

# Run specific simulation targets
./nixr.sh "targets::tar_make(names = starts_with('sim_'))"
```

### Why Use the Wrapper?

- Ensures all required R packages are available
- Maintains reproducibility across different machines
- Handles nix environment setup automatically

### Alternative: Manual Nix Shell

If you need an interactive R session:

```bash
nix develop
R
```

---

## Development Scripts (`scripts/`)

The `scripts/` directory contains reusable R scripts for common debugging and inspection tasks. This prevents clogging the context window with repeated diagnostic commands.

Canonical entrypoints:
- Targets pipeline: `_targets.R`, `data_targets.R`, `analysis_targets.R`, `simulation_targets.R`
- Analysis code: focused modules under `R/`
- Tests: `tests/testthat.R` and `tests/testthat/`
- Old root-level `test_*.R` / `debug_*.R` entrypoints were removed; new one-off workflows should go in `scripts/` instead.

### Available Scripts

See `scripts/README.md` for the full list of available scripts and their purposes.

### Common Usage

```bash
# Inspect simulated data structure
./nixr.sh -f scripts/inspect_sim_data.R

# Test make_cuts() function
./nixr.sh -f scripts/test_make_cuts.R

# Check ILR coordinates are valid
./nixr.sh -f scripts/check_ilrs.R

# Interactive session with everything loaded
./nixr.sh -i
```

### Creating New Scripts

When you find yourself repeating the same diagnostic commands:

1. Create a new script in `scripts/` following the naming convention: `verb_noun.R`
2. Add header documentation explaining purpose and usage
3. Update `scripts/README.md` to document it
4. Use `./nixr.sh -f scripts/your_script.R` to run it

**Note:** The `scripts/` directory is gitignored (except `README.md`). Scripts are for local development only.

---

## Coding Conventions

### R Style
- **Data frames:** Use `data.table` throughout, not `dplyr`
- **Assignment:** Use `<-` not `=`
- **Pipes:** Use base R `|>` not magrittr `%>%`
- **Column selection:** Use `..vars` syntax for data.table
- **Naming:** snake_case for variables and functions

### Function Design
- Functions should be pure where possible (no side effects)
- Large model objects should be stripped before storage (see `strip_glm()`, `strip_lm()`)
- Functions that operate on data should take `dt` as first argument

### Targets Pipeline
- File inputs use `format = "file"` for dependency tracking
- Intermediate objects use `format = "qs"` (default)
- Use `tar_target(..., pattern = map(...))` for mapped operations
- Keep targets granular for caching efficiency

---

## Data Confidentiality

**CRITICAL:** The data is confidential health information.

- **NEVER** print, display, or log individual-level data
- **NEVER** run R code that outputs raw data values
- **NEVER** commit data files to git
- Data paths are in `.env` (not tracked)
- Only aggregated statistics (means, counts, model coefficients) may be displayed

---

## Quick Reference for Agents

### Current MI state

- `imp_mids` is a real `mice::mids` object.
- `imp_datasets` is the canonical bundle of completed datasets materialized from `imp_mids`.
- `imp` is still a legacy single-complete convenience target and should not be used for new analysis wiring.
- If you are changing the analysis graph, prefer `imp_datasets` or `imp_mids` over `imp`.
- On branch `lmtp`, the remaining single-imputation drift is the legacy analysis scaffold in `analysis_targets.R` (`timegroup_cuts`, `dt_surv_long`, `dt_surv_wide`, `comp_limits`, `lmtp_surv_cols`, `lmtp_baseline_covars`, and the top-level `comparison_contract`).
- The support-aware substitution grid is already MI-first: directional support frontiers are computed per imputation and then combined conservatively across imputations.
- `R/bootstrap_utils.R::run_bootstrap_rep()` already follows bootstrap-resample -> imputation -> complete all datasets -> fit within each completed dataset -> average across imputations.

### To understand the data structure:
→ Read `specs/data.md`

### To understand the composition/ILR approach:
→ Read `specs/composition.md`

### To understand model specifications:
→ Read `specs/models.md`

### To understand outcome definitions:
→ Read `specs/outcomes.md`

### To understand the analysis methods:
→ Read `specs/analysis.md`

### To understand simulated data (for dev/validation):
→ Read `specs/simulation.md`

### To see the technical roadmap:
→ Read `IMPLEMENTATION_PLAN.md`
→ Use coordinator Beads epic `coordinator-xyb` for live status, blockers, and next actions

### To understand the current LMTP/TMLE development issues:
→ Read `specs/analysis.md`
→ Check `analysis_targets.R`, `R/lmtp_utils.R`, and `R/substitution_utils.R` together

### To modify the pipeline:
1. Check which targets are affected: `tar_visnetwork()`
2. Modify functions in `R/` 
3. Update target definitions in `data_targets.R`, `analysis_targets.R`, or `simulation_targets.R`
4. Run `tar_make()` to rebuild

---

## Simulated Data

For **privacy-safe development** and **pipeline validation**, simulated data is available.

### Why Use Simulated Data?
1. **Privacy:** Agents can freely query, display, and manipulate simulated data without confidentiality concerns
2. **Validation:** Known causal effects are baked into the data - the pipeline should recover them
3. **Iteration:** Smaller sample sizes enable faster development cycles

### Working with Simulated Data
- Use `sim_dt` targets instead of `dt` for development
- True effects are defined in `sim_specs` target
- Check `validation_results` to verify pipeline recovers known effects
- See `specs/simulation.md` for full specification

### Predefined Scenarios
| Scenario | Description | Key Parameters |
|----------|-------------|----------------|
| `null_effect` | No sleep composition effects | All β = 0 |
| `protective_n3` | N3/SWS is protective | effect_R2_dem = -0.3 |
| `age_interaction` | Effect varies by age | interaction term |

---

## LMTP Contract Notes

The repo currently has an experimental LMTP/TMLE survival path for the dementia/MCI substitution analysis. The intended LMTP estimand is:

> risk ratio under each substitution policy compared with the no-intervention risk.

This requires:

1. A no-intervention reference fit from `lmtp_tmle(..., shift = NULL)`
2. A substitution fit for each shifted policy
3. A contrast from `lmtp_contrast(..., ref = reference_fit, type = "rr")`

Important implementation notes:
- Do not assume `tidy(lmtp_tmle_fit)` is already a risk ratio; it is the mean outcome under that intervention.
- If checking LMTP plots, verify that a 0-minute shift gives a risk ratio near 1.
- For sleep-duration adjustment:
  - Do not include SHHS-1 `slp_time` if SHHS-1 stage minutes `n1`, `n2`, `n3`, and `rem` are already in the model.
  - Do include SHHS-2 `slp_time_s2`, because the SHHS-2 ILR coordinates encode composition, not duration.

---

## Key Decisions Log

| Decision | Rationale |
|----------|-----------|
| 5 components (N1,N2,N3,WASO,REM), not 4 | WASO is part of the intended SHHS-2 exposure composition; adjust for sleep duration separately |
| SHHS-1 as raw times, not ILR | S1 is confounder, not exposure; simpler adjustment |
| Use S1 data as-is despite battery issues | Missingness likely MCAR; bias from exclusion > measurement error |
| SBP: current 5-part matrix in `R/constants.R` | Keep the component order fixed while the broader stats pipeline is being tightened |
| First MRI post-SHHS-2 | Adjust for time-since-exposure; no imputation of MRI timing |
| Grid search for ideal composition | 15-min resolution; filter by MVN density |
