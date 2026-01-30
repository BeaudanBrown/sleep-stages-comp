# Simulation functions for privacy-safe development and pipeline validation
# See specs/simulation.md for full specification

#' Create simulation specification with default parameters
#'
#' @param name Character. Scenario name (e.g., "null_effect", "protective_n3")
#' @param n Integer. Sample size. Default 1500.
#' @param seed Integer. Random seed for reproducibility. Default 42.
#' @param effect_R1_dem Numeric. True effect of R1 (restorative/light) on dementia log-odds. Default 0.
#' @param effect_R2_dem Numeric. True effect of R2 (N3/REM) on dementia log-odds. Default 0.
#' @param effect_R3_dem Numeric. True effect of R3 (N1/N2) on dementia log-odds. Default 0.
#' @param effect_age_dem Numeric. Age effect per year on dementia log-odds. Default 0.08.
#' @param effect_tst_dem Numeric. Total sleep time effect on dementia log-odds. Default 0.
#' @param effect_interaction_age_R2 Numeric. Age × R2 interaction coefficient. Default 0.
#' @param baseline_hazard_dem Numeric. Annual baseline dementia hazard. Default 0.005.
#' @param baseline_hazard_death Numeric. Annual baseline death hazard. Default 0.02.
#' @param effect_age_death Numeric. Age effect per year on death log-odds. Default 0.1.
#' @param effect_bmi_death Numeric. BMI effect on death log-odds. Default 0.02.
#' @param max_followup_years Integer. Maximum follow-up duration. Default 20.
#' @param ... Additional parameters for future extensions
#'
#' @return List containing all simulation parameters
#'
#' @examples
#' # Null effect scenario
#' null_spec <- make_sim_spec(name = "null_effect")
#'
#' # Protective N3 scenario
#' n3_spec <- make_sim_spec(
#'   name = "protective_n3",
#'   effect_R2_dem = -0.3
#' )
make_sim_spec <- function(
  name = "custom",
  n = 1500,
  seed = 42,
  effect_R1_dem = 0,
  effect_R2_dem = 0,
  effect_R3_dem = 0,
  effect_age_dem = 0.08,
  effect_tst_dem = 0,
  effect_interaction_age_R2 = 0,
  baseline_hazard_dem = 0.005,
  baseline_hazard_death = 0.02,
  effect_age_death = 0.1,
  effect_bmi_death = 0.02,
  max_followup_years = 20,
  ...
) {
  spec <- list(
    name = name,
    n = n,
    seed = seed,
    effect_R1_dem = effect_R1_dem,
    effect_R2_dem = effect_R2_dem,
    effect_R3_dem = effect_R3_dem,
    effect_age_dem = effect_age_dem,
    effect_tst_dem = effect_tst_dem,
    effect_interaction_age_R2 = effect_interaction_age_R2,
    baseline_hazard_dem = baseline_hazard_dem,
    baseline_hazard_death = baseline_hazard_death,
    effect_age_death = effect_age_death,
    effect_bmi_death = effect_bmi_death,
    max_followup_years = max_followup_years,
    # Distribution parameters for compositional data
    alpha_s1 = c(n1 = 5, n2 = 30, n3 = 10, rem = 12),
    alpha_s2_base = c(n1 = 5, n2 = 30, n3 = 10, rem = 12),
    s1_s2_correlation = 0.6,
    years_s1_to_s2_mean = 5,
    years_s1_to_s2_sd = 1,
    # Distribution parameters for continuous variables
    age_mean = 65,
    age_sd = 10,
    age_min = 40,
    age_max = 90,
    bmi_mean = 28,
    bmi_sd = 5,
    bmi_age_correlation = 0.1,
    tst_mean = 400,
    tst_sd = 60,
    # Additional parameters
    ...
  )

  class(spec) <- c("sim_spec", "list")
  return(spec)
}


