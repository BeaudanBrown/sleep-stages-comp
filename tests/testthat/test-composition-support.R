test_that("four-stage kNN support retains clusters and rejects distant profiles", {
  set.seed(20260202)
  stage_vars <- c("n1_s2", "n2_s2", "n3_s2", "rem_s2")
  cluster_1 <- sweep(
    matrix(rnorm(240, sd = 3), ncol = 4),
    2,
    c(30, 180, 80, 90),
    FUN = "+"
  )
  cluster_2 <- sweep(
    matrix(rnorm(240, sd = 3), ncol = 4),
    2,
    c(80, 100, 40, 60),
    FUN = "+"
  )
  dt <- as.data.table(rbind(cluster_1, cluster_2))
  setnames(dt, stage_vars)

  support <- fit_knn_composition_support(
    dt,
    stage_vars,
    get_sbp(),
    k = 10L,
    support_quantile = 0.95
  )
  expect_equal(ncol(support$training_features), 4L)
  candidates <- rbindlist(
    list(
      cbind(candidate = "cluster", dt[1, ..stage_vars]),
      data.table(
        candidate = "distant",
        n1_s2 = 55,
        n2_s2 = 140,
        n3_s2 = 150,
        rem_s2 = 75
      )
    ),
    use.names = TRUE
  )

  supported <- filter_knn_composition_support(
    candidates,
    support,
    stage_vars,
    get_sbp()
  )

  expect_equal(supported$candidate, "cluster")
  expect_true(supported$knn_distance <= support$threshold)

  ilr_names <- paste0("R", 1:3, "_s2")
  dt[, (ilr_names) := make_ilrs(dt, stage_vars, get_sbp())]
  dt[, outcome_value := R1_s2]
  split_fit <- list(
    split_id = 7L,
    outcome = "outcome_value",
    train_data = dt,
    model = list(
      model = lm(outcome_value ~ R1_s2, data = dt),
      outcome = "outcome_value"
    ),
    support = support
  )
  batch_predictions <- evaluate_ideal_composition_split_batch(
    candidates,
    split_fit,
    stage_vars,
    get_sbp()
  )

  expect_equal(batch_predictions$candidate, "cluster")
  expect_equal(batch_predictions$split_id, 7L)
})
