read_synthetic_structure <- function(
  dictionary_root = "synthetic-data-dictionaries"
) {
  path <- file.path(dictionary_root, "schema", "manual_overrides.yaml")
  if (!file.exists(path)) {
    stop("Synthetic structure file is missing: ", path, call. = FALSE)
  }
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop(
      "The yaml package is required for synthetic structure rules.",
      call. = FALSE
    )
  }

  config <- yaml::read_yaml(path)
  validate_synthetic_structure(config, dictionary_root)
  config
}

validate_synthetic_structure <- function(config, dictionary_root) {
  if (!is.list(config$defaults) || !is.list(config$files)) {
    stop("Synthetic structure must define defaults and files.", call. = FALSE)
  }
  if (length(config$files) == 0L) {
    stop("Synthetic structure must define at least one file.", call. = FALSE)
  }

  seen_sources <- character()
  seen_headers <- character()
  for (file_rule in config$files) {
    source <- file_rule$source_file
    header <- file_rule$header_file
    if (!is.character(source) || !nzchar(source)) {
      stop("Each synthetic file rule must define source_file.", call. = FALSE)
    }
    if (!is.character(header) || !nzchar(header)) {
      stop("Each synthetic file rule must define header_file.", call. = FALSE)
    }

    header_path <- file.path(dictionary_root, header)
    if (!file.exists(header_path)) {
      stop(
        "Synthetic header file is missing for ",
        source,
        ": ",
        header,
        call. = FALSE
      )
    }

    header_cols <- read_synthetic_header(header_path)
    key_cols <- unique(c(
      unlist(file_rule$merge_key, use.names = FALSE),
      unlist(file_rule$bridge_key, use.names = FALSE),
      names(file_rule$id_columns)
    ))
    key_cols <- key_cols[nzchar(key_cols)]
    missing_keys <- key_cols[
      !tolower(key_cols) %in% tolower(header_cols)
    ]
    if (length(missing_keys) > 0L) {
      stop(
        "Synthetic key columns are missing from ",
        header,
        ": ",
        paste(missing_keys, collapse = ", "),
        call. = FALSE
      )
    }

    assessments <- synthetic_assessments_for_file_rule(file_rule)
    if (!is.finite(assessments) || assessments < 1L) {
      stop(
        "Invalid assessments_per_person for ",
        source,
        ": ",
        assessments,
        call. = FALSE
      )
    }

    seen_sources <- c(seen_sources, source)
    seen_headers <- c(seen_headers, header)
  }

  if (anyDuplicated(seen_sources)) {
    stop("Synthetic source_file entries must be unique.", call. = FALSE)
  }
  if (anyDuplicated(seen_headers)) {
    stop("Synthetic header_file entries must be unique.", call. = FALSE)
  }

  invisible(TRUE)
}

synthetic_file_rules_dt <- function(config) {
  data.table::rbindlist(lapply(config$files, function(file_rule) {
    data.table::data.table(
      source_file = file_rule$source_file,
      header_file = file_rule$header_file,
      row_grain = file_rule$row_grain %||% NA_character_,
      assessments_per_person = synthetic_assessments_for_file_rule(file_rule)
    )
  }))
}

synthetic_header_to_source <- function(config) {
  rules <- synthetic_file_rules_dt(config)
  stats::setNames(rules$source_file, rules$header_file)
}

synthetic_assessments_for_file_rule <- function(file_rule) {
  assessments <- file_rule$repeated_key_strategy$assessments_per_person
  if (is.null(assessments)) {
    return(1L)
  }
  as.integer(assessments)
}

synthetic_assessments_for_source <- function(config, source) {
  matches <- vapply(
    config$files,
    function(file_rule) identical(file_rule$source_file, source),
    logical(1)
  )
  if (!any(matches)) {
    stop("No synthetic file rule found for source: ", source, call. = FALSE)
  }
  synthetic_assessments_for_file_rule(config$files[[which(matches)[1L]]])
}

