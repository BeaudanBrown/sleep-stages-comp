test_that("prepare_simulated_dataset matches the 5-part SHHS-2 exposure contract", {
  spec <- make_sim_spec(name = "test_contract", n = 40, seed = 101)

  raw_dt <- simulate_dataset(spec)
  sim_dt <- prepare_simulated_dataset(raw_dt)

  expect_true(all(
    c(comp_vars, "slp_time_s2", "n1", "n2", "n3", "rem") %in% names(sim_dt)
  ))
  expect_true("waso" %in% names(sim_dt))
  expect_true(all(ilr_names %in% names(sim_dt)))
  expect_equal(length(ilr_names), 4L)
  expect_true(all(sim_dt$waso_s2 > 0))
  expect_true(all(sim_dt$slp_time_s2 > 0))
  expect_equal(sim_dt$n1, sim_dt$n1_s1)
  expect_equal(sim_dt$n2, sim_dt$n2_s1)
  expect_equal(sim_dt$n3, sim_dt$n3_s1)
  expect_equal(sim_dt$rem, sim_dt$rem_s1)
})

test_that("simulated ILRs are recomputed from the 5-part SHHS-2 composition", {
  spec <- make_sim_spec(name = "test_ilr", n = 25, seed = 202)

  sim_dt <- prepare_simulated_dataset(simulate_dataset(spec))
  expected_ilrs <- make_ilrs(sim_dt)

  expect_equal(sim_dt[, ..ilr_names], expected_ilrs)
})

test_that("simulation substitution grid spans all directed 5-part substitutions", {
  pairs <- t(combn(comp_vars, 2))
  pair_dt <- data.table::data.table(from = pairs[, 1], to = pairs[, 2])
  pair_dt <- data.table::rbindlist(list(
    pair_dt,
    pair_dt[, .(from = to, to = from)]
  ))
  grid <- pair_dt[, .(duration = c(15, 30, 60)), by = .(from, to)]

  expect_equal(nrow(grid), length(comp_vars) * (length(comp_vars) - 1L) * 3L)
  expect_true(all(grid$from != grid$to))
  expect_setequal(unique(grid$duration), c(15, 30, 60))
})
