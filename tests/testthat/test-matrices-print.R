# matrices() prints by default. Dependent packages and resampling loops need it
# silent, so `print = FALSE` must emit nothing and return the payload visibly.

test_that("matrices(print = FALSE) is silent and returns the same payload", {
  set.seed(21)
  d <- data.frame(id = 1, A = stats::rnorm(80), B = stats::rnorm(80),
                  C = stats::rnorm(80))
  fit <- fit_var(d, vars = c("A", "B", "C"), id = "id")

  quiet <- utils::capture.output(silent <- matrices(fit, print = FALSE))
  loud  <- utils::capture.output(printed <- matrices(fit))

  expect_length(quiet, 0L)
  expect_gt(length(loud), 0L)
  expect_identical(silent, printed)
  expect_true(is.list(silent))
  expect_true(all(vapply(silent, is.matrix, logical(1))))
})

test_that("print = FALSE reaches methods that delegate to another method", {
  set.seed(22)
  W <- matrix(c(0, 0.3, -0.2, 0), 2, 2,
              dimnames = list(c("A", "B"), c("A", "B")))
  net <- as_netobject(structure(
    list(weights = W, method = "relative", directed = TRUE),
    class = "cograph_network"))
  # matrices.netobject delegates to matrices.cograph_network.
  # NOTE: the value must be assigned inside capture.output(). print = FALSE
  # returns the list VISIBLY, so a bare call would be auto-printed by R and
  # capture.output() would record that, not any output from matrices() itself.
  expect_length(utils::capture.output(m <- matrices(net, print = FALSE)), 0L)
  expect_true(is.list(m))

  d <- data.frame(id = rep(1:2, each = 60), day = 1,
                  beep = rep(seq_len(60), 2),
                  A = stats::rnorm(120), B = stats::rnorm(120),
                  C = stats::rnorm(120))
  fits <- fit_var_each(d, vars = c("A", "B", "C"), id = "id",
                       day = "day", beep = "beep")
  # matrices.var_list delegates through .ido_pick_fit()
  expect_length(utils::capture.output(m2 <- matrices(fits, print = FALSE)), 0L)
  expect_true(is.list(m2))

  roll <- fit_rolling_var(d, vars = c("A", "B", "C"), id = "id", day = "day",
                          beep = "beep", window_size = 40L, step = 20L,
                          keep_fits = TRUE)
  # matrices.rolling_var_result delegates through .ido_pick_fit()
  expect_length(utils::capture.output(m3 <- matrices(roll, print = FALSE)), 0L)
  expect_true(is.list(m3))
})

test_that("`print` cannot be matched positionally or by partial name", {
  # `print` follows `...` in every method, so R requires the full name. A
  # pre-existing undocumented call like matrices(x, p = FALSE) previously put
  # `p` in `...` and ignored it; it must keep doing so rather than silently
  # becoming a request to suppress output.
  set.seed(27)
  d <- data.frame(id = 1, A = stats::rnorm(80), B = stats::rnorm(80),
                  C = stats::rnorm(80))
  fit <- fit_var(d, vars = c("A", "B", "C"), id = "id")
  expect_gt(length(utils::capture.output(m <- matrices(fit, p = FALSE))), 0L)
  expect_length(utils::capture.output(m2 <- matrices(fit, print = FALSE)), 0L)

  d2 <- data.frame(id = rep(1:2, each = 60), day = 1,
                   beep = rep(seq_len(60), 2),
                   A = stats::rnorm(120), B = stats::rnorm(120),
                   C = stats::rnorm(120))
  roll <- fit_rolling_var(d2, vars = c("A", "B", "C"), id = "id", day = "day",
                          beep = "beep", window_size = 40L, step = 20L,
                          keep_fits = TRUE)
  # positional fit/subject selection is unchanged
  expect_gt(length(utils::capture.output(m3 <- matrices(roll, 1L, 2L))), 0L)
})

test_that("print = TRUE remains the default for every method", {
  set.seed(23)
  d <- data.frame(id = 1, A = stats::rnorm(80), B = stats::rnorm(80),
                  C = stats::rnorm(80))
  fit <- fit_var(d, vars = c("A", "B", "C"), id = "id")
  expect_output(matrices(fit), "temporal")
})
