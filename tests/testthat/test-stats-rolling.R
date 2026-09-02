roll_panel <- function(n_id = 3L, n_time = 40L) {
  set.seed(9)
  d <- data.frame(
    id = rep(seq_len(n_id), each = n_time),
    time = rep(seq_len(n_time), n_id),
    x1 = stats::rnorm(n_id * n_time),
    x2 = stats::rnorm(n_id * n_time)
  )
  d$y <- 0.8 * d$x1 - 0.4 * d$x2 + stats::rnorm(nrow(d), sd = 0.3)
  d
}

test_that("fit_rolling adds folds but keeps the tidy contract", {
  d <- roll_panel()
  fit <- fit_rolling(d, "y", c("x1", "x2"), "id", method = "lm",
                     time = "time", folds = 4L, min_train = 20)

  expect_s3_class(fit, "idiostats_fit")
  expect_true("fold" %in% names(predictions(fit)))
  expect_setequal(unique(predictions(fit)$fold), 1:4)
  expect_equal(fit$spec$folds, 4L)

  # Everything before `fold` is the standard prediction contract.
  expect_equal(head(names(predictions(fit)), 9L),
               c("scope", "model", "estimator", "subject", "subgroup", "row",
                 "observed", "predicted", "residual"))
  # Metrics pool across folds and keep the usual columns.
  expect_named(metrics(fit),
               c("scope", "model", "estimator", "subject", "subgroup", "n",
                 "rmse", "mae", "bias", "r_squared"))
  expect_true(all(metrics(fit, overall = TRUE)$n ==
                    4L * length(unique(d$id))))
})

test_that("each rolling fold trains only on the past", {
  d <- roll_panel()
  fit <- fit_rolling(d, "y", c("x1", "x2"), "id", method = "lm", time = "time",
                     initial = 30L, assess = 1L, step = 1L, folds = 3L,
                     min_train = 20)

  # Fold f tests the (initial + f)-th row of each person, and nothing earlier.
  pred <- predictions(fit, scope = "individual")
  tested_time <- d$time[pred$row]
  expect_setequal(unique(tested_time[pred$fold == 1L]), 31L)
  expect_setequal(unique(tested_time[pred$fold == 2L]), 32L)
  expect_setequal(unique(tested_time[pred$fold == 3L]), 33L)
})

test_that("fit_rolling works with the ml engine and tuning", {
  d <- roll_panel()
  fit <- fit_rolling(d, "y", c("x1", "x2"), "id", method = "ml",
                     model = "ridge", time = "time", folds = 3L,
                     min_train = 20, tune = TRUE)

  expect_equal(unique(metrics(fit)$model), "ridge")
  expect_true(all(is.finite(metrics(fit, overall = TRUE)$rmse)))
  expect_true(nrow(tuning(fit)) > 0L)
  expect_true("fold" %in% names(tuning(fit)))
})

test_that("an impossible rolling schedule is refused clearly", {
  d <- roll_panel()
  expect_error(
    fit_rolling(d, "y", c("x1", "x2"), "id", method = "lm", time = "time",
                folds = 50L, min_train = 20),
    "rolling schedule does not fit"
  )
})