#' Main simulation entry point
#'
#' Generates a complete simulated dataset matching the structure of real data.
#' Outcomes are generated from a known causal model with user-specified true effects.
#'
#' @param spec List. Simulation specification created by make_sim_spec()
#'
#' @return data.table with simulated data matching real data structure
#'
#' @examples
#' spec <- make_sim_spec(name = "null_effect", n = 500)
#' sim_data <- simulate_dataset(spec)
simulate_dataset <- function(spec) {
  # If spec is a named sublist from targets branching, extract the actual spec
  # targets map() on named lists may pass list(name = spec) instead of spec
  if (is.list(spec) && length(names(spec)) == 1 && is.list(spec[[1]])) {
    spec <- spec[[1]]
  }

  # Check for required fields (more robust than class check after targets branching)
  required_fields <- c(
    "n",
    "seed",
    "effect_R1_dem",
    "effect_R2_dem",
    "effect_R3_dem",
    "baseline_hazard_dem",
    "baseline_hazard_death"
  )
  missing_fields <- setdiff(required_fields, names(spec))
  if (length(missing_fields) > 0) {
    stop(
      "spec missing required fields: ",
      paste(missing_fields, collapse = ", ")
    )
  }

  # Set seed for reproducibility
  set.seed(spec$seed)

  # Generate components
  dt_baseline <- simulate_baseline(spec)
  dt_sleep <- simulate_sleep_stages(spec, dt_baseline)
  dt_outcomes <- simulate_outcomes(spec, dt_baseline, dt_sleep)

  # Combine into single dataset
  dt <- cbind(dt_baseline, dt_sleep, dt_outcomes)

  return(dt)
}


#' Simulate baseline demographics and confounders
#'
#' Generates correlated demographic variables:
#' - age_s1: truncated normal, mean 65, sd 10, range [40, 90]
#' - gender: Bernoulli, p=0.5
#' - bmi_s1: normal, mean 28, sd 5, correlated with age
#' - IDTYPE: Bernoulli, p=0.9 (Offspring vs Omni)
#' - educat: ordinal, age-dependent
#'
#' @param spec List. Simulation specification
#'
#' @return data.table with baseline variables
simulate_baseline <- function(spec) {
  n <- spec$n

  # Age: truncated normal
  age_s1 <- rnorm(n, mean = spec$age_mean, sd = spec$age_sd)
  age_s1 <- pmin(pmax(age_s1, spec$age_min), spec$age_max)

  # Gender: Bernoulli
  gender <- rbinom(n, 1, 0.5)

  # BMI: normal with correlation to age
  bmi_s1 <- rnorm(n, mean = spec$bmi_mean, sd = spec$bmi_sd)
  # Add small correlation with age
  age_std <- (age_s1 - spec$age_mean) / spec$age_sd
  bmi_s1 <- bmi_s1 + spec$bmi_age_correlation * age_std * spec$bmi_sd

  # IDTYPE: Bernoulli (0.9 Offspring)
  IDTYPE <- rbinom(n, 1, 0.9)

  # Education: ordinal, age-cohort dependent (older → less education)
  # Probabilities decrease with age
  educat_probs <- matrix(0, nrow = n, ncol = 5)
  for (i in seq_len(n)) {
    # Base probabilities shift with age
    age_effect <- (age_s1[i] - 65) / 20 # standardized age effect
    probs <- c(0.25, 0.30, 0.25, 0.15, 0.05) -
      age_effect * c(0.05, 0.03, 0, 0.03, 0.05)
    probs <- pmax(probs, 0.01) # ensure positive
    probs <- probs / sum(probs) # normalize
    educat_probs[i, ] <- probs
  }
  educat <- sapply(seq_len(n), function(i) {
    sample(1:5, 1, prob = educat_probs[i, ])
  })

  # Create PID (participant ID)
  PID <- sprintf("SIM_%05d", seq_len(n))

  dt <- data.table::data.table(
    PID = PID,
    age_s1 = age_s1,
    gender = gender,
    bmi_s1 = bmi_s1,
    IDTYPE = IDTYPE,
    educat = educat
  )

  return(dt)
}