synthetic_participant_count <- function(config, participant_count = NULL) {
  if (!is.null(participant_count)) {
    return(as.integer(participant_count))
  }
  as.integer(config$defaults$id_universe$participant_count)
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

read_synthetic_header <- function(path) {
  names(data.table::fread(path, nrows = 0L))
}

synthetic_participant_index <- function(row_index, assessments) {
  ((row_index - 1L) %/% assessments) + 1L
}

synthetic_assessment_index <- function(row_index, assessments) {
  ((row_index - 1L) %% assessments) + 1L
}

synthetic_idtype <- function(person) {
  data.table::fifelse(person %% 10L == 0L, 7L, 1L)
}

synthetic_pid <- function(person) {
  100000L + person
}

synthetic_pptidr <- function(person) {
  sprintf("R%06d", person)
}

synthetic_pptidu <- function(person) {
  sprintf("U%06d", person)
}

bounded_sequence <- function(person, low, high, period = 97L) {
  low + (high - low) * ((person %% period) / max(period - 1L, 1L))
}

synthetic_sleep_values <- function(person, visit) {
  modifier <- (person %% 11L) - 5L
  if (visit == 1L) {
    n1 <- 28 + modifier
    n2 <- 205 + modifier
    n3 <- 65 - modifier / 2
    rem <- 92 - modifier / 2
    waso <- 45 + (person %% 10L)
  } else {
    n1 <- 32 + modifier
    n2 <- 198 + modifier
    n3 <- 70 - modifier / 2
    rem <- 96 - modifier / 2
    waso <- 50 + (person %% 10L)
  }
  slp_time <- n1 + n2 + n3 + rem
  data.table::data.table(
    timest1 = round(n1, 2),
    timest2 = round(n2, 2),
    timest34 = round(n3, 2),
    timerem = round(rem, 2),
    WASO = as.integer(waso),
    waso = as.integer(waso),
    slp_time = round(slp_time, 2),
    timest1p = round(100 * n1 / slp_time, 3),
    timest2p = round(100 * n2 / slp_time, 3),
    times34p = round(100 * n3 / slp_time, 3),
    timeremp = round(100 * rem / slp_time, 3),
    slp_lat = round(12 + (person %% 20L) * 0.5, 2),
    oahi = round(1 + (person %% 30L) * 0.4, 2),
    stdatep = 1000
  )
}

synthetic_numeric_default <- function(column, person, assessment) {
  c <- tolower(column)
  if (
    grepl("date", c) ||
      c %in%
        c(
          "eddd",
          "datedth",
          "dem_survdate",
          "censdate",
          "stdatep",
          "np_date",
          "mri_date"
        )
  ) {
    return(1500L + person + assessment * 180L)
  }
  if (grepl("age", c)) {
    return(round(bounded_sequence(person, 55, 85), 1))
  }
  if (grepl("bmi", c)) {
    return(round(bounded_sequence(person, 22, 36), 1))
  }
  if (grepl("educat", c)) {
    return((person %% 5L) + 1L)
  }
  if (c %in% c("gender", "sex")) {
    return(person %% 2L)
  }
  if (c == "vital") {
    return(1L)
  }
  if (c %in% c("dem_status", "dthrvwd", "status")) {
    return(data.table::fifelse(person %% 8L == 0L, 1L, 0L))
  }
  if (
    grepl("score", c) ||
      c %in%
        c(
          "trailsa",
          "trailsb",
          "lmi",
          "lmd",
          "lmr",
          "vri",
          "vrd",
          "vrr",
          "pasd",
          "hvot",
          "dsf",
          "dsb",
          "bnt36",
          "sim"
        )
  ) {
    return(round(bounded_sequence(person + assessment, 20, 80), 2))
  }
  if (grepl("brain|cerebrum|white|gray|hippo|vent|csf", c)) {
    return(round(bounded_sequence(person + assessment, 1000, 1500), 2))
  }
  if (grepl("wmh", c)) {
    return(round(bounded_sequence(person + assessment, 0.1, 12), 3))
  }
  round(bounded_sequence(person + assessment, 1, 100), 3)
}

synthetic_special_value <- function(source, column, person, assessment) {
  c <- tolower(column)
  if (c %in% c("pid", "parent")) {
    return(synthetic_pid(person))
  }
  if (c == "idtype") {
    return(synthetic_idtype(person))
  }
  if (c == "pptidr") {
    return(synthetic_pptidr(person))
  }
  if (c == "pptidu") {
    return(synthetic_pptidu(person))
  }
  if (c == "permiss") {
    return(1L)
  }
  if (c == "days_studyv1") {
    return(100L)
  }

  if (source == "SHHS_1/shhs1final_13jun2014_5839.csv") {
    if (c == "age_s1") {
      return(round(bounded_sequence(person, 55, 85), 1))
    }
    if (c == "bmi_s1") {
      return(round(bounded_sequence(person, 22, 36), 1))
    }
    if (c == "gender") {
      return(person %% 2L)
    }
    if (c == "educat") return((person %% 5L) + 1L)
  }

  if (source == "SHHS_1/shhs1final_PSG_15jan2014_5839.csv") {
    values <- synthetic_sleep_values(person, 1L)
    if (column %in% names(values)) return(values[[column]])
  }

  if (source == "SHHS_2/shhs2final_PSG_15jan2014_4103.csv") {
    values <- synthetic_sleep_values(person, 2L)
    if (column %in% names(values)) return(values[[column]])
  }

  if (source == "SHHS_2/shhs_status_08apr2014_5837.csv") {
    if (c == "vital") {
      return(1L)
    }
    if (c == "censdate") return(3000L)
  }

  if (source == "vr_demrev_2018_a_1254d_v1.csv") {
    if (c == "review_date") {
      return(1500L + assessment * 200L + person)
    }
    if (c == "normal_date") {
      return(1400L + assessment * 200L + person)
    }
    if (c == "impairment_date") {
      return(data.table::fifelse(
        person %% 7L == 0L,
        1700L + assessment * 200L + person,
        NA_integer_
      ))
    }
    if (c %in% c("mild_date", "moderate_date", "severe_date")) {
      return(NA_integer_)
    }
    if (c == "eddd") return(2400L + person)
  }

  if (source == "vr_demsurv_2018_a_1281d.csv") {
    if (c == "dem_status") {
      return(data.table::fifelse(person %% 9L == 0L, 1L, 0L))
    }
    if (c == "dem_survdate") return(2600L + person)
  }

  if (source == "vr_survdth_2019_a_1337d.csv") {
    if (c == "dthrvwd") {
      return(0L)
    }
    if (c == "datedth") return(NA_integer_)
  }

  if (c == "np_date") {
    return(2100L + assessment * 200L + person)
  }
  if (c == "mri_date") {
    return(2200L + assessment * 200L + person)
  }
  NULL
}

synthetic_generic_value <- function(rule, column, person, assessment) {
  generation_class <- rule[["generation_class"]]
  sas_type <- rule[["sas_type"]]
  if (is.na(generation_class)) {
    generation_class <- "numeric"
  }
  if (is.na(sas_type)) {
    sas_type <- ""
  }

  if (generation_class == "character" || sas_type == "Char") {
    width <- suppressWarnings(as.integer(rule[["sas_len"]]))
    if (is.na(width)) {
      width <- 12L
    }
    return(substr(sprintf("SYN%06d", person), 1L, width))
  }
  if (generation_class %in% c("categorical", "categorical_flag")) {
    return(person %% 2L)
  }
  if (generation_class == "id") {
    return(synthetic_pid(person))
  }
  if (generation_class == "date_or_day_offset") {
    return(1500L + person + assessment * 180L)
  }
  synthetic_numeric_default(column, person, assessment)
}

generate_synthetic_source_file <- function(
  source,
  header,
  rules,
  out_root,
  assessments,
  participant_count = 500L
) {
  n_rows <- participant_count * assessments
  row_index <- seq_len(n_rows)
  person <- synthetic_participant_index(row_index, assessments)
  assessment <- synthetic_assessment_index(row_index, assessments)
  out <- data.table::data.table(.synthetic_row = row_index)

  for (column in header) {
    special <- synthetic_special_value(source, column, person, assessment)
    if (!is.null(special)) {
      values <- special
    } else {
      column_name <- column
      rule <- rules[source_file == source & column == column_name][1]
      values <- synthetic_generic_value(rule, column, person, assessment)
    }
    out[, (column) := values]
  }

  out[, .synthetic_row := NULL]
  out_path <- file.path(out_root, source)
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(out, out_path, na = "")
  out_path
}

generate_synthetic_data_files <- function(
  dictionary_root = "synthetic-data-dictionaries",
  out_root = file.path(dictionary_root, "synthetic-data"),
  participant_count = NULL
) {
  config <- read_synthetic_structure(dictionary_root)
  participant_count <- synthetic_participant_count(config, participant_count)
  file_rules <- synthetic_file_rules_dt(config)
  header_to_source <- synthetic_header_to_source(config)
  rules <- data.table::fread(file.path(
    dictionary_root,
    "schema",
    "generation_rules.csv"
  ))
  dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

  paths <- Map(
    f = function(header_file, source) {
      header <- read_synthetic_header(file.path(dictionary_root, header_file))
      generate_synthetic_source_file(
        source = source,
        header = header,
        rules = rules,
        out_root = out_root,
        assessments = file_rules[
          source_file == source,
          assessments_per_person
        ],
        participant_count = participant_count
      )
    },
    header_file = names(header_to_source),
    source = unname(header_to_source)
  )
  paths <- unname(unlist(paths))

  manifest <- data.table::data.table(
    source_file = unname(header_to_source),
    rows = vapply(
      unname(header_to_source),
      function(source) {
        participant_count * synthetic_assessments_for_source(config, source)
      },
      integer(1)
    ),
    columns = vapply(
      names(header_to_source),
      function(header_file) {
        length(read_synthetic_header(file.path(dictionary_root, header_file)))
      },
      integer(1)
    ),
    path = paths
  )
  manifest_path <- file.path(out_root, "synthetic_manifest.tsv")
  data.table::fwrite(manifest, manifest_path, sep = "\t")
  c(paths, manifest_path)
}

create_synthetic_dataset_from_files <- function(
  synthetic_source_files,
  synthetic_data_root,
  dictionary_root = "synthetic-data-dictionaries"
) {
  force(synthetic_source_files)
  config <- read_synthetic_structure(dictionary_root)
  source_path <- function(source) {
    file.path(synthetic_data_root, source)
  }
  required_sources <- c(
    "vr_demrev_2018_a_1254d_v1.csv",
    "vr_demsurv_2018_a_1281d.csv",
    "t_mrbrwmh_2019_a_1328d.csv",
    "t_mrbrnm3_2019_a_1906d.csv",
    "vr_np_2018_a_1185d.csv",
    "vr_survdth_2019_a_1337d.csv",
    "SHHS_1/shhs1final_13jun2014_5839.csv",
    "SHHS_2/shhs_status_08apr2014_5837.csv",
    "SHHS_1/shhs1final_PSG_15jan2014_5839.csv",
    "SHHS_2/shhs2final_PSG_15jan2014_4103.csv",
    "ParentStudy_SHHSLink/parent_shhs_public_2016.csv"
  )
  configured_sources <- synthetic_file_rules_dt(config)$source_file
  missing_sources <- setdiff(required_sources, configured_sources)
  if (length(missing_sources) > 0L) {
    stop(
      "Synthetic structure is missing required loader sources: ",
      paste(missing_sources, collapse = ", "),
      call. = FALSE
    )
  }

  create_dataset(
    source_path("vr_demrev_2018_a_1254d_v1.csv"),
    source_path("vr_demsurv_2018_a_1281d.csv"),
    source_path("t_mrbrwmh_2019_a_1328d.csv"),
    source_path("t_mrbrnm3_2019_a_1906d.csv"),
    source_path("vr_np_2018_a_1185d.csv"),
    source_path("vr_survdth_2019_a_1337d.csv"),
    source_path("SHHS_1/shhs1final_13jun2014_5839.csv"),
    source_path("SHHS_2/shhs_status_08apr2014_5837.csv"),
    source_path("SHHS_1/shhs1final_PSG_15jan2014_5839.csv"),
    source_path("SHHS_2/shhs2final_PSG_15jan2014_4103.csv"),
    source_path("ParentStudy_SHHSLink/parent_shhs_public_2016.csv")
  )
}
