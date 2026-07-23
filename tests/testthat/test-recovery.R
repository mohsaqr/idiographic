test_that("fit_var recovers planted temporal network signs and magnitudes", {
  d <- synth_planted_var(seed = 901)
  fit <- fit_var(d, vars = c("A", "B", "C"), id = "id",
                   day = "day", beep = "beep",
                   scale = FALSE, center_within = FALSE)
  B <- fit$temporal

  expect_gt(B["A", "A"], 0.45)
  expect_gt(B["B", "A"], 0.25)
  expect_gt(B["B", "B"], 0.30)
  expect_lt(B["C", "B"], -0.20)
  expect_gt(B["C", "C"], 0.25)

  expect_lt(abs(B["A", "B"]), 0.15)
  expect_lt(abs(B["B", "C"]), 0.15)
  expect_lt(abs(B["C", "A"]), 0.15)
})

test_that("graphical_var recovers planted temporal network with fixed penalties", {
  d <- synth_planted_var(seed = 901)
  fit <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                       day = "day", beep = "beep",
                       scale = FALSE, center_within = FALSE,
                       lambda_beta = 0.02, lambda_kappa = 0.02,
                       n_lambda = 8)
  B <- fit$temporal

  expect_gt(B["A", "A"], 0.40)
  expect_gt(B["B", "A"], 0.25)
  expect_gt(B["B", "B"], 0.30)
  expect_lt(B["C", "B"], -0.20)
  expect_gt(B["C", "C"], 0.25)
  expect_lt(abs(B["A", "B"]), 0.12)
  expect_lt(abs(B["B", "C"]), 0.12)
})

test_that("fit_mlvar recovers planted fixed temporal effects", {
  skip_if_not_installed("lme4")
  d <- synth_planted_panel(n_id = 12, days = 5, beeps = 20, seed = 903,
                           noise_sd = 0.60, between_sd = 0.20)
  fit <- suppressWarnings(fit_mlvar(d, vars = c("A", "B"), id = "id",
                                      day = "day", beep = "beep",
                                      scale = FALSE))
  B <- fit$temporal$weights

  expect_gt(B["A", "A"], 0.30)
  expect_gt(B["B", "A"], 0.20)
  expect_gt(B["B", "B"], 0.30)
  expect_lt(abs(B["A", "B"]), 0.12)
})

test_that("fixed uSEM recovers planted temporal paths", {
  skip_if_not_installed("lavaan")
  d <- synth_planted_panel(n_id = 5, days = 8, beeps = 25, seed = 902)
  fit <- fit_usem(d, vars = c("A", "B"), id = "id",
                    day = "day", beep = "beep",
                    temporal = "all", contemporaneous = "none",
                    residual_cov = TRUE)
  B <- fit$temporal

  expect_equal(fit$n_converged, 5L)
  expect_gt(B["A", "A"], 0.45)
  expect_gt(B["B", "A"], 0.30)
  expect_gt(B["B", "B"], 0.30)
  expect_lt(abs(B["A", "B"]), 0.12)
})

test_that("GIMME recovers planted group-level lagged paths", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_planted_panel(n_id = 5, days = 8, beeps = 25, seed = 902)
  fit <- suppressWarnings(suppressMessages(fit_gimme(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    VAR = TRUE, groupcutoff = 0.60, n_excellent = 1, seed = 1
  )))

  expect_s3_class(fit, "net_gimme")
  expect_equal(fit$temporal["A", "A"], fit$n_subjects)
  expect_equal(fit$temporal["B", "A"], fit$n_subjects)
  expect_equal(fit$temporal["B", "B"], fit$n_subjects)
  expect_equal(fit$temporal["A", "B"], 0)
  expect_true("B~Alag" %in% fit$group_paths)
})
