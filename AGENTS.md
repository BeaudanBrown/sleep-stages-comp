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
├── R/
│   ├── constants.R      # Composition variables, SBP matrix
│   ├── make_dataset_from_raw_files.R  # Raw data loading functions
│   ├── prepare_dataset.R              # Data cleaning, ILR creation
│   └── utils.R          # Model fitting, prediction, substitution functions
├── specs/               # Detailed specifications for each analysis component
│   ├── data.md          # Variables, cleaning, exclusions
│   ├── composition.md   # ILR transformation, SBP choice
│   ├── models.md        # Model specifications, formulas
│   ├── outcomes.md      # Outcome definitions and timing
│   └── analysis.md      # Isotemporal substitution and ideal composition methods
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

### To modify the pipeline:
1. Check which targets are affected: `tar_visnetwork()`
2. Modify functions in `R/` 
3. Update target definitions in `data_targets.R` or `analysis_targets.R`
4. Run `tar_make()` to rebuild

---

## Current Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Data loading (SHHS + Framingham) | ✅ Complete | Includes Omni |
| Exclusion criteria | ⚠️ Partial | MCI/dementia exclusion done; CVD exclusion needed |
| Composition variables | ⚠️ Needs update | Currently 5 components; should be 4 (N1,N2,N3,REM) |
| ILR transformation | ⚠️ Needs update | Currently uses SHHS-1; should use SHHS-2 |
| Confounders | ❌ Not implemented | Need to add from data dictionary |
| Dementia outcome model | ⚠️ Partial | Structure exists; needs confounders and interactions |
| MRI outcome models | ❌ Not implemented | |
| Death competing risk | ✅ Complete | For dementia outcome |
| Isotemporal substitutions | ✅ Complete | With density checking |
| Ideal composition search | ❌ Not implemented | |
| Bootstrap inference | ❌ Not implemented | |

---

## Key Decisions Log

| Decision | Rationale |
|----------|-----------|
| 4 components (N1,N2,N3,REM), not 5 | Wake excluded; adjust for total sleep time instead |
| SHHS-1 as raw times, not ILR | S1 is confounder, not exposure; simpler adjustment |
| Use S1 data as-is despite battery issues | Missingness likely MCAR; bias from exclusion > measurement error |
| SBP: {N3,REM} vs {N1,N2} hierarchy | Interpretable as "restorative vs light" sleep |
| First MRI post-SHHS-2 | Adjust for time-since-exposure; no imputation of MRI timing |
| Grid search for ideal composition | 15-min resolution; filter by MVN density |
