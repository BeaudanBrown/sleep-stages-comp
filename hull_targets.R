hull_targets <- list(
  # estimate convex hull and create intervened dataset
  tar_target(
    comp_hull_input_file,
    write_comp_hull_input_file(
      dt = dt,
      comp_vars = paste0(comp_vars, "_s2")
    ),
    format = "file"
  ),
  tar_target(
    comp_hull_frontier_file,
    run_julia_comp_hull_frontiers(
      input_file = comp_hull_input_file,
      comparison_settings,
      comp_vars = paste0(comp_vars, "_s2")
    ),
    format = "file"
  ),
  tar_target(
    substitution_support_frontiers,
    read_comp_hull_frontiers(comp_hull_frontier_file)
  ),
  tar_target(
    substitutions,
    build_support_aware_substitution_grid(
      substitution_support_frontiers,
      comparison_settings,
      comp_vars = paste0(comp_vars, "_s2")
    )
  ),
  tar_target(
    comp_hull_substitutions_file,
    write_substitutions_file(substitutions),
    format = "file"
  ),
  tar_target(
    comp_hull_mask_file,
    run_julia_comp_hull_masks(
      input_file = comp_hull_input_file,
      substitutions_file = comp_hull_substitutions_file,
      comp_vars = paste0(comp_vars, "_s2")
    ),
    format = "file"
  ),
  tar_target(
    comp_hull_masks,
    read_comp_hull_masks(comp_hull_mask_file)
  )
)
