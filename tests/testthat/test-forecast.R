test_that("validate_forecast is deterministic for OLS VAR", {
  d <- synth_panel(n_id = 3, days = 5, beeps = 10, vars = c("A", "B", "C"),
                   seed = 501)
  f1 <- validate_forecast(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    estimator = "var", initial = 9, n_splits = 3,
    scale = FALSE, center_within = FALSE
  )
  f2 <- validate_forecast(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    estimator = "var", initial = 9, n_splits = 3,
    scale = FALSE, center_within = FALSE
  )

  expect_s3_class(f1, "forecast_result")
  expect_equal(f1$predictions, f2$predictions, tolerance = 1e-12)
  expect_named(f1$predictions,
               c("split", "original_row", "subject", "day", "beep",
                 "variable", "observed", "predicted", "residual",
                 "abs_error", "squared_error"))
  expect_named(f1$metrics, c("variable", "n", "mae", "rmse", "bias"))
  expect_true(any(f1$metrics$variable == ".overall"))
  expect_output(print(f1), "Idiographic Forecast Validation")
  expect_equal(as.data.frame(f1), f1$predictions)
})

test_that("validate_forecast predictions equal direct build_var matrix prediction", {
  d <- synth_single(n_t = 80, vars = c("A", "B", "C"), seed = 502)
  vars <- c("A", "B", "C")
  train <- d[d$day <= 5, , drop = FALSE]
  test <- d[d$day == 6, , drop = FALSE]

  fit <- build_var(train, vars = vars, id = "id", day = "day", beep = "beep",
                   scale = FALSE, center_within = FALSE)
  design <- idiographic:::.forecast_design(
    train, test, vars = vars, id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, delete_missings = TRUE
  )
  yhat <- design$data_l %*% t(fit$beta)
  colnames(yhat) <- vars

  fc <- validate_forecast(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    estimator = "var", initial = 5, n_splits = 1,
    scale = FALSE, center_within = FALSE
  )
  wide <- matrix(fc$predictions$predicted, ncol = length(vars), byrow = FALSE)
  colnames(wide) <- vars

  expect_equal(wide, yhat, tolerance = 1e-12, ignore_attr = TRUE)
})

test_that("validate_forecast uses the last training row as first assessment lag", {
  set.seed(504)
  d <- data.frame(A = stats::rnorm(40), B = stats::rnorm(40))
  fc <- validate_forecast(
    d, vars = c("A", "B"), estimator = "var", initial = 2, n_splits = 1,
    block_size = 10, scale = FALSE, center_within = FALSE
  )

  expect_true(21L %in% fc$predictions$original_row)
  expect_equal(sort(unique(fc$predictions$original_row)), 21:30)
})

test_that("validate_forecast supports graphical_var and row-block series", {
  d <- synth_single(n_t = 90, vars = c("A", "B", "C"), seed = 503)
  gv <- validate_forecast(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    estimator = "graphical_var", initial = 6, n_splits = 1,
    scale = FALSE, center_within = FALSE, n_lambda = 5
  )
  expect_equal(gv$n_success, 1L)
  expect_true(nrow(gv$predictions) > 0L)

  single <- d[, c("A", "B")]
  row_blocks <- validate_forecast(
    single, vars = c("A", "B"), estimator = "var", initial = 4,
    n_splits = 2, block_size = 10, scale = FALSE
  )
  expect_equal(row_blocks$n_success, 2L)
  expect_true(all(row_blocks$metrics$rmse >= 0))
})

test_that("validate_forecast validates split geometry", {
  d <- data.frame(id = 1, day = 1, beep = 1:20,
                  A = stats::rnorm(20), B = stats::rnorm(20))
  expect_error(
    validate_forecast(d, vars = c("A", "B"), id = "id", day = "day",
                      beep = "beep", initial = 1),
    "at least two ordered blocks|leave at least one"
  )
})
