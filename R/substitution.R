library(data.table)
source("R/compositional.R")

#' Apply isotemporal substitution to a dataset
#'
#' @description
#' Creates a counterfactual dataset where a specified amount of time is reallocated
#' from one sleep stage to another for each participant.
#'
#' @param data data.table containing n1, n2, n3, rem (in minutes)
#' @param from Character, name of source component ("n1", "n2", "n3", "rem")
#' @param to Character, name of target component
#' @param minutes Numeric, amount of time to substitute
#' @return data.table with modified compositions
#' @export
apply_substitution <- function(data, from, to, minutes) {
  dt <- copy(data)

  # Validation
  if (!all(c(from, to) %in% names(dt))) {
    stop("Source or target component not found in data")
  }

  # Apply substitution
  # Decrease 'from', increase 'to'
  dt[, (from) := get(from) - minutes]
  dt[, (to) := get(to) + minutes]

  # Check for negative values
  # If any component becomes negative, that substitution is mathematically impossible for that person
  # We should flag them or set to NA?
  # Usually we exclude them from the specific scenario analysis.

  dt[, is_possible := (n1 >= 0 & n2 >= 0 & n3 >= 0 & rem >= 0)]

  return(dt)
}

#' Perform full substitution analysis (G-computation)
#'
#' @param data data.table (original imputed dataset)
#' @param model Fitted regression model object (glm, lm, etc.)
#' @param from Source component
#' @param to Target component
#' @param minutes Minutes to substitute
#' @param density_model Optional density model for plausibility check
#' @return data.table with effect estimates
#' @export
analyze_substitution <- function(
  data,
  model,
  from,
  to,
  minutes,
  density_model = NULL
) {
  # 1. Predict under no intervention (or use observed if appropriate, but predict is safer for consistency)
  # Ensure data has ILR coordinates for the model
  dt_base <- transform_to_ilr(data)
  pred_base <- predict(model, newdata = dt_base, type = "response")

  # 2. Create counterfactual data
  dt_sub <- apply_substitution(data, from, to, minutes)

  # 3. Filter impossible/implausible substitutions
  # a. Mathematically impossible (negative time)
  valid_indices <- dt_sub$is_possible

  # b. Biologically implausible (density check)
  if (!is.null(density_model)) {
    # Check density of NEW composition
    # We need to calculate ILR for the substituted data
    # Note: transform_to_ilr might fail if values are negative, so filter first

    # We only check density for mathematically possible ones
    is_plausible <- rep(FALSE, nrow(dt_sub))

    if (any(valid_indices)) {
      dt_check <- dt_sub[valid_indices]
      # Transform
      dt_check_ilr <- transform_to_ilr(dt_check)

      # Check density
      plausible_flags <- check_plausibility(dt_check, density_model)
      is_plausible[valid_indices] <- plausible_flags
    }

    valid_indices <- valid_indices & is_plausible
  }

  # 4. Predict outcomes for valid substitutions
  if (sum(valid_indices) == 0) {
    return(data.table(
      from = from,
      to = to,
      minutes = minutes,
      mean_diff = NA,
      risk_ratio = NA,
      n_included = 0
    ))
  }

  # Transform valid substituted data to ILR for prediction
  dt_sub_valid <- transform_to_ilr(dt_sub[valid_indices])

  # Predict
  pred_sub <- predict(model, newdata = dt_sub_valid, type = "response")

  # Get corresponding base predictions
  pred_base_subset <- pred_base[valid_indices]

  # 5. Calculate effects
  # Mean Difference (Risk Difference)
  mean_diff <- mean(pred_sub - pred_base_subset, na.rm = TRUE)

  # Risk Ratio (Ratio of means)
  # Check if outcome is binary/count (non-negative)
  risk_ratio <- mean(pred_sub, na.rm = TRUE) /
    mean(pred_base_subset, na.rm = TRUE)

  return(data.table(
    from = from,
    to = to,
    minutes = minutes,
    mean_diff = mean_diff,
    risk_ratio = risk_ratio,
    n_included = sum(valid_indices)
  ))
}
