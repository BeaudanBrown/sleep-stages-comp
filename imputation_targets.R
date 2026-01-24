imputation_targets <- list(
  # Perform multiple imputation
  # This returns a 'mids' object
  tar_target(
    data_imputed_mids,
    impute_data(data_final, m = 250, seed = 12345),
    deployment = "worker",
    packages = c("mice", "data.table", "compositions")
  ),

  # Process into a list of completed datasets
  # This makes it easier to map over later
  tar_target(
    data_imputed_list,
    process_imputations(data_imputed_mids, data_final),
    deployment = "worker"
  ),

  # Fit density model on the POOLED data or just use the first one?
  # Or fit on original complete cases?
  # Usually density model defines "plausible region" based on observed data.
  # So we should fit it on data_clean (complete cases) or on imputed?
  # Specs say: "Fit Multivariate Normal Density Model... Used for density checking of substitutions"
  # It implies using the valid data.
  tar_target(
    density_model,
    fit_density_model(data_final),
    deployment = "worker"
  )
)
