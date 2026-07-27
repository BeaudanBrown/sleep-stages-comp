make_composition_support_features <- function(dt, comp_vars, ilr_base) {
  dt <- as.data.table(dt)
  features <- make_ilrs(dt, comp_vars, ilr_base)
  features[, log_whole := log(rowSums(as.matrix(dt[, ..comp_vars])))]
  as.matrix(features)
}

whiten_composition_support_features <- function(
  features,
  center,
  whitening_matrix
) {
  sweep(features, 2L, center, FUN = "-") %*% whitening_matrix
}

fit_knn_composition_support <- function(
  dt,
  comp_vars,
  ilr_base,
  k,
  support_quantile
) {
  features <- make_composition_support_features(dt, comp_vars, ilr_base)
  center <- colMeans(features)
  covariance <- cov(features)
  whitening_matrix <- backsolve(
    chol(covariance),
    diag(ncol(features))
  )
  training_features <- whiten_composition_support_features(
    features,
    center,
    whitening_matrix
  )
  observed_distances <- nn2(
    data = training_features,
    query = training_features,
    k = k + 1L
  )$nn.dists[, k + 1L]

  list(
    training_features = training_features,
    center = center,
    whitening_matrix = whitening_matrix,
    k = k,
    threshold = unname(quantile(observed_distances, support_quantile))
  )
}

filter_knn_composition_support <- function(
  composition_grid,
  support_model,
  comp_vars,
  ilr_base
) {
  features <- make_composition_support_features(
    composition_grid,
    comp_vars,
    ilr_base
  )
  query_features <- whiten_composition_support_features(
    features,
    support_model$center,
    support_model$whitening_matrix
  )
  distances <- nn2(
    data = support_model$training_features,
    query = query_features,
    k = support_model$k
  )$nn.dists[, support_model$k]

  out <- copy(composition_grid)
  out[, knn_distance := distances]
  out[knn_distance <= support_model$threshold]
}
