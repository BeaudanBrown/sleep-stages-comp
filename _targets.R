library(targets)
library(tarchetypes)

dotenv::load_dot_env()
cache_dir <- Sys.getenv("CACHE_DIR")
framingham_dir <- Sys.getenv("FRAMINGHAM_DIR")
shhs_dir <- Sys.getenv("SHHS_DIR")

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
    "mice"
  ),
  format = "qs"
)

# Run the R scripts in the R/ folder
tar_source()

source("data_targets.R")
source("analysis_targets.R")
source("simulation_targets.R")

## pipeline
list(
  data_targets,
  analysis_targets,
  simulation_targets
)
