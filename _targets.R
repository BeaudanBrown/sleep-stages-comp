library(targets)
library(crew)
library(tarchetypes)
library(quarto)

dotenv::load_dot_env()
cache_dir <- Sys.getenv("CACHE_DIR")
framingham_dir <- Sys.getenv("FRAMINGHAM_DIR")
shhs_dir <- Sys.getenv("SHHS_DIR")
ncpus <- as.numeric(Sys.getenv("NCPUS"))

# Ensure single threaded within targets
Sys.setenv(R_DATATABLE_NUM_THREADS = 1)
Sys.setenv(OMP_NUM_THREADS = 1)
Sys.setenv(MKL_NUM_THREADS = 1)
Sys.setenv(OPENBLAS_NUM_THREADS = 1)


# set target configs
tar_config_set(store = cache_dir)

# Set target options:
tar_option_set(
  packages = c(
    "data.table",
    "Hmisc",
    "compositions",
    "mice",
    "ggplot2",
    "rms",
    "survival",
    "mgcv",
    "RANN"
  ),
  controller = crew_controller_local(
    workers = ncpus
  ),
  format = "qs",
  seed = 20260202
)

# Run the R scripts in the R/ folder
#tar_source()

source("data_targets.R")
source("analysis_targets.R")
source("constant_targets.R")
source("hull_targets.R")

source("R/make_dataset_from_raw_files.R")
source("R/composition_utils.R")
source("R/composition_support_utils.R")
source("R/prepare_dataset.R")
source("R/comp_hull_julia_utils.R")
source("R/substitution_utils.R")
source("R/bootstrap_utils.R")
source("R/imputation.R")
source("R/cognitive_summary_score.R")
source("R/continuous_utils.R")
source("R/generic_utils.R")
source("R/risk_summary_plot.R")
source("R/plot_utils.R")
source("R/descriptive_utils.R")
source("R/descriptive_table.R")

## pipeline
list(
  constant_targets,
  data_targets,
  hull_targets,
  # descriptives
  tar_target(comp_dist_plot, plot_composition_distribution(dt)),
  tar_target(covariate_table, summarize_analysis_covariates(dt, outcome_vars)),
  # main analysis
  analysis_targets,
  # quarto report
  tar_quarto(
    report,
    path = "report.qmd",
    execute_params = list(targets_store = targets::tar_config_get("store"))
  )
)
