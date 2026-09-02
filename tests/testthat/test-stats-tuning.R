panel <- function(n_id = 3L, n_time = 60L) {
  set.seed(11)
  d <- data.frame(
    id = rep(seq_len(n_id), each = n_time),
    time = rep(seq_len(n_time), n_id),
    x1 = stats::rnorm(n_id * n_time),
    x2 = stats::rnorm(n_id * n_time),
    x3 = stats::rnorm(n_id * n_time)
  )
  d$y <- 0.8 * d$x1 - 0.4 * d$x2 + stats::rnorm(nrow(d), sd = 0.3)
  d
}

test_that("tuning never sees the test rows", {
  d <- panel()
  fit <- fit_ml(d, "y", "x1:x3", "id", model = "ridge", time = "time",
                scope = "pooled", min_train = 20, tune = TRUE)

  # Candidates are scored on the validation block, so the tuning table's row
  # count must match the validation rows -- not the test rows the metrics use.
  n_test <- metrics(fit, scope = "pooled", overall = TRUE)$n
  n_tuned <- unique(tuning(fit)$n)

  expect_length(n_tuned, 1L)
  expect_false(identical(as.integer(n_tuned), as.integer(n_test)))
  expect_gt(n_tuned, 0L)
})

test_that("validation rows are carved out only when tuning", {
  d <- panel()
  prep_tuned <- idiographic:::.idio_prepare(d, "y", c("x1", "x2", "x3"), "id",
                                          time = "time", min_train = 20,
                                          valid_prop = 0.2)
  prep_plain <- idiographic:::.idio_prepare(d, "y", c("x1", "x2", "x3"), "id",
                                          time = "time", min_train = 20,
                                          valid_prop = 0)

  expect_true(any(prep_tuned$data$.idio_role == "valid"))
  expect_false(any(prep_plain$data$.idio_role == "valid"))

  # Test rows are identical either way: tuning must not move the goalposts.
  test_tuned <- prep_tuned$data$.idio_row[prep_tuned$data$.idio_role == "test"]
  test_plain <- prep_plain$data$.idio_row[prep_plain$data$.idio_role == "test"]
  expect_setequal(test_tuned, test_plain)
})

test_that("tuning reports a ranked grid and keeps only the winner elsewhere", {
  d <- panel()
  fit <- fit_ml(d, "y", "x1:x3", "id", model = c("ridge", "knn"),
                time = "time", scope = "pooled", min_train = 20, tune = TRUE,
                grid = list(ridge = list(lambda = c(0.1, 1, 5)),
                            knn = list(k = c(3, 5))))

  ridge_grid <- tuning(fit, model = "ridge")
  expect_equal(nrow(ridge_grid), 3L)
  expect_setequal(ridge_grid$value, c("0.1", "1", "5"))
  expect_equal(sort(ridge_grid$rank), 1:3)
  expect_equal(nrow(tuning(fit, model = "knn")), 2L)

  # metrics()/predictions() report the winner only: one row per model.
  expect_equal(nrow(metrics(fit, scope = "pooled", overall = TRUE)), 2L)
})

test_that("custom grids are validated", {
  d <- panel()
  expect_error(
    fit_ml(d, "y", "x1:x3", "id", model = "ridge", scope = "pooled",
           min_train = 20, tune = TRUE,
           grid = list(ridge = list(lambda = c(NA, NaN)))),
    "finite numeric"
  )
})
