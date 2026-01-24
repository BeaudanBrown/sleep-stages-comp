library(data.table)
library(compositions)

#' Get the Sequential Binary Partition (SBP) basis for sleep stages
#'
#' @description
#' Defines the specific ILR transformation basis used for 4-part sleep composition.
#' The partition structure is:
#' 1. z1: REM vs NREM (n1, n2, n3) - Represents sleep architecture type (Dreaming vs Non-dreaming)
#' 2. z2: N3 vs Light Sleep (n1, n2) - Represents NREM depth (Deep vs Light)
#' 3. z3: N2 vs N1 - Represents Light sleep stability/depth
#'
#' @return A matrix defining the SBP
#' @export
get_sleep_sbp <- function() {
  # Parts order: n1, n2, n3, rem
  # 1 means numerator, -1 means denominator, 0 means not involved

  #           n1  n2  n3  rem
  # z1 (REM)  -1  -1  -1   1
  # z2 (N3)   -1  -1   1   0
  # z3 (N2)   -1   1   0   0

  sbp <- matrix(
    c(
      -1,
      -1,
      -1,
      1, # z1: REM vs Rest
      -1,
      -1,
      1,
      0, # z2: N3 vs N1+N2
      -1,
      1,
      0,
      0 # z3: N2 vs N1
    ),
    byrow = TRUE,
    ncol = 4
  )

  colnames(sbp) <- c("n1", "n2", "n3", "rem")
  rownames(sbp) <- c("ilr1", "ilr2", "ilr3")

  return(sbp)
}

#' Transform 4-part sleep composition to ILR coordinates
#'
#' @param data data.table containing n1, n2, n3, rem columns
#' @return data.table with added ilr1, ilr2, ilr3 columns
#' @export
transform_to_ilr <- function(data) {
  dt <- copy(data)

  # Ensure strict positivity for log-ratio
  # We assume validation has handled zeros or we apply a tiny offset here if needed
  # ideally zeros should be imputed before this step

  # Extract composition parts
  parts <- c("n1", "n2", "n3", "rem")

  if (!all(parts %in% names(dt))) {
    stop("Data must contain columns: n1, n2, n3, rem")
  }

  # Create compositions object
  # acoump ensures the closure (sum to 1) is handled
  comp_obj <- acomp(dt[, ..parts])

  # Get basis
  sbp <- get_sleep_sbp()
  psi <- compositions::gsi.buildilrBase(t(sbp))

  # Apply transformation
  ilr_coords <- compositions::ilr(comp_obj, V = psi)

  # Assign back to data.table
  dt[, ilr1 := ilr_coords[, 1]]
  dt[, ilr2 := ilr_coords[, 2]]
  dt[, ilr3 := ilr_coords[, 3]]

  return(dt)
}

#' Inverse transform ILR coordinates back to component minutes
#'
#' @param ilr_data data.table or matrix containing ilr1, ilr2, ilr3
#' @param total_minutes vector or scalar of total sleep time to scale to (default 1)
#' @return data.table with n1, n2, n3, rem columns (in minutes if total_minutes provided)
#' @export
transform_to_comp <- function(ilr_data, total_minutes = 1) {
  # Handle input types
  if (is.data.table(ilr_data)) {
    ilr_mat <- as.matrix(ilr_data[, c("ilr1", "ilr2", "ilr3")])
  } else {
    ilr_mat <- as.matrix(ilr_data)
  }

  # Get basis
  sbp <- get_sleep_sbp()
  psi <- compositions::gsi.buildilrBase(t(sbp))

  # Inverse ILR
  comp_prop <- compositions::ilrInv(ilr_mat, V = psi)

  # Convert to data.table
  dt_res <- as.data.table(comp_prop)
  setnames(dt_res, c("n1", "n2", "n3", "rem"))

  # Scale by total minutes
  # If total_minutes is a vector, it must match rows
  dt_res[, n1 := n1 * total_minutes]
  dt_res[, n2 := n2 * total_minutes]
  dt_res[, n3 := n3 * total_minutes]
  dt_res[, rem := rem * total_minutes]

  return(dt_res)
}

#' Fit Multivariate Normal Density Model
#'
#' @description
#' Fits a robust mean and covariance matrix to the ILR coordinates.
#' This defines the "plausible region" of sleep compositions.
#'
#' @param data data.table containing n1, n2, n3, rem
#' @return List containing mean and covariance matrix
#' @export
fit_density_model <- function(data) {
  # Transform to ILR if not already done
  if (!all(c("ilr1", "ilr2", "ilr3") %in% names(data))) {
    dt <- transform_to_ilr(data)
  } else {
    dt <- copy(data)
  }

  ilr_cols <- c("ilr1", "ilr2", "ilr3")
  ilr_mat <- as.matrix(dt[, ..ilr_cols])

  # Remove NAs
  ilr_mat <- na.omit(ilr_mat)

  # Use robust covariance estimation (MCD) to avoid outlier influence
  # MASS::cov.mcd is standard
  mcd_fit <- MASS::cov.mcd(ilr_mat)

  return(list(
    center = mcd_fit$center,
    cov = mcd_fit$cov,
    cutoff = qchisq(0.99, df = 3) # 99% tolerance ellipsoid
  ))
}

#' Check plausibility of new compositions
#'
#' @param new_comp data.table with n1, n2, n3, rem
#' @param model density model object from fit_density_model
#' @param return_dist Logical, whether to return the Mahalanobis distance
#' @return Logical vector (TRUE if plausible) or distances
#' @export
check_plausibility <- function(new_comp, model, return_dist = FALSE) {
  # Transform
  dt_ilr <- transform_to_ilr(new_comp)
  ilr_mat <- as.matrix(dt_ilr[, c("ilr1", "ilr2", "ilr3")])

  # Calculate Mahalanobis distance
  dists <- mahalanobis(ilr_mat, center = model$center, cov = model$cov)

  if (return_dist) {
    return(dists)
  } else {
    return(dists <= model$cutoff)
  }
}
