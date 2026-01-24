library(targets)
library(tarchetypes)
library(crew)

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
  format = "qs",
  seed = 12345,
  error = "continue",
  garbage_collection = TRUE,
  controller = crew::crew_controller_local(
    workers = max(1, parallel::detectCores() - 1)
  )
)

# Run the R scripts in the R/ folder
tar_source()

source("data_targets.R")
source("validation_targets.R")

## pipeline
list(
  data_targets,
  validation_targets
)