#' Simulate SHHS-1 and SHHS-2 sleep stage compositions
#'
#' Uses Dirichlet distribution for compositional data:
#' - SHHS-1: Base composition with age effect (older → less N3, more N1)
#' - SHHS-2: Autocorrelated with S1 (rho≈0.6), plus additional aging
#' - Total sleep time: normal, mean 400, sd 60 minutes
#'
#' @param spec List. Simulation specification
#' @param dt_baseline data.table. Baseline variables from simulate_baseline()
#'
#' @return data.table with sleep stage variables (n1_s1, n2_s1, etc.)
simulate_sleep_stages <- function(spec, dt_baseline) {
  n <- spec$n
  age_s1 <- dt_baseline$age_s1

  # SHHS-1: Dirichlet with age-adjusted concentration parameters
  # Older participants have less N3, more N1
  alpha_s1 <- matrix(0, nrow = n, ncol = 4)
  colnames(alpha_s1) <- c("n1", "n2", "n3", "rem")

  age_dev <- (age_s1 - 65) / 20 # deviation from mean age, scaled

  for (i in seq_len(n)) {
    # Adjust concentration parameters by age
    alpha_s1[i, "n1"] <- spec$alpha_s1["n1"] + age_dev[i] * 2 # more N1 with age
    alpha_s1[i, "n2"] <- spec$alpha_s1["n2"] # N2 relatively stable
    alpha_s1[i, "n3"] <- max(spec$alpha_s1["n3"] - age_dev[i] * 3, 1) # less N3 with age
    alpha_s1[i, "rem"] <- spec$alpha_s1["rem"] - age_dev[i] * 0.5 # slightly less REM
  }

  # Generate SHHS-1 proportions from Dirichlet
  props_s1 <- matrix(0, nrow = n, ncol = 4)
  colnames(props_s1) <- c("n1", "n2", "n3", "rem")
  for (i in seq_len(n)) {
    # Convert acomp to numeric vector to avoid compositional arithmetic issues
    props_s1[i, ] <- as.numeric(rDirichlet.acomp(1, alpha_s1[i, ]))
  }

  # Total sleep time S1
  tst_s1 <- rnorm(n, mean = spec$tst_mean, sd = spec$tst_sd)
  tst_s1 <- pmax(tst_s1, 180) # minimum 3 hours

  # Stage minutes S1
  n1_s1 <- props_s1[, "n1"] * tst_s1
  n2_s1 <- props_s1[, "n2"] * tst_s1
  n3_s1 <- props_s1[, "n3"] * tst_s1
  rem_s1 <- props_s1[, "rem"] * tst_s1

  # Sleep time (same as TST for sim, but separate variable for compatibility)
  slp_time <- tst_s1

  # SHHS-2: Years between assessments
  years_s1_to_s2 <- rnorm(
    n,
    mean = spec$years_s1_to_s2_mean,
    sd = spec$years_s1_to_s2_sd
  )
  years_s1_to_s2 <- pmax(years_s1_to_s2, 2) # minimum 2 years

  # Autocorrelated composition with S1
  # Use geometric mean approach: S2 = weighted combination of S1 and new draw
  props_s2 <- matrix(0, nrow = n, ncol = 4)
  colnames(props_s2) <- c("n1", "n2", "n3", "rem")

  for (i in seq_len(n)) {
    # Generate new composition
    age_s2 <- age_s1[i] + years_s1_to_s2[i]
    age_dev_s2 <- (age_s2 - 65) / 20

    alpha_s2_i <- c(
      n1 = spec$alpha_s2_base["n1"] + age_dev_s2 * 2,
      n2 = spec$alpha_s2_base["n2"],
      n3 = max(spec$alpha_s2_base["n3"] - age_dev_s2 * 3, 1),
      rem = spec$alpha_s2_base["rem"] - age_dev_s2 * 0.5
    )

    # Convert acomp to numeric vector to avoid compositional arithmetic issues
    new_props <- as.numeric(rDirichlet.acomp(1, alpha_s2_i))

    # Combine with S1 using autocorrelation
    rho <- spec$s1_s2_correlation
    # Use log-ratio space for proper compositional interpolation
    log_s1 <- log(props_s1[i, ] + 0.001) # add small constant to avoid log(0)
    log_new <- log(new_props + 0.001)
    log_s2 <- rho * log_s1 + (1 - rho) * log_new
    props_s2[i, ] <- exp(log_s2) / sum(exp(log_s2)) # normalize
  }

  # Total sleep time S2 (slightly correlated with S1)
  tst_s2 <- rnorm(
    n,
    mean = spec$tst_mean + 0.2 * (tst_s1 - spec$tst_mean),
    sd = spec$tst_sd * 0.8
  )
  tst_s2 <- pmax(tst_s2, 180)

  # Stage minutes S2
  n1_s2 <- props_s2[, "n1"] * tst_s2
  n2_s2 <- props_s2[, "n2"] * tst_s2
  n3_s2 <- props_s2[, "n3"] * tst_s2
  rem_s2 <- props_s2[, "rem"] * tst_s2

  dt <- data.table::data.table(
    n1_s1 = n1_s1,
    n2_s1 = n2_s1,
    n3_s1 = n3_s1,
    rem_s1 = rem_s1,
    slp_time = slp_time,
    n1_s2 = n1_s2,
    n2_s2 = n2_s2,
    n3_s2 = n3_s2,
    rem_s2 = rem_s2,
    total_sleep_time_s2 = tst_s2,
    years_s1_to_s2 = years_s1_to_s2
  )

  return(dt)
}


