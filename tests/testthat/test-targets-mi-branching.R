test_that("dynamic MI branches can auto-combine tagged data.tables", {
  skip_if_not_installed("targets")

  tmp_dir <- tempfile("targets-mi-branching-")
  dir.create(tmp_dir)
  old_wd <- setwd(tmp_dir)
  on.exit(setwd(old_wd), add = TRUE)

  targets::tar_script(
    {
      library(targets)
      library(data.table)

      list(
        tar_target(
          imp_datasets,
          list(
            data.table::data.table(value = 1),
            data.table::data.table(value = 2)
          ),
          iteration = "list"
        ),
        tar_target(
          imp_dataset_ids,
          seq_len(length(imp_datasets))
        ),
        tar_target(
          tagged_results,
          {
            out <- data.table::copy(imp_datasets)
            out[, imputation_id := as.character(imp_dataset_ids)]
            out
          },
          pattern = map(imp_datasets, imp_dataset_ids)
        ),
        tar_target(
          combined_results,
          data.table::as.data.table(tagged_results)
        )
      )
    },
    ask = FALSE
  )

  targets::tar_make(callr_function = NULL)
  tagged_results <- targets::tar_read(tagged_results)
  combined_results <- targets::tar_read(combined_results)

  data.table::setorder(tagged_results, imputation_id)
  data.table::setorder(combined_results, imputation_id)

  expect_s3_class(tagged_results, "data.table")
  expect_s3_class(combined_results, "data.table")
  expect_equal(tagged_results$imputation_id, c("1", "2"))
  expect_equal(combined_results$imputation_id, c("1", "2"))
  expect_equal(combined_results$value, c(1, 2))
})
