descriptive_targets <- list(
  tar_target(comp_dist_plot, plot_composition_distribution(dt)),
  tar_target(covariate_table, summarize_analysis_covariates(dt, outcome_vars))
)
