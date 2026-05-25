library(targets)
library(crew)
library(tarchetypes)

dotenv::load_dot_env()
cache_dir <- Sys.getenv("CACHE_DIR")
framingham_dir <- Sys.getenv("FRAMINGHAM_DIR")
shhs_dir <- Sys.getenv("SHHS_DIR")
ncpus <- future::availableCores() - 4

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
    "mgcv"
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

source("R/make_dataset_from_raw_files.R")
source("R/composition_utils.R")
source("R/prepare_dataset.R")
source("R/survival_utils.R")
source("R/comp_hull_julia_utils.R")
source("R/substitution_utils.R")
source("R/bootstrap_utils.R")
source("R/risk_summary_plot.R")

## pipeline
list(
  constant_targets,
  data_targets,
  time_to_event_targets
)