#' Simulate dementia and death outcomes from known DGP
#'
#' Dementia hazard model (discrete-time):
#'   logit(h_dem) = baseline + beta_R1*R1 + beta_R2*R2 + beta_R3*R3 + beta_age*age + ...
#'
#' Death hazard model (competing risk):
#'   logit(h_death) = baseline + gamma_age*age + gamma_bmi*bmi + ...
#'
#' Events generated sequentially respecting competing risks.
#'
#' @param spec List. Simulation specification
#' @param dt_baseline data.table. Baseline variables
#' @param dt_sleep data.table. Sleep stage variables
#'
#' @return data.table with outcome variables
simulate_outcomes <- function(spec, dt_baseline, dt_sleep) {
  n <- spec$n

  # Extract variables for outcome model
  age_s1 <- dt_baseline$age_s1
  bmi_s1 <- dt_baseline$bmi_s1

  # Create ILR coordinates from SHHS-2 sleep stages
  comp <- compositions::acomp(dt_sleep[, .(n1_s2, n2_s2, n3_s2, rem_s2)])

  # Use the SBP from constants.R (must be 4-part for simulation)
  # Create temporary SBP matching expected 4-part structure
  sbp_4part <- matrix(
    c(
      -1,
      -1,
      1,
      1, # R1: restorative vs light
      0,
      0,
      1,
      -1, # R2: N3 vs REM
      1,
      -1,
      0,
      0 # R3: N1 vs N2
    ),
    ncol = 4,
    byrow = TRUE
  )
  v_4part <- compositions::gsi.buildilrBase(t(sbp_4part))

  ilr_coords <- compositions::ilr(comp, V = v_4part)
  R1 <- ilr_coords[, 1]
  R2 <- ilr_coords[, 2]
  R3 <- ilr_coords[, 3]

  # Age at SHHS-2
  age_s2 <- age_s1 + dt_sleep$years_s1_to_s2
  tst_s2 <- dt_sleep$total_sleep_time_s2

  # Initialize outcome variables
  dem_status <- integer(n)
  dem_surv_date <- numeric(n)
  death_status <- integer(n)
  death_surv_date <- numeric(n)
  dem_or_mci_status <- integer(n)
  dem_or_mci_surv_date <- numeric(n)

  # Generate events sequentially
  for (i in seq_len(n)) {
    # Initialize event flags
    dem_event <- FALSE
    death_event <- FALSE
    event_year <- spec$max_followup_years

    # Loop through years
    for (year in seq_len(spec$max_followup_years)) {
      # Current age
      current_age <- age_s2[i] + year

      if (current_age > 100) {
        # Censor at age 100
        event_year <- year - 1
        break
      }

      # Dementia hazard
      logit_h_dem <- log(
        spec$baseline_hazard_dem / (1 - spec$baseline_hazard_dem)
      ) +
        spec$effect_R1_dem * R1[i] +
        spec$effect_R2_dem * R2[i] +
        spec$effect_R3_dem * R3[i] +
        spec$effect_age_dem * (current_age - 65) +
        spec$effect_tst_dem * (tst_s2[i] - 400) / 60 + # standardized TST
        spec$effect_interaction_age_R2 * (current_age - 65) * R2[i]

      h_dem <- 1 / (1 + exp(-logit_h_dem))

      # Death hazard
      logit_h_death <- log(
        spec$baseline_hazard_death / (1 - spec$baseline_hazard_death)
      ) +
        spec$effect_age_death * (current_age - 65) +
        spec$effect_bmi_death * (bmi_s1[i] - 28)

      h_death <- 1 / (1 + exp(-logit_h_death))

      # Generate events (competing risks)
      u <- runif(2)

      if (u[1] < h_dem && !death_event) {
        dem_event <- TRUE
        dem_surv_date[i] <- year * 365.25 # days
        dem_status[i] <- 1
        # Death is competing risk - check if death occurs first
        if (u[2] < h_death) {
          death_event <- TRUE
          death_surv_date[i] <- year * 365.25
          death_status[i] <- 1
          # If both in same year, death wins (competing risk)
          dem_event <- FALSE
          dem_status[i] <- 0
          dem_surv_date[i] <- year * 365.25
        }
        break
      } else if (u[2] < h_death) {
        death_event <- TRUE
        death_surv_date[i] <- year * 365.25
        death_status[i] <- 1
        break
      }

      event_year <- year
    }

    # If no event, censor at end of follow-up
    if (!dem_event && !death_event) {
      dem_surv_date[i] <- event_year * 365.25
      death_surv_date[i] <- event_year * 365.25
      dem_status[i] <- 0
      death_status[i] <- 0
    }

    # For simplicity, MCI same as dementia in simulation
    # (can be extended later)
    dem_or_mci_status[i] <- dem_status[i]
    dem_or_mci_surv_date[i] <- dem_surv_date[i]
  }

  dt <- data.table::data.table(
    dem_status = dem_status,
    dem_surv_date = pmax(dem_surv_date, 1), # ensure minimum 1 day
    death_status = death_status,
    death_surv_date = pmax(death_surv_date, 1), # ensure minimum 1 day
    dem_or_mci_status = dem_or_mci_status,
    dem_or_mci_surv_date = pmax(dem_or_mci_surv_date, 1) # ensure minimum 1 day
  )

  return(dt)
}


