simpson_panel <- function(seed = 9L, n_id = 6L, n_time = 40L) {
  set.seed(seed)
  # Between people, x and y move together. Within any one person, x does
  # nothing. A pooled model sees a strong effect that is not there.
  do.call(rbind, lapply(seq_len(n_id), function(i) {
    data.frame(
      id = i, day = seq_len(n_time),
      x = i + stats::rnorm(n_time, sd = 0.5),
      y = 3 * i + stats::rnorm(n_time, sd = 0.5)
    )
  }))
}

test_that("person-centering removes the between-person confound", {
  d <- simpson_panel()
  raw_slope <- stats::coef(stats::lm(y ~ x, d))[[2]]

  pc <- preprocess_panel(d, id = "id", time = "day", vars = "x", center = "person")
  pc$y <- d$y
  within_slope <- stats::coef(stats::lm(y ~ x, pc))[[2]]

  expect_gt(raw_slope, 2)             # the spurious pooled effect
  expect_lt(abs(within_slope), 0.3)   # the truth: no within-person effect

  # Each person's centered predictor now has mean zero.
  means <- tapply(pc$x, pc$id, mean)
  expect_true(all(abs(means) < 1e-8))
})

test_that("grand-centering does not remove it", {
  d <- simpson_panel()
  gc <- preprocess_panel(d, id = "id", time = "day", vars = "x", center = "grand")
  gc$y <- d$y
  expect_gt(stats::coef(stats::lm(y ~ x, gc))[[2]], 2)   # still spurious
})

test_that("person-scaling puts people on a common footing", {
  d <- simpson_panel()
  ps <- preprocess_panel(d, id = "id", time = "day", vars = "x",
                   center = "person", scale = "person")
  sds <- tapply(ps$x, ps$id, stats::sd)
  expect_true(all(abs(sds - 1) < 1e-8))
})

test_that("lags shift within a person and never across people", {
  d <- simpson_panel()
  lg <- preprocess_panel(d, id = "id", time = "day", vars = "x", lag = 1)

  expect_true("x_lag1" %in% names(lg))
  # The first occasion of every person has no predecessor.
  expect_true(all(is.na(lg$x_lag1[lg$day == 1])))
  # And the lag is that person's own previous value, not someone else's.
  p2 <- lg[lg$id == 2, ]
  p2 <- p2[order(p2$day), ]
  expect_equal(p2$x_lag1[-1], utils::head(p2$x, -1))
  expect_equal(nrow(lg), nrow(d))
})

test_that("multiple lags produce one column each", {
  d <- simpson_panel()
  lg <- preprocess_panel(d, id = "id", time = "day", vars = "x", lag = 1:2)
  expect_true(all(c("x_lag1", "x_lag2") %in% names(lg)))
  expect_true(all(is.na(lg$x_lag2[lg$day <= 2])))
})

test_that("lagging without a time column is refused", {
  d <- simpson_panel()
  expect_error(preprocess_panel(d, id = "id", vars = "x", lag = 1), "needs `time`")
  expect_error(
    preprocess_panel(d, id = "id", time = "day", vars = "x", lag = 0),
    "whole numbers >= 1"
  )
})

test_that("preprocessed data flows straight into a fitter", {
  d <- simpson_panel()
  prepped <- preprocess_panel(d, id = "id", time = "day", vars = "x",
                        center = "person", lag = 1)
  fit <- fit_lm(prepped, y = "y", x = c("x", "x_lag1"), id = "id",
                time = "day", scope = "pooled", min_train = 20)
  expect_s3_class(fit, "idiostats_fit")
  expect_true(all(is.finite(metrics(fit, overall = TRUE)$rmse)))
})

test_that("the remaining plots draw without error", {
  d <- simpson_panel()
  fit <- fit_ml(d, "y", "x", "id", time = "day", model = "ridge",
                min_train = 20)
  expect_silent(plot_predictions(fit, scope = "individual", n_subjects = 2L))
  expect_silent(plot_subjects(fit, scope = "individual"))

  g <- find_subgroups(d, "y", "x", "id", k = 2L, reps = 5L)
  expect_silent(plot_subgroups(g))
})

test_that("lag_max_gap refuses a lag that reaches too far back", {
  # A lag counts occasions, not elapsed time. With irregular sampling that
  # means "the previous occasion" is 1 day back for some rows and 37 for
  # others, and a lag-1 effect estimated across both is not one quantity.
  d <- data.frame(id = "a", day = c(1, 2, 3, 40, 41), v = c(10, 20, 30, 40, 50),
                  stringsAsFactors = FALSE)

  loose <- preprocess_panel(d, id = "id", time = "day", vars = "v", lag = 1)
  expect_equal(loose$v_lag1, c(NA, 10, 20, 30, 40))   # the 37-day jump is kept

  strict <- preprocess_panel(d, id = "id", time = "day", vars = "v", lag = 1,
                       lag_max_gap = 2)
  expect_equal(strict$v_lag1, c(NA, 10, 20, NA, 40))  # and now refused

  # Evenly spaced data is unaffected by the limit.
  even <- data.frame(id = "a", day = 1:5, v = c(10, 20, 30, 40, 50),
                     stringsAsFactors = FALSE)
  expect_equal(preprocess_panel(even, id = "id", time = "day", vars = "v", lag = 1,
                          lag_max_gap = 1)$v_lag1,
               preprocess_panel(even, id = "id", time = "day", vars = "v",
                          lag = 1)$v_lag1)

  expect_error(preprocess_panel(d, id = "id", time = "day", vars = "v", lag = 1,
                          lag_max_gap = -1),
               "`lag_max_gap` must be")
})
