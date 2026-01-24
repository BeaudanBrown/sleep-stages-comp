validation_targets <- list(
  tar_target(
    data_validated_raw,
    validate_dataset(dt_raw)
  ),
  tar_target(
    data_clean,
    data_validated_raw[valid_record == TRUE]
  ),
  tar_target(
    data_final,
    calculate_wake_time(data_clean)
  )
)