#' Prepare simulated dataset to match real data structure
#'
#' Applies same transformations as prepare_dataset() to ensure
#' column names and types match real data.
#'
#' @param dt_raw data.table. Raw simulated data from simulate_dataset()
#'
#' @return data.table with prepared simulated data
prepare_simulated_dataset <- function(dt_raw) {
  dt <- data.table::copy(dt_raw)

  # Create derived variables that would come from prepare_dataset()

  # ILR coordinates (already computed in simulate_outcomes, but ensure they exist)
  # Use 4-part composition from SHHS-2
  comp <- compositions::acomp(dt[, .(n1_s2, n2_s2, n3_s2, rem_s2)])

  # SBP for 4-part composition
  sbp_4part <- matrix(
    c(
      -1,
      -1,
      1,
      1, # R1: restorative vs light
      0,
      0,
      1,
      -1, # R2: N3 vs REM
      1,
      -1,
      0,
      0 # R3: N1 vs N2
    ),
    ncol = 4,
    byrow = TRUE
  )
  v_4part <- compositions::gsi.buildilrBase(t(sbp_4part))

  ilr_coords <- compositions::ilr(comp, V = v_4part)
  dt[, R1 := ilr_coords[, 1]]
  dt[, R2 := ilr_coords[, 2]]
  dt[, R3 := ilr_coords[, 3]]

  # S1 incomplete indicator (for SHHS-1 battery failure)
  # Default to 0 (complete) in simulation
  dt[, s1_incomplete := 0L]

  # Additional derived variables
  dt[, age_s2 := age_s1 + years_s1_to_s2]

  # Ensure proper integer types for binary variables
  dt[, gender := as.integer(gender)]
  dt[, IDTYPE := as.integer(IDTYPE)]
  dt[, educat := as.integer(educat)]
  dt[, dem_status := as.integer(dem_status)]
  dt[, death_status := as.integer(death_status)]
  dt[, dem_or_mci_status := as.integer(dem_or_mci_status)]

  return(dt)
}
