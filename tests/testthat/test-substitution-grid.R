test_that("make_substitution_grid returns all directed pairwise substitutions", {
  grid <- make_substitution_grid(
    durations = c(15, 30, 60),
    directed = TRUE
  )

  expect_s3_class(grid, "data.table")
  expect_equal(
    nrow(grid),
    length(comp_vars) * (length(comp_vars) - 1L) * 3L
  )
  expect_true(all(grid$from != grid$to))
  expect_setequal(unique(grid$duration), c(15, 30, 60))

  reversed_pairs <- data.table::copy(grid)[, .(from = to, to = from, duration)]
  expect_setequal(
    unique(paste(grid$from, grid$to, sep = "->")),
    unique(paste(reversed_pairs$from, reversed_pairs$to, sep = "->"))
  )
})

test_that("make_substitution_grid supports undirected signed-duration policies", {
  durations <- seq(-30, 30, by = 15)
  grid <- make_substitution_grid(
    durations = durations,
    directed = FALSE
  )

  expect_equal(nrow(grid), choose(length(comp_vars), 2L) * length(durations))
  expect_true(all(grid$from != grid$to))
  expect_setequal(unique(grid$duration), durations)

  pair_keys <- unique(paste(grid$from, grid$to, sep = "->"))
  reverse_keys <- paste(grid$to, grid$from, sep = "->")
  expect_false(any(reverse_keys %in% pair_keys))
})

test_that("compute_directional_support_frontier finds the largest supported whole-minute shift", {
  dt <- make_test_comp_dt()
  limits <- make_test_comp_limits()

  expect_equal(
    compute_directional_support_frontier(
      dt = dt,
      from = "n2_s2",
      to = "n3_s2",
      comp_limits = limits,
      ratio_threshold = 0.75,
      max_minutes = 60
    ),
    30L
  )
  expect_equal(
    compute_directional_support_frontier(
      dt = dt,
      from = "n3_s2",
      to = "n2_s2",
      comp_limits = limits,
      ratio_threshold = 0.75,
      max_minutes = 60
    ),
    20L
  )
})

test_that("combine_imputation_support_frontiers takes the conservative minimum", {
  frontier_a <- data.table::data.table(
    from = c("n2_s2", "n3_s2"),
    to = c("n3_s2", "n2_s2"),
    max_supported_minutes = c(30L, 20L)
  )
  frontier_b <- data.table::data.table(
    from = c("n2_s2", "n3_s2"),
    to = c("n3_s2", "n2_s2"),
    max_supported_minutes = c(18L, 12L)
  )

  combined <- combine_imputation_support_frontiers(list(frontier_a, frontier_b))

  expect_equal(
    combined[order(from, to)]$max_supported_minutes,
    c(18L, 12L)
  )
})

test_that("build_support_aware_substitution_grid uses directional support on each half-axis", {
  support_frontiers <- data.table::data.table(
    from = c("n1_s2", "n2_s2"),
    to = c("n2_s2", "n1_s2"),
    max_supported_minutes = c(12L, 60L)
  )

  grid <- build_support_aware_substitution_grid(support_frontiers)
  pair_grid <- grid[from == "n1_s2" & to == "n2_s2"][order(duration)]

  expect_equal(
    pair_grid$duration,
    c(-60L, -45L, -30L, -15L, 0L, 3L, 6L, 9L, 12L)
  )
})
