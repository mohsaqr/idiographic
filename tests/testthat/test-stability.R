test_that("estimate_stability is deterministic for OLS VAR block bootstrap", {
  d <- synth_panel(n_id = 4, days = 3, beeps = 10, vars = c("A", "B", "C"),
                   seed = 401)

  s1 <- estimate_stability(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    estimator = "var", n_resamples = 6, seed = 99, scale = FALSE
  )
  s2 <- estimate_stability(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    estimator = "var", n_resamples = 6, seed = 99, scale = FALSE
  )

  expect_s3_class(s1, "stability_result")
  expect_s3_class(s1$original, "var_result")
  expect_equal(s1$n_success, 6L)
  expect_equal(s1$stability, s2$stability, tolerance = 1e-12)
  expect_named(s1$stability,
               c("network", "from", "to", "original", "mean", "sd",
                 "q05", "q50", "q95", "selection_prop", "positive_prop",
                 "negative_prop", "n_success"))
  expect_true(all(s1$stability$selection_prop >= 0 &
                  s1$stability$selection_prop <= 1))
  expect_output(print(s1), "Idiographic Stability Result")
  expect_equal(as.data.frame(s1), s1$stability)
})

test_that("estimate_stability preserves graphical_var compatibility", {
  d <- synth_single(n_t = 80, vars = c("A", "B", "C"), seed = 402)
  st <- estimate_stability(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    estimator = "graphical_var", n_resamples = 2, seed = 3,
    scale = FALSE, center_within = FALSE, n_lambda = 5
  )

  expect_s3_class(st$original, "gvar_result")
  expect_equal(st$n_success, 2L)
  expect_true(all(c("temporal", "contemporaneous") %in%
                    unique(st$stability$network)))
})

test_that("estimate_stability split-half and row-block paths are deterministic", {
  d <- synth_panel(n_id = 5, days = 2, beeps = 8, vars = c("A", "B"),
                   seed = 403)
  split <- estimate_stability(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    estimator = "var", resample = "split_half", n_resamples = 4,
    seed = 44, scale = FALSE
  )
  expect_equal(split$n_success, 4L)
  expect_true(all(split$resample_edges$resample %in% 1:4))

  single <- synth_single(n_t = 90, vars = c("A", "B"), seed = 404)
  r1 <- estimate_stability(
    single[, c("A", "B")], vars = c("A", "B"), estimator = "var",
    n_resamples = 3, block_size = 12, seed = 5, scale = FALSE
  )
  r2 <- estimate_stability(
    single[, c("A", "B")], vars = c("A", "B"), estimator = "var",
    n_resamples = 3, block_size = 12, seed = 5, scale = FALSE
  )
  expect_equal(r1$stability, r2$stability, tolerance = 1e-12)
})

test_that("stability resampling preserves beep order inside sampled blocks", {
  d <- data.frame(
    id = 1,
    day = rep(1:2, each = 4),
    beep = rep(c(3, 1, 4, 2), 2),
    A = 1:8,
    B = 11:18
  )
  plan <- idiographic:::.stability_plan(d, "id", "day", "beep", NULL)
  boot <- idiographic:::.stability_resample_data(d, plan, selected = 1,
                                                 id = "id", day = "day")

  expect_equal(boot$data$beep, 1:4)
  expect_equal(boot$data$.idiographic_stability_beep, 1:4)
})

test_that("estimate_stability validates unsupported split-half designs", {
  d <- data.frame(id = 1, day = 1, beep = 1:20,
                  A = stats::rnorm(20), B = stats::rnorm(20))
  expect_error(
    estimate_stability(d, vars = c("A", "B"), id = "id", day = "day",
                       beep = "beep", resample = "split_half"),
    "at least two blocks"
  )
})

test_that("estimate_stability supports mlVAR edge stability", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("corpcor")
  skip_if_not_installed("data.table")
  d <- synth_panel(n_id = 5, days = 3, beeps = 8, vars = c("A", "B", "C"),
                   seed = 405)

  st <- suppressWarnings(estimate_stability(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    estimator = "mlvar", n_resamples = 2, seed = 6, scale = FALSE
  ))

  expect_s3_class(st$original, "net_mlvar")
  expect_equal(st$n_success, 2L)
  expect_true(all(c("temporal", "contemporaneous", "between") %in%
                    unique(st$stability$network)))
})

test_that("estimate_stability supports uSEM edge stability", {
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 3, days = 3, beeps = 12, vars = c("A", "B"),
                   seed = 406)

  st <- estimate_stability(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    estimator = "usem", n_resamples = 2, seed = 7,
    temporal = "ar", contemporaneous = "none", residual_cov = TRUE
  )

  expect_s3_class(st$original, "net_usem")
  expect_equal(st$n_success, 2L)
  expect_true(all(c("temporal", "residual_cov") %in%
                    unique(st$stability$network)))
})

test_that("estimate_stability supports GIMME edge stability", {
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"),
                   seed = 407)

  st <- estimate_stability(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    estimator = "gimme", n_resamples = 2, seed = 8,
    ar = TRUE, groupcutoff = 1, n_excellent = 1
  )

  expect_s3_class(st$original, "net_gimme")
  expect_equal(st$n_success, 2L)
  expect_true("temporal" %in% unique(st$stability$network))
})

test_that("estimate_stability id-based estimators require id", {
  d <- synth_single(n_t = 80, vars = c("A", "B"), seed = 408)
  expect_error(
    estimate_stability(d[, c("A", "B")], vars = c("A", "B"),
                       estimator = "usem"),
    "requires an `id`"
  )
})
