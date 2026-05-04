comp_hull_work_dir <- function() {
  file.path("_targets", "user", "comp_hull")
}

write_comp_hull_input_file <- function(
  dt,
  imputation_id,
  dir = comp_hull_work_dir(),
  vars = comp_vars
) {
  dt <- data.table::as.data.table(dt)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  out <- data.table::copy(dt[, c("PID", vars), with = FALSE])
  out[, row_id := seq_len(.N)]
  data.table::setcolorder(out, c("row_id", "PID", vars))

  path <- file.path(dir, sprintf("comp_hull_input_imp_%s.csv", imputation_id))
  data.table::fwrite(out, path)
  path
}

write_substitutions_file <- function(
  substitutions,
  dir = comp_hull_work_dir()
) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, "substitutions.csv")
  data.table::fwrite(data.table::as.data.table(substitutions), path)
  path
}

compute_comp_hull_masks_for_dt <- function(
  dt,
  substitutions,
  imputation_id = "1",
  dir = tempfile("comp_hull_runtime_", tmpdir = comp_hull_work_dir())
) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  input_file <- write_comp_hull_input_file(
    dt = dt,
    imputation_id = imputation_id,
    dir = dir
  )
  substitutions_file <- write_substitutions_file(
    substitutions = substitutions,
    dir = dir
  )
  mask_file <- run_julia_comp_hull_masks(
    input_file = input_file,
    substitutions_file = substitutions_file,
    imputation_id = imputation_id,
    dir = dir
  )

  read_comp_hull_masks(mask_file)
}

run_julia_comp_hull_frontiers <- function(
  input_file,
  imputation_id,
  ratio_threshold = comparison_ratio_threshold(),
  max_minutes = comparison_duration_limit(),
  dir = comp_hull_work_dir(),
  vars = comp_vars
) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  output_file <- file.path(
    dir,
    sprintf("comp_hull_frontiers_imp_%s.csv", imputation_id)
  )

  run_julia_comp_hull_support(
    c(
      "--input",
      input_file,
      "--vars",
      paste(vars, collapse = ","),
      "--frontiers",
      output_file,
      "--ratio-threshold",
      as.character(ratio_threshold),
      "--max-minutes",
      as.character(max_minutes)
    )
  )

  output_file
}

run_julia_comp_hull_masks <- function(
  input_file,
  substitutions_file,
  imputation_id,
  dir = comp_hull_work_dir(),
  vars = comp_vars
) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  output_file <- file.path(
    dir,
    sprintf("comp_hull_masks_imp_%s.csv", imputation_id)
  )

  run_julia_comp_hull_support(
    c(
      "--input",
      input_file,
      "--vars",
      paste(vars, collapse = ","),
      "--substitutions",
      substitutions_file,
      "--masks",
      output_file
    )
  )

  output_file
}

run_julia_comp_hull_support <- function(args) {
  script <- file.path("scripts", "comp_hull_support.jl")
  res <- system2("julia", c(script, args), stdout = TRUE, stderr = TRUE)
  status <- attr(res, "status")

  if (!is.null(status) && status != 0L) {
    stop(
      "Julia convex hull support calculation failed:\n",
      paste(res, collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(res)
}

read_comp_hull_frontiers <- function(frontier_file) {
  data.table::fread(frontier_file)[,
    max_supported_minutes := as.integer(max_supported_minutes)
  ]
}

read_comp_hull_masks <- function(mask_file) {
  out <- data.table::fread(mask_file)
  out[, duration := as.integer(duration)]
  out[, substituted := as.logical(substituted)]
  out
}

is_substitution_mask_table <- function(x) {
  data.table::is.data.table(x) &&
    all(c("from", "to", "duration", "substituted") %in% names(x))
}

lookup_substitution_mask <- function(
  dt,
  substitution_masks,
  from,
  to,
  duration
) {
  dt <- data.table::as.data.table(dt)
  masks <- data.table::as.data.table(substitution_masks)
  duration_value <- as.integer(duration)
  from_value <- from
  to_value <- to

  mask_dt <- masks[
    masks[["from"]] == from_value &
      masks[["to"]] == to_value &
      masks[["duration"]] == duration_value
  ]

  if (nrow(mask_dt) == 0L) {
    stop(
      sprintf(
        "No substitution mask for %s -> %s at %s minutes.",
        from,
        to,
        duration
      ),
      call. = FALSE
    )
  }

  if ("PID" %in% names(dt) && "PID" %in% names(mask_dt)) {
    lookup <- mask_dt[
      data.table::data.table(PID = as.character(dt$PID)),
      on = "PID",
      substituted
    ]
  } else if ("row_id" %in% names(mask_dt)) {
    lookup <- mask_dt[
      data.table::data.table(row_id = seq_len(nrow(dt))),
      on = "row_id",
      substituted
    ]
  } else {
    stop("Substitution masks need PID or row_id for lookup.", call. = FALSE)
  }

  if (length(lookup) != nrow(dt) || anyNA(lookup)) {
    stop(
      sprintf("Substitution mask does not align with %s input rows.", nrow(dt)),
      call. = FALSE
    )
  }

  as.logical(lookup)
}
