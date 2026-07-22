test_that("min_obs is validated as a whole number >= 1", {
  d <- synth_panel(n_id = 5, days = 2, beeps = 12)
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             min_obs = 2.5, n_lambda = 5), "min_obs")
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             min_obs = 0, n_lambda = 5), "min_obs")
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             min_obs = NA, n_lambda = 5), "min_obs")
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             min_obs = "2", n_lambda = 5), "min_obs")
})

test_that("over-large min_obs errors clearly instead of crashing", {
  d <- synth_panel(n_id = 5, days = 2, beeps = 12)
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             min_obs = 9999, n_lambda = 5),
               "No observations remain")
})

test_that("unknown subject is rejected", {
  d <- synth_panel(n_id = 5, days = 2, beeps = 12)
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             subject = 999, n_lambda = 5), "not found")
})

test_that("optional column args must name real columns", {
  d <- synth_panel(n_id = 5, days = 2, beeps = 12)
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             day = "nope", n_lambda = 5), "not found")
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             beep = c("a", "b"), n_lambda = 5),
               "single column name")
})

test_that("scalar logical flags are validated", {
  d <- synth_panel(n_id = 5, days = 2, beeps = 12)
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             scale = "yes", n_lambda = 5), "TRUE/FALSE")
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                             lambda_min_ratio = -1, n_lambda = 5))
})

test_that("fit_mlvar / fit_gimme validate their column args", {
  d <- synth_panel(n_id = 6, days = 2, beeps = 12)
  expect_error(
    fit_mlvar(d, vars = c("A", "B", "C"), id = "id", day = "missing"),
    "not found"
  )
  skip_if_not_installed("lavaan")
  expect_error(
    fit_gimme(d, vars = c("A", "B", "C"), id = "id", beep = c("x", "y")),
    "single column name"
  )
})
