library(data.table)
library(mice)
library(compositions)
source("R/compositional.R")

#' Perform multiple imputation on sleep data
#'
#' @description
#' Imputes missing values in sleep data using a compositional approach:
#' 1. Transforms sleep components (n1, n2, n3, rem) to ILR coordinates
#' 2. Imputes ILR coordinates and covariates using MICE (m=250)
#' 3. Back-transforms imputed ILR to compositional parts
#'
#' @param data data.table containing sleep data and covariates
#' @param m Integer, number of imputations (default 250)
#' @param max_iter Integer, number of iterations (default 10)
#' @param seed Integer, random seed
#' @return mids object (mice output) containing imputed datasets
#' @export
impute_data <- function(data, m = 250, max_iter = 10, seed = 12345) {
  dt <- copy(data)

  # 1. Transform to ILR
  # We need to handle cases where components are missing.
  # If any component is missing, ILR should be NA.

  parts <- c("n1", "n2", "n3", "rem")

  # check which rows have complete composition
  complete_comp <- complete.cases(dt[, ..parts])

  # Initialize ILR columns with NA
  dt[, `:=`(ilr1 = NA_real_, ilr2 = NA_real_, ilr3 = NA_real_)]

  if (sum(complete_comp) > 0) {
    # Transform valid rows
    dt_valid <- transform_to_ilr(dt[complete_comp])

    # Assign back
    dt[complete_comp, ilr1 := dt_valid$ilr1]
    dt[complete_comp, ilr2 := dt_valid$ilr2]
    dt[complete_comp, ilr3 := dt_valid$ilr3]
  }

  # 2. Setup MICE

  # Select variables for imputation
  # We exclude raw parts from predictor matrix to avoid circularity/collinearity with ILR
  # But we want to impute them? No, we impute ILR then calculate parts.
  # So we exclude parts from the imputation process itself.

  # Define predictors (include ILR, TST, covariates)
  # Exclude id columns if any
  exclude_cols <- c("id", "subid", parts) # Adjust based on actual ID column names
  pred_vars <- setdiff(names(dt), exclude_cols)

  # Configure method
  # Use 'norm' (Bayesian linear regression) for ILR as they are approx normal
  # Use 'pmm' for others if needed, or defaults
  default_method <- make.method(dt[, ..pred_vars])

  # Explicitly set ILR to 'norm'
  default_method[c("ilr1", "ilr2", "ilr3")] <- "norm"

  # 3. Run MICE
  imp <- mice(
    dt[, ..pred_vars],
    m = m,
    maxit = max_iter,
    method = default_method,
    seed = seed,
    printFlag = FALSE
  )

  return(imp)
}

#' Extract and back-transform imputed datasets
#'
#' @param imp mids object from impute_data
#' @param original_data data.table (to merge back ID columns if needed)
#' @return list of data.tables (one per imputation) with n1, n2, n3, rem
#' @export
process_imputations <- function(imp, original_data) {
  m <- imp$m
  results <- vector("list", m)

  # Iterate through imputations
  for (i in 1:m) {
    # Extract completed data
    dt_comp <- as.data.table(complete(imp, i))

    # Back-transform ILR to Composition
    # We need TST. If TST was imputed, use it. If not, use original?
    # Usually TST is part of the imputation model.

    # Check if tst_sum or slp_time is in data
    tst_col <- grep("tst|slp_time", names(dt_comp), value = TRUE)[1]
    if (is.na(tst_col)) {
      # If no TST column, assume normalized or default to 1?
      # Better to warn.
      warning("No TST column found. Returning compositions summing to 1.")
      tst_vals <- 1
    } else {
      tst_vals <- dt_comp[[tst_col]]
    }

    dt_parts <- transform_to_comp(
      dt_comp[, .(ilr1, ilr2, ilr3)],
      total_minutes = tst_vals
    )

    # Combine with other columns
    # We replace the original n1,n2,n3,rem with back-transformed ones
    # And keep other imputed variables

    dt_final <- cbind(
      dt_comp[, !c("ilr1", "ilr2", "ilr3"), with = FALSE],
      dt_parts
    )

    # Add back IDs from original data if they were excluded
    # Assuming row order is preserved (mice preserves it)
    # Be careful if original_data has different row order
    if (!is.null(original_data)) {
      # Merge or bind IDs.
      # Safest is to bind cols that were excluded
      # We need to know which cols were excluded in imputation.
      # For now, let's assume the user handles merging or we just return the imputed block.
      # Ideally, we should include IDs in imputation but set their method to "" (no imputation) and predictor matrix to 0.
      # But since we filtered cols in impute_data, we should return just the result or merge intelligently.

      # Better strategy: impute_data should return mids object.
      # This function processes it.
      # We can just bind with original data's ID columns if we trust row order.
      # MICE preserves row order.

      # Find columns in original not in imp
      missing_cols <- setdiff(names(original_data), names(dt_final))
      if (length(missing_cols) > 0) {
        dt_final <- cbind(original_data[, ..missing_cols], dt_final)
      }
    }

    results[[i]] <- dt_final
  }

  return(results)
}
