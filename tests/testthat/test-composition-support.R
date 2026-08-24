test_that("kNN support retains clusters and rejects the gap between them", {
  set.seed(20260202)
  comp_vars <- c("n1_s2", "n2_s2", "n3_s2", "waso_s2", "rem_s2")
  cluster_1 <- sweep(
    matrix(rnorm(300, sd = 3), ncol = 5),
    2,
    c(30, 180, 80, 30, 90),
    FUN = "+"
  )
  cluster_2 <- sweep(
    matrix(rnorm(300, sd = 3), ncol = 5),
    2,
    c(80, 100, 40, 100, 60),
    FUN = "+"
  )
  dt <- as.data.table(rbind(cluster_1, cluster_2))
  setnames(dt, comp_vars)

  support <- fit_knn_composition_support(
    dt,
    comp_vars,
    get_sbp(),
    k = 10L,
    support_quantile = 0.95
  )
  candidates <- rbindlist(
    list(
      cbind(candidate = "cluster", dt[1, ..comp_vars]),
      data.table(
        candidate = "gap",
        n1_s2 = 55,
        n2_s2 = 140,
        n3_s2 = 60,
        waso_s2 = 65,
        rem_s2 = 75
      )
    ),
    use.names = TRUE
  )

  supported <- filter_knn_composition_support(
    candidates,
    support,
    comp_vars,
    get_sbp()
  )

  expect_equal(supported$candidate, "cluster")
  expect_true(supported$knn_distance <= support$threshold)

  ilr_names <- paste0("R", 1:4, "_s2")
  dt[, (ilr_names) := make_ilrs(dt, comp_vars, get_sbp())]
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
    comp_vars,
    get_sbp()
  )

  expect_equal(batch_predictions$candidate, "cluster")
  expect_equal(batch_predictions$split_id, 7L)
})
