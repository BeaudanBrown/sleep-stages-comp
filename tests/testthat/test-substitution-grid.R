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
