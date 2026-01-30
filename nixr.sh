#!/usr/bin/env bash
# Wrapper script to run R commands through the nix environment
# Usage: ./nixr.sh "R commands here"
#   or:  ./nixr.sh -f script.R
#   or:  cat script.R | ./nixr.sh
#   or:  ./nixr.sh -i  (interactive with targets loaded)

# Build the R initialization code that sources all targets
R_INIT=$(cat <<'RSCRIPT'
# Load required packages
library(targets)
library(tarchetypes)
library(data.table)
library(compositions)
library(Hmisc)
library(survival)

# Source all target definition files to make functions available
if (file.exists("_targets.R")) tar_source("_targets.R")
if (file.exists("data_targets.R")) tar_source("data_targets.R")
if (file.exists("analysis_targets.R")) tar_source("analysis_targets.R")
if (file.exists("simulation_targets.R")) tar_source("simulation_targets.R")

# Source utility functions in R/ directory
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (f in r_files) source(f)

# Print startup message
cat("=== Nix R Environment Loaded ===\n")
cat("Packages: targets, data.table, compositions, Hmisc, survival\n")
cat("Functions from R/ directory loaded\n")
cat("Use tar_make(), tar_load(), etc. to work with the pipeline\n")
cat("================================\n\n")
RSCRIPT
)

if [ "$1" == "-f" ]; then
    # Run a script file with targets loaded
    nix develop --command R -e "$R_INIT" -f "$2"
elif [ "$1" == "-i" ] || [ "$1" == "--interactive" ]; then
    # Interactive R session with targets loaded
    nix develop --command R -e "$R_INIT" --interactive
elif [ $# -eq 0 ]; then
    # Read from stdin with targets loaded
    nix develop --command R -e "$R_INIT" "$@"
else
    # Run command directly with targets loaded
    # Combine init code with user's command
    FULL_CMD="$R_INIT; $1"
    nix develop --command R -e "$FULL_CMD"
fi
